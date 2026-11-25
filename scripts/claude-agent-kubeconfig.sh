#!/usr/bin/env bash
# Mint a short-lived, read-only kubeconfig for Claude Code on the devbox
# (ADR-0038 phase 2). Run it yourself with your admin kubeconfig; never by an agent.
# The token goes straight into the output file and is never printed.
#
#   scripts/claude-agent-kubeconfig.sh [OUT_FILE] [DURATION]
#   default OUT_FILE: ./claude-agent.kubeconfig   default DURATION: 720h (30 days)
#
# Then copy OUT_FILE to the devbox as ~/.kube/config for the agent user and
# delete the local copy. Re-run before it expires.
set -euo pipefail

OUT="${1:-./claude-agent.kubeconfig}"
DURATION="${2:-720h}"
NS=agent-access
SA=claude-agent
VIP_SERVER="https://192.168.86.210:6443"

umask 077
TOKEN="$(kubectl -n "$NS" create token "$SA" --duration="$DURATION")"
CA_DATA="$(kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')"

cat > "$OUT" <<KUBECONFIG
apiVersion: v1
kind: Config
clusters:
  - name: homelab
    cluster:
      server: ${VIP_SERVER}
      certificate-authority-data: ${CA_DATA}
users:
  - name: ${SA}
    user:
      token: ${TOKEN}
contexts:
  - name: homelab-readonly
    context:
      cluster: homelab
      user: ${SA}
current-context: homelab-readonly
KUBECONFIG
unset TOKEN

echo "Wrote ${OUT} (valid ${DURATION}). Check it: KUBECONFIG=${OUT} kubectl auth can-i get secrets -A   # must say no"
