# Hermes cron jobs

Cron jobs live in Hermes' own state DB (`/opt/data`), not in this GitOps repo. They are
created once by hand and re-created only if the PVC is rebuilt. This file records the
exact commands so a rebuild is reproducible.

Run these from inside the Hermes pod (the operator runs the exec):

```bash
kubectl exec -it -n hermes deploy/hermes -- hermes cron list
```

## Grafana Cloud alert poller

Polls Grafana Cloud Alertmanager every 2 minutes via a pre-check script
(`grafana-alerts.py`) that only wakes the agent when there are **new** firing alerts
(fingerprint-tagged in `/opt/data/cron-state/grafana-alerts.json`). When it wakes, the
agent runs the `alert-triage` skill and the result is delivered to the Slack home channel
(`#homelab-alerts`).

```bash
kubectl exec -it -n hermes deploy/hermes -- hermes cron create "every 2m" \
  --script grafana-alerts.py \
  --skill alert-triage \
  --deliver slack \
  --name "grafana-alerts" \
  "Triage the new firing Grafana Cloud alerts with the alert-triage skill."
```

Env wiring:

- `GRAFANA_ALERTS_URL` — in `managed/.env` (non-secret). The stack hostname is a
  placeholder (`<grafana-cloud-stack>`) that must be replaced with the real Grafana Cloud
  stack before the poller can reach it.
- `GRAFANA_ALERTS_TOKEN` — in `secret.enc.yaml`, forwarded to the script via
  `terminal.env_passthrough`.

Verify:

```bash
kubectl exec -it -n hermes deploy/hermes -- hermes cron list
kubectl exec -it -n hermes deploy/hermes -- hermes cron run grafana-alerts
```

## Webhook (future in-lab alert manager)

The `alerts` webhook route is already defined in `managed/config.yaml`
(`platforms.webhook.extra.routes.alerts`) and serves
`POST http://hermes-webhook.hermes.svc:8644/webhooks/alerts` (ingress from the
`monitoring` namespace only). It loads `alert-triage` and delivers to Slack. The HMAC
secret is `WEBHOOK_SECRET` in `secret.enc.yaml`; the sender must sign with it
(`X-Webhook-Signature-V2` + `X-Webhook-Timestamp`).
