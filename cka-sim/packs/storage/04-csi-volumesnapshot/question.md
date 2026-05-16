# storage/04-csi-volumesnapshot

**Domain:** Storage  |  **Estimated time:** 9 minutes

A `PersistentVolumeClaim` named `app-data` in `${CKA_SIM_LAB_NS}` is `Bound` (backed by `rancher.io/local-path`). Your task is to author a `VolumeSnapshot` of it, which requires first creating a `VolumeSnapshotClass`.

> **Note:** `rancher.io/local-path` does not implement real CSI snapshots. The grader verifies your `VolumeSnapshotClass` and `VolumeSnapshot` are schema-correct and reference the installed provisioner. This question teaches the API shape (what a `VolumeSnapshotClass` is, how a `VolumeSnapshot` references a PVC), not a working backup.

## Tasks

1. Create a cluster-scoped `VolumeSnapshotClass` named `q04-snapclass` with:
   - `driver: rancher.io/local-path`
   - `deletionPolicy: Delete`
2. Create a `VolumeSnapshot` named `q04-snapshot` in `${CKA_SIM_LAB_NS}` that:
   - References `q04-snapclass` via `spec.volumeSnapshotClassName`
   - Sources `spec.source.persistentVolumeClaimName: app-data`

## Constraints

- Do NOT modify or delete the `app-data` PVC or the writer Pod.
- `apiVersion` for both objects: `snapshot.storage.k8s.io/v1`.
- The `driver` field must literally be `rancher.io/local-path` (the provisioner installed on your cluster).

## Verify yourself

```
kubectl get volumesnapshotclass q04-snapclass -o jsonpath='{.driver}'    # rancher.io/local-path
kubectl get volumesnapshot q04-snapshot -n ${CKA_SIM_LAB_NS} \
  -o jsonpath='{.spec.source.persistentVolumeClaimName}'                  # app-data
```
