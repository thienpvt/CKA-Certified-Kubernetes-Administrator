#!/bin/bash
# cka-sim version — print version + optional git checksum

set -euo pipefail

VERSION="1.0.0-dev"
REVISION=""

if command -v git >/dev/null 2>&1; then
  REVISION=$(git -C "${CKA_SIM_ROOT:-.}" rev-parse --short HEAD 2>/dev/null || true)
fi

if [[ -n "$REVISION" ]]; then
  printf 'cka-sim v%s (%s)\n' "$VERSION" "$REVISION"
else
  printf 'cka-sim v%s\n' "$VERSION"
fi
