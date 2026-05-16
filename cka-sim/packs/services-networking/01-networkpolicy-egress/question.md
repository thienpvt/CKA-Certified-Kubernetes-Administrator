# services-networking/01-networkpolicy-egress

**Domain:** Services & Networking  |  **Estimated time:** 9 minutes

A `Pod` named `probe` is running in `${CKA_SIM_LAB_NS}` and a `NetworkPolicy` named `egress-restrict` is in place. The pod is supposed to be able to resolve and reach the in-cluster DNS service, but DNS resolution from the pod is failing.

## Tasks

1. Inspect the `NetworkPolicy` `egress-restrict` in `${CKA_SIM_LAB_NS}`.
2. Diagnose why the pod cannot resolve names like `kubernetes.default`. Read the policy's egress rules carefully.
3. Modify the NetworkPolicy in place so DNS resolution from the pod succeeds.

## Constraints

- Do NOT delete the NetworkPolicy — modify it in place (`kubectl edit netpol egress-restrict -n ${CKA_SIM_LAB_NS}`).
- You must NOT widen egress beyond what is required for DNS resolution.

## Verify yourself

Before typing `done`, confirm:

```
kubectl exec -n ${CKA_SIM_LAB_NS} probe -- nslookup kubernetes.default 2>&1 | head -5
```
This should resolve, not time out.
