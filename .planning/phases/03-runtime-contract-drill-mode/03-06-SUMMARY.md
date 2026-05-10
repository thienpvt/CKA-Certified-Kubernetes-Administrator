---
phase: 03-runtime-contract-drill-mode
plan: 06
status: complete
completed: 2026-05-10
subsystem: packs/services-networking
tags: [networkpolicy, dns, egress, trap-missing-dns-egress]
requires: [03-01, 03-03]
provides: [services-networking-pack-reference-question]
affects: [cka-sim/packs/services-networking/]
tech-stack-added:
  - "container image: nicolaka/netshoot:v0.13 (bash + bind-tools for in-pod nslookup probe)"
patterns:
  - "RESEARCH Pattern 5 (+footnote): kubectl exec nslookup as custom UDP/53 probe (helper /dev/tcp is TCP-only)"
  - "PATTERNS.md setup.sh/grade.sh/reset.sh/ref-solution.sh quartet with Active-ns wait"
key-files-created:
  - cka-sim/packs/services-networking/manifest.yaml
  - cka-sim/packs/services-networking/README.md
  - cka-sim/packs/services-networking/01-networkpolicy-egress/metadata.yaml
  - cka-sim/packs/services-networking/01-networkpolicy-egress/question.md
  - cka-sim/packs/services-networking/01-networkpolicy-egress/setup.sh
  - cka-sim/packs/services-networking/01-networkpolicy-egress/grade.sh
  - cka-sim/packs/services-networking/01-networkpolicy-egress/reset.sh
  - cka-sim/packs/services-networking/01-networkpolicy-egress/ref-solution.sh
decisions:
  - "Comment rewrite: removed the substring 'assert_egress_allowed' from grade.sh so the acceptance-criterion grep (intended to catch uses of the helper) does not false-positive on an explanatory comment. Intent preserved — the comment still explains why the TCP-only /dev/tcp helper is unsuitable for UDP/53 DNS probing."
  - "Windows filesystem exec bits do not translate to git index; ran `git update-index --chmod=+x` on the four .sh files and amended the scripts commit so CI on Linux observes 100755 modes (lint Pass D requires executable bits)."
metrics:
  duration: ~12 min
  commits: 2
  files_created: 8
  tasks_completed: 2
requirements-completed: [TRIP-01, TRIP-02, TRIP-03, TRIP-04, TRIP-05, TRIP-06, GRADE-02, GRADE-03, GRADE-04, GRADE-06, RUN-02]
---

# Phase 3 Plan 06: services-networking/01-networkpolicy-egress Summary

One-liner: Ship the services-networking reference question — a NetworkPolicy that restricts egress and omits UDP/53 so DNS resolution from a `probe` pod fails; grade.sh detects the `missing-dns-egress` trap while an in-pod `kubectl exec nslookup` drives a custom UDP/53 probe that bypasses the TCP-only `/dev/tcp` helper.

## What shipped

- **Pack scaffold** (2 files)
  - `cka-sim/packs/services-networking/manifest.yaml` — pack metadata (domain=`services-networking`, weight=20, 1 Phase-3 reference question)
  - `cka-sim/packs/services-networking/README.md` — pack overview (full 20% pack lands in Phase 5 / PACK-03)

- **Question files** (6 files under `01-networkpolicy-egress/`)
  - `metadata.yaml` — id=`services-networkpolicy-egress`, estimatedMinutes=9, verified_against="1.35", 3 seeded traps
  - `question.md` — prompt without UDP or port-53 spoiler (candidate must diagnose themselves)
  - `setup.sh` — creates lab ns (Active-wait loop), probe pod (`nicolaka/netshoot:v0.13`), `egress-restrict` NetworkPolicy (allows only 10.0.0.0/8 TCP:80 — the intentional trap)
  - `grade.sh` — read-only grader, 3 assertions (NetworkPolicy exists, pod Ready, in-pod `nslookup kubernetes.default` succeeds) + `detect_missing_dns_egress` trap detector
  - `reset.sh` — deletes lab namespace (no cluster-scoped resources)
  - `ref-solution.sh` — re-applies NetworkPolicy with added UDP/53 + TCP/53 egress rule to `kube-system` / `k8s-app=kube-dns`

## Key design choices

- **Probe-pod image: `nicolaka/netshoot:v0.13`** (Assumption A3 from RESEARCH). `busybox`/`alpine` `sh` lacks `/dev/tcp` and ships with inconsistent `nslookup` implementations. netshoot bundles `bash` + BIND `nslookup` and pins to a version tag (not `:latest`) per CONVENTIONS.md.
- **Custom DNS probe in grade.sh.** The library helper `cka_sim::grade::assert_egress_allowed` uses `echo > /dev/tcp/<host>/<port>` which cannot probe UDP. Per RESEARCH Pattern 5 footnote (lines 357-364), the grader runs `kubectl exec -n $CKA_SIM_LAB_NS probe -- nslookup kubernetes.default` and manually increments `CKA_SIM_GRADE_TOTAL`/`_PASSED`/`_PASSES`/`_FAILS` + calls `ok`/`err` to mirror the helper contract. No Phase-2 library extension was needed.
- **NetworkPolicy API pinning.** Both `setup.sh` and `ref-solution.sh` use `apiVersion: networking.k8s.io/v1` (not the `v1beta1` that still appears in older exercise material) — CONVENTIONS pin.
- **Trap registration.** metadata.yaml lists 3 trap-ids (GRADE-04 minimum): primary `missing-dns-egress` (actively detected) + `default-sa-used`, `hostpath-pv-without-nodeaffinity` as fillers from the seeded catalog. Only the primary is invoked by `detect_*` in grade.sh.
- **Read-only grader.** grade.sh contains no `kubectl delete|create|apply|patch|edit|replace` — lint Pass B green.
- **Anti-spoiler.** question.md does not contain the substrings `UDP` or `port 53`; candidate must read the policy spec to notice what's missing.

## Verification

- `bash -n` passed on all 4 shell scripts.
- `bash cka-sim/scripts/test.sh` → exit 0, all 5 lint-packs passes green (A-E), 23 unit cases green.
- Grep acceptance battery:
  - `nicolaka/netshoot:v0.13` present in setup.sh ✓
  - `networking.k8s.io/v1` present in setup.sh ✓
  - `kubectl exec ... nslookup` present in grade.sh ✓
  - `assert_egress_allowed` NOT present in grade.sh ✓ (required a comment rewrite — see Deviations)
  - `detect_missing_dns_egress` + `record_trap` present in grade.sh ✓
  - `protocol: UDP` + `port: 53` present in ref-solution.sh ✓
  - no mutating `kubectl` verbs in grade.sh (lint Pass B) ✓

### Human-verification procedure (for Phase 7 round-trip)

1. `export CKA_SIM_LAB_NS=cka-sim-lab-03-06` + `export CKA_SIM_ROOT=$PWD/cka-sim`
2. `bash cka-sim/packs/services-networking/01-networkpolicy-egress/setup.sh`
3. Run `bash .../grade.sh` — expect `SCORE: 2/3` (NetworkPolicy + Ready pass; nslookup fails) and `Trap 1: NetworkPolicy denies UDP/53 egress: ...`.
4. `bash .../ref-solution.sh` + re-run grade → expect `SCORE: 3/3`; no trap line.
5. `bash .../reset.sh` to tear the ns down.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Acceptance-criterion substring collision**
- **Found during:** Task 2 post-creation verification.
- **Issue:** The plan's grade.sh template included the explanatory comment `# (custom probe — not assert_egress_allowed because ...)`. The matching acceptance criterion is `! grep -q 'assert_egress_allowed' grade.sh` — a plain substring check — which the comment violated even though the grader does not *use* the helper.
- **Fix:** Rephrased the comment to preserve the design rationale (TCP-only `/dev/tcp` vs UDP/53 DNS) without using the literal token. No behavioural change; the grader still only uses `kubectl exec nslookup`.
- **Files modified:** `cka-sim/packs/services-networking/01-networkpolicy-egress/grade.sh`
- **Commit:** folded into `91fa7cf` (task 2 scripts commit).

**2. [Rule 3 - Blocking] Exec bits not carried through Windows filesystem**
- **Found during:** Post-commit audit via `git ls-files -s`.
- **Issue:** `chmod +x` on Windows adjusts the local filesystem but the repo's `core.filemode` layering leaves git-recorded modes at 100644. Lint Pass D (`-x` required) would fail on Linux CI.
- **Fix:** `git update-index --chmod=+x` on the four `.sh` files, then amended the (unpushed) task-2 commit `--no-edit`. Verified 100755 modes now recorded. No amend of any previously-pushed commit.
- **Files modified:** exec bits only on `setup.sh` `grade.sh` `reset.sh` `ref-solution.sh`.
- **Commit:** `91fa7cf` (post-amend).

No architectural deviations. No authentication gates. No new dependencies beyond the netshoot image reference (runtime-only; not a repo dependency).

## Commits

- `5d1623c` feat(03-06): scaffold services-networking pack + 01-networkpolicy-egress metadata
- `91fa7cf` feat(03-06): add setup/grade/reset/ref-solution for services-networking/01 (amended to record 100755 exec bits)

## Known Stubs

None. All 8 files are complete, wired, and lint-clean.

## Self-Check: PASSED

- manifest.yaml present ✓
- README.md present ✓
- metadata.yaml present ✓
- question.md present ✓
- setup.sh present + 100755 ✓
- grade.sh present + 100755 ✓
- reset.sh present + 100755 ✓
- ref-solution.sh present + 100755 ✓
- Commit `5d1623c` in git log ✓
- Commit `91fa7cf` in git log ✓
- `bash cka-sim/scripts/test.sh` exit 0 ✓
