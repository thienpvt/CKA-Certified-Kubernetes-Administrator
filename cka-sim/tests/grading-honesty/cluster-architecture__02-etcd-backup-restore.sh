#!/bin/bash
# Phase 07.1 grading-honesty regression: cluster-architecture/02-etcd-backup-restore
#
# AUDIT-ESCAPE (D-22 file-baseline gap): This question's candidate work is pure
# filesystem state (write snapshot.db, populate restored-data/member/wal, edit
# apply-script.sh). lib/baseline.sh tracks K8s API resources only — there is no
# file-mtime/sha256 baseline to gate the file probes on.
#
# The ref-solution path additionally requires the etcdutl binary on PATH to run
# `etcdutl snapshot status` + `etcdutl snapshot restore`. Neither is available
# inside the unit-test harness, so we cannot mechanically test the ref-solution.
#
# What we CAN test: empty submission (no sandbox files) scores 0/3 + the 2
# missing-content traps fire. Ref-solution verification deferred to v1.x (file-
# baseline support).

set -uo pipefail
: "${CKA_SIM_ROOT:?}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?}"

pack="cluster-architecture"
slug="02-etcd-backup-restore"
qdir="$CKA_SIM_ROOT/packs/$pack/$slug"
test_id="${pack}__${slug}"

# Pre-clean: ensure NO sandbox state exists from prior test runs.
sandbox="/tmp/q02-etcd-backup"
rm -rf "$sandbox"

# ----- empty submission test -----
export CKA_SIM_TEST_CURRENT="grading-honesty/${test_id}/post-setup"
export CKA_SIM_BASELINE_PATH="$CKA_SIM_TEST_FIXTURES_DIR/grading-honesty/${test_id}/post-setup/baseline.json"
export CKA_SIM_LAB_NS="cka-sim-cluster-architecture-02"

out=$(bash "$qdir/grade.sh" 2>&1)

score_line=$(echo "$out" | grep -E '^SCORE:' | tail -1)
expected_setup_score="SCORE: 0/3"

if [[ "$score_line" == "$expected_setup_score" ]]; then
  ok "empty submission $test_id: $expected_setup_score [audit-escape: file-baseline gap]"
else
  err "empty submission $test_id: expected '$expected_setup_score', got '$score_line'"
  echo "$out" | tail -20 >&2
  rm -rf "$sandbox"
  exit 1
fi

# ----- ref-solution test: SKIPPED (audit-escape) -----
# Requires etcdutl + actual snapshot.db file. Documented in 07.1-11-AUDIT-ESCAPE.md.
ok "ref-solution $test_id: SKIPPED [audit-escape: requires etcdutl + file-baseline support, see 07.1-11-AUDIT-ESCAPE.md]"

rm -rf "$sandbox"
