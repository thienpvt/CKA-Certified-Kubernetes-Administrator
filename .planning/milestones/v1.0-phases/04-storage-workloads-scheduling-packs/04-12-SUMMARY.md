---
phase: 04-storage-workloads-scheduling-packs
plan: 12
subsystem: packs
tags: [workloads-scheduling, configmap, secret, env-var, volume-mount, read-only, items-projection, kubectl-exec]

# Dependency graph
requires:
  - phase: 04-storage-workloads-scheduling-packs
    provides: shared cka-sim/lib/setup.sh helpers (Plan 04-01)
  - phase: 04-storage-workloads-scheduling-packs
    provides: workloads-scheduling coverage.yaml slot `configmap-secret-env-volume` (Plan 04-02 / 04-03)
  - phase: 04-storage-workloads-scheduling-packs
    provides: workloads-deployment-requests reference question shape (Plan 04-05)
provides:
  - Workloads & Scheduling pack Q03 `workloads-configmap-secret-env-volume` (6 files + 3 fixtures)
  - valueFrom.configMapKeyRef env-var assertion idiom for graders (grade.sh jsonpath filter)
  - Secret `items` projection idiom (key API_KEY -> path api-key) for candidate-facing path-rename
  - Tracker coverage: configmap-secret-env-volume (primary)
affects: [04-16 manifest-catchup, future workloads questions needing env + volume behavioural probes]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Dual-behavioural-probe grader: kubectl exec printenv <VAR> AND kubectl exec cat <secret-file>, both manually incrementing CKA_SIM_GRADE_TOTAL outside assert_* helpers"
    - "Secret volume items[].path projection: candidate renames key API_KEY -> file path api-key so the exec probe has a deterministic path to cat"
    - "valueFrom.configMapKeyRef jsonpath filter: `env[?(@.name==\"APP_MODE\")].valueFrom.configMapKeyRef.{name,key}` to assert env wired via reference (not literal copy)"
    - "readOnly volume-mount jsonpath filter: `volumeMounts[?(@.mountPath==\"/etc/app-secrets\")].readOnly` keyed on mountPath for path-agnostic slot matching"

key-files:
  created:
    - cka-sim/packs/workloads-scheduling/03-configmap-secret-env-volume/metadata.yaml
    - cka-sim/packs/workloads-scheduling/03-configmap-secret-env-volume/question.md
    - cka-sim/packs/workloads-scheduling/03-configmap-secret-env-volume/setup.sh
    - cka-sim/packs/workloads-scheduling/03-configmap-secret-env-volume/grade.sh
    - cka-sim/packs/workloads-scheduling/03-configmap-secret-env-volume/reset.sh
    - cka-sim/packs/workloads-scheduling/03-configmap-secret-env-volume/ref-solution.sh
    - cka-sim/tests/fixtures/workloads-03-configmap-secret-env-volume/stub-responses.json
    - cka-sim/tests/fixtures/workloads-03-configmap-secret-env-volume/expected-fail-score.txt
    - cka-sim/tests/fixtures/workloads-03-configmap-secret-env-volume/expected-pass-score.txt
  modified: []

key-decisions:
  - "Used busybox:1.36 with `sleep 3600` (matching the `sh -c` wrapper idiom) so the pod stays Running long enough for the grader's dual exec probes without needing a real daemon image"
  - "Assertion on `volumeMounts[?(@.mountPath==\"/etc/app-secrets\")].readOnly` keyed by mountPath (not array index 0) so the candidate can add other volume mounts without breaking the grader"
  - "ref-solution uses Secret `items:` projection with explicit `path: api-key` rename — without it, the key lands at /etc/app-secrets/API_KEY (uppercase) which would mismatch the question's stated /etc/app-secrets/api-key path"
  - "setup.sh seeds Secret via `stringData.API_KEY: q03-api-key-value` (not base64 `data:`) for authoring ergonomics — Kubernetes converts to base64 server-side"
  - "Only the `default-sa-used` trap is actively detected at grade time; the other two (`hostpath-pv-without-nodeaffinity`, `deployment-missing-requests`) are registered in metadata per plan requirement but are concern-style education items that don't apply to a single-Pod question"

patterns-established:
  - "kv-projection-question: seed CM+Secret with known values; candidate creates Pod that consumes each via the correct projection (env valueFrom for CM keys, volume items[] for Secret file paths); grader asserts both declarative jsonpath AND behavioural exec probes"
  - "behavioural-exec-grader: kubectl exec <pod> -- {printenv <VAR> | cat <path>} | tr -d CR/LF/space; string-equality against sentinel; increment CKA_SIM_GRADE_TOTAL manually outside assert_* helpers"

requirements-completed: [PACK-02, PACK-06]

# Metrics
duration: ~12min
completed: 2026-05-10
---

# Phase 04 Plan 12: Workloads Q03 configmap-secret-env-volume Summary

**Workloads & Scheduling pack Q03 `workloads-configmap-secret-env-volume`: candidate builds a Pod that reads a ConfigMap key into an env var via `valueFrom.configMapKeyRef` AND mounts a Secret read-only at `/etc/app-secrets/api-key`; grader verifies via jsonpath plus `kubectl exec printenv` + `kubectl exec cat /etc/app-secrets/api-key` behavioural probes.**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-05-10T17:35:00Z
- **Completed:** 2026-05-10T17:47:00Z
- **Tasks:** 1
- **Files modified:** 9 (all created)

## Accomplishments

- Shipped full 6-file question shape for `workloads-configmap-secret-env-volume` with exec-bit on all 4 `.sh` files (chmod 755 in git index via `git update-index --chmod=+x`).
- `setup.sh` sources `cka-sim/lib/setup.sh`, calls `ensure_lab_ns` + `wait_for_ns_active` (120 s), then seeds ConfigMap `q03-app-config` (`data.APP_MODE: production`) + Secret `q03-app-secret` (`stringData.API_KEY: q03-api-key-value`). No candidate-side Pod — the candidate creates it.
- `grade.sh` runs 6 assertions (state machine increments `CKA_SIM_GRADE_TOTAL` to 6): pod Ready, env configMapKeyRef.name, env configMapKeyRef.key, volumeMount at /etc/app-secrets has readOnly=true, behavioural `printenv APP_MODE` match, behavioural `cat /etc/app-secrets/api-key` match. Grader records `default-sa-used` trap when the candidate's Pod inherits the default SA.
- `ref-solution.sh` lands a dedicated `q03-app-sa` ServiceAccount + Pod `q03-app` on `busybox:1.36 sleep 3600` with `valueFrom.configMapKeyRef` env and a Secret volume projecting `API_KEY -> api-key` with `readOnly: true`; waits for `Ready=True` up to 60 s.
- `reset.sh` async-deletes the lab namespace (no cluster-scoped resources to clean).
- `metadata.yaml`: `id: workloads-configmap-secret-env-volume`, `domain: workloads-scheduling`, `estimatedMinutes: 8`, `verified_against: "1.35"`, traps `[default-sa-used, hostpath-pv-without-nodeaffinity, deployment-missing-requests]` (all registered in `cka-sim/traps/catalog.yaml`), 3 references (2 k8s-doc + 1 pattern link).
- Round-trip fixture dir `cka-sim/tests/fixtures/workloads-03-configmap-secret-env-volume/` with `stub-responses.json` (golden Pod JSON matching the ref-solution), `expected-pass-score.txt` (`SCORE: 6/6`), and `expected-fail-score.txt` (`SCORE: 0/6`).

## Task Commits

Each task committed atomically:

1. **Task 1: 6 question files + 3 fixtures** — `6aed4c5` (feat)

## Files Created

- `cka-sim/packs/workloads-scheduling/03-configmap-secret-env-volume/metadata.yaml` — id, domain, estimatedMinutes=8, 3 traps, 3 references
- `cka-sim/packs/workloads-scheduling/03-configmap-secret-env-volume/question.md` — candidate-facing brief (tasks + constraints + verify-yourself exec commands)
- `cka-sim/packs/workloads-scheduling/03-configmap-secret-env-volume/setup.sh` — ns + ConfigMap + Secret seeding via shared `lib/setup.sh` helpers
- `cka-sim/packs/workloads-scheduling/03-configmap-secret-env-volume/grade.sh` — 6 assertions (4 jsonpath + 2 behavioural exec) + default-sa-used detector
- `cka-sim/packs/workloads-scheduling/03-configmap-secret-env-volume/reset.sh` — async ns delete
- `cka-sim/packs/workloads-scheduling/03-configmap-secret-env-volume/ref-solution.sh` — dedicated SA + Pod with env valueFrom + Secret items projection + readiness wait
- `cka-sim/tests/fixtures/workloads-03-configmap-secret-env-volume/stub-responses.json` — golden Pod shape
- `cka-sim/tests/fixtures/workloads-03-configmap-secret-env-volume/expected-fail-score.txt` — no-candidate baseline (`SCORE: 0/6`)
- `cka-sim/tests/fixtures/workloads-03-configmap-secret-env-volume/expected-pass-score.txt` — ref-solution score (`SCORE: 6/6`)

## Decisions Made

- Used `busybox:1.36` with `sleep 3600` so the Pod stays Running long enough for two successive exec probes without pulling a heavier nginx image. `busybox` also provides `printenv` + `cat` needed by the grader.
- Keyed the volumeMount readOnly assertion on `mountPath=="/etc/app-secrets"` (not `volumeMounts[0]`) so the candidate can add other mounts without breaking the assertion — the question only constrains the app-secrets mount.
- Chose `stringData.API_KEY` in setup.sh over `data.API_KEY: cTAzLWFwaS1rZXktdmFsdWU=` (base64). Both are equivalent to the kube-apiserver, but `stringData` is authoring-friendlier for review.
- ref-solution uses `items: [{key: API_KEY, path: api-key}]` to rename the key to lowercase `api-key` so the Secret file lands at the question-stated `/etc/app-secrets/api-key` path. Without `items:`, Kubernetes would project `/etc/app-secrets/API_KEY` (uppercase) and the behavioural probe would fail on case.
- Kept the reset script simple (async ns delete only). No cluster-scoped resources were seeded, so no cluster cleanup is needed.
- Did NOT touch `cka-sim/packs/workloads-scheduling/manifest.yaml`. Per plan instructions and prior summaries (04-10), manifest catch-up is Plan 16's responsibility in Wave 4.

## Deviations from Plan

None — plan executed as written. All acceptance criteria satisfied as authored (including the literal AC regex checks for `valueFrom.configMapKeyRef`, `kubectl exec.*cat /etc/app-secrets/api-key`, `path: api-key`, `APP_MODE: production`, and `API_KEY: q03-api-key-value`).

## Issues Encountered

- `git add` on new files initially recorded mode 100644 despite the filesystem `+x` bits (Windows/NTFS filemode interaction with git). Resolved via `git update-index --chmod=+x` on the four `.sh` files after staging. Final index shows 100755 on `setup.sh`, `grade.sh`, `reset.sh`, `ref-solution.sh`.
- `lint-coverage.sh` will report forward-reference errors for `workloads-configmap-secret-env-volume` being in `coverage.yaml` but not yet in `manifest.yaml`. Expected and consistent with sibling Wave 3 plans — `manifest.yaml` catch-up is Plan 16.

## Validation Results

- `bash cka-sim/scripts/test.sh` — PASS (lint-traps + lint-packs + 29 unit cases all green).
- `bash -n` on all four `.sh` — syntax OK.
- `grep -q 'APP_MODE: production' setup.sh` — match.
- `grep -q 'API_KEY: q03-api-key-value' setup.sh` — match.
- `grep -q 'valueFrom.configMapKeyRef' grade.sh` — match.
- `grep -q 'kubectl exec.*cat /etc/app-secrets/api-key' grade.sh` — match.
- `grep -q 'path: api-key' ref-solution.sh` — match.
- `grep -qE '^id:' metadata.yaml` — match (`id: workloads-configmap-secret-env-volume`).
- `grep -qE '^domain: workloads-scheduling$' metadata.yaml` — match.
- `grep -qE '^estimatedMinutes: 8$' metadata.yaml` — match (in [4,12] range).
- `grep -q 'verified_against: "1.35"' metadata.yaml` — match.
- metadata traps list: 3 entries, all registered in `cka-sim/traps/catalog.yaml`.
- `! grep -qE 'kubectl[[:space:]]+(delete|create|apply|patch|edit|replace)' grade.sh` — no mutating verbs in grader.
- `! grep -qE 'kubectl[[:space:]]+get[[:space:]].*\|[[:space:]]*grep' grade.sh` — no banned `get | grep`.

## Next Phase Readiness

- Workloads & Scheduling pack now has Q01 (deployment-requests, reference + retrofit) + Q03 (configmap-secret-env-volume, this plan). Remaining Wave 3 workloads questions (Q02 rolling-update-rollback, Q04 hpa-metrics-server, Q05 daemonset, Q06 static-pod, Q07 native-sidecar, Q08 nodeselector-affinity-taints) ship in sibling plans 04-11 and 04-13..04-15.
- Plan 16 (Wave 4) will append `workloads-configmap-secret-env-volume` (path `03-configmap-secret-env-volume`) to `cka-sim/packs/workloads-scheduling/manifest.yaml`, at which point `lint-coverage.sh` will go green for the `configmap-secret-env-volume` tracker entry.

## Self-Check: PASSED

- File `cka-sim/packs/workloads-scheduling/03-configmap-secret-env-volume/metadata.yaml` — FOUND
- File `cka-sim/packs/workloads-scheduling/03-configmap-secret-env-volume/question.md` — FOUND
- File `cka-sim/packs/workloads-scheduling/03-configmap-secret-env-volume/setup.sh` — FOUND
- File `cka-sim/packs/workloads-scheduling/03-configmap-secret-env-volume/grade.sh` — FOUND
- File `cka-sim/packs/workloads-scheduling/03-configmap-secret-env-volume/reset.sh` — FOUND
- File `cka-sim/packs/workloads-scheduling/03-configmap-secret-env-volume/ref-solution.sh` — FOUND
- File `cka-sim/tests/fixtures/workloads-03-configmap-secret-env-volume/stub-responses.json` — FOUND
- File `cka-sim/tests/fixtures/workloads-03-configmap-secret-env-volume/expected-fail-score.txt` — FOUND
- File `cka-sim/tests/fixtures/workloads-03-configmap-secret-env-volume/expected-pass-score.txt` — FOUND
- Commit `6aed4c5` — FOUND in `git log --oneline`

---
*Phase: 04-storage-workloads-scheduling-packs*
*Completed: 2026-05-10*
