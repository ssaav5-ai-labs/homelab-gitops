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
else
  echo "apps/argocd.yaml does not exist yet (step 7); skipping version checks."
fi

if (( FAIL )); then
  echo ""
  echo "Version check FAILED." >&2
  exit 1
fi
echo "Version check passed."