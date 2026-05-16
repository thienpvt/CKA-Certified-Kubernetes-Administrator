---
phase: 6
slug: troubleshooting-pack
status: superseded
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-12
superseded: 2026-05-14
---

# Phase 6 — Validation Strategy

> **Superseded (2026-05-14).** This draft validation contract was not marked up
> during execution. Phase 6 verification was instead carried by `06-VERIFICATION.md`
> (status: verified) and `06-HUMAN-UAT.md` (22/22 pass on the 1+2 cluster). The
> per-task table below is retained for historical reference only.

> Per-phase validation contract for feedback sampling during Phase 6 (Troubleshooting Pack) execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Pure bash harness (`cka-sim/scripts/test.sh`) with PATH-shadowed `kubectl` stub (Phase 2) |
| **Config file** | `cka-sim/scripts/test.sh` (orchestrator) + `cka-sim/tests/run.sh` (runner) |
| **Quick run command** | `bash cka-sim/scripts/lint-packs.sh cka-sim/packs/troubleshooting && bash -n cka-sim/packs/troubleshooting/<question-slug>/*.sh` |
| **Full suite command** | `bash cka-sim/scripts/test.sh` (lint-traps + lint-packs + lint-coverage + fixture round-trip) |
| **Estimated runtime** | ~60s full suite; ~5s focused per-question quick |

---

## Sampling Rate

- **After every task commit:** Run `bash -n` on any modified `*.sh` + focused `lint-packs.sh` on the question directory touched (~5s).
- **After every plan wave:** Run `bash cka-sim/scripts/test.sh` full suite + `bash cka-sim/scripts/lint-coverage.sh` (~60s).
- **Before `/gsd-verify-work`:** Full suite must be green on all 5 packs; live 1+2 cluster drill checklist completed for each of the 6 troubleshooting questions.
- **Max feedback latency:** 60 seconds.

---

## Per-Task Verification Map

Executor fills concrete `Task ID | Plan` rows as plans are generated; the columns below encode the contract every Phase 6 task must satisfy.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 06-01-XX | 01 (lint-packs guard) | 1 | PACK-05, PACK-06 | — | Reject forbidden commands (`systemctl`, live kube-system / `/etc/kubernetes` / `/var/lib/kubelet` writes) in any troubleshooting `*.sh` | unit | `bash cka-sim/scripts/lint-packs.sh cka-sim/packs/troubleshooting` | ✅ | ⬜ pending |
| 06-02-XX | 02 (catalog +11 traps) | 1 | PACK-06 (≥3 traps/question), GRADE-05 | — | 11 new trap IDs pass 8-field schema + structured references | unit | `bash cka-sim/scripts/lint-traps.sh` | ✅ | ⬜ pending |
| 06-03-XX | 03 (Q1 service-mismatch retrofit) | 1 | PACK-05, PACK-06, TRIP-05 | — | Retrofit sources `lib/setup.sh`; adds ImagePullBackOff trap detection; cross-pack ref path | fixture | `bash cka-sim/scripts/test.sh` (fixture `troubleshooting-01-deploy-svc-mismatch`) | ✅ | ⬜ pending |
| 06-04-XX | 04 (Q2 netpol-dns-egress) | 2 | PACK-05, PACK-06, GRADE-02, GRADE-06 | — | Label-key drift + DNS egress omission; kubectl exec probe oracle; no `kubectl get \| grep` | fixture | `bash cka-sim/scripts/test.sh` (fixture `troubleshooting-02-netpol-dns-egress`) | ✅ W0 | ⬜ pending |
| 06-05-XX | 05 (Q3 coredns-resolution) | 2 | PACK-05, PACK-06, GRADE-06 | T-6-03 (no live kube-system) | Lab-namespace CoreDNS Deployment + ConfigMap; candidate fixes Corefile `forward` clause; kube-system untouched | fixture | `bash cka-sim/scripts/test.sh` (fixture `troubleshooting-03-coredns-resolution`) | ✅ W0 | ⬜ pending |
| 06-06-XX | 06 (Q4 debug-node) | 2 | PACK-05, PACK-06, GRADE-06 | T-6-04 (read-only host) | Requires real `kubectl debug node/<worker> -- chroot /host ...`; answer oracle is Node-API `kernelVersion` jsonpath; debug pods reaped on reset | fixture | `bash cka-sim/scripts/test.sh` (fixture `troubleshooting-04-debug-node`) | ✅ W0 | ⬜ pending |
| 06-07-XX | 07 (Q5 static-pod-manifest) | 2 | PACK-05, PACK-06, TRIP-06 | T-6-05 (no `/etc/kubernetes/manifests/` write) | Sandbox `/tmp/q05-staticpod/`; grader uses `kubectl apply --dry-run=client` content match only | fixture | `bash cka-sim/scripts/test.sh` (fixture `troubleshooting-05-static-pod-manifest`) | ✅ W0 | ⬜ pending |
| 06-08-XX | 08 (Q6 broken-kubelet) | 2 | PACK-05, PACK-06, TRIP-06 | T-6-06 (no `/var/lib/kubelet/` write, no `systemctl`) | Sandbox `/tmp/q06-kubelet-flags/`; grader content-only assertions on removed/added kubelet flags | fixture | `bash cka-sim/scripts/test.sh` (fixture `troubleshooting-06-broken-kubelet`) | ✅ W0 | ⬜ pending |
| 06-09-XX | 09 (pack finalize + VERIFY) | 3 | PACK-05, PACK-06, PACK-07, CI-03 | — | `manifest.yaml` + `coverage.yaml` + `README.md` complete; VERIFICATION.md authored; 100% across all 5 packs | integration | `bash cka-sim/scripts/lint-coverage.sh \| grep -q '100%'` and full `bash cka-sim/scripts/test.sh` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

Universal acceptance rules every task MUST pass (also enforced by `lint-packs.sh`):

- Bash syntax clean: `bash -n` on every new `*.sh`.
- Grader never contains `kubectl get \| grep` or `kubectl get -A` (GRADE-02).
- Forbidden commands absent from any troubleshooting script: `systemctl`, `kubectl edit configmap coredns -n kube-system`, `kubectl delete ns kube-system`, `kubectl cordon|drain` on a worker, writes into `/etc/kubernetes/` or `/var/lib/kubelet/`, copies into `/etc/kubernetes/manifests/`.
- Every `metadata.yaml` has ≥1 `references[]` entry whose target begins with `cka-sim/packs/` (Phase 6 D-05 cross-pack guarantee).

---

## Wave 0 Requirements

All Wave 0 prerequisites already landed in Phases 2-5 — this phase ships no new test-framework infrastructure.

- [x] `cka-sim/scripts/test.sh` orchestrator — exists (Phase 2)
- [x] `cka-sim/scripts/lint-traps.sh` — exists (Phase 2)
- [x] `cka-sim/scripts/lint-packs.sh` — exists (Phase 3)
- [x] `cka-sim/scripts/lint-coverage.sh` — exists (Phase 4, walks every pack under `packs/`)
- [x] PATH-shadowed `kubectl` stub + `cka-sim/tests/run.sh` — exists (Phase 2)
- [x] `cka-sim/lib/grade.sh`, `lib/traps.sh`, `lib/setup.sh` — exist; Phase 6 research confirms zero new helpers required
- [ ] `cka-sim/tests/fixtures/troubleshooting-NN-<slug>/` — 6 fixture dirs seeded by the per-question plans (Plans 03-08)
- [ ] `cka-sim/scripts/lint-packs.sh` forbidden-command guard extension — seeded in Plan 01 (Wave 1)

*Existing infrastructure covers all phase requirements; Phase 6 only adds fixtures and one lint-packs.sh deny-list extension.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `cka-sim drill troubleshooting NN` runs every question round-trip on the real 1+2 kubeadm cluster | PACK-05 success criterion 4 | The cluster is an external dependency; CI uses stubs, never live kubectl | On the control-plane node: for NN in 01..06, `cka-sim drill troubleshooting NN` → complete the drill → verify `SCORE:` + at least one `Trap:` on a wrong attempt and no `Trap:` on the ref-solution attempt |
| Q4 debug-pod cleanup on live cluster | PACK-05, safety | `kubectl debug node/...` can leak debug pods when the drill is Ctrl-C'd; the stub harness can't exercise this | After Q4 drill: `kubectl get pods --all-namespaces -l 'kubectl.kubernetes.io/debug-source'` returns empty |
| Q6 kubelet-flags baseline preservation | D-09 host-safety | Only a live system has `/var/lib/kubelet/kubeadm-flags.env`; CI can't inspect it | Before Q6 drill: `sha256sum /var/lib/kubelet/kubeadm-flags.env` saved to `/tmp/q06-baseline.sha`. After drill: `sha256sum -c /tmp/q06-baseline.sha` must pass (file unchanged) |
| Q5 manifests dir untouched | D-09 host-safety | Live `/etc/kubernetes/manifests/` can't be inspected by CI | Before Q5 drill: `ls -la /etc/kubernetes/manifests/` recorded. After drill: identical listing |
| Q3 kube-system CoreDNS untouched | D-11 safety | Live `kube-system/coredns` ConfigMap can't be inspected by CI | Before Q3 drill: `kubectl -n kube-system get cm coredns -o yaml > /tmp/q03-coredns-baseline.yaml`. After drill: `diff` against re-fetched current ConfigMap returns empty |

---

## Validation Sign-Off

- [ ] All 9 plan tasks have `<automated>` verify OR a documented manual-only entry above
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (all Phase 6 Wave 0 boxes are checked above — no net-new framework needed)
- [ ] No watch-mode flags (test.sh is one-shot; no `--watch`)
- [ ] Feedback latency < 60s (full-suite budget)
- [ ] `nyquist_compliant: true` set in frontmatter once every PLAN.md references this VALIDATION.md and every manual-only entry is signed off against a live 1+2 drill

**Approval:** pending
