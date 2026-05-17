# storage/01-pvc-binding

**Domain:** Storage  |  **Estimated time:** 8 minutes

A `PersistentVolumeClaim` named `app-data` exists in your lab namespace and references a `PersistentVolume` named `q01-app-pv`. A consumer Pod named `q01-app-consumer` has been deployed in your lab namespace to mount that PVC, but the Pod fails to schedule onto a worker node.

## Tasks

1. Inspect the Pod `q01-app-consumer` and the PVC `app-data` in `${CKA_SIM_LAB_NS}`, and the PV `q01-app-pv` (cluster-scoped).
2. Diagnose why the Pod cannot schedule. Read the PV spec and Pod events carefully.
3. Modify the PV in place so the Pod can schedule successfully.

## Constraints

- Do NOT delete or recreate the PV — modify it in place.
- Do NOT modify the PVC.
- Do NOT modify the consumer Pod `q01-app-consumer`.
- The lab cluster has 1 control-plane + 2 worker nodes. The PV must remain usable on any worker.

## Verify yourself

Before typing `done`, confirm:

```
kubectl get pod q01-app-consumer -n ${CKA_SIM_LAB_NS}    # STATUS should be Running
kubectl get pvc app-data -n ${CKA_SIM_LAB_NS}            # STATUS should be Bound
kubectl get pv q01-app-pv                                # STATUS should be Bound
```
