#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$SCRIPT_DIR/platform/hermes/scripts/grafana-alerts.py"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

STATE="$TMP/state.json"
FAIL=0

run_script() {
  python3 "$SCRIPT" --fixture "$1" --state "$STATE" | tail -1
}

echo "=== grafana-alerts.py ==="

# 1. Empty list -> wakeAgent false.
printf '[]\n' > "$TMP/empty.json"
out=$(run_script "$TMP/empty.json")
if [[ "$out" == '{"wakeAgent": false}' ]]; then
  echo "OK: empty list -> wakeAgent false"
else
  echo "FAIL: empty list -> wanted wakeAgent false, got: $out" >&2
  FAIL=1
fi

# 2. A brand-new alert -> wakeAgent true.
cat > "$TMP/one.json" <<'JSON'
[{"fingerprint":"1111111111111111","labels":{"alertname":"TestAlert"},"annotations":{"summary":"boom"},"startsAt":"2026-11-05T00:00:00Z","generatorURL":"https://example.test"}]
JSON
out=$(run_script "$TMP/one.json")
if printf '%s\n' "$out" | grep -q '"wakeAgent": true'; then
  echo "OK: new alert -> wakeAgent true"
else
  echo "FAIL: new alert did not wake the agent, got: $out" >&2
  FAIL=1
fi

# 3. The same alert again -> wakeAgent false (fingerprint already seen).
out=$(run_script "$TMP/one.json")
if [[ "$out" == '{"wakeAgent": false}' ]]; then
  echo "OK: same alert again -> wakeAgent false"
else
  echo "FAIL: repeated alert should be silent, got: $out" >&2
  FAIL=1
fi

# 4. A 501-character annotation is cut to 500.
long_annotation=$(printf 'x%.0s' {1..501})
cat > "$TMP/long.json" <<JSON
[{"fingerprint":"2222222222222222","labels":{"alertname":"LongAlert"},"annotations":{"summary":"$long_annotation"},"startsAt":"2026-11-05T00:00:00Z","generatorURL":"https://example.test"}]
JSON
out=$(run_script "$TMP/long.json")
ann_len=$(printf '%s\n' "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(len(d["context"]["alerts"][0]["annotations"]["summary"]))')
if [[ "$ann_len" == "500" ]]; then
  echo "OK: 501-char annotation -> cut to 500"
else
  echo "FAIL: annotation length was $ann_len, wanted 500" >&2
  FAIL=1
fi

# 5. Missing URL -> non-zero exit + an error line, and no wakeAgent JSON.
ERRSTATE="$TMP/err-state.json"
if env -u GRAFANA_ALERTS_URL -u GRAFANA_ALERTS_TOKEN \
     python3 "$SCRIPT" --state "$ERRSTATE" >"$TMP/err-out1.txt" 2>"$TMP/err-err1.txt"; then
  echo "FAIL: missing URL should exit non-zero" >&2
  FAIL=1
elif ! grep -q "GRAFANA_ALERTS_URL is not set" "$TMP/err-err1.txt"; then
  echo "FAIL: missing URL should print an error line" >&2
  FAIL=1
elif [[ -s "$TMP/err-out1.txt" ]]; then
  echo "FAIL: missing URL should not print a wakeAgent gate" >&2
  FAIL=1
else
  echo "OK: missing URL -> non-zero exit + error line"
fi

# 6. Second error within the window -> quiet (exit 0, no output).
if ! env -u GRAFANA_ALERTS_URL -u GRAFANA_ALERTS_TOKEN \
       python3 "$SCRIPT" --state "$ERRSTATE" >"$TMP/err-out2.txt" 2>"$TMP/err-err2.txt"; then
  echo "FAIL: rate-limited error should exit 0" >&2
  FAIL=1
elif [[ -s "$TMP/err-out2.txt" ]] || [[ -s "$TMP/err-err2.txt" ]]; then
  echo "FAIL: rate-limited error should be quiet" >&2
  FAIL=1
else
  echo "OK: rate-limited error -> quiet"
fi

if (( FAIL )); then
  echo ""
  echo "grafana-alerts test FAILED." >&2
  exit 1
fi
echo "grafana-alerts test passed."