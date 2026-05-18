#!/bin/bash
# Phase 07.1 grading-honesty regression: cluster-architecture/04-pss-enforce
# Phase 10 BUG-H03 reshape: 1 weight=1 (broken: contradicted question.md) →
#   5 weight=0 preconditions (NS PSS labels x2 + admission log + Deploy exists + readyReplicas)
#   + 5 weight=1 file-based assertions on /tmp/q04-pss-enforce/candidate-violator.yaml
#     (privileged, runAsNonRoot, capabilities.drop ALL, seccompProfile, allowPrivilegeEscalation).
# Empty submission: 0/5 (seeded violator with privileged=true fails all 5).
# Ref-solution: 5/5 (compliant Pod passes all 5).
# kubectl-stub manifest entries below mock the `kubectl apply --dry-run=client -f ... -o jsonpath`
# calls that the grader uses to inspect the file — content of the file itself is not parsed
# by the stub, but the file must exist so the grader's pre-flight check doesn't err.

set -uo pipefail
: "${CKA_SIM_ROOT:?}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?}"

pack="cluster-architecture"
slug="04-pss-enforce"
qdir="$CKA_SIM_ROOT/packs/$pack/$slug"
test_id="${pack}__${slug}"

# Setup: write admission log + candidate-violator.yaml (grader reads both from filesystem).
# Stub mocks the kubectl apply --dry-run results, so file contents don't have to be valid
# YAML — the existence check is the only thing the grader does outside kubectl.
sandbox="/tmp/q04-pss-enforce"
mkdir -p "$sandbox"
printf 'violates PodSecurity "restricted:v1.35": ...' > "$sandbox/violator-admission.log"
printf 'apiVersion: v1\nkind: Pod\nmetadata: { name: q04-candidate }\n' > "$sandbox/candidate-violator.yaml"

# ----- empty submission test -----
export CKA_SIM_TEST_CURRENT="grading-honesty/${test_id}/post-setup"
export CKA_SIM_BASELINE_PATH="$CKA_SIM_TEST_FIXTURES_DIR/grading-honesty/${test_id}/post-setup/baseline.json"
export CKA_SIM_LAB_NS="cka-sim-cluster-architecture-04"

out=$(bash "$qdir/grade.sh" 2>&1)

score_line=$(echo "$out" | grep -E '^SCORE:' | tail -1)
expected_setup_score="SCORE: 0/5"

if [[ "$score_line" == "$expected_setup_score" ]]; then
  ok "empty submission $test_id: $expected_setup_score"
else
  err "empty submission $test_id: expected '$expected_setup_score', got '$score_line'"
  rm -rf "$sandbox"
  exit 1
fi

# ----- ref-solution test -----
export CKA_SIM_TEST_CURRENT="grading-honesty/${test_id}/post-ref-solution"
export CKA_SIM_BASELINE_PATH="$CKA_SIM_TEST_FIXTURES_DIR/grading-honesty/${test_id}/post-ref-solution/baseline.json"

out=$(bash "$qdir/grade.sh" 2>&1)
score_line=$(echo "$out" | grep -E '^SCORE:' | tail -1)
expected_ref_score="SCORE: 5/5"

if [[ "$score_line" == "$expected_ref_score" ]]; then
  ok "ref-solution $test_id: $expected_ref_score"
else
  err "ref-solution $test_id: expected '$expected_ref_score', got '$score_line'"
  rm -rf "$sandbox"
  exit 1
fi

# Cleanup
rm -rf "$sandbox"
