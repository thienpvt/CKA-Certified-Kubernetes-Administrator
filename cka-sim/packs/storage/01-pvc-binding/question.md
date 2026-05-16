# storage/01-pvc-binding

**Domain:** Storage  |  **Estimated time:** 8 minutes

A `PersistentVolumeClaim` named `app-data` exists in your lab namespace and references a `PersistentVolume` named `q01-app-pv`. The PVC is stuck `Pending`.

## Tasks

1. Inspect the PVC `app-data` in `${CKA_SIM_LAB_NS}` and the PV `q01-app-pv` (cluster-scoped).
2. Diagnose why the PVC is not binding. Read the PV spec and events carefully.
3. Modify the PV in place so the PVC can bind successfully.

## Constraints

- Do NOT delete or recreate the PV — modify it in place.
- Do NOT modify the PVC.
- The lab cluster has 1 control-plane + 2 worker nodes. The PV must remain usable on any worker.

## Verify yourself

Before typing `done`, confirm:

```
kubectl get pvc app-data -n ${CKA_SIM_LAB_NS}    # STATUS should be Bound
kubectl get pv q01-app-pv                        # STATUS should be Bound
```
