#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

FAIL=0
# `root` lives in bootstrap/root.yaml (not under apps/); these must not carry
# the resources finalizer because deleting them is what tears the cluster down
# (root) or would strand their state (argocd, prometheus-operator-crds).
EXEMPT="root argocd prometheus-operator-crds"

echo "=== Checking Argo CD app finalizers ==="

for app_file in apps/*.yaml; do
  name=$(grep -m1 '^  name:' "$app_file" | sed 's/^  name:\s*//')

  if [[ -z "$name" ]]; then
    echo "FAIL: $app_file has no metadata.name" >&2
    FAIL=1
    continue
  fi

  if [[ " $EXEMPT " == *" $name "* ]]; then
    echo "SKIP: $app_file ($name is exempt from the resources finalizer)"
    continue
  fi

  # Require the resources finalizer as one item in `metadata.finalizers`, but
  # allow additional finalizers (e.g. Argo CD's pre-delete finalizers) alongside it.
  if grep -qE '^[[:space:]]*-[[:space:]]*resources-finalizer\.argocd\.argoproj\.io[[:space:]]*$' "$app_file"; then
    echo "OK: $app_file has resources-finalizer.argocd.argoproj.io"
  else
    echo "FAIL: $app_file ($name) is missing resources-finalizer.argocd.argoproj.io" >&2
    FAIL=1
  fi
done

if (( FAIL )); then
  echo ""
  echo "Finalizer check FAILED." >&2
  exit 1
fi
echo "Finalizer check passed."
