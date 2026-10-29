#!/usr/bin/env bash
set -euo pipefail

FAIL=0

echo "=== Checking for plain kind: Secret in non-encrypted YAML ==="
PLAIN=$(grep -rl 'kind:\s*Secret' --include='*.yaml' --include='*.yml' . 2>/dev/null | grep -v '\.enc\.yaml' | grep -v '\.enc\.yml' || true)
if [[ -n "$PLAIN" ]]; then
  echo "FAIL: plain kind: Secret found in:" >&2
  echo "$PLAIN" >&2
  FAIL=1
else
  echo "OK: no plain kind: Secret outside *.enc.yaml"
fi

echo ""
echo "=== Checking encrypted files ==="
ENC_FILES=$(find . -name '*.enc.yaml' -o -name '*.enc.yml' 2>/dev/null || true)
if [[ -z "$ENC_FILES" ]]; then
  echo "No encrypted files found (OK for now)."
else
  for f in $ENC_FILES; do
    if ! head -5 "$f" | grep -q '^sops:'; then
      echo "FAIL: $f missing top-level sops: block" >&2
      FAIL=1
    fi
  done
  echo "All encrypted files have sops: block."
fi

if (( FAIL )); then
  echo ""
  echo "Secrets check FAILED." >&2
  exit 1
fi
echo "Secrets check passed."