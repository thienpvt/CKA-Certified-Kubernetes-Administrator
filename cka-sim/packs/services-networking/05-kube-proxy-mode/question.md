# services-networking/05-kube-proxy-mode

**Domain:** Services & Networking  |  **Estimated time:** 8 minutes

The platform operations team needs to audit which kube-proxy mode the cluster is running. A sandbox file has been prepared at `/tmp/q05-kube-proxy/reported-mode.txt` containing a draft value.

## Tasks

1. Determine the cluster's actual kube-proxy mode by inspecting the `kube-proxy` ConfigMap in `kube-system`.
2. Overwrite `/tmp/q05-kube-proxy/reported-mode.txt` with the correct value (one of `iptables`, `ipvs`, or `nftables`).

## Constraints

- **Read-only** — do NOT modify the `kube-proxy` ConfigMap in `kube-system`.
- The kube-proxy ConfigMap contains a `config.conf` data key with the runtime configuration including the `mode:` field.

## Verify yourself

Before typing `done`, confirm:

```bash
cat /tmp/q05-kube-proxy/reported-mode.txt
kubectl -n kube-system get configmap kube-proxy -o jsonpath='{.data.config\.conf}' | grep '^mode:'
```
