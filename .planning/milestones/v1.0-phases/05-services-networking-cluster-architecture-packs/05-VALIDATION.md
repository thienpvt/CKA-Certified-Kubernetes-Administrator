---
phase: 05
slug: services-networking-cluster-architecture-packs
status: superseded
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-12
superseded: 2026-05-14
---

# Phase 05 — Validation Strategy

> **Superseded (2026-05-14).** This draft validation contract was not marked up
> during execution. Phase 5 verification was instead carried by `05-VERIFICATION.md`
> (status: verified) and live-drill UAT (14/14 pass on the 1+2 cluster). The
> per-task table below is retained for historical reference only.

> Per-phase validation contract for feedback sampling during execution. Phase 5 is content-authoring (no new runtime code); validation is pack-lint + round-trip tests + live-drill checklist.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash + PATH-shadowed `kubectl` stub (existing, Phase 2) |
| **Config file** | `cka-sim/scripts/test.sh` (harness), fixtures under `cka-sim/tests/fixtures/phase-05/` |
| **Quick run command** | `bash cka-sim/scripts/lint-packs.sh` (< 5 s) |
| **Full suite command** | `bash cka-sim/scripts/test.sh && bash cka-sim/scripts/lint-packs.sh && bash cka-sim/scripts/lint-traps.sh && bash cka-sim/scripts/lint-coverage.sh && bash cka-sim/scripts/lint-deprecated-strings.sh` |
| **Estimated runtime** | ~30 seconds for the full suite |

---

## Sampling Rate

- **After every task commit:** Run `bash cka-sim/scripts/lint-packs.sh` (catches schema/RFC-1123/round-trip regressions fast)
- **After every plan wave:** Run the full suite (all 5 lint scripts + test harness)
- **Before `/gsd-verify-work`:** Full suite green + live-drill checklist all green on the 1+2 cluster
- **Max feedback latency:** 5 seconds for the quick run; 30 seconds for the full suite

---

## Per-Task Verification Map

Task IDs follow the pattern `05-PP-TT` where `PP` is the plan number and `TT` the task number. Filled in once plans exist; placeholder rows show the expected shape per plan.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 05-01-XX | P01 lib extensions | 1 | helper API | — | `seed_netpol_skeleton` emits DNS-allow egress; `read_node_worker` returns non-empty non-CP node | unit | `bash -n cka-sim/lib/setup.sh && bash cka-sim/scripts/test.sh` | ❌ W0 | ⬜ pending |
| 05-02-XX | P02 S&N retrofit + new Qs | 1-2 | PACK-03, PACK-06, PACK-07 subset | — | 6 questions round-trip FAIL→trap and PASS→no trap against kubectl stub | unit | `bash cka-sim/scripts/lint-packs.sh && bash cka-sim/scripts/lint-coverage.sh services-networking && bash cka-sim/scripts/test.sh` | ❌ W0 | ⬜ pending |
| 05-03-XX | P03 Cluster-Arch retrofit + new Qs | 1-2 | PACK-04, PACK-06, PACK-07 subset | — | 8 questions round-trip via kubectl stub | unit | `bash cka-sim/scripts/lint-packs.sh && bash cka-sim/scripts/lint-coverage.sh cluster-architecture && bash cka-sim/scripts/test.sh` | ❌ W0 | ⬜ pending |
| 05-04-XX | P04 trap catalog + coverage.yaml | 1 | GRADE-04, PACK-07 | — | 10 new trap ids pass schema lint; both coverage.yaml files pass coverage lint | unit | `bash cka-sim/scripts/lint-traps.sh && bash cka-sim/scripts/lint-coverage.sh` | ❌ W0 | ⬜ pending |
| 05-05-XX | P05 deprecated-strings CI lint | 2 | CI-02 | — | Lint script fails PR on forbidden strings; zero false positives on Phase 4 output | unit | `bash cka-sim/scripts/lint-deprecated-strings.sh; echo exit=$?` | ❌ W0 | ⬜ pending |
| 05-06-XX | P06 Phase 3 retrofits sourcing lib/setup.sh | 1 | reuse-audit | — | `01-networkpolicy-egress` and `01-rbac-viewer` still round-trip green after sourcing helpers | unit | `bash cka-sim/scripts/lint-packs.sh && bash cka-sim/scripts/test.sh` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

Plan IDs are a placeholder — the planner may split these differently; VALIDATION.md gets updated after planning.

---

## Wave 0 Requirements

- [ ] `cka-sim/tests/fixtures/phase-05/services-networking/` — one fixture per new question (allow + trap-fire states), stubbing kubectl per-resource
- [ ] `cka-sim/tests/fixtures/phase-05/cluster-architecture/` — one fixture per new question (sandbox path state for etcd/kubeadm/cri-dockerd/audit-policy drills)
- [ ] `cka-sim/scripts/lint-deprecated-strings.sh` — new lint script (see RESEARCH §13)
- [ ] `cka-sim/scripts/lint-packs.sh` — extended to walk `services-networking` and `cluster-architecture` packs (already walks storage + workloads)
- [ ] `cka-sim/scripts/lint-coverage.sh` — extended to walk the two new pack `coverage.yaml` files
- [ ] Extend `cka-sim/scripts/test.sh` harness to auto-discover Phase 5 fixtures via the existing case-glob (no new suite-label flag; plans use concrete shell invocations in the Per-Task table above)
- [ ] `.github/workflows/validate.yml` — add `bash cka-sim/scripts/lint-deprecated-strings.sh` step

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `cka-sim drill services-networking` round-trips all 6 Qs on the live 1+2 cluster | PACK-03, GRADE-06 | Requires a running kubeadm v1.35 cluster; kubectl stub cannot reproduce real apiserver + CNI + CoreDNS behaviour | For each Q 1-6: `cka-sim drill services-networking N` → expect ≥1 trap on FAIL path; `cka-sim drill services-networking N && bash <ref-solution> && bash grade.sh` → expect exit 0 on PASS path. Record pass/fail per Q in VERIFICATION.md. |
| `cka-sim drill cluster-architecture` round-trips all 8 Qs on the live 1+2 cluster | PACK-04, GRADE-06 | Same as above — etcd backup drill must hit live etcd read-only, PSS enforcement relies on real apiserver admission | For each Q 1-8: same FAIL-then-PASS round-trip. Q04 PSS check depends on v1.35 apiserver admitting the privileged pod and returning the correct wording; Q07 CRI-dockerd asserts on sandbox file contents only. |
| Deprecated-strings lint produces zero false positives on Phase 4 content | CI-02 | Regex-based lint may misfire on pre-existing content — must be validated by humans before CI enforcement | Run `bash cka-sim/scripts/lint-deprecated-strings.sh` against HEAD; expect exit 0 and empty output. Any non-zero exit blocks merge until the lint or the carveout is adjusted. |
| Coverage lint reports 100 % for both packs | PACK-07 | Tracker checkbox → question mapping is semantic and author-authored | After all Qs land: `bash cka-sim/scripts/lint-coverage.sh services-networking` and `bash cka-sim/scripts/lint-coverage.sh cluster-architecture` — both exit 0 and report "100% tracker coverage". |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s (full suite)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
