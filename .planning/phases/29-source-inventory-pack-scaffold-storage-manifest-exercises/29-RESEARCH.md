# Phase 29 Research: Source Inventory + Pack Scaffold + Storage/Manifest Exercises

**Researched:** 2026-05-29
**Scope:** Phase 29 implementation planning for `cka-prep-2025-v2`

## Existing Contracts To Preserve

- Pack root is `cka-sim/packs/<pack-id>/` with `README.md`, `manifest.yaml`, `coverage.yaml`, and optional source inventory docs.
- `lint-packs.sh` walks every question directory two levels under `cka-sim/packs` and requires `metadata.yaml`, `question.md`, `setup.sh`, `grade.sh`, `reset.sh`, and `ref-solution.sh` with executable shell files.
- Phase 29 success criteria require complete seven-file runtime directories, so each implemented question must also include `expected-symptom.yaml`.
- Metadata must include RFC 1123 `id`, one existing domain enum, integer `estimatedMinutes` in 4..12, `verified_against: "1.35"`, at least one registered trap, and at least one structured reference.
- Graders must be read-only: no `kubectl delete/create/patch/edit/replace`, and `kubectl apply` only with `--dry-run=client`.
- Setup scripts must not delete namespaces. Reset scripts must clean `/tmp/cka-sim/<slug>/`.
- Existing discovery reads `manifest.yaml` question entries with `id`, `path`, and `estimatedMinutes`; coverage lint checks every coverage question ID appears in manifest.

## Closest Existing Analogs

- `cka-sim/packs/dump-cooloo9871` is the closest source-derived pack scaffold. It uses stable source-derived ordering, a pack README, manifest, coverage map, and source inventory with adaptation notes.
- Storage analogs: `cka-sim/packs/storage/01-pvc-binding`, `storage/02-storageclass-dynamic`, and `dump-cooloo9871/06-source-q06-pv-pvc-pod-volume` show PVC/PV grading and storage metadata shape.
- Manifest/rendering analogs: existing command/inspection questions in `dump-cooloo9871` use ConfigMap-backed answer state when the candidate must capture derived data.
- CRD/certificate simulation analogs: `dump-cooloo9871/22-source-q22-apiserver-cert`, `23-source-q23-kubelet-certs`, and `28-preview-q01-etcd-certs` seed namespace-scoped deterministic data instead of touching host certificate paths.
- Cluster-scoped safety analogs: existing StorageClass/PriorityClass exercises reset cluster-scoped resources explicitly and avoid hard-coded node names.

## Source Inventory Shape

Create `SOURCE-INVENTORY.md` with one row per cloned `Question-*` folder:

- Source folder name and stable `source-qNN` key.
- Source commit and local path summary.
- Phase assignment and requirement ID.
- Simulator question ID and runtime path.
- Metadata domain.
- Runtime status for Phase 29 implemented entries versus later planned entries.
- v1.35/lab-safety adaptation note.

Phase 29 should list all 17 planned entries in manifest and coverage so `PACK-05` and `PACK-06` are true immediately. Because lint requires every manifest path to resolve to a directory with required files, create skeletal but complete seven-file directories for later-phase entries if needed, or keep later entries outside manifest. The roadmap success criteria say 17 planned entries in the pack scaffold, so the safer path is complete placeholder runtime directories for all 17 with non-scoring planned markers, then later phases replace those placeholders with real exercises.

## Phase 29 Exercise Design

Implemented question slice:

- VJQ-01 MariaDB/PV restore: seed a retained PV plus original workload failure state; candidate creates a replacement PVC/workload using retained data. Grade bound PVC, workload readiness, and data visibility while preserving empty-submission zero.
- VJQ-02 Argo CD manifest rendering: avoid Helm, internet, and Argo CD install. Seed deterministic chart-like source data in ConfigMaps and require the candidate to create a rendered manifest ConfigMap or Secret that excludes CRDs and keeps the workload resources.
- VJQ-06 cert-manager CRD inspection: seed deterministic CRD-like YAML/docs. Require the candidate to capture requested Certificate subject fields in a ConfigMap so grading is API-state-based and does not depend on cert-manager being installed.
- VJQ-14 StorageClass defaulting: create or patch `local-storage` as the only default class. Reset must restore any pre-existing default annotations captured during setup.

## Verification Strategy

Phase 29 can run:

- `bash cka-sim/scripts/lint-packs.sh`
- `bash cka-sim/scripts/lint-coverage.sh`
- `bash cka-sim/scripts/lint-traps.sh`
- `bash cka-sim/scripts/lint-trap-coverage.sh`
- `bash cka-sim/scripts/lint-question-symptom.sh`
- `bash cka-sim/scripts/test.sh`
- Targeted local smoke checks for `cka-sim list packs` and `cka-sim list questions cka-prep-2025-v2` if supported by the CLI.

Live drill empty/ref verification is deferred to Phase 33, but Phase 29 should keep local/static checks green and avoid known grading-honesty leaks.

## Risks And Plan Implications

- The user requested exact copying of source question content; project requirements explicitly forbid copied source wording and copied answer text. Plan must include a wording review step.
- Later-phase placeholders can accidentally become misleading runnable content. Mark placeholder question text clearly as "planned for later phase" and make graders fail with zero until replaced.
- Cluster-scoped StorageClass changes can leak across drills. Setup/reset must snapshot and restore default-class annotations.
- Argo CD/Helm source assumptions are environment-heavy. Use deterministic rendered-manifest modeling rather than requiring Helm or external downloads during drill execution.
- cert-manager CRDs may not exist on learner clusters. Seed deterministic CRD documents inside the lab namespace.
