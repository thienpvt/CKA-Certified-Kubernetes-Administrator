# storage/05-wait-for-first-consumer

**Domain:** Storage  |  **Estimated time:** 7 minutes

A `PersistentVolumeClaim` named `q05-claim` in `${CKA_SIM_LAB_NS}` is stuck `Pending`. Events show
`waiting for first consumer to be created before binding`. The `StorageClass` `q05-wffc` is intentional —
you must work with it, not around it. A matching `PersistentVolume` `q05-wffc-pv` already exists and is
pinned to a worker node via `nodeAffinity`.

## Tasks

1. Inspect `q05-claim` and the `StorageClass` `q05-wffc` to understand why binding is deferred.
2. Get the PVC to `Bound` without modifying the `StorageClass` or the `PVC` itself.
3. Follow ServiceAccount hygiene — do NOT rely on the `default` ServiceAccount.

## Constraints

- Do NOT change `q05-claim.spec.storageClassName`.
- Do NOT delete or modify the `StorageClass` `q05-wffc`.
- Do NOT modify the existing PV `q05-wffc-pv`.
- The workload Pod you create MUST be named `q05-consumer`.
- The Pod MUST mount `q05-claim` via `spec.volumes[0].persistentVolumeClaim.claimName`.

## Verify yourself

Before typing `done`, confirm:

```
kubectl get pvc q05-claim  -n ${CKA_SIM_LAB_NS}    # STATUS should be Bound
kubectl get pod q05-consumer -n ${CKA_SIM_LAB_NS}  # READY should be 1/1
```
