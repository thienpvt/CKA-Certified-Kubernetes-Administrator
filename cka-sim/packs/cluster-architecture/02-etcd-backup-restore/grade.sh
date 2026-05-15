#!/bin/bash
# Phase 07.1 AUDIT-01 — distinguish setup-state from candidate work.
# Phase 07.1 D-22 audit-escape: file-baseline gap.
#
# cluster-architecture/02-etcd-backup-restore/grade.sh
#
# Ownership analysis:
#   - setup.sh creates apply-script.sh with TODO comments + .cka-sim-sentinel.
#   - Candidate work: write snapshot.db, populate restored-data/member/wal,
#     embed ETCDCTL_API=3 + correct --data-dir in apply-script.sh.
#   - All scoring assertions read FILESYSTEM state, not K8s API. The
#     lib/baseline.sh schema (D-03) tracks K8s resources only — this Q is
#     unverifiable by the grading-honesty harness until v1.x adds file-mtime +
#     sha256 baseline support. Empty submission naturally fails all asserts
#     (setup writes none of the scored files), so no demotion is required.
set -uo pipefail
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

source "$CKA_SIM_ROOT/lib/grade.sh"

sandbox="/tmp/q02-etcd-backup"
script="$sandbox/apply-script.sh"

CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ -s "$sandbox/snapshot.db" ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  ok "snapshot.db exists and is non-empty"
else
  CKA_SIM_GRADE_FAILS+=("snapshot.db is missing or empty")
  err "snapshot.db is missing or empty"
fi

CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ -s "$sandbox/snapshot.db" ]] && etcdutl snapshot status "$sandbox/snapshot.db" --write-out=table >/dev/null 2>&1; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  ok "snapshot status succeeds"
else
  CKA_SIM_GRADE_FAILS+=("etcdutl snapshot status failed")
  err "etcdutl snapshot status failed"
fi

CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ -d "$sandbox/restored-data/member/wal" ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
  ok "restored member/wal directory exists"
else
  CKA_SIM_GRADE_FAILS+=("restored member/wal directory missing")
  err "restored member/wal directory missing"
fi

if ! grep -q 'ETCDCTL_API=3' "$script" 2>/dev/null; then
  cka_sim::grade::record_trap etcd-snapshot-without-env-set
fi

if ! grep -q -- '--data-dir=/tmp/q02-etcd-backup/restored-data' "$script" 2>/dev/null || grep -q -- '--data-dir=/var/lib/etcd' "$script" 2>/dev/null; then
  cka_sim::grade::record_trap etcd-restore-wrong-data-dir
fi

cka_sim::grade::emit_result
