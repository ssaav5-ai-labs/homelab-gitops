#!/usr/bin/env python3
"""Poll Grafana Cloud Alertmanager and wake Hermes only for new firing alerts.

Run by Hermes' cron scheduler as a pre-check script (not in no-agent mode). The
script itself involves no model: on every 2-minute tick it fetches the firing
alerts, keeps the fingerprints it has already seen, and emits a final-line JSON
gate that tells the scheduler whether to wake the agent.

  {"wakeAgent": false}
  {"wakeAgent": true, "context": {"alerts": [...]}}

Standard library only. Reads GRAFANA_ALERTS_URL and GRAFANA_ALERTS_TOKEN from
the environment (the token is forwarded in, never printed).
"""
import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request

DEFAULT_STATE_PATH = "/opt/data/cron-state/grafana-alerts.json"
MAX_FIELD_CHARS = 500
MAX_ALERTS = 5
FETCH_TIMEOUT_SECONDS = 20
ERROR_REPORT_SECONDS = 3600


def _log_error(message):
    sys.stderr.write(message + "\n")


def load_state(path):
    try:
        with open(path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, ValueError):
        data = None
    if not isinstance(data, dict):
        data = {}
    fingerprints = data.get("fingerprints")
    if not isinstance(fingerprints, list):
        fingerprints = []
    last_error_ts = data.get("last_error_ts", 0.0)
    if not isinstance(last_error_ts, (int, float)):
        last_error_ts = 0.0
    return {"fingerprints": fingerprints, "last_error_ts": last_error_ts}


def save_state(path, state):
    directory = os.path.dirname(path)
    if directory and not os.path.isdir(directory):
        os.makedirs(directory, exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(state, fh)


def _truncate(value):
    if isinstance(value, str) and len(value) > MAX_FIELD_CHARS:
        return value[:MAX_FIELD_CHARS]
    return value


def _truncate_map(mapping):
    if not isinstance(mapping, dict):
        return {}
    return {str(key): _truncate(value) for key, value in mapping.items()}


def summarize_alert(alert):
    fingerprint = alert.get("fingerprint")
    if not fingerprint:
        return None
    return {
        "fingerprint": fingerprint,
        "labels": _truncate_map(alert.get("labels")),
        "annotations": _truncate_map(alert.get("annotations")),
        "startsAt": alert.get("startsAt"),
        "generatorURL": alert.get("generatorURL"),
    }


def fetch_alerts(url, token):
    request = urllib.request.Request(url, method="GET")
    request.add_header("Authorization", "Bearer " + token)
    request.add_header("Accept", "application/json")
    with urllib.request.urlopen(request, timeout=FETCH_TIMEOUT_SECONDS) as response:
        body = response.read().decode("utf-8")
    data = json.loads(body)
    if isinstance(data, dict):
        data = data.get("alerts", data)
    if not isinstance(data, list):
        raise ValueError("unexpected Grafana response shape")
    return data


def report_error(path, state, exc):
    now = time.time()
    if now - state.get("last_error_ts", 0.0) >= ERROR_REPORT_SECONDS:
        _log_error("grafana-alerts: failed to fetch alerts: %s" % exc)
        state["last_error_ts"] = now
        save_state(path, state)


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--fixture",
        help="read alerts from a JSON file instead of the API (for tests)",
    )
    parser.add_argument(
        "--state",
        default=DEFAULT_STATE_PATH,
        help="state file path (default: %(default)s)",
    )
    args = parser.parse_args(argv)

    state = load_state(args.state)
    seen = set(state["fingerprints"])

    if args.fixture:
        with open(args.fixture, "r", encoding="utf-8") as fh:
            raw = json.load(fh)
        if isinstance(raw, dict):
            raw = raw.get("alerts", raw)
        if not isinstance(raw, list):
            raw = []
        alerts = raw
    else:
        url = os.environ.get("GRAFANA_ALERTS_URL", "")
        token = os.environ.get("GRAFANA_ALERTS_TOKEN", "")
        if not url:
            _log_error("grafana-alerts: GRAFANA_ALERTS_URL is not set")
            return 2
        if not token:
            _log_error("grafana-alerts: GRAFANA_ALERTS_TOKEN is not set")
            return 2
        try:
            alerts = fetch_alerts(url, token)
        except (urllib.error.URLError, OSError, ValueError, json.JSONDecodeError) as exc:
            report_error(args.state, state, exc)
            print(json.dumps({"wakeAgent": False}))
            return 0

    summaries = [s for s in (summarize_alert(a) for a in alerts) if s]
    current = set(s["fingerprint"] for s in summaries)

    new_summaries = [s for s in summaries if s["fingerprint"] not in seen]

    state["fingerprints"] = sorted(current)
    state["last_error_ts"] = 0.0
    save_state(args.state, state)

    if not new_summaries:
        print(json.dumps({"wakeAgent": False}))
        return 0

    context = {"alerts": new_summaries[:MAX_ALERTS]}
    if len(new_summaries) > MAX_ALERTS:
        context["total"] = len(new_summaries)

    print(json.dumps({"wakeAgent": True, "context": context}))
    return 0


if __name__ == "__main__":
    sys.exit(main())