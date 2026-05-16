# kubeadm Upgrade Planning

The control plane is currently represented as version `v1.34.2` in `/tmp/q03-kubeadm-upgrade/current-version.txt`.

Prepare a sandbox upgrade plan to v1.35:

- Write `/tmp/q03-kubeadm-upgrade/planned-upgrade.txt` with a short plan that names the target version.
- Write `/tmp/q03-kubeadm-upgrade/apply-script.sh` with the commands you would run.
- The script must run `kubeadm upgrade plan` before `kubeadm upgrade apply`.

Do not run kubeadm upgrade against the live cluster. This is a file-level planning drill.
