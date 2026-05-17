#!/bin/bash
# cka-sim/tests/cases/lint_trap_coverage.sh — Phase 12 LINT-01 synthetic regression.
# Asserts cka-sim/scripts/lint-trap-coverage.sh:
#   1. Exits 0 with "trap coverage OK" on a clean fixture (one declared trap, one record_trap call).
#   2. Exits 1 with the orphan citation when an orphan id is added to metadata.yaml `traps:` and
#      no matching `record_trap <id>` exists in the sibling grade.sh.
#   3. Treats a grade.sh using the dynamic `record_trap "$var"` form as covered (warn, not err).
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"
# shellcheck source=../lib/assert.sh disable=SC1091
source "$CKA_SIM_ROOT/tests/lib/assert.sh"

case_failed=0

# ---- helpers ----
_seed_question() {
  # _seed_question <root> <domain> <q-name> <metadata-traps-block> <grade-record-block>
  local root="$1" domain="$2" qname="$3" traps_block="$4" record_block="$5"
  mkdir -p "$root/$domain/$qname"
  cat > "$root/$domain/$qname/metadata.yaml" <<METAEOF
id: $domain-$qname
domain: $domain
estimatedMinutes: 5
verified_against: "1.35"
$traps_block
references: []
METAEOF
  cat > "$root/$domain/$qname/grade.sh" <<GRADEEOF
#!/bin/bash
# synthetic fixture grade.sh
set -uo pipefail
$record_block
GRADEEOF
  chmod +x "$root/$domain/$qname/grade.sh"
}

# ---- branch 1: clean fixture (literal id, matches) ----
root_clean=$(mktemp -d -t lint-trap-cov-clean-XXXXXX)
_seed_question "$root_clean" "storage" "01-clean" \
'traps:
  - synthetic-clean-trap' \
'cka_sim::grade::record_trap synthetic-clean-trap'

out=$(CKA_SIM_LINT_PACKS_DIR="$root_clean" bash "$CKA_SIM_ROOT/scripts/lint-trap-coverage.sh" 2>&1); rc=$?
expect_eq "$rc" "0" "clean fixture: lint-trap-coverage exits 0" || case_failed=1
expect_contains "$out" "storage/01-clean: trap coverage OK" "clean fixture: emits OK line" || case_failed=1
rm -rf "$root_clean"

# ---- branch 2: orphan fixture (declared but no record_trap call) ----
root_orphan=$(mktemp -d -t lint-trap-cov-orphan-XXXXXX)
_seed_question "$root_orphan" "storage" "02-orphan" \
'traps:
  - synthetic-orphan-trap' \
'# grade.sh deliberately does NOT call record_trap for synthetic-orphan-trap'

out=$(CKA_SIM_LINT_PACKS_DIR="$root_orphan" bash "$CKA_SIM_ROOT/scripts/lint-trap-coverage.sh" 2>&1); rc=$?
expect_eq "$rc" "1" "orphan fixture: lint-trap-coverage exits 1" || case_failed=1
expect_contains "$out" "storage/02-orphan/metadata.yaml:" "orphan fixture: citation includes file:line" || case_failed=1
expect_contains "$out" "trap 'synthetic-orphan-trap' declared but no record_trap call in grade.sh" "orphan fixture: error message names the orphan id" || case_failed=1
rm -rf "$root_orphan"

# ---- branch 3: dynamic-id fixture (record_trap "$var") -> warn, not err ----
root_dyn=$(mktemp -d -t lint-trap-cov-dyn-XXXXXX)
_seed_question "$root_dyn" "storage" "03-dynamic" \
'traps:
  - synthetic-dyn-trap' \
'tid="synthetic-dyn-trap"
cka_sim::grade::record_trap "$tid"'

out=$(CKA_SIM_LINT_PACKS_DIR="$root_dyn" bash "$CKA_SIM_ROOT/scripts/lint-trap-coverage.sh" 2>&1); rc=$?
expect_eq "$rc" "0" "dynamic-id fixture: lint-trap-coverage exits 0" || case_failed=1
expect_contains "$out" "storage/03-dynamic" "dynamic-id fixture: question slug appears in output" || case_failed=1
expect_contains "$out" "dynamic record_trap" "dynamic-id fixture: warn message mentions dynamic" || case_failed=1
rm -rf "$root_dyn"

exit "$case_failed"
