# storage/02-storageclass-dynamic

**Domain:** Storage  |  **Estimated time:** 7 minutes

A `PersistentVolumeClaim` named `app-cache` exists in your lab namespace. It requests a specific `StorageClass` that does not exist on the cluster, so the PVC is stuck `Pending`.

## Tasks

1. Inspect the PVC `app-cache` in `${CKA_SIM_LAB_NS}` and note the `storageClassName` it requires.
2. Create a matching `StorageClass` that supports dynamic volume binding on this cluster.
3. Wait for the PVC to reach `Bound`.

## Constraints

- Do NOT modify the PVC (its `storageClassName` is locked per the scenario).
- Do NOT create the PV by hand — the StorageClass must bind dynamically.
- The cluster is 1 control-plane + 2 workers; pick a backing plugin that actually runs here.

## Verify yourself

Before typing `done`, confirm:

```
kubectl get sc
kubectl get pvc app-cache -n ${CKA_SIM_LAB_NS}    # STATUS should be Bound
```
