#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

source "$CKA_SIM_ROOT/lib/setup.sh"

CKA_SIM_PACK="cluster-architecture"
CKA_SIM_QUESTION_ID="cluster-architecture-etcd-backup-restore"
sandbox="/tmp/q02-etcd-backup"

cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" "$CKA_SIM_PACK" "$CKA_SIM_QUESTION_ID"
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" "$CKA_SIM_PACK" "$CKA_SIM_QUESTION_ID"

mkdir -p "$sandbox/restored-data"
touch "$sandbox/.cka-sim-sentinel" "$sandbox/restored-data/.pre-existing"
cat > "$sandbox/apply-script.sh" <<'EOF'
# TODO: save a v3 etcd snapshot to /tmp/q02-etcd-backup/snapshot.db
# TODO: restore it into /tmp/q02-etcd-backup/restored-data
EOF
chmod 0644 "$sandbox/apply-script.sh"

command -v etcdutl >/dev/null 2>&1 || warn "etcdutl not present -- install etcd 3.5+ binaries"
