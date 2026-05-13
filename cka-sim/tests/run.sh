#!/bin/bash
# cka-sim/tests/run.sh — bash unit-test runner for traps.sh + grade.sh.
# Walks cka-sim/tests/cases/*.sh, sources each in a subshell, aggregates pass/fail.
# Local: bash cka-sim/tests/run.sh
# CI: invoked by cka-sim/scripts/test.sh.

set -uo pipefail   # NOT -e: continue past failing cases to aggregate results

CKA_SIM_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export CKA_SIM_ROOT

# PATH-shadow real kubectl with the test stub.
export PATH="$CKA_SIM_ROOT/tests/bin:$PATH"

# Fixtures dir — case files set CKA_SIM_TEST_CURRENT to a sub-path under here.
export CKA_SIM_TEST_FIXTURES_DIR="$CKA_SIM_ROOT/tests/fixtures"

# shellcheck source=../lib/colors.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/colors.sh"
# shellcheck source=../lib/log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"

header "cka-sim bash unit tests"

cases_dir="$CKA_SIM_ROOT/tests/cases"
if [[ ! -d "$cases_dir" ]]; then
  warn "no cases directory at $cases_dir — nothing to run (treat as success during scaffold)"
  exit 0
fi

total=0
failed=0

while IFS= read -r -d '' case_file; do
  total=$(( total + 1 ))
  header "$(basename "$case_file" .sh)"
  # Run case in a subshell so its set -u/-o pipefail / variable leaks don't poison run.sh.
  if ( source "$case_file" ); then
    ok "case passed: $(basename "$case_file" .sh)"
  else
    err "case failed (rc=$?): $(basename "$case_file" .sh)"
    failed=$(( failed + 1 ))
  fi
done < <(find "$cases_dir" -name '*.sh' -print0 | sort -z)

# Walk tests/exam/ if it exists (Phase 7+ exam mode tests).
exam_dir="$CKA_SIM_ROOT/tests/exam"
if [[ -d "$exam_dir" ]]; then
  while IFS= read -r -d '' case_file; do
    total=$(( total + 1 ))
    header "$(basename "$case_file" .sh)"
    if ( source "$case_file" ); then
      ok "case passed: $(basename "$case_file" .sh)"
    else
      err "case failed (rc=$?): $(basename "$case_file" .sh)"
      failed=$(( failed + 1 ))
    fi
  done < <(find "$exam_dir" -name '*.sh' -print0 | sort -z)
fi

printf '\n' >&2
if (( total == 0 )); then
  warn "no test cases found in $cases_dir — treat as success during scaffold"
  exit 0
fi
if (( failed == 0 )); then
  ok "all $total case(s) passed"
  exit 0
else
  err "$failed of $total case(s) failed"
  exit 1
fi
