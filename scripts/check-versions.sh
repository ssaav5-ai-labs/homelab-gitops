#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

source bootstrap/versions.env
FAIL=0

if [[ -f apps/argocd.yaml ]]; then
  echo "=== Checking ARGOCD_CHART_VERSION vs apps/argocd.yaml ==="
  APP_REV=$(grep 'targetRevision:' apps/argocd.yaml | head -1 | sed 's/.*targetRevision:\s*//' | tr -d '"')
  if [[ "$APP_REV" != "$ARGOCD_CHART_VERSION" ]]; then
    echo "FAIL: ARGOCD_CHART_VERSION=$ARGOCD_CHART_VERSION but apps/argocd.yaml targetRevision=$APP_REV" >&2
    FAIL=1
  else
    echo "OK: ARGOCD_CHART_VERSION=$ARGOCD_CHART_VERSION matches apps/argocd.yaml"
  fi

  echo ""
  echo "=== Checking KSOPS_VERSION vs bootstrap/argocd/values.yaml ==="
  VALUES_TAG=$(grep 'viaductoss/ksops:' bootstrap/argocd/values.yaml | sed 's/.*viaductoss\/ksops://' | tr -d '"')
  if [[ "$VALUES_TAG" != "$KSOPS_VERSION" ]]; then
    echo "FAIL: KSOPS_VERSION=$KSOPS_VERSION but values.yaml tag=$VALUES_TAG" >&2
    FAIL=1
  else
    echo "OK: KSOPS_VERSION=$KSOPS_VERSION matches values.yaml"
  fi

  echo ""
  echo "=== Checking K8S_MONITORING_CHART_VERSION vs apps/monitoring.yaml ==="
  MON_REV=$(grep -A1 'k8s-monitoring' apps/monitoring.yaml | grep 'targetRevision' | sed 's/.*targetRevision:\s*//' | tr -d '"')
  if [[ "$MON_REV" != "$K8S_MONITORING_CHART_VERSION" ]]; then
    echo "FAIL: K8S_MONITORING_CHART_VERSION=$K8S_MONITORING_CHART_VERSION but apps/monitoring.yaml targetRevision=$MON_REV" >&2
    FAIL=1
  else
    echo "OK: K8S_MONITORING_CHART_VERSION=$K8S_MONITORING_CHART_VERSION matches apps/monitoring.yaml"
  fi

  echo ""
  echo "=== Checking PROM_OPERATOR_CRDS_CHART_VERSION vs apps/prometheus-operator-crds.yaml ==="
  CRDS_REV=$(grep 'targetRevision:' apps/prometheus-operator-crds.yaml | sed 's/.*targetRevision:\s*//' | tr -d '"')
  if [[ "$CRDS_REV" != "$PROM_OPERATOR_CRDS_CHART_VERSION" ]]; then
    echo "FAIL: PROM_OPERATOR_CRDS_CHART_VERSION=$PROM_OPERATOR_CRDS_CHART_VERSION but apps/prometheus-operator-crds.yaml targetRevision=$CRDS_REV" >&2
    FAIL=1
  else
    echo "OK: PROM_OPERATOR_CRDS_CHART_VERSION=$PROM_OPERATOR_CRDS_CHART_VERSION matches apps/prometheus-operator-crds.yaml"
  fi

  echo ""
  echo "=== Checking HERMES_IMAGE vs platform/hermes/deployment.yaml ==="
  HERMES_DEPLOYED=$(grep 'nousresearch/hermes-agent' platform/hermes/deployment.yaml | sed 's/.*image:\s*//' | sort -u)
  if [[ "$HERMES_DEPLOYED" != "$HERMES_IMAGE" ]]; then
    echo "FAIL: HERMES_IMAGE=$HERMES_IMAGE but deployment.yaml image=$HERMES_DEPLOYED" >&2
    FAIL=1
  else
    echo "OK: HERMES_IMAGE=$HERMES_IMAGE matches deployment.yaml"
  fi

  echo ""
  echo "=== Checking GIT_SYNC_IMAGE vs platform/hermes/deployment.yaml ==="
  GIT_SYNC_DEPLOYED=$(grep 'registry.k8s.io/git-sync' platform/hermes/deployment.yaml | sed 's/.*image:\s*//')
  if [[ "$GIT_SYNC_DEPLOYED" != "$GIT_SYNC_IMAGE" ]]; then
    echo "FAIL: GIT_SYNC_IMAGE=$GIT_SYNC_IMAGE but deployment.yaml image=$GIT_SYNC_DEPLOYED" >&2
    FAIL=1
  else
    echo "OK: GIT_SYNC_IMAGE=$GIT_SYNC_IMAGE matches deployment.yaml"
  fi

  echo ""
  echo "=== Checking KUBECTL_VERSION vs platform/hermes/deployment.yaml ==="
  KUBECTL_DEPLOYED=$(grep 'KUBECTL_VERSION=' platform/hermes/deployment.yaml | sed 's/.*KUBECTL_VERSION=//' | tr -d ';')
  if [[ "$KUBECTL_DEPLOYED" != "$KUBECTL_VERSION" ]]; then
    echo "FAIL: KUBECTL_VERSION=$KUBECTL_VERSION but deployment.yaml version=$KUBECTL_DEPLOYED" >&2
    FAIL=1
  else
    echo "OK: KUBECTL_VERSION=$KUBECTL_VERSION matches deployment.yaml"
  fi

  echo ""
  echo "=== Checking POSTGRES_IMAGE vs platform/llm-gateway/postgres.yaml ==="
  POSTGRES_DEPLOYED=$(grep 'image:' platform/llm-gateway/postgres.yaml | sed 's/.*image:\s*//')
  if [[ "$POSTGRES_DEPLOYED" != "$POSTGRES_IMAGE" ]]; then
    echo "FAIL: POSTGRES_IMAGE=$POSTGRES_IMAGE but postgres.yaml image=$POSTGRES_DEPLOYED" >&2
    FAIL=1
  else
    echo "OK: POSTGRES_IMAGE=$POSTGRES_IMAGE matches postgres.yaml"
  fi

  echo ""
  echo "=== Checking SRE_CREWS_IMAGE vs platform/sre-crews/deployment.yaml ==="
  SRE_CREWS_DEPLOYED=$(grep 'ghcr.io/ssaav5-ai-labs/sre-crews' platform/sre-crews/deployment.yaml | sed 's/.*image:\s*//')
  if [[ "$SRE_CREWS_DEPLOYED" != "$SRE_CREWS_IMAGE" ]]; then
    echo "FAIL: SRE_CREWS_IMAGE=$SRE_CREWS_IMAGE but deployment.yaml image=$SRE_CREWS_DEPLOYED" >&2
    FAIL=1
  else
    echo "OK: SRE_CREWS_IMAGE=$SRE_CREWS_IMAGE matches deployment.yaml"
  fi

  echo ""
  echo "=== Checking SRE_CREWS_IMAGE vs lab-actions-deployment.yaml ==="
  SRE_CREWS_DEPLOYED_LAB=$(grep 'ghcr.io/ssaav5-ai-labs/sre-crews' platform/sre-crews/lab-actions-deployment.yaml | sed 's/.*image:\s*//')
  if [[ "$SRE_CREWS_DEPLOYED_LAB" != "$SRE_CREWS_IMAGE" ]]; then
    echo "FAIL: SRE_CREWS_IMAGE=$SRE_CREWS_IMAGE but lab-actions-deployment.yaml image=$SRE_CREWS_DEPLOYED_LAB" >&2
    FAIL=1
  else
    echo "OK: SRE_CREWS_IMAGE=$SRE_CREWS_IMAGE matches lab-actions-deployment.yaml"
  fi

  echo ""
  echo "=== Checking ghcr.io image digests resolve ==="
  if command -v curl >/dev/null 2>&1; then
    while IFS= read -r line; do
      REPO=$(sed 's#.*ghcr.io/##; s/:.*//' <<< "$line")
      DIGEST=$(grep -oP 'sha256:[a-f0-9]{64}' <<< "$line" | head -1)
      if [[ -n "$DIGEST" ]]; then
        TOKEN=$(curl -sf "https://ghcr.io/token?scope=repository:${REPO}:pull" | sed 's/.*"token":"//; s/".*//' 2>/dev/null) || true
        HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer ${TOKEN:-}" "https://ghcr.io/v2/${REPO}/manifests/${DIGEST}" 2>/dev/null) || HTTP_CODE="000"
        if [[ "$HTTP_CODE" != "200" ]]; then
          echo "FAIL: ghcr.io/${REPO}@${DIGEST} returned HTTP $HTTP_CODE" >&2
          FAIL=1
        else
          echo "OK: ghcr.io/${REPO}@${DIGEST} resolves (HTTP 200)"
        fi
      fi
    done < <(grep 'ghcr.io' bootstrap/versions.env)
  else
    echo "SKIP: curl not available, cannot check ghcr.io digest resolution"
  fi

  echo ""
  echo "=== Checking K8S_MCP_IMAGE vs platform/sre-crews/deployment.yaml ==="
  K8S_MCP_DEPLOYED=$(grep 'quay.io/containers/kubernetes_mcp_server' platform/sre-crews/deployment.yaml | sed 's/.*image:\s*//')
  if [[ "$K8S_MCP_DEPLOYED" != "$K8S_MCP_IMAGE" ]]; then
    echo "FAIL: K8S_MCP_IMAGE=$K8S_MCP_IMAGE but deployment.yaml image=$K8S_MCP_DEPLOYED" >&2
    FAIL=1
  else
    echo "OK: K8S_MCP_IMAGE=$K8S_MCP_IMAGE matches deployment.yaml"
  fi

  echo ""
  echo "=== Checking GRAFANA_MCP_IMAGE vs platform/sre-crews/deployment.yaml ==="
  GRAFANA_MCP_DEPLOYED=$(grep 'grafana/mcp-grafana' platform/sre-crews/deployment.yaml | sed 's/.*image:\s*//')
  if [[ "$GRAFANA_MCP_DEPLOYED" != "$GRAFANA_MCP_IMAGE" ]]; then
    echo "FAIL: GRAFANA_MCP_IMAGE=$GRAFANA_MCP_IMAGE but deployment.yaml image=$GRAFANA_MCP_DEPLOYED" >&2
    FAIL=1
  else
    echo "OK: GRAFANA_MCP_IMAGE=$GRAFANA_MCP_IMAGE matches deployment.yaml"
  fi
else
  echo "apps/argocd.yaml does not exist yet (step 7); skipping version checks."
fi

if (( FAIL )); then
  echo ""
  echo "Version check FAILED." >&2
  exit 1
fi
echo "Version check passed."