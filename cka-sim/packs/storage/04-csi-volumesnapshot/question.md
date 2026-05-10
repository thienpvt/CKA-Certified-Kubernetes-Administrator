# storage/04-csi-volumesnapshot

**Domain:** Storage  |  **Estimated time:** 9 minutes

A PVC `app-data` in `${CKA_SIM_LAB_NS}` holds a file `/data/marker` written by a helper pod. The cluster has a CSI driver installed with a matching `VolumeSnapshotClass`. Capture the PVC's current state as a `VolumeSnapshot` resource.

## Tasks

1. Confirm a `VolumeSnapshotClass` is present on the cluster and note its name.
2. Create a `VolumeSnapshot` named `q04-app-snapshot` in `${CKA_SIM_LAB_NS}` whose source is PVC `app-data` and whose `volumeSnapshotClassName` matches the installed class.
3. Wait until `.status.readyToUse` is `true`.

## Constraints

- Do NOT modify or delete PVC `app-data`.
- Do NOT install a new CSI driver; one is already available.

## Verify yourself

```
kubectl get volumesnapshotclass                                                                      # note the name
kubectl get volumesnapshot -n ${CKA_SIM_LAB_NS} q04-app-snapshot -o jsonpath='{.status.readyToUse}'  # true
```
