#!/bin/bash
# cka-sim/tests/cases/baseline_runner_hook.sh — static assertions that drill.sh and exam.sh
# source baseline.sh and call capture after setup.sh.
# TDD RED: this case MUST fail until the runner hooks are wired in.
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"

# shellcheck source=../lib/assert.sh disable=SC1091
source "$CKA_SIM_ROOT/tests/lib/assert.sh"

case_failed=0

DRILL="$CKA_SIM_ROOT/lib/cmd/drill.sh"
EXAM="$CKA_SIM_ROOT/lib/cmd/exam.sh"

# ---------- drill.sh assertions ----------

# 1. drill.sh sources lib/baseline.sh
count=$(grep -c 'source.*lib/baseline.sh' "$DRILL" || true)
expect_eq "$count" "1" "drill.sh: sources lib/baseline.sh exactly once" || case_failed=1

# 2. drill.sh calls cka_sim::baseline::capture
count=$(grep -c 'cka_sim::baseline::capture' "$DRILL" || true)
(( count >= 1 )) || { printf '%s  ✗ drill.sh: cka_sim::baseline::capture not found%s\n' "$RED" "$NC" >&2; case_failed=1; }
if (( count >= 1 )); then
  printf '%s  ✓ drill.sh: calls cka_sim::baseline::capture%s\n' "$GREEN" "$NC" >&2
fi

# 3. drill.sh exports CKA_SIM_BASELINE_PATH
count=$(grep -c 'CKA_SIM_BASELINE_PATH' "$DRILL" || true)
(( count >= 1 )) || { printf '%s  ✗ drill.sh: CKA_SIM_BASELINE_PATH not found%s\n' "$RED" "$NC" >&2; case_failed=1; }
if (( count >= 1 )); then
  printf '%s  ✓ drill.sh: exports CKA_SIM_BASELINE_PATH%s\n' "$GREEN" "$NC" >&2
fi

# 4. Sequence: setup.sh line MUST come BEFORE baseline::capture line
setup_line=$(grep -n 'bash "$CKA_SIM_QUESTION_DIR/setup.sh"' "$DRILL" | head -1 | cut -d: -f1)
capture_line=$(grep -n 'cka_sim::baseline::capture' "$DRILL" | head -1 | cut -d: -f1)
if [[ -z "$setup_line" || -z "$capture_line" ]]; then
  printf '%s  ✗ drill.sh: cannot find setup.sh or capture lines for sequence check%s\n' "$RED" "$NC" >&2
  case_failed=1
elif (( setup_line < capture_line )); then
  printf '%s  ✓ drill.sh: setup.sh (L%d) before capture (L%d)%s\n' "$GREEN" "$setup_line" "$capture_line" "$NC" >&2
else
  printf '%s  ✗ drill.sh: setup.sh (L%d) NOT before capture (L%d)%s\n' "$RED" "$setup_line" "$capture_line" "$NC" >&2
  case_failed=1
fi

# ---------- exam.sh assertions ----------

# 5. exam.sh sources lib/baseline.sh
count=$(grep -c 'source.*lib/baseline.sh' "$EXAM" || true)
expect_eq "$count" "1" "exam.sh: sources lib/baseline.sh exactly once" || case_failed=1

# 6. exam.sh calls cka_sim::baseline::capture
count=$(grep -c 'cka_sim::baseline::capture' "$EXAM" || true)
(( count >= 1 )) || { printf '%s  ✗ exam.sh: cka_sim::baseline::capture not found%s\n' "$RED" "$NC" >&2; case_failed=1; }
if (( count >= 1 )); then
  printf '%s  ✓ exam.sh: calls cka_sim::baseline::capture%s\n' "$GREEN" "$NC" >&2
fi

# 7. exam.sh exports CKA_SIM_BASELINE_PATH
count=$(grep -c 'CKA_SIM_BASELINE_PATH' "$EXAM" || true)
(( count >= 1 )) || { printf '%s  ✗ exam.sh: CKA_SIM_BASELINE_PATH not found%s\n' "$RED" "$NC" >&2; case_failed=1; }
if (( count >= 1 )); then
  printf '%s  ✓ exam.sh: exports CKA_SIM_BASELINE_PATH%s\n' "$GREEN" "$NC" >&2
fi

# 8. exam.sh batch_grade loop re-exports CKA_SIM_BASELINE_PATH per question
# The batch_grade function must contain CKA_SIM_BASELINE_PATH between export_lab_ns and grade.sh
batch_grade_section=$(sed -n '/^cka_sim::exam::batch_grade()/,/^}/p' "$EXAM")
if echo "$batch_grade_section" | grep -q 'CKA_SIM_BASELINE_PATH'; then
  printf '%s  ✓ exam.sh: batch_grade re-exports CKA_SIM_BASELINE_PATH per question%s\n' "$GREEN" "$NC" >&2
else
  printf '%s  ✗ exam.sh: batch_grade does NOT re-export CKA_SIM_BASELINE_PATH per question%s\n' "$RED" "$NC" >&2
  case_failed=1
fi

# 9. Sequence in exam.sh: setup.sh line MUST come BEFORE baseline::capture line (in setup_question)
setup_q_section=$(sed -n '/^cka_sim::exam::setup_question()/,/^}/p' "$EXAM")
setup_line_exam=$(echo "$setup_q_section" | grep -n 'bash "$qdir/setup.sh"' | head -1 | cut -d: -f1)
capture_line_exam=$(echo "$setup_q_section" | grep -n 'cka_sim::baseline::capture' | head -1 | cut -d: -f1)
if [[ -z "$setup_line_exam" || -z "$capture_line_exam" ]]; then
  printf '%s  ✗ exam.sh: cannot find setup.sh or capture lines in setup_question for sequence check%s\n' "$RED" "$NC" >&2
  case_failed=1
elif (( setup_line_exam < capture_line_exam )); then
  printf '%s  ✓ exam.sh: setup_question: setup.sh before capture%s\n' "$GREEN" "$NC" >&2
else
  printf '%s  ✗ exam.sh: setup_question: setup.sh NOT before capture%s\n' "$RED" "$NC" >&2
  case_failed=1
fi

exit "$case_failed"
