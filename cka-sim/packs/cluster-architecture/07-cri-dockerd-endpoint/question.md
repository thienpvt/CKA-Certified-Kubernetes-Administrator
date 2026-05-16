# CRI-dockerd Endpoint

The sandbox file `/tmp/q07-kubelet-flags/kubeadm-flags.env` contains an obsolete runtime flag. Edit only that sandbox copy so `KUBELET_KUBEADM_ARGS` uses the v1.35 endpoint flag:

`--container-runtime-endpoint=unix:///run/cri-dockerd.sock`

Constraints:

- Do not edit `/tmp/q07-kubelet-flags/kubelet.conf`; that is the kubelet kubeconfig, not runtime configuration.
- Do not modify live `/var/lib/kubelet/` or `/etc/kubernetes/` files.
- The endpoint must include the `unix://` scheme.
