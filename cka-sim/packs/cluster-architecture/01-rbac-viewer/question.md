# cluster-architecture/01-rbac-viewer

**Domain:** Cluster Architecture  |  **Estimated time:** 8 minutes

A `ServiceAccount` named `viewer` exists in your lab namespace, along with a `Role` named `pod-viewer` and a `RoleBinding` named `viewer-binding`. The intent is that `viewer` can read Pods in the namespace, but it cannot.

## Tasks

1. Inspect the Role `pod-viewer`, the RoleBinding `viewer-binding`, and the ServiceAccount `viewer` in `${CKA_SIM_LAB_NS}`.
2. Diagnose why the `viewer` ServiceAccount cannot read Pods. Check what the Role actually permits.
3. Modify the resources so that `kubectl auth can-i get pods --as=system:serviceaccount:${CKA_SIM_LAB_NS}:viewer -n ${CKA_SIM_LAB_NS}` returns `yes`.

## Constraints

- Do NOT delete or recreate the Role or RoleBinding — modify in place.
- Do NOT grant cluster-wide permissions (ClusterRole/ClusterRoleBinding).
- The Role must still be scoped to Pods only (no wildcards, no other resources).

## Verify yourself

Before typing `done`, confirm:

```
kubectl auth can-i get pods -n ${CKA_SIM_LAB_NS} \
  --as=system:serviceaccount:${CKA_SIM_LAB_NS}:viewer
# Should print: yes
```
