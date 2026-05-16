#!/bin/bash
# Phase 07.1 grading-honesty regression: cluster-architecture/05-audit-policy
#
# AUDIT-ESCAPE (D-22 file-baseline gap): candidate work is filesystem-only —
# edits /tmp/q05-audit-policy/policy.yaml. lib/baseline.sh tracks K8s API
# resources only. The grader uses Phase-07.1 weight=0 demotion to neutralize
# setup-state asserts (file exists + has-rules) so the only scored assertion
# is the candidate-work structure validation.
#
# Setup state: malformed policy.yaml (rules[].level missing) → 0/1.
# Ref-solution: corrected policy.yaml → 1/1.
#
# Requires python3 + yaml on PATH (grader-internal). Skips if unavailable.

set -uo pipefail
: "${CKA_SIM_ROOT:?}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?}"

pack="cluster-architecture"
slug="05-audit-policy"
qdir="$CKA_SIM_ROOT/packs/$pack/$slug"
test_id="${pack}__${slug}"
sandbox="/tmp/q05-audit-policy"

# Skip the test entirely if python3 cannot import yaml — the grader needs it.
if ! python3 -c 'import yaml' >/dev/null 2>&1; then
  ok "skipped $test_id: python3 + yaml unavailable in test environment"
  return 0
fi

# Pre-clean
rm -rf "$sandbox"
mkdir -p "$sandbox"

# ----- empty submission test (setup state: malformed policy) -----
cat > "$sandbox/policy.yaml" <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  - resources:
      - group: ""
        resources: ["secrets"]
EOF

export CKA_SIM_TEST_CURRENT="grading-honesty/${test_id}/post-setup"
export CKA_SIM_BASELINE_PATH="$CKA_SIM_TEST_FIXTURES_DIR/grading-honesty/${test_id}/post-setup/baseline.json"
export CKA_SIM_LAB_NS="cka-sim-cluster-architecture-05"

out=$(bash "$qdir/grade.sh" 2>&1)

score_line=$(echo "$out" | grep -E '^SCORE:' | tail -1)
expected_setup_score="SCORE: 0/1"

if [[ "$score_line" == "$expected_setup_score" ]]; then
  ok "empty submission $test_id: $expected_setup_score [audit-escape: setup-state demoted to weight=0]"
else
  err "empty submission $test_id: expected '$expected_setup_score', got '$score_line'"
  echo "$out" | tail -20 >&2
  rm -rf "$sandbox"
  exit 1
fi

# ----- ref-solution test (corrected policy with valid level/omitStages) -----
cat > "$sandbox/policy.yaml" <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
  - RequestReceived
rules:
  - level: Metadata
    resources:
      - group: ""
        resources: ["secrets"]
EOF

export CKA_SIM_TEST_CURRENT="grading-honesty/${test_id}/post-ref-solution"
export CKA_SIM_BASELINE_PATH="$CKA_SIM_TEST_FIXTURES_DIR/grading-honesty/${test_id}/post-ref-solution/baseline.json"

out=$(bash "$qdir/grade.sh" 2>&1)
score_line=$(echo "$out" | grep -E '^SCORE:' | tail -1)
expected_ref_score="SCORE: 1/1"

if [[ "$score_line" == "$expected_ref_score" ]]; then
  ok "ref-solution $test_id: $expected_ref_score"
else
  err "ref-solution $test_id: expected '$expected_ref_score', got '$score_line'"
  echo "$out" | tail -20 >&2
  rm -rf "$sandbox"
  exit 1
fi

rm -rf "$sandbox"
