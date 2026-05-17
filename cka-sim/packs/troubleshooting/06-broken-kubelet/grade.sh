#!/bin/bash
# troubleshooting/06-broken-kubelet/grade.sh
# Phase 07.1 AUDIT-01 — audit-escape.
# Phase 07.1 D-22 audit-escape: file-edit baseline gap + node-action (SSH on worker).
#   Candidate work is pure file-edit to /tmp/q06-kubelet-flags/kubeadm-flags.env (proxy for node-side edits).
#   Baseline schema captures only kubectl resources; no file-tracking. Setup writes the file with the wrong CRI
#   endpoint (--container-runtime=remote + missing unix:// prefix) that must be repaired before grade.sh passes.
#   All assertions (file exists, parseable, correct endpoint regex match) correctly require candidate work.
#   Captured in 07.1-12-AUDIT-ESCAPE.md for Plan 13 VERIFICATION consumption.
set -uo pipefail
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

source "$CKA_SIM_ROOT/lib/grade.sh"
source "$CKA_SIM_ROOT/lib/traps.sh"

# Phase 14 BUG-M09 — comment-aware trap detection.
# _strip_comments_from FILE
#   Emit FILE's content with whole-line shell comments removed and trailing
#   inline '# ...' content stripped. Used ONLY by the three comment-vulnerable
#   trap detectors below; the bash-parseable + correct-CRI-endpoint scoring
#   assertions continue to read the raw file because comments are part of
#   bash-parseability semantics. Returns the stripped stream on stdout.
_strip_comments_from() {
  local _f="$1"
  [[ -r "$_f" ]] || return 0
  sed -E -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$_f"
}

sandbox="/tmp/q06-kubelet-flags"
flags="$sandbox/kubeadm-flags.env"
kubeconfig="$sandbox/kubelet.conf"
removed_flag="container-runtime""=remote"

# Phase 07.1 AUDIT-01: setup-collision — setup writes kubeadm-flags.env on disk; existence is setup-state, not candidate-driven.
#   Demoted to weight=0 (informational only).
if [[ -s "$flags" ]]; then
  ok "kubeadm-flags.env exists (setup-owned)"
else
  CKA_SIM_GRADE_FAILS+=("kubeadm-flags.env missing (setup-owned)")
  err "kubeadm-flags.env missing (setup-owned)"
fi

CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if ( set +u; source "$flags" >/dev/null 2>&1; ); then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  ok "kubeadm-flags.env is bash-parseable"
else
  CKA_SIM_GRADE_FAILS+=("kubeadm-flags.env is not bash-parseable")
  err "kubeadm-flags.env is not bash-parseable"
  cka_sim::grade::record_trap kubelet-flag-file-malformed-quoting
fi

CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if grep -qE 'KUBELET_KUBEADM_ARGS=.*--container-runtime-endpoint=unix:///run/cri-dockerd\.sock' "$flags" 2>/dev/null; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  ok "correct CRI endpoint present"
else
  CKA_SIM_GRADE_FAILS+=("correct CRI endpoint missing")
  err "correct CRI endpoint missing"
fi

if _strip_comments_from "$flags" | grep -q "$removed_flag" 2>/dev/null; then
  cka_sim::grade::record_trap removed-container-runtime-flag
fi

if _strip_comments_from "$kubeconfig" | grep -q 'container-runtime-endpoint' 2>/dev/null; then
  cka_sim::grade::record_trap kubelet-runtime-flag-in-kubeconfig
fi

endpoint=$(_strip_comments_from "$flags" | awk -F'container-runtime-endpoint=' '/container-runtime-endpoint=/{print $2}' 2>/dev/null | awk '{print $1}' | tr -d '"' | head -1)
if [[ -n "$endpoint" && "$endpoint" != unix://* ]]; then
  cka_sim::grade::record_trap cri-endpoint-unix-prefix-missing
fi

cka_sim::grade::emit_result
