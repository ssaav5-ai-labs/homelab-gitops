#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

source bootstrap/versions.env

if [[ ! -f "$SOPS_AGE_KEY_FILE" ]]; then
  echo "ERROR: SOPS_AGE_KEY_FILE ($SOPS_AGE_KEY_FILE) does not exist." >&2
  exit 1
fi

echo "=== Creating argocd namespace ==="
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

echo "=== Creating sops-age Secret (if missing) ==="
if kubectl -n argocd get secret sops-age >/dev/null 2>&1; then
  echo "sops-age Secret already exists, skipping."
else
  kubectl -n argocd create secret generic sops-age --from-file=keys.txt="$SOPS_AGE_KEY_FILE"
  echo "sops-age Secret created."
fi

echo "=== Installing Argo CD ==="
helm repo add argo https://argoproj.github.io/argo-helm --force-update
helm upgrade --install argocd argo/argo-cd \
  --version "$ARGOCD_CHART_VERSION" \
  -n argocd \
  -f bootstrap/argocd/values.yaml \
  --wait --timeout 10m

echo ""
echo "=== Argo CD installed ==="

if [[ -f bootstrap/project.yaml ]] && [[ -f bootstrap/root.yaml ]]; then
  if git show origin/main:bootstrap/project.yaml >/dev/null 2>&1 && \
     git show origin/main:bootstrap/root.yaml >/dev/null 2>&1; then
    echo "=== Applying project and root app (already on main) ==="
    kubectl apply -f bootstrap/project.yaml
    kubectl apply -f bootstrap/root.yaml
    echo "Project and root app applied."
  else
    echo "Skipping project/root: not yet on origin/main (step 7)."
  fi
else
  echo "Skipping project/root: files don't exist yet (step 7)."
fi