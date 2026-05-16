# Troubleshooting: Pods cannot resolve DNS names

**Domain:** Troubleshooting  |  **Estimated time:** 8 minutes

A debug Pod named `q03-dnsclient` in `${CKA_SIM_LAB_NS}` cannot resolve external names such as `www.example.com`. Cluster-internal names such as `kubernetes.default.svc.cluster.local` also fail. Other lab namespace infrastructure is running.

## Tasks
1. Inspect namespaced workloads and supporting resources in `${CKA_SIM_LAB_NS}`.
2. Reproduce the DNS failure from inside `q03-dnsclient`.
3. Restore name resolution for both external and cluster-internal names.

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
