#!/bin/bash
# cka-sim/tests/cases/drill_load_pack.sh — verifies cka_sim::drill::_parse_manifest
# populates the question arrays and pack meta map correctly for both single-question
# and multi-question manifests.

set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?must be set by run.sh}"

# shellcheck source=../lib/assert.sh disable=SC1091
source "$CKA_SIM_ROOT/tests/lib/assert.sh"
# shellcheck source=../../lib/cmd/drill.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/cmd/drill.sh"
# drill.sh enables `set -euo pipefail`; the test contract is `set -uo pipefail`
# (accumulate failures, do not exit on first non-zero). Restore it now.
set +e

case_failed=0

# ---------- parse storage.yaml (single-question manifest) ----------
CKA_SIM_PACK_QUESTION_IDS=()
CKA_SIM_PACK_QUESTION_PATHS=()
CKA_SIM_PACK_QUESTION_MINUTES=()
CKA_SIM_PACK_META=()
cka_sim::drill::_parse_manifest "$CKA_SIM_TEST_FIXTURES_DIR/manifest/storage.yaml"

expect_eq "${#CKA_SIM_PACK_QUESTION_IDS[@]}" "1" \
  "storage: 1 question parsed" || case_failed=1
expect_eq "${CKA_SIM_PACK_QUESTION_IDS[0]}" "storage-pvc-binding" \
  "storage: id parsed" || case_failed=1
expect_eq "${CKA_SIM_PACK_QUESTION_PATHS[0]}" "01-pvc-binding" \
  "storage: path parsed" || case_failed=1
expect_eq "${CKA_SIM_PACK_QUESTION_MINUTES[0]}" "8" \
  "storage: minutes parsed" || case_failed=1
expect_eq "${CKA_SIM_PACK_META[id]}" "storage" \
  "storage: pack.id parsed" || case_failed=1
expect_eq "${CKA_SIM_PACK_META[domain]}" "storage" \
  "storage: pack.domain parsed" || case_failed=1
expect_eq "${CKA_SIM_PACK_META[weight]}" "10" \
  "storage: pack.weight parsed" || case_failed=1

# ---------- parse multi.yaml (3-question manifest) ----------
CKA_SIM_PACK_QUESTION_IDS=()
CKA_SIM_PACK_QUESTION_PATHS=()
CKA_SIM_PACK_QUESTION_MINUTES=()
CKA_SIM_PACK_META=()
cka_sim::drill::_parse_manifest "$CKA_SIM_TEST_FIXTURES_DIR/manifest/multi.yaml"

expect_eq "${#CKA_SIM_PACK_QUESTION_IDS[@]}" "3" \
  "multi: 3 questions parsed" || case_failed=1
expect_eq "${CKA_SIM_PACK_QUESTION_IDS[0]}" "ts-question-one" \
  "multi: index 0 id" || case_failed=1
expect_eq "${CKA_SIM_PACK_QUESTION_IDS[1]}" "ts-question-two" \
  "multi: index 1 id" || case_failed=1
expect_eq "${CKA_SIM_PACK_QUESTION_IDS[2]}" "ts-question-three" \
  "multi: index 2 id" || case_failed=1
expect_eq "${CKA_SIM_PACK_QUESTION_PATHS[2]}" "03-question-three" \
  "multi: index 2 path" || case_failed=1
expect_eq "${CKA_SIM_PACK_QUESTION_MINUTES[1]}" "10" \
  "multi: index 1 minutes" || case_failed=1
expect_eq "${CKA_SIM_PACK_META[id]}" "troubleshooting" \
  "multi: pack.id parsed" || case_failed=1

# ---------- parse empty.yaml (no questions — meta-only) ----------
CKA_SIM_PACK_QUESTION_IDS=()
CKA_SIM_PACK_QUESTION_PATHS=()
CKA_SIM_PACK_QUESTION_MINUTES=()
CKA_SIM_PACK_META=()
cka_sim::drill::_parse_manifest "$CKA_SIM_TEST_FIXTURES_DIR/manifest/empty.yaml"
expect_eq "${#CKA_SIM_PACK_QUESTION_IDS[@]}" "0" \
  "empty: zero questions parsed" || case_failed=1
expect_eq "${CKA_SIM_PACK_META[id]}" "empty" \
  "empty: pack.id still parsed" || case_failed=1

exit "$case_failed"
