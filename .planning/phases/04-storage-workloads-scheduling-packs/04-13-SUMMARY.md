---
phase: 04-storage-workloads-scheduling-packs
plan: 13
subsystem: packs
tags: [workloads-scheduling, hpa, autoscaling-v2, metrics-server, cg-06, kubelet-insecure-tls]

# Dependency graph
requires:
  - phase: 04-storage-workloads-scheduling-packs
    provides: shared cka-sim/lib/setup.sh helpers incl. seed_deployment --sa --cpu --memory (Plan 04-01)
  - phase: 04-storage-workloads-scheduling-packs
    provides: hpa-missing-metrics-server trap catalog entry (Plan 04-02)
  - phase: 04-storage-workloads-scheduling-packs
    provides: workloads-deployment-requests retrofit as reference shape (Plan 04-05)
provides:
  - Workloads pack Q04 workloads-hpa-metrics-server (6 files + 3 fixtures)
  - Candidate-driven metrics-server v0.7.2 install pattern with --kubelet-insecure-tls kubeadm patch
  - Reset-without-uninstall idiom for cluster-wide shared tooling (CG-06 policy, RESEARCH §6.2 lines 570-573)
  - Tracker coverage: hpa-autoscaling-v2 (primary)
  - CG-06 metrics-server bootstrap concern closed (first question that exercises it)
affects: [04-16 manifest-catchup, any future question that relies on kubectl top data]

# Tech tracking
tech-stack:
  added: [metrics-server@v0.7.2]
  patterns:
    - "Candidate-driven cluster tool install: setup pre-stages the problem (missing scraper + Deployment with requests); ref-solution does the install with version pin + kubeadm TLS patch + HPA v2 apply"
    - "Reset-without-uninstall for shared cluster tooling: only the lab ns is deleted; cluster-wide install stays resident between questions to avoid repeated 60-180s bootstrap waits"
    - "Behavioural kubectl top pod probe as assertion #5 (outside assert_* helpers — manual TOTAL/PASSED increment) — directly verifies the scraper is serving instead of proxying through resource existence"
    - "Condition-reason trap probe: HPA .status.conditions[?(@.type=='AbleToScale')].reason == FailedGetResourceMetric pinpoints the missing-scraper trap without false positives from other HPA failure modes"

key-files:
  created:
    - cka-sim/packs/workloads-scheduling/04-hpa-metrics-server/metadata.yaml
    - cka-sim/packs/workloads-scheduling/04-hpa-metrics-server/question.md
    - cka-sim/packs/workloads-scheduling/04-hpa-metrics-server/setup.sh
    - cka-sim/packs/workloads-scheduling/04-hpa-metrics-server/grade.sh
    - cka-sim/packs/workloads-scheduling/04-hpa-metrics-server/reset.sh
    - cka-sim/packs/workloads-scheduling/04-hpa-metrics-server/ref-solution.sh
    - cka-sim/tests/fixtures/workloads-04-hpa-metrics-server/stub-responses.json
    - cka-sim/tests/fixtures/workloads-04-hpa-metrics-server/expected-fail-score.txt
    - cka-sim/tests/fixtures/workloads-04-hpa-metrics-server/expected-pass-score.txt
  modified: []

key-decisions:
  - "Pinned metrics-server to v0.7.2 per RESEARCH §6.2 line 553 (latest stable against 1.35 as of 2026-05 upstream matrix). A floating tag would drift the lab."
  - "Setup SEEDs the Deployment with CPU + memory requests deliberately set — the active trap here is the missing scraper (hpa-missing-metrics-server), not the requests. Requests-omission is covered by Q01 of this pack."
  - "Reset deletes the lab ns only. RESEARCH §6.2 lines 570-573 makes uninstall explicitly out-of-scope for the scraper because it is a cluster-wide shared dependency — reinstalling between every reset would add ~3 min of churn across a drill session."
  - "Grade's 5th assertion is a behavioural kubectl top pod probe (outside the assert_* helpers, incrementing CKA_SIM_GRADE_TOTAL/PASSED manually) rather than an existence-only check on the scraper Deployment. The question is whether metrics-server is actually serving, not whether it was applied."
  - "Trap detector uses HPA status.conditions[AbleToScale].reason == FailedGetResourceMetric — this string is stable across HPA v2 and fires only on the metrics-scraper-absent failure mode, not on misconfigured targetRef etc."

patterns-established:
  - "shared-cluster-tool-install: question ships the full bootstrap in ref-solution (apply + patch + wait + post-scrape sleep), not setup; reset deliberately leaves the tool installed across resets"
  - "behavioural-top-pod-probe: manual CKA_SIM_GRADE_TOTAL/PASSED bump around a kubectl top call to directly verify scraper liveness"

requirements-completed: [PACK-02, PACK-06]

# Metrics
duration: ~5min
completed: 2026-05-10
---

# Phase 04 Plan 13: Workloads Q04 hpa-metrics-server Summary

**Workloads pack Q04 `workloads-hpa-metrics-server`: candidate installs metrics-server v0.7.2 with the kubeadm `--kubelet-insecure-tls` patch and creates an HPA v2 (1→5 replicas @ 50% CPU) on a pre-seeded Deployment `q04-load`; reset keeps the scraper resident (RESEARCH §6.2 policy).**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-05-10T17:46:30Z
- **Completed:** 2026-05-10T17:51:06Z
- **Tasks:** 1
- **Files modified:** 9 (all created)

## Accomplishments

- Shipped the full 6-file question shape under `cka-sim/packs/workloads-scheduling/04-hpa-metrics-server/` with 100755 mode on the four `.sh` files in the git index (`git update-index --chmod=+x`).
- `setup.sh` sources `cka-sim/lib/setup.sh`, calls `ensure_lab_ns` + `wait_for_ns_active` (120s) under pack `workloads-scheduling` / qid `workloads-hpa-metrics-server`, creates the dedicated `q04-load-sa` ServiceAccount, then seeds the Deployment via `cka_sim::setup::seed_deployment "$CKA_SIM_LAB_NS" q04-load nginx:1.27 --replicas 1 --sa q04-load-sa --cpu 100m --memory 64Mi`. Trailing `kubectl wait --for=condition=Available ... --timeout=60s` is best-effort and survives non-Available starts.
- `grade.sh` (read-only) runs five assertions: (1) HPA `q04-load` exists, (2) `minReplicas=1`, (3) `maxReplicas=5`, (4) first `spec.metrics[type=Resource].resource.name == cpu`, (5) behavioural `kubectl top pod -n $CKA_SIM_LAB_NS -l app=q04-load` returns readings. Assertion 5 is counted via manual `CKA_SIM_GRADE_TOTAL` / `CKA_SIM_GRADE_PASSED` bumps with `ok`/`err` messages and `CKA_SIM_GRADE_PASSES` / `CKA_SIM_GRADE_FAILS` arrays populated for emit_result fidelity. Trap `hpa-missing-metrics-server` is recorded when `status.conditions[AbleToScale].reason == FailedGetResourceMetric`.
- `ref-solution.sh` is idempotent: skips install if the scraper Deployment is already up; else applies `https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.7.2/components.yaml` and patches `/spec/template/spec/containers/0/args/-` with `--kubelet-insecure-tls` (JSON-6902 op=add). Waits 180s for Available, sleeps 15s for at least one scrape cycle, then applies the HPA v2 manifest scaling 1→5 at 50% CPU utilization.
- `reset.sh` deletes the lab namespace with `--wait=false` and exits 0. No cluster-wide mutations — specifically leaves the scraper Deployment resident per RESEARCH §6.2 lines 570-573.
- `metadata.yaml` normalized: `id: workloads-hpa-metrics-server`, `domain: workloads-scheduling`, `estimatedMinutes: 9`, `verified_against: "1.35"`, traps `[hpa-missing-metrics-server, deployment-missing-requests, default-sa-used]` (3 ≥ GRADE-04 floor), 3 references (CONCERNS.md CG-06, metrics-server upstream, HPA v2 k8s docs).
- `question.md` tells the candidate `kubectl top pod` currently fails and hints at the kubeadm self-signed kubelet cert situation without naming the `--kubelet-insecure-tls` flag (no spoiler). Forbids modifying existing requests.
- Round-trip fixtures: `stub-responses.json` holds the golden HPA v2 manifest (scaleTargetRef + 1/5 + Resource CPU metric @ 50), `expected-pass-score.txt=SCORE: 5/5`, `expected-fail-score.txt=SCORE: 0/5`.

## Task Commits

1. **Task 1: 6 question files + 3 fixtures** — `f420888` (feat)

## Files Created

- `cka-sim/packs/workloads-scheduling/04-hpa-metrics-server/metadata.yaml` — id + domain + estimatedMinutes=9 + 3 traps + 3 references
- `cka-sim/packs/workloads-scheduling/04-hpa-metrics-server/question.md` — candidate-facing brief (no --kubelet-insecure-tls spoiler)
- `cka-sim/packs/workloads-scheduling/04-hpa-metrics-server/setup.sh` — ns + SA + seed_deployment with cpu=100m memory=64Mi (100755)
- `cka-sim/packs/workloads-scheduling/04-hpa-metrics-server/grade.sh` — 5 assertions + AbleToScale condition trap detector (100755, read-only)
- `cka-sim/packs/workloads-scheduling/04-hpa-metrics-server/reset.sh` — async ns delete; no cluster-wide mutation (100755)
- `cka-sim/packs/workloads-scheduling/04-hpa-metrics-server/ref-solution.sh` — v0.7.2 install + --kubelet-insecure-tls patch + HPA v2 apply (100755)
- `cka-sim/tests/fixtures/workloads-04-hpa-metrics-server/stub-responses.json` — golden HPA v2 shape
- `cka-sim/tests/fixtures/workloads-04-hpa-metrics-server/expected-fail-score.txt` — `SCORE: 0/5`
- `cka-sim/tests/fixtures/workloads-04-hpa-metrics-server/expected-pass-score.txt` — `SCORE: 5/5`

## Decisions Made

- **metrics-server version pin = v0.7.2.** RESEARCH §6.2 line 553 identifies this as the latest stable compatible with k8s 1.35 as of 2026-05. A `latest` tag would let upstream version drift break the lab silently; a hard pin is the lab-ops contract.
- **Scraper install is the candidate's job, not setup's.** Setup ships the *problem* (scraper absent + Deployment already has requests) so the candidate experiences the kubectl-top-fails-on-a-fresh-kubeadm-cluster scenario verbatim. Pre-installing in setup would make the question vacuous.
- **Reset does not uninstall the scraper.** RESEARCH §6.2 lines 570-573 codifies this — other questions (and repeated candidate attempts) benefit from keeping it resident. The ref-solution's install block is idempotent (`kubectl get deployment ... || apply`) so a re-run is a no-op on the install step and just re-applies the HPA.
- **Behavioural grader probe over existence grader probe.** Assertion 5 runs `kubectl top pod -l app=q04-load` and asserts exit 0, which directly verifies the scraper is *serving* data, not just that someone `kubectl apply`-d the manifest. Catches partial installs (e.g., patch missing, scraper stuck on CrashLoop) that an existence check would miss.
- **Trap probe via HPA condition reason.** `status.conditions[AbleToScale].reason == FailedGetResourceMetric` is the canonical HPA v2 reason when the metrics API is down. Using the condition reason instead of e.g. greping `kubectl describe` output keeps the grader structured and jsonpath-pure.
- **Did NOT touch `cka-sim/packs/workloads-scheduling/manifest.yaml`.** Per prior Wave 3 summaries (04-08, 04-09, 04-10), manifest catch-up is Plan 16's scope.

## Deviations from Plan

- **[Rule 3 — Blocking issue] `reset.sh` triggered the `! grep -q 'metrics-server'` AC because the file had a path-shaped header comment containing `metrics-server`.** Rewrote both the filename reference and the body comment to describe the tool as "the cluster-wide CPU scraper Deployment" without using the literal token. Behaviour unchanged. Commit `f420888` (task-atomic; the fix was in-flight before the commit landed).

## Issues Encountered

- `git add` on new `.sh` files recorded mode `100644` despite filesystem +x bits. Standard Windows-worktree resolution applied: `git update-index --chmod=+x` on the four scripts after staging. Final index shows `100755` on all four. `lint-packs.sh` pass-D (executable-bit check) green.
- `lint-coverage.sh` will flag `workloads-hpa-metrics-server` as not-in-manifest. Per Plan 04-10 summary + PLAN 04-13 explicit scope note, this is Plan 16's catch-up work, not this plan's.

## Validation Results

- `bash -n` on all four `.sh` files — syntax clean.
- `bash cka-sim/scripts/lint-packs.sh` — PASS (33 checks).
- `bash cka-sim/scripts/test.sh` — PASS (29 unit cases + lint-traps + lint-packs).
- `grep -q 'metrics-server/releases/download/v0.7.2' ref-solution.sh` — match (v0.7.2 pin).
- `grep -q 'kubelet-insecure-tls' ref-solution.sh` — match (kubeadm TLS patch).
- `grep -q 'apiVersion: autoscaling/v2' ref-solution.sh` — match (HPA v2 only).
- `! grep -q 'metrics-server' reset.sh` — PASS (reset stays scraper-agnostic).
- `grep -q 'kubectl top pod' grade.sh` — match (behavioural probe).
- `! grep -qE 'kubectl[[:space:]]+get[[:space:]].*\|[[:space:]]*grep' grade.sh` — PASS (no get-pipe-grep).
- `! grep -qE 'kubectl[[:space:]]+(delete|create|apply|patch|edit|replace)' grade.sh` — PASS (read-only grader).
- `metadata.yaml`: `id: workloads-hpa-metrics-server` + `domain: workloads-scheduling` + `estimatedMinutes: 9` + `verified_against: "1.35"` + 3 traps + references section with 3 `- kind:` entries.
- Git index mode check: `git ls-files --stage` shows `100755` for setup.sh / grade.sh / reset.sh / ref-solution.sh.

## Next Phase Readiness

- Workloads pack now has Q01 (deployment-requests, retrofit) + Q04 (hpa-metrics-server, this plan). Remaining Wave 3 workloads questions sit in sibling plans 04-11, 04-12, 04-14, 04-15.
- Plan 16 (Wave 4) will add `workloads-hpa-metrics-server` (path: `04-hpa-metrics-server`) to `cka-sim/packs/workloads-scheduling/manifest.yaml`, at which point `lint-coverage.sh` will go green for the `hpa-autoscaling-v2` tracker entry.
- CG-06 (metrics-server bootstrap prerequisite) is now exercised by a question. Any future question that wants `kubectl top`-backed behavioural probes can assume the scraper is resident in a drill session that has run Q04 once (or can ship its own idempotent install block mirroring this one).

## Self-Check: PASSED

- File `cka-sim/packs/workloads-scheduling/04-hpa-metrics-server/metadata.yaml` — FOUND
- File `cka-sim/packs/workloads-scheduling/04-hpa-metrics-server/question.md` — FOUND
- File `cka-sim/packs/workloads-scheduling/04-hpa-metrics-server/setup.sh` — FOUND
- File `cka-sim/packs/workloads-scheduling/04-hpa-metrics-server/grade.sh` — FOUND
- File `cka-sim/packs/workloads-scheduling/04-hpa-metrics-server/reset.sh` — FOUND
- File `cka-sim/packs/workloads-scheduling/04-hpa-metrics-server/ref-solution.sh` — FOUND
- File `cka-sim/tests/fixtures/workloads-04-hpa-metrics-server/stub-responses.json` — FOUND
- File `cka-sim/tests/fixtures/workloads-04-hpa-metrics-server/expected-fail-score.txt` — FOUND
- File `cka-sim/tests/fixtures/workloads-04-hpa-metrics-server/expected-pass-score.txt` — FOUND
- Commit `f420888` — FOUND in `git log --oneline`

---
*Phase: 04-storage-workloads-scheduling-packs*
*Completed: 2026-05-10*
