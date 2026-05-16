#!/bin/bash
# Phase 6 UAT — Fixed test suite (v2).
# Fixes from v1:
#   - Pre-fix assertions: only check score < max (traps are bonus, not required for pass)
#   - Q04: grade immediately after ref-solution (no sleep gap that lets pod vanish)
#
# Run on the control-plane node of a 1+2 kubeadm cluster.
# Usage: bash rerun-phase6-uat.sh [path-to-cka-sim]

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CKA_SIM_ROOT="${1:-$(cd "$SCRIPT_DIR/../../.." && pwd)/cka-sim}"
export CKA_SIM_ROOT

PASS_COUNT=0
FAIL_COUNT=0
RESULTS=()

# ─── Helpers ─────────────────────────────────────────────────────────────────

color_green='\033[0;32m'
color_red='\033[0;31m'
color_yellow='\033[0;33m'
color_reset='\033[0m'

pass() {
  PASS_COUNT=$(( PASS_COUNT + 1 ))
  RESULTS+=("PASS: $1")
  printf "${color_green}PASS${color_reset}: %s\n" "$1"
}

fail() {
  FAIL_COUNT=$(( FAIL_COUNT + 1 ))
  RESULTS+=("FAIL: $1 — $2")
  printf "${color_red}FAIL${color_reset}: %s — %s\n" "$1" "$2"
}

info() {
  printf "${color_yellow}INFO${color_reset}: %s\n" "$1"
}

separator() {
  printf '\n%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf ' TEST %s: %s\n' "$1" "$2"
  printf '%s\n\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

wait_ns_gone() {
  local ns="$1" timeout_s="${2:-90}" elapsed=0
  while (( elapsed < timeout_s )); do
    if ! kubectl get ns "$ns" -o name >/dev/null 2>&1; then return 0; fi
    sleep 2; elapsed=$(( elapsed + 2 ))
  done
  return 0
}

run_grade() {
  local dir="$1" ns="$2"
  CKA_SIM_LAB_NS="$ns" CKA_SIM_ROOT="$CKA_SIM_ROOT" bash "$dir/grade.sh" 2>&1
}

extract_score() {
  echo "$1" | grep -oP 'SCORE:\s*\K[0-9]+/[0-9]+' | tail -1
}

score_is_full() {
  local score="$1"
  local num den
  num=$(echo "$score" | cut -d/ -f1)
  den=$(echo "$score" | cut -d/ -f2)
  [[ "$num" == "$den" ]]
}

# ─── Pre-flight ──────────────────────────────────────────────────────────────

info "CKA_SIM_ROOT=$CKA_SIM_ROOT"
[[ -d "$CKA_SIM_ROOT/packs/troubleshooting" ]] || { echo "ERROR: packs not found" >&2; exit 1; }
kubectl cluster-info >/dev/null 2>&1 || { echo "ERROR: cluster unreachable" >&2; exit 1; }

info "Recording baselines..."
BASELINE_MANIFESTS_DIR=$(ls /etc/kubernetes/manifests/ 2>/dev/null | sort)
BASELINE_KUBELET_SHA=$(sha256sum /var/lib/kubelet/kubeadm-flags.env 2>/dev/null | awk '{print $1}')
BASELINE_COREDNS_CM=$(kubectl get cm coredns -n kube-system -o yaml 2>/dev/null | sha256sum | awk '{print $1}')

info "Starting Phase 6 UAT v2"
printf '\n'

# ─── TEST 1: Q01 deploy-svc-mismatch ────────────────────────────────────────

separator "1" "troubleshooting 01 — deploy-svc-mismatch"

Q01_DIR="$CKA_SIM_ROOT/packs/troubleshooting/01-deploy-svc-mismatch"
Q01_NS="cka-sim-troubleshooting-01"

CKA_SIM_LAB_NS="$Q01_NS" bash "$Q01_DIR/reset.sh" 2>/dev/null || true
wait_ns_gone "$Q01_NS"

info "Setup..."
CKA_SIM_LAB_NS="$Q01_NS" CKA_SIM_ROOT="$CKA_SIM_ROOT" bash "$Q01_DIR/setup.sh"

info "Grade pre-fix..."
Q01_PRE=$(run_grade "$Q01_DIR" "$Q01_NS")
Q01_PRE_SCORE=$(extract_score "$Q01_PRE")
if ! score_is_full "$Q01_PRE_SCORE"; then
  pass "Q01 pre-fix: score=$Q01_PRE_SCORE (correctly not full marks)"
else
  fail "Q01 pre-fix" "expected less than full marks, got $Q01_PRE_SCORE"
fi

info "Ref-solution..."
CKA_SIM_LAB_NS="$Q01_NS" bash "$Q01_DIR/ref-solution.sh"
sleep 5

info "Grade post-fix..."
Q01_POST=$(run_grade "$Q01_DIR" "$Q01_NS")
Q01_POST_SCORE=$(extract_score "$Q01_POST")
if [[ "$Q01_POST_SCORE" == "3/3" ]]; then
  pass "Q01 post-fix: score=$Q01_POST_SCORE"
else
  fail "Q01 post-fix" "expected 3/3, got $Q01_POST_SCORE"
fi

CKA_SIM_LAB_NS="$Q01_NS" bash "$Q01_DIR/reset.sh" 2>/dev/null || true

# ─── TEST 2: Q02 netpol-dns-egress ──────────────────────────────────────────

separator "2" "troubleshooting 02 — netpol-dns-egress"

Q02_DIR="$CKA_SIM_ROOT/packs/troubleshooting/02-netpol-dns-egress"
Q02_NS="cka-sim-troubleshooting-02"

CKA_SIM_LAB_NS="$Q02_NS" bash "$Q02_DIR/reset.sh" 2>/dev/null || true
wait_ns_gone "$Q02_NS"

info "Setup..."
CKA_SIM_LAB_NS="$Q02_NS" CKA_SIM_ROOT="$CKA_SIM_ROOT" bash "$Q02_DIR/setup.sh"

info "Grade pre-fix..."
Q02_PRE=$(run_grade "$Q02_DIR" "$Q02_NS")
Q02_PRE_SCORE=$(extract_score "$Q02_PRE")
if ! score_is_full "$Q02_PRE_SCORE"; then
  pass "Q02 pre-fix: score=$Q02_PRE_SCORE (correctly not full marks)"
else
  fail "Q02 pre-fix" "expected less than full marks, got $Q02_PRE_SCORE"
fi

info "Ref-solution..."
CKA_SIM_LAB_NS="$Q02_NS" bash "$Q02_DIR/ref-solution.sh"
sleep 5

info "Grade post-fix..."
Q02_POST=$(run_grade "$Q02_DIR" "$Q02_NS")
Q02_POST_SCORE=$(extract_score "$Q02_POST")
if [[ "$Q02_POST_SCORE" == "6/6" ]]; then
  pass "Q02 post-fix: score=$Q02_POST_SCORE"
else
  fail "Q02 post-fix" "expected 6/6, got $Q02_POST_SCORE"
fi

CKA_SIM_LAB_NS="$Q02_NS" bash "$Q02_DIR/reset.sh" 2>/dev/null || true

# ─── TEST 3: Q03 coredns-resolution ─────────────────────────────────────────

separator "3" "troubleshooting 03 — coredns-resolution"

Q03_DIR="$CKA_SIM_ROOT/packs/troubleshooting/03-coredns-resolution"
Q03_NS="cka-sim-troubleshooting-03"

CKA_SIM_LAB_NS="$Q03_NS" bash "$Q03_DIR/reset.sh" 2>/dev/null || true
wait_ns_gone "$Q03_NS"

info "Setup..."
CKA_SIM_LAB_NS="$Q03_NS" CKA_SIM_ROOT="$CKA_SIM_ROOT" bash "$Q03_DIR/setup.sh"
kubectl wait --for=condition=Available deployment/q03-coredns -n "$Q03_NS" --timeout=60s 2>/dev/null || true
kubectl wait --for=condition=Ready pod/q03-dnsclient -n "$Q03_NS" --timeout=30s 2>/dev/null || true

info "Grade pre-fix..."
Q03_PRE=$(run_grade "$Q03_DIR" "$Q03_NS")
Q03_PRE_SCORE=$(extract_score "$Q03_PRE")
if ! score_is_full "$Q03_PRE_SCORE"; then
  pass "Q03 pre-fix: score=$Q03_PRE_SCORE (correctly not full marks)"
else
  fail "Q03 pre-fix" "expected less than full marks, got $Q03_PRE_SCORE"
fi

info "Ref-solution..."
CKA_SIM_LAB_NS="$Q03_NS" bash "$Q03_DIR/ref-solution.sh"
sleep 10
kubectl wait --for=condition=Available deployment/q03-coredns -n "$Q03_NS" --timeout=60s 2>/dev/null || true
kubectl wait --for=condition=Ready pod/q03-dnsclient -n "$Q03_NS" --timeout=30s 2>/dev/null || true

info "Grade post-fix..."
Q03_POST=$(run_grade "$Q03_DIR" "$Q03_NS")
Q03_POST_SCORE=$(extract_score "$Q03_POST")
if score_is_full "$Q03_POST_SCORE"; then
  pass "Q03 post-fix: score=$Q03_POST_SCORE (full marks)"
else
  fail "Q03 post-fix" "expected full marks, got $Q03_POST_SCORE"
fi

info "Verify kube-system CoreDNS unchanged..."
CUR_CM=$(kubectl get cm coredns -n kube-system -o yaml 2>/dev/null | sha256sum | awk '{print $1}')
if [[ "$CUR_CM" == "$BASELINE_COREDNS_CM" ]]; then
  pass "Q03 kube-system CoreDNS ConfigMap unchanged"
else
  fail "Q03 kube-system safety" "CoreDNS ConfigMap modified"
fi

CKA_SIM_LAB_NS="$Q03_NS" bash "$Q03_DIR/reset.sh" 2>/dev/null || true

# ─── TEST 4: Q04 debug-node ─────────────────────────────────────────────────

separator "4" "troubleshooting 04 — debug-node"

Q04_DIR="$CKA_SIM_ROOT/packs/troubleshooting/04-debug-node"
Q04_NS="cka-sim-troubleshooting-04"

CKA_SIM_LAB_NS="$Q04_NS" bash "$Q04_DIR/reset.sh" 2>/dev/null || true
wait_ns_gone "$Q04_NS"

info "Setup..."
CKA_SIM_LAB_NS="$Q04_NS" CKA_SIM_ROOT="$CKA_SIM_ROOT" bash "$Q04_DIR/setup.sh"

info "Grade pre-fix..."
Q04_PRE=$(run_grade "$Q04_DIR" "$Q04_NS")
Q04_PRE_SCORE=$(extract_score "$Q04_PRE")
if [[ "$Q04_PRE_SCORE" == "0/1" ]]; then
  pass "Q04 pre-fix: score=$Q04_PRE_SCORE"
else
  fail "Q04 pre-fix" "expected 0/1, got $Q04_PRE_SCORE"
fi

info "Ref-solution (kubectl debug node — may take 60s)..."
CKA_SIM_LAB_NS="$Q04_NS" bash "$Q04_DIR/ref-solution.sh"

# Grade IMMEDIATELY — no sleep. The debug pod evidence must exist right after ref-solution.
info "Grade post-fix (immediate)..."
Q04_POST=$(run_grade "$Q04_DIR" "$Q04_NS")
Q04_POST_SCORE=$(extract_score "$Q04_POST")
if [[ "$Q04_POST_SCORE" == "1/1" ]]; then
  pass "Q04 post-fix: score=$Q04_POST_SCORE"
else
  # Diagnostic: show what the grader saw
  info "Q04 grader output:"
  echo "$Q04_POST"
  info "Q04 answer.txt content:"
  cat /tmp/q04-debug-node/answer.txt 2>/dev/null || echo "(missing)"
  info "Q04 worker.txt content:"
  cat /tmp/q04-debug-node/worker.txt 2>/dev/null || echo "(missing)"
  WORKER=$(cat /tmp/q04-debug-node/worker.txt 2>/dev/null || echo "")
  if [[ -n "$WORKER" ]]; then
    info "Q04 expected kernelVersion from Node API:"
    kubectl get node "$WORKER" -o jsonpath='{.status.nodeInfo.kernelVersion}' 2>/dev/null; echo
    info "Q04 debug-source pods:"
    kubectl get pods -A -l "kubectl.kubernetes.io/debug-source=$WORKER" -o wide 2>/dev/null || echo "(none)"
    info "Q04 ALL debug-source pods:"
    kubectl get pods -A -l "kubectl.kubernetes.io/debug-source" -o wide 2>/dev/null || echo "(none)"
  fi
  fail "Q04 post-fix" "expected 1/1, got $Q04_POST_SCORE"
fi

CKA_SIM_LAB_NS="$Q04_NS" bash "$Q04_DIR/reset.sh" 2>/dev/null || true

info "Verify debug pods cleaned..."
DEBUG_PODS=$(kubectl get pods -A -l 'kubectl.kubernetes.io/debug-source' -o name 2>/dev/null || true)
if [[ -z "$DEBUG_PODS" ]]; then
  pass "Q04 debug pods cleaned after reset"
else
  fail "Q04 debug pod cleanup" "leftover: $DEBUG_PODS"
fi

# ─── TEST 5: Q05 static-pod-manifest ────────────────────────────────────────

separator "5" "troubleshooting 05 — static-pod-manifest"

Q05_DIR="$CKA_SIM_ROOT/packs/troubleshooting/05-static-pod-manifest"
Q05_NS="cka-sim-troubleshooting-05"

CKA_SIM_LAB_NS="$Q05_NS" bash "$Q05_DIR/reset.sh" 2>/dev/null || true
wait_ns_gone "$Q05_NS"

info "Setup..."
CKA_SIM_LAB_NS="$Q05_NS" CKA_SIM_ROOT="$CKA_SIM_ROOT" bash "$Q05_DIR/setup.sh"

info "Grade pre-fix..."
Q05_PRE=$(run_grade "$Q05_DIR" "$Q05_NS")
Q05_PRE_SCORE=$(extract_score "$Q05_PRE")
if ! score_is_full "$Q05_PRE_SCORE"; then
  pass "Q05 pre-fix: score=$Q05_PRE_SCORE (correctly not full marks)"
else
  fail "Q05 pre-fix" "expected less than full marks, got $Q05_PRE_SCORE"
fi

info "Ref-solution..."
bash "$Q05_DIR/ref-solution.sh"

info "Grade post-fix..."
Q05_POST=$(run_grade "$Q05_DIR" "$Q05_NS")
Q05_POST_SCORE=$(extract_score "$Q05_POST")
if [[ "$Q05_POST_SCORE" == "4/4" ]]; then
  pass "Q05 post-fix: score=$Q05_POST_SCORE"
else
  fail "Q05 post-fix" "expected 4/4, got $Q05_POST_SCORE"
fi

info "Verify /etc/kubernetes/manifests/ unchanged..."
CUR_MANIFESTS=$(ls /etc/kubernetes/manifests/ 2>/dev/null | sort)
if [[ "$CUR_MANIFESTS" == "$BASELINE_MANIFESTS_DIR" ]]; then
  pass "Q05 /etc/kubernetes/manifests/ unchanged"
else
  fail "Q05 host safety" "/etc/kubernetes/manifests/ modified"
fi

CKA_SIM_LAB_NS="$Q05_NS" bash "$Q05_DIR/reset.sh" 2>/dev/null || true

# ─── TEST 6: Q06 broken-kubelet ─────────────────────────────────────────────

separator "6" "troubleshooting 06 — broken-kubelet"

Q06_DIR="$CKA_SIM_ROOT/packs/troubleshooting/06-broken-kubelet"
Q06_NS="cka-sim-troubleshooting-06"

CKA_SIM_LAB_NS="$Q06_NS" bash "$Q06_DIR/reset.sh" 2>/dev/null || true
wait_ns_gone "$Q06_NS"

info "Setup..."
CKA_SIM_LAB_NS="$Q06_NS" CKA_SIM_ROOT="$CKA_SIM_ROOT" bash "$Q06_DIR/setup.sh"

info "Grade pre-fix..."
Q06_PRE=$(run_grade "$Q06_DIR" "$Q06_NS")
Q06_PRE_SCORE=$(extract_score "$Q06_PRE")
if ! score_is_full "$Q06_PRE_SCORE"; then
  pass "Q06 pre-fix: score=$Q06_PRE_SCORE (correctly not full marks)"
else
  fail "Q06 pre-fix" "expected less than full marks, got $Q06_PRE_SCORE"
fi

info "Ref-solution..."
bash "$Q06_DIR/ref-solution.sh"

info "Grade post-fix..."
Q06_POST=$(run_grade "$Q06_DIR" "$Q06_NS")
Q06_POST_SCORE=$(extract_score "$Q06_POST")
if [[ "$Q06_POST_SCORE" == "3/3" ]]; then
  pass "Q06 post-fix: score=$Q06_POST_SCORE"
else
  fail "Q06 post-fix" "expected 3/3, got $Q06_POST_SCORE"
fi

info "Verify /var/lib/kubelet/kubeadm-flags.env unchanged..."
CUR_KUBELET=$(sha256sum /var/lib/kubelet/kubeadm-flags.env 2>/dev/null | awk '{print $1}')
if [[ "$CUR_KUBELET" == "$BASELINE_KUBELET_SHA" ]]; then
  pass "Q06 /var/lib/kubelet/kubeadm-flags.env unchanged"
else
  fail "Q06 host safety" "kubelet flags modified"
fi

CKA_SIM_LAB_NS="$Q06_NS" bash "$Q06_DIR/reset.sh" 2>/dev/null || true

# ─── TEST 7: Host-safety sweep ──────────────────────────────────────────────

separator "7" "Post-drill host-safety sweep"

info "Waiting for lab namespaces to terminate..."
for ns in cka-sim-troubleshooting-{01,02,03,04,05,06}; do
  wait_ns_gone "$ns" 60
done

DEBUG_PODS_FINAL=$(kubectl get pods -A -l 'kubectl.kubernetes.io/debug-source' -o name 2>/dev/null || true)
if [[ -z "$DEBUG_PODS_FINAL" ]]; then
  pass "Host-safety: no debug pods remain"
else
  fail "Host-safety: debug pods" "leftover: $DEBUG_PODS_FINAL"
fi

FINAL_MANIFESTS=$(ls /etc/kubernetes/manifests/ 2>/dev/null | sort)
if [[ "$FINAL_MANIFESTS" == "$BASELINE_MANIFESTS_DIR" ]]; then
  pass "Host-safety: /etc/kubernetes/manifests/ unchanged"
else
  fail "Host-safety: /etc/kubernetes/manifests/" "listing differs"
fi

FINAL_KUBELET=$(sha256sum /var/lib/kubelet/kubeadm-flags.env 2>/dev/null | awk '{print $1}')
if [[ "$FINAL_KUBELET" == "$BASELINE_KUBELET_SHA" ]]; then
  pass "Host-safety: kubelet flags unchanged"
else
  fail "Host-safety: kubelet flags" "sha256 differs"
fi

FINAL_CM=$(kubectl get cm coredns -n kube-system -o yaml 2>/dev/null | sha256sum | awk '{print $1}')
if [[ "$FINAL_CM" == "$BASELINE_COREDNS_CM" ]]; then
  pass "Host-safety: kube-system CoreDNS ConfigMap unchanged"
else
  fail "Host-safety: CoreDNS ConfigMap" "sha256 differs"
fi

info "DNS smoke test..."
DNS_OUT=$(kubectl run --rm -i --image=busybox:1.37 dns-smoke-uat --restart=Never -- nslookup kubernetes.default.svc.cluster.local 2>&1)
if echo "$DNS_OUT" | grep -q "Address"; then
  pass "Host-safety: cluster DNS resolves"
else
  fail "Host-safety: cluster DNS" "nslookup failed"
fi

info "Idempotency: Q01 setup twice..."
CKA_SIM_LAB_NS="cka-sim-troubleshooting-01" CKA_SIM_ROOT="$CKA_SIM_ROOT" bash "$CKA_SIM_ROOT/packs/troubleshooting/01-deploy-svc-mismatch/setup.sh" >/dev/null 2>&1
IDEM_OUT=$(CKA_SIM_LAB_NS="cka-sim-troubleshooting-01" CKA_SIM_ROOT="$CKA_SIM_ROOT" bash "$CKA_SIM_ROOT/packs/troubleshooting/01-deploy-svc-mismatch/setup.sh" 2>&1)
if ! echo "$IDEM_OUT" | grep -qi "AlreadyExists"; then
  pass "Host-safety: Q01 idempotent (no AlreadyExists)"
else
  fail "Host-safety: Q01 idempotency" "AlreadyExists on second run"
fi
CKA_SIM_LAB_NS="cka-sim-troubleshooting-01" bash "$CKA_SIM_ROOT/packs/troubleshooting/01-deploy-svc-mismatch/reset.sh" 2>/dev/null || true

# ─── Summary ─────────────────────────────────────────────────────────────────

printf '\n%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf ' PHASE 6 UAT v2 RESULTS\n'
printf '%s\n\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for r in "${RESULTS[@]}"; do
  if [[ "$r" == PASS* ]]; then
    printf "${color_green}%s${color_reset}\n" "$r"
  else
    printf "${color_red}%s${color_reset}\n" "$r"
  fi
done

printf '\nTotal: %d passed, %d failed (out of %d checks)\n' "$PASS_COUNT" "$FAIL_COUNT" "$(( PASS_COUNT + FAIL_COUNT ))"

if (( FAIL_COUNT > 0 )); then
  printf "\n${color_red}VERDICT: FAIL${color_reset}\n"
  exit 1
else
  printf "\n${color_green}VERDICT: ALL PASSED${color_reset}\n"
  exit 0
fi
