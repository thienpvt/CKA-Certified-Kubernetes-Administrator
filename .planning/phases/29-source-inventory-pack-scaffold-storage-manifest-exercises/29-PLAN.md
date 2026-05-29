# Phase 29 Plan - Source Inventory + Pack Scaffold + Storage/Manifest Exercises

**Status:** Planned

<objective>
Create the `cka-prep-2025-v2` pack root, source inventory, manifest, coverage map, README, all 17 planned runtime entries, and complete Phase 29 exercises for MariaDB/PV restore, Argo CD manifest rendering without CRDs, cert-manager CRD inspection, and StorageClass defaulting.
</objective>

<requirements>
SRC-04, SRC-05, SRC-06, PACK-05, PACK-06, PACK-07, PACK-08, VJQ-01, VJQ-02, VJQ-06, VJQ-14
</requirements>

<tasks>

1. Build pack scaffold at `cka-sim/packs/cka-prep-2025-v2` with `README.md`, `manifest.yaml`, `coverage.yaml`, and `SOURCE-INVENTORY.md`.
2. Map all 17 cloned `Question-*` folders from `D:\git\CKA-PREP-2025-v2` at commit `38c2a0e3ed3eb93baac4fc7423f082b136a2141f` to stable source keys, requirement IDs, simulator question IDs, runtime paths, domains, and v1.35/lab-safety adaptation notes.
3. Create complete seven-file runtime directories for all 17 planned entries while preserving existing packs; Phase 29 must fully implement only source Q1, Q2, Q6, and Q14.
4. Implement VJQ-01 MariaDB/PV retained-data restore with idempotent setup/reset, authored-state grading, reference solution, expected symptom, and zero-score empty behavior.
5. Implement VJQ-02 Argo CD manifest rendering without CRDs using deterministic repo-local or cluster-seeded data instead of live Helm/Argo/internet dependencies.
6. Implement VJQ-06 cert-manager CRD inspection with deterministic seeded CRD documentation and grader-visible captured Certificate subject data.
7. Implement VJQ-14 StorageClass defaulting with cluster-scoped reset safety that restores pre-existing default StorageClass annotations.
8. Review all authored question wording and reference solutions to ensure no source question text or source answer text is copied verbatim.
9. Run static and unit gates: `lint-packs.sh`, `lint-coverage.sh`, `lint-traps.sh`, `lint-trap-coverage.sh`, `lint-question-symptom.sh`, and `test.sh`; record verification results.

</tasks>
