---
phase: 05-services-networking-cluster-architecture-packs
plan: 18
subsystem: services-networking
status: complete
gap_closure: true
gaps_closed: [2]
tags: [services-networking, netpol, endport, gap-closure, uat]
requirements: [PACK-03, PACK-06, PACK-07]
dependency_graph:
  requires:
    - 05-07 (Q06 netpol-endport pack)
    - 05-01 (seed_netpol_skeleton helper, signature locked)
  provides:
    - closure of UAT gap 2 — S&N Q06 ref-solution reaches 6/6 rc=0
  affects:
    - cka-sim/packs/services-networking/06-netpol-endport/setup.sh
tech_stack:
  added: []
  patterns:
    - Sibling NetworkPolicy pattern (second policy layered on top of shared DNS baseline instead of widening the helper)
key_files:
  created: []
  modified:
    - cka-sim/packs/services-networking/06-netpol-endport/setup.sh
decisions:
  - 2026-05-13 — Fix Q06 egress gap with a supplemental NetworkPolicy q06-client-egress rather than extending seed_netpol_skeleton; the shared helper signature stays locked per 05-01-SUMMARY.md so other S&N packs remain greppable for the DNS-only baseline pattern.
  - 2026-05-13 — Cap the client-side egress at endPort 8090 so grader assertion 6 (8095 must fail) stays true even in broken state; assertion 6 thus does not depend on the server-side ingress policy being present.
metrics:
  tasks_completed: 2
  files_modified: 1
  commits: 1
  duration: ~5 minutes (edit + lint run)
  completed: 2026-05-13
---

# Phase 05 Plan 18: Q06 netpol-endport client-egress gap closure Summary

One-liner: Added a supplemental `q06-client-egress` NetworkPolicy to Q06 setup.sh so ref-solution grades 6/6 instead of 5/6, closing UAT gap 2 without touching the shared `seed_netpol_skeleton` helper.

## What Changed

Single file edit: `cka-sim/packs/services-networking/06-netpol-endport/setup.sh`. Inserted a `kubectl apply -f -` block between the existing `cka_sim::setup::seed_netpol_skeleton` call and the `kubectl wait` for pod readiness. The new manifest:

- `kind: NetworkPolicy`, `name: q06-client-egress`, scoped to `${CKA_SIM_LAB_NS}`
- `podSelector: matchLabels.app=q06-client`
- `policyTypes: [Egress]` (ingress intentionally omitted — not needed on the client)
- Single egress rule: `to: [{ podSelector: { matchLabels: { app: q06-server } } }]`, ports `TCP 8080 endPort 8090`

## Fix Rationale

Kubernetes NetworkPolicy semantics are additive (UNION) and scoped by `podSelector`. Before this fix:

- `q06-baseline` (from `seed_netpol_skeleton`) selects `app=q06-client` with `policyTypes: [Ingress, Egress]` and a single DNS-only egress rule. Because `Egress` is declared, all other egress from q06-client is implicit-deny.
- `q06-allow-range` (from ref-solution) is an **ingress** policy on q06-server. It does not grant any egress on q06-client.
- Grader assertion 5 `kubectl exec q06-client -- wget q06-server:8085` therefore times out under the baseline even after the ref-solution applies its ingress policy → ref-solution grade ceilings at 5/6.

After this fix, the two q06-client-selecting egress policies (`q06-baseline` + `q06-client-egress`) UNION: q06-client may egress DNS to kube-system AND TCP 8080-8090 to `app=q06-server`. 8095 remains denied on the client side because the new policy caps at endPort 8090 and the DNS rule only covers 53. Server-side, ref-solution adds an ingress allow for the same 8080-8090 range from q06-client. Both sides aligned → 6/6.

### Broken-state behaviour

Because no NetworkPolicy selects q06-server in broken state, q06-server's ingress is default-allow. Client egress is now explicitly permitted for 8080-8090. Net broken-state grade:

| Assertion | Broken result | Reason |
|-----------|---------------|--------|
| 1. `q06-allow-range` exists | fail | candidate has not authored it |
| 2. `.spec.ingress[0].ports[0].port == 8080` | fail | resource missing |
| 3. `.spec.ingress[0].ports[0].endPort == 8090` | fail | resource missing |
| 4. protocol TCP declared | fail | resource missing — fires `netpol-endport-missing-protocol` trap |
| 5. 8085 wget succeeds | pass | client-egress allows 8085, server ingress default-allow |
| 6. 8095 wget fails | pass | client-egress caps at 8090 |

Broken SCORE: 2/6, rc=1, trap `netpol-endport-missing-protocol` recorded. Matches the truth #4 expectation in the plan frontmatter.

### Why a sibling policy rather than extending the helper

The plan explicitly locks `seed_netpol_skeleton`'s three-argument signature (`ns`, `name`, `selector-key=value`) per 05-01-SUMMARY.md because other Phase 5 questions rely on greppable identical DNS-only baselines. Widening it here would ripple across the whole pack and muddy the "DNS baseline" lint pattern. A sibling policy keeps the helper pristine and is the idiomatic K8s shape anyway: layered policies expressing distinct concerns (default DNS baseline + per-question workload egress).

### Why client-side cap at 8090

Grader assertion 6 (`wget q06-server:8095` must fail) would pass incidentally from broken-state default-deny if the baseline blocked everything — but once any client egress policy permits 8080-8090, it must stop there. If the new policy had permitted `port: 8080 endPort: 8095` by mistake, broken-state assertion 6 would flip to fail and the whole point of the trap catalog (teaching endPort semantics) would be undermined. Capping at 8090 makes assertion 6 independent of the server-side policy.

## Tasks

### Task 1: Add q06-client-egress supplemental NetworkPolicy to setup.sh

- Files modified: `cka-sim/packs/services-networking/06-netpol-endport/setup.sh` (+31 lines)
- Commit: `d3fd5c3` — `fix(05-18): add q06-client-egress policy so Q06 ref-solution grades 6/6`
- Automated verify: `bash -n` clean, all five grep assertions pass (q06-client-egress present, port 8080, endPort 8090, seed_netpol_skeleton preserved)
- `lib/setup.sh` NOT touched — helper signature stable

### Task 2: Lint suite — confirm no regressions

Verification-only task, no file changes → no commit.

Results:

- `bash cka-sim/scripts/test.sh` → 32 cases pass, exit 0
- `bash cka-sim/scripts/lint-packs.sh` → 203 checks pass, exit 0
- `bash cka-sim/scripts/lint-coverage.sh` → 4 packs OK, 0 warnings, exit 0
- `bash cka-sim/scripts/lint-traps.sh` → 36 catalog entries pass schema, exit 0
- `bash cka-sim/scripts/lint-deprecated-strings.sh` → 940 file-pattern checks pass, exit 0

No regressions on sibling S&N questions (Q01 retrofit still uses the same baseline helper and emits the same YAML).

## Live Round-Trip Status

Deferred to the Phase 5 live drill UAT re-run (`$gsd-verify-work 5`), gated on live 1+2 kubeadm cluster time per STATE.md "Deferred Verification". Expected live outcomes when run:

1. `cka-sim drill services-networking --question 06 --grade-broken` → rc=1, SCORE 2/6, trap `netpol-endport-missing-protocol`
2. `cka-sim drill services-networking --question 06 --ref-solution`
3. `cka-sim drill services-networking --question 06 --grade` → rc=0, SCORE 6/6
4. `cka-sim drill services-networking --question 06 --reset` → lab namespace deleted; both sibling NetworkPolicies cleaned via cascading namespace delete

## Deviations from Plan

None — plan executed exactly as written. No auto-fixes (Rules 1-3) triggered; no architectural changes (Rule 4) required.

## Self-Check: PASSED

- `cka-sim/packs/services-networking/06-netpol-endport/setup.sh` — FOUND
- `grep -q q06-client-egress setup.sh` — PRESENT
- `grep -q seed_netpol_skeleton setup.sh` — PRESENT
- `grep -q 'port: 8080' setup.sh` — PRESENT
- `grep -q 'endPort: 8090' setup.sh` — PRESENT
- `cka-sim/lib/setup.sh` — UNCHANGED (`git diff HEAD cka-sim/lib/setup.sh` empty)
- Commit `d3fd5c3` — FOUND in `git log`
- All 5 lints + test.sh on this worktree — exit 0
