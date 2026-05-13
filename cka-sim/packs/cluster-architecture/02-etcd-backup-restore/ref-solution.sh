#!/bin/bash
set -euo pipefail

sandbox="/tmp/q02-etcd-backup"
mkdir -p "$sandbox"
cat > "$sandbox/apply-script.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
export ETCDCTL_API=3
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /tmp/q02-etcd-backup/snapshot.db
rm -rf /tmp/q02-etcd-backup/restored-data
etcdutl snapshot restore /tmp/q02-etcd-backup/snapshot.db \
  --data-dir=/tmp/q02-etcd-backup/restored-data
EOF
chmod 0755 "$sandbox/apply-script.sh"
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save "$sandbox/snapshot.db"
rm -rf "$sandbox/restored-data"
etcdutl snapshot restore "$sandbox/snapshot.db" --data-dir="$sandbox/restored-data"
