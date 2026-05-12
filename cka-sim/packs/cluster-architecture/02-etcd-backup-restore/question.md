# etcd Backup And Restore

Create a safe etcd snapshot drill in the sandbox at `/tmp/q02-etcd-backup`.

Write the snapshot to `/tmp/q02-etcd-backup/snapshot.db`, restore it to `/tmp/q02-etcd-backup/restored-data`, and record the exact commands in `/tmp/q02-etcd-backup/apply-script.sh`.

Constraints:

- Use the v3 etcd API.
- Use the kubeadm etcd certificates under `/etc/kubernetes/pki/etcd/`.
- Restore only into the sandbox data directory.
- Do not write to the live etcd data directory.
