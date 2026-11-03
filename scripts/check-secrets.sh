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
    if ! grep -q '^sops:' "$f"; then
      echo "FAIL: $f missing sops: block" >&2
      FAIL=1
    fi

    # No recognizable plaintext key anywhere in the file (values only print line numbers).
    if grep -qE 'sk-or-|sk-lf-' "$f"; then
      echo "FAIL: $f contains a plaintext key at line(s): $(grep -nE 'sk-or-|sk-lf-' "$f" | cut -d: -f1 | tr '\n' ' ')" >&2
      FAIL=1
    fi

    # Every value under stringData:/data: must be a SOPS ENC[...] blob.
    if ! awk '
      /^(stringData|data):[[:space:]]*$/ { inblock=1; next }
      inblock && /^[^[:space:]]/ { inblock=0 }
      inblock && /^[[:space:]]+[^[:space:]#][^:]*:/ {
        v=$0
        sub(/^[[:space:]]+[^:]*:[[:space:]]*/, "", v)
        gsub(/^["\x27]|["\x27]$/, "", v)
        if (v !~ /^ENC\[/) {
          k=$0
          sub(/^[[:space:]]+/, "", k)
          sub(/:.*/, "", k)
          print "FAIL: " FILENAME ": non-ENC value under key " k
          bad=1
        }
      }
      END { exit bad }
    ' "$f"; then
      FAIL=1
    fi
  done
  if (( ! FAIL )); then
    echo "All encrypted files have sops: block and ENC[...] values."
  fi
fi

if (( FAIL )); then
  echo ""
  echo "Secrets check FAILED." >&2
  exit 1
fi
echo "Secrets check passed."
