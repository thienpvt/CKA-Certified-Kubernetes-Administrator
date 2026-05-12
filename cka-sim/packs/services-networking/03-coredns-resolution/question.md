# services-networking/03-coredns-resolution

**Domain:** Services & Networking  |  **Estimated time:** 7 minutes

A Pod named `q03-dnsclient` is Running, but DNS lookups for cluster Services fail.

## Tasks

1. Inspect `q03-dnsclient` in `${CKA_SIM_LAB_NS}`.
2. Find the ClusterIP for the `kube-dns` Service in `kube-system`.
3. Recreate `q03-dnsclient` so `dnsPolicy` remains `None` and `dnsConfig.nameservers` points to the cluster DNS Service IP.
4. Confirm `nslookup kubernetes.default.svc.cluster.local` works from the Pod.

## Constraints

- Do NOT edit the `kube-system/coredns` ConfigMap.
- Do NOT change `dnsPolicy` away from `None`.
- Only fix the Pod's `dnsConfig.nameservers` value.

## Verify yourself

Before typing `done`, confirm:

```bash
kubectl get svc kube-dns -n kube-system
kubectl get pod q03-dnsclient -n ${CKA_SIM_LAB_NS} -o yaml
kubectl exec -n ${CKA_SIM_LAB_NS} q03-dnsclient -- nslookup kubernetes.default.svc.cluster.local
```
