---
phase: 13-grader-strengthening
verified: 2026-05-17
status: human_needed
plans_complete: 3/3
---

# Phase 13 Verification — Grader-Strengthening (BUG-M04 / M05 / M06)

## Plan execution summary

| Plan  | Bug      | Files modified                                                      | bash -n | Commit    |
| ----- | -------- | ------------------------------------------------------------------- | ------- | --------- |
| 13-01 | BUG-M04  | services-networking/06-netpol-endport/{setup,grade}.sh              | OK      | e0fa449   |
| 13-02 | BUG-M05  | cluster-architecture/05-audit-policy/grade.sh                       | OK      | d7e415e   |
| 13-03 | BUG-M06  | workloads-scheduling/04-hpa-metrics-server/grade.sh                 | OK      | d267419   |

All 3 plans landed atomically. Acceptance greps in each SUMMARY.md
confirm marker comments, helper invocations, sentinel paths, jsonpath
shapes, and trap-detector preservation.

## Phase 13 ROADMAP success criteria (4)

1. **services-networking/06-netpol-endport — over-permissive NP fails;
   CNI enforcement detected and gated.**
   - Structural assertion `port=8080 + endPort=8090 + protocol=TCP` is
     unconditional → a candidate NP with `endPort=8095` now fails the
     structural endPort check (no false-pass via "8095 unreachable
     because no listener"). Met at code level.
   - CNI enforcement detected at setup-time via temp `q06-cni-probe-deny`
     NP + `q06-client` wget probe + sentinel write at
     `/tmp/q06-netpol-endport/.cni-enforces`. Met at code level.
   - **Requires live cluster to confirm probe actually writes `true` on
     calico/cilium and `false` on flannel-without-NP-plugin.**

2. **cluster-architecture/05-audit-policy — per-resource level mapping
   + omitStages enforced; a flipped mapping fails.**
   - 4 weight=1 scoring assertions (A/B/C/D) replace the bundled
     "structure valid" check. Flipping Secrets→Request makes Assertion
     A fail. Met at code level.

3. **workloads-scheduling/04-hpa-metrics-server — target.type ==
   Utilization AND target.averageUtilization == 50 asserted.**
   - 2 new weight=1 assertions inserted after Assertion 4 using the
     existing `[?(@.type=="Resource")]` jsonpath filter shape. A
     candidate HPA with `averageUtilization: 80` fails Assertion 6.
     Met at code level.

4. **Ref-solutions still score max/max under the strengthened graders.**
   - **Requires live cluster** to run setup + ref-solution + grade
     round-trips. Code review confirms ref-solution.sh files already
     declare the canonical values the new graders demand.

**Conclusion:** Code changes are complete and syntactically valid. Live
GRADE round-trips on a real cluster are required to confirm probe
sentinel writes, scoring totals, and trap firing under all branches.

## test.sh baseline diff (Phase 10/11 regression suite)

Pre-Phase-13 baseline (HEAD^^^ = 84e99f7): **4 failures**

- cluster-architecture__04-pss-enforce
- storage__01-pvc-binding
- storage__02-storageclass-dynamic
- workloads-scheduling__05-daemonset

Post-Phase-13 (HEAD = d267419): **6 failures** (+2 new)

- cluster-architecture__04-pss-enforce (pre-existing)
- storage__01-pvc-binding (pre-existing)
- storage__02-storageclass-dynamic (pre-existing)
- workloads-scheduling__05-daemonset (pre-existing)
- **services-networking__06-netpol-endport (Phase 13-introduced):**
  fixture expects `SCORE: 0/6` on empty submission, actual is `SCORE: 0/4`.
  Reason — the empty-submission post-setup baseline cannot evaluate any
  reachability matrix because no NP is authored AND the kubectl-stub
  fixture has no live CNI to produce a sentinel. The strengthened grader
  now scores only the 4 unconditional structural assertions on this
  fixture path (0/4 = empty-submission expected behaviour). Sentinel
  missing → reachability skipped per the contract.
- **workloads-scheduling__04-hpa-metrics-server (Phase 13-introduced):**
  fixture expects `SCORE: 0/5` on empty submission, actual is `SCORE: 0/7`.
  Reason — added Assertions 5 and 6 increase max-points from 5 to 7;
  empty-submission still scores 0 but denominator changed.

These 2 new failures are **expected behaviour changes from Phase 13 and
require fixture regeneration after live-UAT confirms the new scoring
totals on a real cluster**. Per the milestone plan, fixture regen is a
post-UAT activity, not part of the autonomous execution. The
`workloads-scheduling__05-daemonset` failure observed in BOTH baseline
and post-Phase-13 runs is unrelated to Phase 13 (Phases 10/11 leftover).

## Live-UAT checklist (handoff)

For each of the 3 questions, on a cluster with metrics-server +
NetworkPolicy-enforcing CNI installed:

1. **BUG-M04 netpol-endport:**
   - `cka-sim drill services-networking 06-netpol-endport`
   - Inspect `/tmp/q06-netpol-endport/.cni-enforces` after setup →
     should contain `true`.
   - Run ref-solution → grader should score `8/8` with 0 traps.
   - Run with empty submission → `0/8` with `netpol-endport-missing-protocol`
     trap fired.
   - Synthetic: author NP with `endPort=8095` → score `≤3/8` (structural
     endPort=8090 + reachability :8095 unreachable both fail; trap may
     or may not fire depending on protocol).
   - On flannel-without-NP-plugin cluster (if available), confirm
     sentinel writes `false` and grader emits "CNI non-enforcing — not
     gradable" with score `4/4`.

2. **BUG-M05 audit-policy:**
   - `cka-sim drill cluster-architecture 05-audit-policy`
   - Empty: `0/4` with `audit-policy-wrong-stage-verbosity` trap fired.
   - Ref-solution: `4/4` with 0 traps.
   - Synthetic: flip Secrets→Request → `3/4` with trap.
   - Synthetic: truncate policy.yaml → `0/4` with trap (no python crash).

3. **BUG-M06 hpa-metrics-server:**
   - `cka-sim drill workloads-scheduling 04-hpa-metrics-server`
   - Empty: `0/7` (or `0/6` if metrics-server is up and Assertion 7 passes).
   - Ref-solution: `7/7` with 0 traps.
   - Synthetic: `averageUtilization: 80` → `6/7` (Assertion 6 fails).
   - Synthetic: `target.type: AverageValue + averageValue: 100m` → `5/7`
     (Assertions 5 and 6 both fail).

After live-UAT confirms the above, regenerate fixtures via the existing
`--regen` workflow (per services-networking/06-netpol-endport fixture
script header note) and update `workloads-scheduling/04-hpa-metrics-server`
fixture totals from 5→7.

## Open blockers

None at code level. Live-UAT is the next gate.
