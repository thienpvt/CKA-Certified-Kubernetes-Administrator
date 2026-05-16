---
phase: 04-storage-workloads-scheduling-packs
plan: 15
subsystem: cka-sim-packs
tags: [workloads-scheduling, static-pod, native-sidecar, nodeselector, node-affinity, taints, tolerations, kubelet-mirror, sidecar-containers, GRADE-02]

requires:
  - phase: 04-storage-workloads-scheduling-packs/plan-01
    provides: lib/setup.sh helpers (ensure_lab_ns + wait_for_ns_active 120s)
  - phase: 04-storage-workloads-scheduling-packs/plan-02
    provides: traps/catalog.yaml entry `sidecar-not-native-restartpolicy-always`
  - phase: 04-storage-workloads-scheduling-packs/plan-05
    provides: workloads-scheduling pack shape (01-deployment-requests precedent)
  - phase: 01-cluster-bootstrap-runner-skeleton
    provides: passwordless SSH from runner to node-01 (BOOT-02/03)
provides:
  - Q06 06-static-pod pack (kubelet mirror pod via /etc/kubernetes/manifests)
  - Q07 07-native-sidecar pack (CG-08 initContainers[].restartPolicy=Always)
  - Q08 08-nodeselector-affinity-taints pack (label + toleration + required nodeAffinity bundled)
  - 9 fixtures (3 per question: stub-responses.json, expected-pass/fail-score.txt)
affects:
  - 04-16-PLAN.md (final storage/workloads manifest + coverage roll-up)
  - Phase 05 services-networking packs (reuses GRADE-02 counting pattern with wc -w on jsonpath)
  - Any pack-checker consumer (Q07 validates the 1dcdab8 blocker-fix pattern end-to-end)

tech-stack:
  added: []
  patterns:
    - "GRADE-02 container-count idiom: `kubectl ... -o jsonpath='{.spec.template.spec.containers[*].name}' | wc -w | tr -d ' '` (NEVER `kubectl get | grep`)"
    - "Cluster-scoped reset cleanup: reset.sh removes BOTH label AND taint when setup adds either (Q08 taints node-02, reset MUST undo)"
    - "SSH preflight in setup.sh: `ssh -o BatchMode=yes -o ConnectTimeout=5 node-01 true` with doctor-hint exit 1 on failure (Q06)"
    - "Peer-container sidecar seeded as spec.containers[1] to force candidate into initContainers[].restartPolicy=Always migration (Q07)"
    - "Comment hygiene in grade.sh: banned pipe-to-grep idiom paraphrased away from verbatim match to keep self-lint clean even against comments"

key-files:
  created:
    - cka-sim/packs/workloads-scheduling/06-static-pod/metadata.yaml
    - cka-sim/packs/workloads-scheduling/06-static-pod/question.md
    - cka-sim/packs/workloads-scheduling/06-static-pod/setup.sh
    - cka-sim/packs/workloads-scheduling/06-static-pod/grade.sh
    - cka-sim/packs/workloads-scheduling/06-static-pod/reset.sh
    - cka-sim/packs/workloads-scheduling/06-static-pod/ref-solution.sh
    - cka-sim/packs/workloads-scheduling/07-native-sidecar/metadata.yaml
    - cka-sim/packs/workloads-scheduling/07-native-sidecar/question.md
    - cka-sim/packs/workloads-scheduling/07-native-sidecar/setup.sh
    - cka-sim/packs/workloads-scheduling/07-native-sidecar/grade.sh
    - cka-sim/packs/workloads-scheduling/07-native-sidecar/reset.sh
    - cka-sim/packs/workloads-scheduling/07-native-sidecar/ref-solution.sh
    - cka-sim/packs/workloads-scheduling/08-nodeselector-affinity-taints/metadata.yaml
    - cka-sim/packs/workloads-scheduling/08-nodeselector-affinity-taints/question.md
    - cka-sim/packs/workloads-scheduling/08-nodeselector-affinity-taints/setup.sh
    - cka-sim/packs/workloads-scheduling/08-nodeselector-affinity-taints/grade.sh
    - cka-sim/packs/workloads-scheduling/08-nodeselector-affinity-taints/reset.sh
    - cka-sim/packs/workloads-scheduling/08-nodeselector-affinity-taints/ref-solution.sh
    - cka-sim/tests/fixtures/workloads-06-static-pod/stub-responses.json
    - cka-sim/tests/fixtures/workloads-06-static-pod/expected-pass-score.txt
    - cka-sim/tests/fixtures/workloads-06-static-pod/expected-fail-score.txt
    - cka-sim/tests/fixtures/workloads-07-native-sidecar/stub-responses.json
    - cka-sim/tests/fixtures/workloads-07-native-sidecar/expected-pass-score.txt
    - cka-sim/tests/fixtures/workloads-07-native-sidecar/expected-fail-score.txt
    - cka-sim/tests/fixtures/workloads-08-nodeselector-affinity-taints/stub-responses.json
    - cka-sim/tests/fixtures/workloads-08-nodeselector-affinity-taints/expected-pass-score.txt
    - cka-sim/tests/fixtures/workloads-08-nodeselector-affinity-taints/expected-fail-score.txt
  modified: []

key-decisions:
  - "Q07 container-count check uses `wc -w | tr -d ' '` on space-separated jsonpath (GRADE-02 canonical; Phase 5 should reuse verbatim)"
  - "Q07 grade comment paraphrased banned idiom (`pipe-to-grep pattern is rejected`) to avoid regex self-match in lint-packs.sh Pass A"
  - "Q08 reset removes both gpu label AND gpu taint from node-02 — cluster-scoped side effects MUST fully revert or they leak into later questions"
  - "Q06 setup performs SSH preflight but does NOT mutate /etc/kubernetes/manifests — only the candidate (and ref-solution) may touch the kubelet manifest dir"
  - "Q07 setup seeds the sidecar as spec.containers[1] specifically to trigger the `sidecar-not-native-restartpolicy-always` trap detector in grade.sh"

patterns-established:
  - "Container count via jsonpath + wc -w: every future question needing array-length assertions should use this shape"
  - "Cluster-scoped cleanup parity: any setup.sh that mutates node labels/taints requires symmetric reset.sh removal"
  - "Static-pod question shape: setup runs SSH preflight only, candidate drops manifest, reset SSH-removes it"

requirements-completed: [PACK-02, PACK-06]

duration: 1h 14m
completed: 2026-05-10
---

# Phase 04 Plan 15: Workloads Q06+Q07+Q08 (Static Pod + Native Sidecar + NodeSelector/Affinity/Taints) Summary

**Three Workloads & Scheduling questions shipped as one plan: kubelet-mirrored static pod on node-01, v1.35 native sidecar via initContainers[].restartPolicy=Always, and bundled nodeSelector/nodeAffinity/taints with cluster-scoped label+taint cleanup in reset.**

## Performance

- **Duration:** 1h 14m
- **Started:** 2026-05-10T16:35Z
- **Completed:** 2026-05-10T17:49Z
- **Tasks:** 3 (Q06, Q07, Q08)
- **Files created:** 27 (18 question files + 9 fixtures)
- **Files modified:** 0

## Accomplishments

- **Q06 static-pod:** Candidate SSHes into `node-01`, drops `q06-static-nginx.yaml` into `/etc/kubernetes/manifests/`, kubelet mirrors it as `q06-static-nginx-node-01` in `default` ns. Grade asserts the mirror pod exists, is Ready, and carries annotation `kubernetes.io/config.source=file`. Setup runs SSH preflight and exits with a `cka-sim doctor` hint if passwordless SSH regressed; reset best-effort SSH-removes the manifest.
- **Q07 native-sidecar (CG-08):** Setup seeds a broken Deployment `q07-app` with `log-tailer` as a peer container (spec.containers[1]). Candidate moves it into `initContainers[]` with `restartPolicy: Always` (v1.35 canonical native sidecar). Grade asserts the initContainer shape, the 1-container count, and records the primary trap when the sidecar is still peer-form.
- **Q08 nodeselector-affinity-taints:** Setup adds `gpu=true:NoSchedule` taint to `node-02` and seeds broken Deployment `q08-gpu-sim` without toleration/nodeAffinity. Candidate labels `node-02` with `gpu=true`, adds matching toleration, and required nodeAffinity. Grade asserts all 4 pieces; reset cleans both label AND taint so later questions see a clean scheduler.
- **GRADE-02 discipline:** All 3 grade.sh files use `kubectl -o jsonpath | wc -w | tr -d ' '` for collection counting — no `kubectl get | grep` anywhere (validated by lint-packs.sh Pass A + plan's self-lint check).
- **test.sh green:** `bash cka-sim/scripts/test.sh` passes end-to-end (lint-traps + lint-packs across 39 checks + 29 bash unit cases).

## Task Commits

Each task committed atomically with `pvtcwd@gmail.com` identity:

1. **Task 1: Q06 static-pod** — `f6d895e` (feat)
2. **Task 2: Q07 native-sidecar** — `a978ed9` (feat)
3. **Task 3: Q08 nodeselector-affinity-taints + verify plan** — `151c298` (feat)

Plan metadata commit: `<this-commit>` (docs: SUMMARY).

## Files Created/Modified

### Q06 `06-static-pod`
- `metadata.yaml` — id `workloads-static-pod`, domain workloads-scheduling, estMin=8, 3 traps (kubelet-runtime-flag-in-kubeconfig, default-sa-used, deployment-missing-requests), 2 k8s-doc references
- `question.md` — SSH + drop manifest + confirm mirror-pod readiness + annotation check
- `setup.sh` — SSH preflight (BatchMode, ConnectTimeout=5) + ensure_lab_ns/wait_for_ns_active; DOES NOT touch /etc/kubernetes/manifests
- `grade.sh` — assert mirror pod exists in default ns + annotation kubernetes.io/config.source=file + assert_pod_ready
- `reset.sh` — delete lab ns + best-effort SSH rm of static-pod manifest on node-01
- `ref-solution.sh` — SSH tee manifest into /etc/kubernetes/manifests/q06-static-nginx.yaml + poll up to 60s for mirror + wait Ready 120s

### Q07 `07-native-sidecar`
- `metadata.yaml` — id `workloads-native-sidecar`, estMin=8, 3 traps (primary: sidecar-not-native-restartpolicy-always)
- `question.md` — explains peer-container vs native-sidecar shape, constraints (spec.containers==1, initContainers[log-tailer].restartPolicy=Always)
- `setup.sh` — seeds Deployment q07-app with peer-container sidecar + emptyDir /shared
- `grade.sh` — assert deployment exists + initContainer restartPolicy=Always + container_count=1 via wc -w; records sidecar-not-native-restartpolicy-always when peer sidecar persists
- `reset.sh` — delete lab ns (no cluster-scoped side effects)
- `ref-solution.sh` — apply native-shape Deployment (log-tailer moved to initContainers with restartPolicy=Always) + rollout status

### Q08 `08-nodeselector-affinity-taints`
- `metadata.yaml` — id `workloads-nodeselector-affinity-taints`, estMin=9, 3 traps (default-sa-used, deployment-missing-requests, hostpath-pv-without-nodeaffinity as adjacent concept)
- `question.md` — label node-02, add toleration + required nodeAffinity (operator=In), confirm placement
- `setup.sh` — `kubectl taint nodes node-02 gpu=true:NoSchedule --overwrite` + broken Deployment q08-gpu-sim (no toleration, no affinity)
- `grade.sh` — 4 assertions: toleration effect=NoSchedule, required nodeAffinity matchExpressions operator=In, every replica lands on node-02 (unique nodeName == node-02), node-02 label gpu=true
- `reset.sh` — delete ns + `kubectl taint nodes node-02 gpu-` + `kubectl label nodes node-02 gpu-` (symmetric cleanup)
- `ref-solution.sh` — label node + strategic-patch Deployment with toleration + required nodeAffinity + rollout status

### Fixtures
- `tests/fixtures/workloads-06-static-pod/` — 3 files (stub mirror pod, pass 3/3, fail 0/3)
- `tests/fixtures/workloads-07-native-sidecar/` — 3 files (stub deployment with initContainers, pass 3/3, fail 0/3)
- `tests/fixtures/workloads-08-nodeselector-affinity-taints/` — 3 files (stub deployment with toleration + affinity, pass 4/4, fail 0/4)

## Decisions Made

- **GRADE-02 canonical counting idiom:** `kubectl ... -o jsonpath='{.spec.template.spec.containers[*].name}' 2>/dev/null | wc -w | tr -d ' '`. Space-separated jsonpath + wc -w is clean, predictable, and dodges the `kubectl get | grep` banned pattern. Every future pack that needs an array-length check should reuse this exact shape.
- **Comment hygiene is non-trivial:** `lint-packs.sh` Pass A regex is greedy against non-`#` lines but comments can still trip the Q07 plan-level self-lint check (`! grep -qE 'kubectl[[:space:]]+get[[:space:]].*\|[[:space:]]*grep'`) because that check has no comment filter. The fix is to paraphrase the banned idiom in comments (e.g., "the pipe-to-grep pattern is rejected") instead of quoting it verbatim.
- **Cluster-scoped reset parity:** Q08 setup mutates `node-02` (both taint and potentially label if re-run with candidate partial state); reset MUST undo both so later questions do not observe phantom scheduler behaviour. This is now an established pattern: any `kubectl taint` or `kubectl label` in setup requires a matching `kubectl taint ... <key>-` or `kubectl label ... <key>-` in reset.
- **Q06 setup discipline:** Setup only runs SSH preflight and creates the lab ns — it does NOT mutate `/etc/kubernetes/manifests`. That directory is exclusively the candidate's (and ref-solution's) responsibility. This keeps the question honest: setup never does the work for the candidate.
- **Q07 peer-container seeding is intentional:** The sidecar MUST start as `spec.containers[1]` at setup so the candidate has something to fix and the `sidecar-not-native-restartpolicy-always` trap has something to detect. Shipping a Deployment already in native shape would defeat the question.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Q07 setup comment accidentally contained literal `initContainers[]` token**
- **Found during:** Task 2 (Q07 acceptance checks)
- **Issue:** The plan's acceptance criteria includes `! grep -q 'initContainers' cka-sim/packs/workloads-scheduling/07-native-sidecar/setup.sh`. My first pass wrote a header comment that said "move log-tailer into initContainers[] with restartPolicy: Always" — the word `initContainers` in a comment tripped the check.
- **Fix:** Paraphrased the header comment to "move log-tailer into the init-container slot with restartPolicy=Always (v1.35 native sidecar shape)".
- **Files modified:** `cka-sim/packs/workloads-scheduling/07-native-sidecar/setup.sh`
- **Verification:** `! grep -q 'initContainers' setup.sh` now passes.
- **Committed in:** `a978ed9` (Task 2 commit).

**2. [Rule 1 - Bug] Q07 grade.sh comment matched the GRADE-02 banned-idiom regex**
- **Found during:** Task 2 (Q07 acceptance check: `! grep -qE 'kubectl[[:space:]]+get[[:space:]].*\|[[:space:]]*grep' grade.sh`)
- **Issue:** A warning comment said "NEVER `kubectl get ... | grep` (lint-packs.sh pass A)" — the backticked example matched the regex literally.
- **Fix:** Paraphrased to "the banned pipe-to-grep pattern is rejected by lint-packs.sh pass A" (no `kubectl get | grep` fragment anywhere in the file).
- **Files modified:** `cka-sim/packs/workloads-scheduling/07-native-sidecar/grade.sh`
- **Verification:** `grep -qE 'kubectl[[:space:]]+get[[:space:]].*\|[[:space:]]*grep' grade.sh` returns empty; `bash cka-sim/scripts/lint-packs.sh` passes all 39 checks.
- **Committed in:** `a978ed9` (Task 2 commit).

---

**Total deviations:** 2 auto-fixed (2 Rule 1 — comment-content bugs in freshly-written files that tripped self-lint checks targeting the file as a whole rather than executable code).
**Impact on plan:** Both deviations were cosmetic comment edits; no semantic change to setup/grade behaviour. Plan executed exactly as designed; acceptance-criteria regex strictness just required the authored comments to avoid literal collision with forbidden patterns.

## Issues Encountered

- **Windows `python3` alias routes to Microsoft Store shim**, not the installed Python 3.12 interpreter. Acceptance-criteria scripts that call `python3 -c ...` need to use `python` on this host. Worked around by invoking `python -c ...` directly. No file change; relevant to any future plan relying on `python3` in a `<verify>` block on Windows.
- **Worktree HEAD started at `5500f29`** (unrelated upstream commits merged in while the worktree was idle). The `<worktree_branch_check>` performed the expected `git reset --hard 87e50ee...` back to the plan's base commit and execution proceeded cleanly from there.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Phase 04 Plan 16 (final manifest + coverage roll-up) can now include all 8 workloads-scheduling question dirs — `01-deployment-requests` through `08-nodeselector-affinity-taints`.
- CG-08 native sidecar mandate closed (Q07 exercises `initContainers[].restartPolicy=Always` end-to-end).
- Tracker slugs covered by this plan: `static-pods`, `native-sidecar`, `nodeselector-node-affinity`, `taints-tolerations`.
- Pack-checker blocker-fix (commit `1dcdab8`) is validated in practice: Q07 grade.sh is the reference implementation of the canonical container-count idiom.

## Self-Check: PASSED

Verified post-write:
- FOUND: cka-sim/packs/workloads-scheduling/06-static-pod/{metadata.yaml, question.md, setup.sh, grade.sh, reset.sh, ref-solution.sh}
- FOUND: cka-sim/packs/workloads-scheduling/07-native-sidecar/{metadata.yaml, question.md, setup.sh, grade.sh, reset.sh, ref-solution.sh}
- FOUND: cka-sim/packs/workloads-scheduling/08-nodeselector-affinity-taints/{metadata.yaml, question.md, setup.sh, grade.sh, reset.sh, ref-solution.sh}
- FOUND: cka-sim/tests/fixtures/workloads-{06,07,08}-*/{stub-responses.json, expected-pass-score.txt, expected-fail-score.txt}
- FOUND: commits f6d895e, a978ed9, 151c298 in `git log --oneline -5`
- FOUND: `bash cka-sim/scripts/test.sh` exits 0 (lint-traps + lint-packs + 29 unit cases all green)
- FOUND: `bash cka-sim/scripts/lint-packs.sh` reports 39 checks green, 0 errors
- FOUND: all 3 grade.sh files pass the plan-level `! grep -qE 'kubectl[[:space:]]+get[[:space:]].*\|[[:space:]]*grep' ...` self-lint
- FOUND: all 3 metadata.yaml pass the W2 normalized-schema block (id + domain + estimatedMinutes in [6,9] + verified_against=1.35 + ≥3 traps + references)

---
*Phase: 04-storage-workloads-scheduling-packs*
*Completed: 2026-05-10*
