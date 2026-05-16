#!/bin/bash
# cka-sim/tests/exam/blueprint_validate.sh — verify blueprint validation rules.
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"

source "$CKA_SIM_ROOT/tests/lib/assert.sh"

case_failed=0

REAL_ROOT="$CKA_SIM_ROOT"
export CKA_SIM_ROOT="$REAL_ROOT/tests/fixtures/exam"

source "$REAL_ROOT/lib/exam-blueprint.sh"

FIXTURES="$REAL_ROOT/tests/fixtures/exam"
TMP_DIR=$(mktemp -d -t cka-sim-bp-validate-XXXXXX)

# --- Test 1: good manifest passes ---
set +e
cka_sim::blueprint::validate "$FIXTURES/blueprint-mock-alpha.yaml" 2>/dev/null
rc=$?
set -e

if [[ "$rc" -ne 0 ]]; then
  err "Test 1: good manifest should pass validation (rc=$rc)"
  case_failed=1
else
  ok "Test 1: good manifest passes validation"
fi

# --- Test 2: bad count (16 questions) ---
head -n 3 "$FIXTURES/blueprint-mock-alpha.yaml" > "$TMP_DIR/bad-count.yaml"
# Copy weighting block
sed -n '/weighting:/,/^questions:/p' "$FIXTURES/blueprint-mock-alpha.yaml" | head -n -1 >> "$TMP_DIR/bad-count.yaml"
cat >> "$TMP_DIR/bad-count.yaml" <<'EOF'
questions:
  - pack: mock-pack-alpha
    slug: 01-fake
  - pack: mock-pack-alpha
    slug: 02-fake
  - pack: mock-pack-alpha
    slug: 03-fake
  - pack: mock-pack-alpha
    slug: 04-fake
  - pack: mock-pack-alpha
    slug: 05-fake
  - pack: mock-pack-alpha
    slug: 06-fake
  - pack: mock-pack-alpha
    slug: 07-fake
  - pack: mock-pack-alpha
    slug: 08-fake
  - pack: mock-pack-alpha
    slug: 09-fake
  - pack: mock-pack-alpha
    slug: 10-fake
  - pack: mock-pack-alpha
    slug: 11-fake
  - pack: mock-pack-alpha
    slug: 12-fake
  - pack: mock-pack-alpha
    slug: 13-fake
  - pack: mock-pack-alpha
    slug: 14-fake
  - pack: mock-pack-alpha
    slug: 15-fake
  - pack: mock-pack-alpha
    slug: 16-fake
EOF

set +e
out=$(cka_sim::blueprint::validate "$TMP_DIR/bad-count.yaml" 2>&1)
rc=$?
set -e

if [[ "$rc" -eq 0 ]]; then
  err "Test 2: bad-count manifest should fail (got rc=0)"
  case_failed=1
else
  ok "Test 2: bad-count manifest rejected (rc=$rc)"
fi

# --- Test 3: duplicate (pack, slug) ---
# Copy good manifest but duplicate the last entry
cp "$FIXTURES/blueprint-mock-alpha.yaml" "$TMP_DIR/bad-dupes.yaml"
# Replace slug 17-fake with 01-fake (creates a duplicate)
sed -i 's/slug: 17-fake/slug: 01-fake/' "$TMP_DIR/bad-dupes.yaml"

set +e
out=$(cka_sim::blueprint::validate "$TMP_DIR/bad-dupes.yaml" 2>&1)
rc=$?
set -e

if [[ "$rc" -eq 0 ]]; then
  err "Test 3: duplicate manifest should fail (got rc=0)"
  case_failed=1
else
  ok "Test 3: duplicate manifest rejected (rc=$rc)"
fi

# Cleanup
rm -rf "$TMP_DIR"
export CKA_SIM_ROOT="$REAL_ROOT"
exit "$case_failed"
