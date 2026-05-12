# Troubleshooting: Pod cannot resolve or reach a backend

**Domain:** Troubleshooting  |  **Estimated time:** 8 minutes

A Pod in `${CKA_SIM_LAB_NS}` from `Deployment web` cannot resolve `kubernetes.default.svc.cluster.local` and cannot reach `Service api-svc` on TCP/8080. Pods are Running and Ready. A `Deployment api` exists behind the Service.

## Tasks

- Inspect namespaced workloads and Policy objects.
- From inside the `web` Pod, reproduce both probe failures.
- Restore both flows.

## Constraints

- Do not modify Deployments, Pods, or Service.
- Do not delete any Policy.
- Make only lab-ns-scoped changes; do not mutate cluster system namespaces.

## Verify yourself

```bash
kubectl exec -n "$CKA_SIM_LAB_NS" deploy/web -- nslookup kubernetes.default.svc.cluster.local
```

```bash
kubectl exec -n "$CKA_SIM_LAB_NS" deploy/web -- bash -c 'echo > /dev/tcp/api-svc/8080'
```

Both commands must exit 0.
