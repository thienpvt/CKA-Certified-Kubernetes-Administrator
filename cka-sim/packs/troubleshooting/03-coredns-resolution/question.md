# Troubleshooting: Pods cannot resolve DNS names

**Domain:** Troubleshooting  |  **Estimated time:** 8 minutes

A debug Pod named `q03-dnsclient` in `${CKA_SIM_LAB_NS}` cannot resolve external names such as `www.example.com`. Cluster-internal names such as `kubernetes.default.svc.cluster.local` also fail. A lab CoreDNS Deployment named `q03-coredns` is present in the same namespace but is failing to start; once you stabilise it, you must also fix its upstream forwarder so that DNS resolution works for both cluster-internal and external names.

## Tasks
1. Stabilise the `q03-coredns` Deployment so its Pod reaches Ready.
2. Fix the lab CoreDNS upstream forwarder so cluster-internal and external names resolve.
3. Verify both `kubernetes.default.svc.cluster.local` and `www.example.com` resolve from inside `q03-dnsclient`.

## Constraints
- Make lab-namespace-scoped changes only. Do not mutate shared cluster DNS resources.
- Do NOT modify the `q03-dnsclient` Pod's DNS settings.
- Adjust supporting resources instead.

## Verify yourself

```bash
kubectl exec -n "$CKA_SIM_LAB_NS" q03-dnsclient -- nslookup kubernetes.default.svc.cluster.local
```

```bash
kubectl exec -n "$CKA_SIM_LAB_NS" q03-dnsclient -- nslookup www.example.com
```

Both lookups must resolve.
