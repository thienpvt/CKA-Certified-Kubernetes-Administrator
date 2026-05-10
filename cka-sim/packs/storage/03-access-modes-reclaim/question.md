# storage/03-access-modes-reclaim

**Domain:** Storage  |  **Estimated time:** 9 minutes

Two PersistentVolumes (`q03-retain-pv`, `q03-delete-pv`) and two PVCs (`q03-rwo-pvc`, `q03-rwx-pvc`) exist. One PVC is Bound; the other is stuck Pending. Separately, business rules have changed: volumes that were originally configured to survive PVC deletion must now be reclaimed automatically.

## Tasks

1. Inspect both PVs and both PVCs in `${CKA_SIM_LAB_NS}`.
2. Fix the Pending PVC by modifying the PV(s) — not the PVC — so its access-mode request can be satisfied.
3. Change the reclaim policy on `q03-retain-pv` so that deleting its PVC will also delete the underlying volume.

## Constraints

- Do NOT modify the PVCs.
- Do NOT delete and recreate the PVs — patch them in place.

## Verify yourself

```
kubectl get pvc -n ${CKA_SIM_LAB_NS}                                              # both STATUS=Bound
kubectl get pv q03-retain-pv -o jsonpath='{.spec.persistentVolumeReclaimPolicy}'  # Delete
```
