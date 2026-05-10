# workloads-scheduling/06-static-pod

**Domain:** Workloads & Scheduling  |  **Estimated time:** 8 minutes

Create a static pod on `node-01` that the kubelet will mirror into the cluster.

## Tasks

1. SSH to `node-01` (already configured via `cka-sim bootstrap`).
2. Drop a pod manifest at `/etc/kubernetes/manifests/q06-static-nginx.yaml`:
   - pod name: `q06-static-nginx`
   - image: `nginx:1.27`
   - namespace: `default`
3. From the control-plane, confirm the mirror pod `q06-static-nginx-node-01` exists in the `default` namespace and is `Ready`.

## Constraints

- Do NOT run `kubectl apply` for the static pod — it is kubelet-managed, not API-server-managed.
- Do NOT edit `/etc/kubernetes/kubelet.conf` or any kubeconfig file.

## Verify yourself

```
kubectl get pod q06-static-nginx-node-01 -n default -o jsonpath='{.metadata.annotations.kubernetes\.io/config\.source}'   # file
kubectl get pod q06-static-nginx-node-01 -n default -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'         # True
```
