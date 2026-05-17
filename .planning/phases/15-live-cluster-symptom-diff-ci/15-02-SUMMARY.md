# Plan 15-02 SUMMARY

**Phase:** 15-live-cluster-symptom-diff-ci
**Plan:** 02 — Storage pack expected-symptom YAMLs (5 files: 02-06)
**Status:** Complete (structural acceptance).

## Files shipped (5)

- `cka-sim/packs/storage/02-storageclass-dynamic/expected-symptom.yaml` — PVC `app-cache` Pending with storageClassName=fast-ssd; StorageClass fast-ssd absent.
- `cka-sim/packs/storage/03-access-modes-reclaim/expected-symptom.yaml` — q03-rwo-pvc Bound, q03-rwx-pvc Pending; PV reclaim policies Retain (q03-retain-pv) and Delete (q03-delete-pv).
- `cka-sim/packs/storage/04-csi-volumesnapshot/expected-symptom.yaml` — PVC `app-data` Bound on local-path; VolumeSnapshotClass q04-snapclass + VolumeSnapshot q04-snapshot absent (candidate-authored).
- `cka-sim/packs/storage/05-wait-for-first-consumer/expected-symptom.yaml` — PVC q05-claim Pending; StorageClass q05-wffc with volumeBindingMode WaitForFirstConsumer; PV q05-wffc-pv Available.
- `cka-sim/packs/storage/06-pvc-mount-pod/expected-symptom.yaml` — PVC q06-data Bound; PV q06-data-pv Bound; Deployment q06-reader absent (candidate-authored).

## Verification

- All 5 files parse via `python -c 'import yaml; yaml.safe_load(...)'`.
- All use `${CKA_SIM_LAB_NS}` substitution where lab-scoped.
- All derive from question.md claims, not setup.sh output.
- Live-cluster end-to-end deferred to plan 07's GHA `symptom-diff` job.

Storage pack total: 6 (01 from plan 01 + 02-06 here).
