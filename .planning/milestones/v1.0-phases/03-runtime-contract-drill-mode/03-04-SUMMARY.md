---
phase: 03-runtime-contract-drill-mode
plan: 04
status: complete
completed: 2026-05-10
---

# Plan 03-04 Summary — storage pack + 01-pvc-binding reference question

## What shipped

8 new files — 2 pack-level + 6 question:

- `cka-sim/packs/storage/manifest.yaml` — pack id `storage`, weight 10, 1 question entry (`storage-pvc-binding`, path `01-pvc-binding`, estimatedMinutes 8)
- `cka-sim/packs/storage/README.md` — domain/blueprint notes + run instructions + Phase 4 (PACK-01) forward-reference
- `cka-sim/packs/storage/01-pvc-binding/metadata.yaml` — 6 required keys; `verified_against: "1.35"`; 3 trap-ids (`hostpath-pv-without-nodeaffinity`, `pvc-wrong-storageclass`, `pv-accessmodes-mismatch`) all registered in the Wave-1 catalog; 2 references
- `cka-sim/packs/storage/01-pvc-binding/question.md` — PSI-style 3-step prompt + constraints + self-verify block; uses `${CKA_SIM_LAB_NS}` placeholder; does NOT spoiler the trap word "nodeAffinity"
- `cka-sim/packs/storage/01-pvc-binding/setup.sh` (755) — idempotent ns apply + 50s ns-Active wait + hostPath PV `q01-app-pv` **without** `nodeAffinity` (the seeded trap) + PVC `app-data` (`storageClassName: manual`, RWO, 500Mi) that stays Pending
- `cka-sim/packs/storage/01-pvc-binding/grade.sh` (755) — `set -uo pipefail`; sources `lib/grade.sh` + `lib/traps.sh`; `assert_pvc_bound` + `assert_field_eq` on PV's `.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].key == kubernetes.io/hostname`; `detect_hostpath_pv_without_nodeaffinity` → `record_trap`; ends with `emit_result`
- `cka-sim/packs/storage/01-pvc-binding/reset.sh` (755) — async `kubectl delete namespace --ignore-not-found --wait=false` + cluster-scoped `kubectl delete pv q01-app-pv --ignore-not-found`
- `cka-sim/packs/storage/01-pvc-binding/ref-solution.sh` (755) — JSON-patch PV with `kubernetes.io/hostname` `Exists` nodeAffinity (permissive — any worker matches, honoring the "remain usable on any worker" constraint from the prompt)

## Trap mapping

| trap-id                              | role in this question | catalog match           |
| ------------------------------------ | --------------------- | ----------------------- |
| hostpath-pv-without-nodeaffinity     | **seeded** — setup.sh omits nodeAffinity; grader detector fires; ref-solution.sh patches it in | severity `warn`, domain `storage` |
| pvc-wrong-storageclass               | advertised — metadata only (future variants may seed it)     | severity `warn`, domain `storage` |
| pv-accessmodes-mismatch              | advertised — metadata only (future variants may seed it)     | severity `warn`, domain `storage` |

Satisfies GRADE-04 (`traps[] >= 3`). Only the seeded trap is actively detected by this question's `grade.sh`.

## Contract compliance

- **TRIP-01** triplet shape — all 6 required files present at `cka-sim/packs/storage/01-pvc-binding/`
- **TRIP-02** idempotent setup — `kubectl apply -f -` heredoc throughout; ns-Active wait-loop handles prior `--wait=false` Terminating
- **TRIP-03** cluster-scoped resources prefixed `q01-` — `q01-app-pv`
- **TRIP-04..06** reset async + `--ignore-not-found`, namespace-scoped resources unprefixed (`app-data`), labels `cka-sim/pack=storage` + `cka-sim/question-id=storage-pvc-binding`
- **GRADE-02** `grade.sh` is read-only (zero mutating kubectl verbs, no `kubectl get | grep`, no `kubectl get -A`)
- **GRADE-03** `set -uo pipefail` (not `-e`) so both assertions run even if the first fails
- **GRADE-04** 3 trap-ids in metadata.yaml all catalog-registered
- **GRADE-06** round-trip demonstrable: `setup.sh` → FAIL (1/2 assertions, Trap hostpath-pv-without-nodeaffinity); `setup.sh` + `ref-solution.sh` → PASS (2/2, 0 traps)
- **D-09** runner-owns-cleanup — `setup.sh` does not `kubectl delete ns`
- **RUN-02** drillable via future `cka-sim drill storage` (Phase 4)

## Live-cluster verification procedure (5 min — end-of-phase human check)

Requires a real multi-node cluster (kubeadm/kind with 2+ workers) with `CKA_SIM_ROOT` exported and `CKA_SIM_LAB_NS=cka-sim-storage-01` in env.

```bash
export CKA_SIM_ROOT=/path/to/repo/cka-sim
export CKA_SIM_LAB_NS=cka-sim-storage-01
cd "$CKA_SIM_ROOT/packs/storage/01-pvc-binding"

# 1. Seed the trap
./setup.sh
kubectl get pvc app-data -n "$CKA_SIM_LAB_NS"           # expect STATUS=Pending
kubectl get pv  q01-app-pv                              # expect STATUS=Available

# 2. Grade in broken state — expect SCORE < max + 1 Trap line
./grade.sh
#   stdout should contain:
#     SCORE: 0/2
#     Trap 1: hostPath PV without nodeAffinity: ...

# 3. Apply reference fix
./ref-solution.sh
kubectl get pvc app-data -n "$CKA_SIM_LAB_NS"           # expect STATUS=Bound

# 4. Grade in fixed state — expect green
./grade.sh
#   stdout:   SCORE: 2/2
#   exit:     0
#   no Trap lines

# 5. Clean up
./reset.sh
```

## Verification performed in this plan

- `bash -n` on all 4 shell scripts — syntax OK
- `git ls-files -s` confirms mode `100755` for the 4 .sh files
- `bash cka-sim/scripts/test.sh` — exit 0, **23 cases green** (15 Phase 2 + 4 drill + 4 lint-packs)
  - lint-traps.sh passes
  - lint-packs.sh Pass D accepts the new 6-file question dir + executable bits
  - lint-packs.sh Pass E accepts metadata.yaml schema + all 3 trap-ids registered
  - lint-packs.sh Passes A/B/C scan the new `grade.sh` / `setup.sh` without flagging

## Deviations from Plan

None — plan executed exactly as written. All 8 file contents match the PLAN's verbatim specifications; no Rule 1/2/3 auto-fixes required.

## Commits

- `01e3011` feat(03-04): scaffold storage pack + 01-pvc-binding prompt
- `1680b5b` feat(03-04): implement storage/01-pvc-binding triplet scripts

## Notes

- GRADE-06 round-trip (setup → broken grade → ref-solution → green grade) requires a live multi-node cluster — documented above as a 5-minute human-verification step (per user override #2). The in-repo test suite validates the structural contract only.
- This is Phase 3's single reference question to prove the drill contract end-to-end. The full storage pack (all v1.35 Tracker checkboxes, ~7-10 questions) lands in Phase 4 under PACK-01; the README + manifest already signpost that.
- `ref-solution.sh` uses `operator: Exists` on `kubernetes.io/hostname` (matches every node with the label key) to honor the prompt's "remain usable on any worker" constraint. A stricter `In: [<specific-node>]` variant would pin to one worker and fail that constraint.

## Self-Check: PASSED

- `cka-sim/packs/storage/manifest.yaml` — FOUND
- `cka-sim/packs/storage/README.md` — FOUND
- `cka-sim/packs/storage/01-pvc-binding/metadata.yaml` — FOUND
- `cka-sim/packs/storage/01-pvc-binding/question.md` — FOUND
- `cka-sim/packs/storage/01-pvc-binding/setup.sh` — FOUND (755)
- `cka-sim/packs/storage/01-pvc-binding/grade.sh` — FOUND (755)
- `cka-sim/packs/storage/01-pvc-binding/reset.sh` — FOUND (755)
- `cka-sim/packs/storage/01-pvc-binding/ref-solution.sh` — FOUND (755)
- Commits `01e3011`, `1680b5b` — FOUND in `git log`
- `bash cka-sim/scripts/test.sh` — exit 0, 23 cases green
