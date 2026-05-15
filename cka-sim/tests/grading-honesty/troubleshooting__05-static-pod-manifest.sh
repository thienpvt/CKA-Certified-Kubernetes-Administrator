#!/bin/bash
# Phase 07.1 grading-honesty regression: troubleshooting/05-static-pod-manifest
# AUDIT-ESCAPE + partial demote: file-existence demoted to weight=0; parse/kind/dry-run check candidate work.
# Asserts empty submission (post-setup state) scores 0/3 (broken YAML cannot parse, fail kind, fail dry-run)
# AND ref-solution (post-ref-solution state) scores 3/3 (fixed YAML parses, kind=Pod, dry-run validates).

set -uo pipefail
: "${CKA_SIM_ROOT:?}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?}"

# This grader requires python3 + PyYAML for manifest validation.
# Skip gracefully if unavailable (CI has python3; local dev may not).
if ! python3 -c "import yaml" 2>/dev/null; then
  ok "SKIP troubleshooting__05-static-pod-manifest (python3/PyYAML not available)"
  exit 0
fi

pack="troubleshooting"
slug="05-static-pod-manifest"
qdir="$CKA_SIM_ROOT/packs/$pack/$slug"
test_id="${pack}__${slug}"

# Setup: write the candidate sandbox.
sandbox="/tmp/q05-staticpod"
mkdir -p "$sandbox"
touch "$sandbox/.cka-sim-sentinel"

# ----- empty submission test -----
# Empty submission: write the broken manifest (tab in indentation, will fail YAML parse).
printf 'apiVersion: v1\nkind: Pod\nmetadata:\n  name: q05-cache\nspec:\n  containers:\n    - name: cache\n      image: nginx:1.27-alpine\n      resources:\n        requests:\n          cpu: 50m\n\tlimits:\n          cpu: 100m\n' > "$sandbox/manifest.yaml"

export CKA_SIM_TEST_CURRENT="grading-honesty/${test_id}/post-setup"
export CKA_SIM_BASELINE_PATH="$CKA_SIM_TEST_FIXTURES_DIR/grading-honesty/${test_id}/post-setup/baseline.json"
export CKA_SIM_LAB_NS="cka-sim-troubleshooting-05"

out=$(bash "$qdir/grade.sh" 2>&1)

score_line=$(echo "$out" | grep -E '^SCORE:' | tail -1)
expected_setup_score="SCORE: 0/3"

if [[ "$score_line" == "$expected_setup_score" ]]; then
  ok "empty submission $test_id: $expected_setup_score"
else
  err "empty submission $test_id: expected '$expected_setup_score', got '$score_line'"
  rm -rf "$sandbox"
  exit 1
fi

# ----- ref-solution test -----
# Ref-solution: write the fixed manifest.
cat > "$sandbox/manifest.yaml" <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: q05-cache
  namespace: kube-system
spec:
  containers:
    - name: cache
      image: nginx:1.27-alpine
      resources:
        requests:
          cpu: 50m
          memory: 64Mi
        limits:
          cpu: 100m
          memory: 128Mi
EOF

export CKA_SIM_TEST_CURRENT="grading-honesty/${test_id}/post-ref-solution"
export CKA_SIM_BASELINE_PATH="$CKA_SIM_TEST_FIXTURES_DIR/grading-honesty/${test_id}/post-ref-solution/baseline.json"

out=$(bash "$qdir/grade.sh" 2>&1)
score_line=$(echo "$out" | grep -E '^SCORE:' | tail -1)
expected_ref_score="SCORE: 3/3"

if [[ "$score_line" == "$expected_ref_score" ]]; then
  ok "ref-solution $test_id: $expected_ref_score"
else
  err "ref-solution $test_id: expected '$expected_ref_score', got '$score_line'"
  rm -rf "$sandbox"
  exit 1
fi

# Cleanup
rm -rf "$sandbox"
