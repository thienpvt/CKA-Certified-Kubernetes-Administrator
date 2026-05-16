# Troubleshooting: a node-agent runtime configuration file is rejected at parse time

**Domain:** Troubleshooting  |  **Estimated time:** 11 minutes

A worker in the lab cluster has a node-level runtime configuration source at `/tmp/q06-kubelet-flags/kubeadm-flags.env`. As currently written, this file is rejected at parse time and specifies a runtime endpoint that the current node-agent no longer supports.

A companion placeholder exists at `/tmp/q06-kubelet-flags/kubelet.conf` in the same sandbox and also contains a drifted reference. Repair both sandbox files so `KUBELET_KUBEADM_ARGS` is a bash-parseable single line, uses the `unix://` scheme for the container runtime endpoint, and the companion placeholder contains no runtime-endpoint reference.

## Sandbox

- Working directory: `/tmp/q06-kubelet-flags/`
- Candidate files: `kubeadm-flags.env` and `kubelet.conf`

## Tasks

1. Inspect both sandbox files and identify every reason the node-agent would refuse to parse or reject this configuration.
2. Edit both files in place so `KUBELET_KUBEADM_ARGS` parses cleanly, the container runtime endpoint uses `unix://`, and no runtime flags leak into the companion placeholder.
3. Confirm `bash -c 'source /tmp/q06-kubelet-flags/kubeadm-flags.env'` exits 0.

## Constraints

- Do not modify any file outside `/tmp/q06-kubelet-flags/`.
- Do not run any live-service-restart commands.
- The endpoint must include the `unix://` scheme.

## Verify yourself

Run these checks; both must exit 0:

```bash
bash -c 'source /tmp/q06-kubelet-flags/kubeadm-flags.env'
grep 'unix:///run/cri-dockerd.sock' /tmp/q06-kubelet-flags/kubeadm-flags.env
```
