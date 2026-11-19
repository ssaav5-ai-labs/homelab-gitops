#!/usr/bin/env bash
set -euo pipefail

# Print the sha256 manifest digest for a GHCR image tag via the GitHub API.
#
# Usage:
#   scripts/image-digest.sh IMAGE TAG
#
#   IMAGE  ghcr.io/<org>/<package>  (also accepts <org>/<package> or a bare <package>,
#                                     defaulting the org to ssaav5-ai-labs)
#   TAG    image tag to resolve, e.g. sha-a1e18e8
#
# Prints "sha256:…" on stdout and exits 0 on success; exits 1 if the tag is not found.

if [[ $# -ne 2 ]]; then
  echo "usage: $0 IMAGE TAG" >&2
  exit 2
fi

IMAGE="$1"
TAG="$2"

case "$IMAGE" in
  */*/*)  # host/org/package -> drop the host
    ORG="${IMAGE#*/}"; ORG="${ORG%%/*}"
    PACKAGE="${IMAGE##*/}"
    ;;
  */*)    # org/package
    ORG="${IMAGE%%/*}"
    PACKAGE="${IMAGE##*/}"
    ;;
  *)      # bare package name -> default org
    ORG="ssaav5-ai-labs"
    PACKAGE="$IMAGE"
    ;;
esac

DIGEST="$(gh api "/orgs/${ORG}/packages/container/${PACKAGE}/versions?per_page=100" \
  | jq -r --arg tag "$TAG" \
      '.[] | select((.metadata.container.tags // []) | index($tag)) | .name' \
  | head -n 1)"

if [[ -z "$DIGEST" ]]; then
  echo "tag ${TAG} not found for ghcr.io/${ORG}/${PACKAGE}" >&2
  exit 1
fi

printf '%s\n' "$DIGEST"
