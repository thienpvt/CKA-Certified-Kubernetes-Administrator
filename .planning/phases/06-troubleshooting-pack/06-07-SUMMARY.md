---
phase: 06-troubleshooting-pack
plan: 07
subsystem: cka-sim troubleshooting pack
tags: [troubleshooting, static-pod, yaml-validation, phase-06]
dependency_graph:
  requires: [06-01, 06-02, 06-03]
  provides: [troubleshooting-static-pod-manifest]
  affects: [cka-sim/packs/troubleshooting, cka-sim/scripts/lint-packs.sh]
tech_stack:
  added: [bash, pyYAML safe_load, kubectl client dry-run]
  patterns: [sandbox-only static pod repair, trap-recording grader, fixture score oracle]
key_files:
  created:
    - cka-sim/packs/troubleshooting/05-static-pod-manifest/setup.sh
    - cka-sim/packs/troubleshooting/05-static-pod-manifest/grade.sh
    - cka-sim/packs/troubleshooting/05-static-pod-manifest/reset.sh
    - cka-sim/packs/troubleshooting/05-static-pod-manifest/ref-solution.sh
    - cka-sim/packs/troubleshooting/05-static-pod-manifest/metadata.yaml
    - cka-sim/packs/troubleshooting/05-static-pod-manifest/question.md
    - cka-sim/tests/fixtures/phase-06/troubleshooting-05-static-pod-manifest/stub-responses.json
    - cka-sim/tests/fixtures/phase-06/troubleshooting-05-static-pod-manifest/expected-fail-score.txt
    - cka-sim/tests/fixtures/phase-06/troubleshooting-05-static-pod-manifest/expected-pass-score.txt
  modified:
    - cka-sim/scripts/lint-packs.sh
decisions:
  - Allow kubectl apply only when immediately constrained by --dry-run=client in grade.sh lint, preserving read-only grader safety while matching Q05 oracle.
metrics:
  duration: not recorded
  completed_date: 2026-05-13
  tasks_completed: 1
  files_changed: 10
commits:
  - de0ec6d
---

# Phase 06 Plan 07: Static Pod Manifest Troubleshooting Summary

Sandbox-only static pod manifest repair with two seeded broken variants and client-side grader oracle.

## Completed Work

- Added `troubleshooting-static-pod-manifest` question under `cka-sim/packs/troubleshooting/05-static-pod-manifest/`.
- Added sandbox setup for `/tmp/q05-staticpod/` with `.cka-sim-sentinel`, `manifest-broken.yaml`, `manifest-tagtypo.yaml`, and candidate `manifest.yaml`.
- Added grader assertions for file presence, YAML parse via `python3 yaml.safe_load`, `kind: Pod`, and `kubectl apply --dry-run=client`.
- Added trap detection for `static-pod-manifest-bad-yaml` and `static-pod-image-tag-typo`.
- Added canonical `ref-solution.sh` using pinned `nginx:1.27-alpine`.
- Added sentinel-guarded reset that removes only `/tmp/q05-staticpod/` and deletes lab namespace.
- Added fixtures for fail score `SCORE: 1/4`, pass score `SCORE: 4/4`, and valid JSON kubectl dry-run stub.

## Architecture

### Broken variants

- `manifest-broken.yaml`: valid static Pod shape with literal TAB before nested `limits:` key, forcing PyYAML parse failure.
- `manifest-tagtypo.yaml`: valid YAML Pod using `nginx:1.27-alpine-doesnotexistXYZ` for image-tag trap coverage.
- `manifest.yaml`: candidate working copy, initially copied from `manifest-broken.yaml`.

### Grader design

- Grader remains sandbox-only and never copies manifest into host control-plane paths.
- YAML parse uses `python3 yaml.safe_load` against `/tmp/q05-staticpod/manifest.yaml`.
- Kubernetes schema check uses `kubectl apply --dry-run=client -f /tmp/q05-staticpod/manifest.yaml` only.
- Image trap parses container image from YAML and records typo trap when `doesnotexistXYZ` remains.

## Verification

Commands run:

```bash
chmod +x cka-sim/packs/troubleshooting/05-static-pod-manifest/*.sh
bash -n cka-sim/packs/troubleshooting/05-static-pod-manifest/setup.sh
bash -n cka-sim/packs/troubleshooting/05-static-pod-manifest/grade.sh
bash -n cka-sim/packs/troubleshooting/05-static-pod-manifest/reset.sh
bash -n cka-sim/packs/troubleshooting/05-static-pod-manifest/ref-solution.sh
bash cka-sim/scripts/lint-packs.sh
bash cka-sim/scripts/lint-deprecated-strings.sh
bash cka-sim/scripts/lint-traps.sh
bash cka-sim/scripts/test.sh
```

Result: `test.sh` passed with `all 33 case(s) passed`.

Note: local Windows `python3` alias is unavailable, so direct `python3 json.load` acceptance check could not run in this shell. Fixture JSON was written as static minimal JSON and consumed only by existing test harness patterns.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Allow dry-run kubectl apply in grade lint**
- **Found during:** Task 1 verification
- **Issue:** `lint-packs.sh` rejected any `kubectl apply` in `grade.sh`, but plan requires `kubectl apply --dry-run=client` as read-only oracle.
- **Fix:** Updated mutating-verb lint to keep `delete|create|patch|edit|replace` forbidden and allow `kubectl apply` only when line contains `apply --dry-run=client`.
- **Files modified:** `cka-sim/scripts/lint-packs.sh`
- **Commit:** `de0ec6d`

## Safety Checks

- `setup.sh` contains no `/etc/kubernetes/`, `/var/lib/kubelet/`, or `systemctl` writes.
- `grade.sh` uses only `kubectl apply --dry-run=client`; no real cluster apply.
- `reset.sh` uses sentinel-guarded `rm -rf /tmp/q05-staticpod/` and no host control-plane path.
- `ref-solution.sh` writes only `/tmp/q05-staticpod/manifest.yaml` and pins `nginx:1.27-alpine`.

## Known Stubs

None.

## Threat Flags

None.

## Self-Check: PASSED

- Created pack files present: 6/6.
- Created fixture files present: 3/3.
- Task commit present: `de0ec6d`.
