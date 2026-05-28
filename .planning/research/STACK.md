# Stack Research: v1.1 Dump Cooloo9871 Pack

**Date:** 2026-05-28
**Source:** https://github.com/cooloo9871/cooloo9871.github.io/tree/master/cka

## Existing Stack To Reuse

- Bash-only runtime under `cka-sim`.
- Per-question files: `question.md`, `metadata.yaml`, `setup.sh`, `grade.sh`, `reset.sh`, `ref-solution.sh`, `expected-symptom.yaml`.
- Existing pack-level files: `manifest.yaml`, `coverage.yaml`, `README.md`.
- Existing libraries: `cka-sim/lib/setup.sh`, `cka-sim/lib/grade.sh`, `cka-sim/lib/traps.sh`, baseline ownership helpers, trap catalog, and lint scripts.
- Existing verification: `cka-sim/scripts/lint-packs.sh`, `lint-coverage.sh`, `lint-traps.sh`, `lint-trap-coverage.sh`, `lint-question-symptom.sh`, `test.sh`, and live drill UAT drivers.

## Source Stack Constraints

- Source content targets old Killer Shell style multi-cluster tasks with contexts like `k8s-c1-H`, `k8s-c2-AC`, `k8s-c3-CCC`.
- Source page references Kubernetes-era assumptions around 1.24 and older images.
- This repo targets Kubernetes 1.35, one kubeadm cluster, 1 control-plane plus at least 2 workers, and terminal-only drill/exam execution.
- Source repo exposes no license file in the GitHub tree. Treat it as topic inventory only; do not copy question prose, answer text, scripts, or bundled assets.

## Stack Additions

No new runtime dependency should be added. The new pack should use only:

- `bash`
- `kubectl`
- `jq`
- existing host tools already accepted by the project (`ssh`, `openssl`, `kubeadm`, `etcdctl`, `crictl` where existing patterns allow them)

## Compatibility Notes

- Replace multi-context assumptions with single-cluster lab namespaces and existing SSH topology.
- Replace deprecated or stale image versions only when needed for v1.35 reliability.
- Prefer resource names scoped under `dump-cooloo9871-*` or per-question `qNN-*` names that satisfy RFC 1123.
- Do not depend on cloud-provider-specific node names from source content.

## Recommendation

Build `dump-cooloo9871` as a normal pack using existing pack scaffolding and libraries. Add no new simulator command surface in v1.1 unless lint reveals a generic pack-discovery gap.
