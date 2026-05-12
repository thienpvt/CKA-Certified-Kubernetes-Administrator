#!/bin/bash
# lint_deprecated_strings.sh — verifies the deprecated-strings lint fails on
# forbidden-string hits outside carveouts and skips legitimate comment/prose
# references. Creates a fake packs/ tree under a tmpdir and points
# CKA_SIM_LINT_PACKS_DIR at it.
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"
# shellcheck source=../lib/assert.sh disable=SC1091
source "$CKA_SIM_ROOT/tests/lib/assert.sh"

case_failed=0

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fake_pack="$tmp/packs/fake/q"
mkdir -p "$fake_pack"

# --- Fixture 1: hit.yaml -- forbidden string in a YAML block, NOT a comment -> FAIL ---
cat > "$fake_pack/hit.yaml" <<'EOF'
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: legacy-psp
EOF

# --- Fixture 2: hit.md -- fenced yaml code block containing gitRepo: -> FAIL ---
cat > "$fake_pack/hit.md" <<'EOF'
# Sample broken manifest

```yaml
spec:
  volumes:
    - gitRepo:
        repository: https://example.org/repo
```
EOF

# --- Fixture 3: miss.yaml -- forbidden string is entirely within a comment -> skip ---
cat > "$fake_pack/miss.yaml" <<'EOF'
# historical reference: policy/v1beta1 was removed in v1.25
apiVersion: policy/v1
kind: PodDisruptionBudget
EOF

# --- Fixture 4: miss.md -- forbidden string in prose outside any fence -> skip ---
cat > "$fake_pack/miss.md" <<'EOF'
# CRI history

The old --container-runtime=remote flag is removed. In v1.35 only
--container-runtime-endpoint remains. dockershim was removed in v1.24.
EOF

# --- Run the lint against the fake tree ---
CKA_SIM_LINT_PACKS_DIR="$tmp/packs" bash "$CKA_SIM_ROOT/scripts/lint-deprecated-strings.sh" >/dev/null 2>&1
rc=$?

# Expected: at least 2 failures (hit.yaml has policy/v1beta1 + PodSecurityPolicy;
# hit.md has gitRepo: inside a yaml fence). Exact count depends on how many of
# the five forbidden patterns each hit file touches; assert rc >= 2 and
# miss files contribute 0.
expect_match "$rc" "^[1-9][0-9]*$" "lint exits non-zero on fixtures with real hits (rc=$rc)" || case_failed=1
if (( rc < 2 )); then
  expect_eq "$rc" ">=2" "lint reports at least 2 hits (one per hit file)"
  case_failed=1
fi

# --- Miss-only control: the two miss files in isolation must pass (rc=0) ---
miss_tmp=$(mktemp -d)
trap 'rm -rf "$tmp" "$miss_tmp"' EXIT
mkdir -p "$miss_tmp/packs/fake/q"
cp "$fake_pack/miss.yaml" "$fake_pack/miss.md" "$miss_tmp/packs/fake/q/"

CKA_SIM_LINT_PACKS_DIR="$miss_tmp/packs" bash "$CKA_SIM_ROOT/scripts/lint-deprecated-strings.sh" >/dev/null 2>&1
rc_miss=$?
expect_eq "$rc_miss" "0" "lint exits 0 when only carveout-covered references are present" || case_failed=1

exit "$case_failed"
