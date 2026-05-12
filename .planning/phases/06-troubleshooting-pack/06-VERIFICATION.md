---
phase: 06
verified: 2026-05-13
status: human_needed
must_haves_passed: 7
must_haves_total: 8
human_verification_count: 1
score: "7/8 must-haves verified programmatically"
gaps: []
re_verification: { previous_status: null }
requirements_coverage:
  PACK-05: satisfied
  PACK-06: "satisfied (Troubleshooting subset)"
  PACK-07: "satisfied (all 5 packs at 100% Tracker coverage)"
deferred_items:
  - ref: WR-01 (Phase 4)
    note: full vendoring of CSI + metrics-server manifests under cka-sim/vendor/ with recorded SHA256
  - ref: IN-04 (Phase 4)
    note: cka_sim::grade::assert_custom helper + 6-grader retrofit
  - ref: DF-08
    note: Hint reveal (drill mode only)
  - ref: Phase 1 live UAT
    note: tracked in 01-HUMAN-UAT.md; reopen via /gsd-verify-work 1
  - ref: Phase 5 live UAT
    note: tracked in 05-VERIFICATION.md; reopen via /gsd-verify-work 5
source: [06-RESEARCH.md, 06-VALIDATION.md]
---

# Phase 6 Verification Report

## Summary

Phase 6 Troubleshooting pack completes PACK-05 with 6 questions at a progressive difficulty ramp (53 min total), closes PACK-07 100% coverage across all 5 packs, and introduces 11 new trap catalog entries plus 1 forbidden-command lint guard. Host-safety contract (D-09/D-11/D-12) is encoded twice: per-question sandboxing and lint-packs pass G.

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | MH-1: Troubleshooting pack has >=1 question each for CoreDNS, kubectl debug node, NetworkPolicy, broken kubelet, static pod. | VERIFIED | `cka-sim/packs/troubleshooting/coverage.yaml` maps required topics to 6 manifest IDs. |
| 2 | MH-2: Coverage-matrix lint reports 100% for troubleshooting AND for every pack collectively (closes PACK-07). | VERIFIED | `bash cka-sim/scripts/lint-coverage.sh troubleshooting` and `bash cka-sim/scripts/lint-coverage.sh` exit 0. |
| 3 | MH-3: Every troubleshooting metadata.yaml has >=1 references[] entry whose target begins with `cka-sim/packs/` (D-05 cross-pack guarantee). | VERIFIED | `for f in cka-sim/packs/troubleshooting/*/metadata.yaml; do grep -q 'target: cka-sim/packs/' "$f" || exit 1; done` exits 0. |
| 4 | MH-4: `cka-sim drill troubleshooting` can run every question without error. | HUMAN | Live 1+2 kubeadm drill checklist pending. |
| 5 | MH-5: Every trap ID referenced is registered in `cka-sim/traps/catalog.yaml` (catalog + lint-packs pass E). | VERIFIED | `bash cka-sim/scripts/lint-packs.sh` and `bash cka-sim/scripts/lint-traps.sh` exit 0. |
| 6 | MH-6: lint-packs.sh pass G exits 0 against the full troubleshooting pack with no forbidden commands. | VERIFIED | `bash cka-sim/scripts/lint-packs.sh cka-sim/packs/troubleshooting` exits 0 and pass G is present. |
| 7 | MH-7: All 4 previously-existing lints exit 0 on the post-P08 tree. | VERIFIED | `lint-traps.sh`, `lint-packs.sh`, `lint-coverage.sh`, and `lint-deprecated-strings.sh` exit 0. |
| 8 | MH-8: `bash cka-sim/scripts/test.sh` exits 0 (round-trip fixtures for all 6 questions). | VERIFIED | Full suite exits 0. |

## Required Artifacts

| Artifact | Status | Expected contains |
|----------|--------|-------------------|
| `cka-sim/scripts/lint-packs.sh` | PRESENT | `pass G: FORBIDDEN-COMMAND guard` |
| `cka-sim/traps/catalog.yaml` | PRESENT | 11 Phase 6 trap IDs including `kubelet-flag-file-malformed-quoting` |
| `cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/{metadata.yaml,question.md,setup.sh,grade.sh,reset.sh,ref-solution.sh}` | PRESENT | Service mismatch + ImagePullBackOff retrofit |
| `cka-sim/packs/troubleshooting/02-netpol-dns-egress/{metadata.yaml,question.md,setup.sh,grade.sh,reset.sh,ref-solution.sh}` | PRESENT | NetworkPolicy DNS egress troubleshooting |
| `cka-sim/packs/troubleshooting/03-coredns-resolution/{metadata.yaml,question.md,setup.sh,grade.sh,reset.sh,ref-solution.sh}` | PRESENT | lab-ns CoreDNS, not kube-system mutation |
| `cka-sim/packs/troubleshooting/04-debug-node/{metadata.yaml,question.md,setup.sh,grade.sh,reset.sh,ref-solution.sh}` | PRESENT | kubectl debug node read-only workflow |
| `cka-sim/packs/troubleshooting/05-static-pod-manifest/{metadata.yaml,question.md,setup.sh,grade.sh,reset.sh,ref-solution.sh}` | PRESENT | `/tmp/q05-staticpod/` sandbox |
| `cka-sim/packs/troubleshooting/06-broken-kubelet/{metadata.yaml,question.md,setup.sh,grade.sh,reset.sh,ref-solution.sh}` | PRESENT | `/tmp/q06-kubelet-flags/` sandbox |
| `cka-sim/tests/fixtures/troubleshooting-01-deploy-svc-mismatch/{stub-responses.json,expected-fail-score.txt,expected-pass-score.txt}` | PRESENT | Q01 fixture round-trip |
| `cka-sim/tests/fixtures/troubleshooting-02-netpol-dns-egress/{stub-responses.json,expected-fail-score.txt,expected-pass-score.txt}` | PRESENT | Q02 fixture round-trip |
| `cka-sim/tests/fixtures/troubleshooting-03-coredns-resolution/{stub-responses.json,expected-fail-score.txt,expected-pass-score.txt}` | PRESENT | Q03 fixture round-trip |
| `cka-sim/tests/fixtures/troubleshooting-04-debug-node/{stub-responses.json,expected-fail-score.txt,expected-pass-score.txt}` | PRESENT | Q04 fixture round-trip |
| `cka-sim/tests/fixtures/troubleshooting-05-static-pod-manifest/{stub-responses.json,expected-fail-score.txt,expected-pass-score.txt}` | PRESENT | Q05 fixture round-trip |
| `cka-sim/tests/fixtures/troubleshooting-06-broken-kubelet/{stub-responses.json,expected-fail-score.txt,expected-pass-score.txt}` | PRESENT | Q06 fixture round-trip |
| `cka-sim/packs/troubleshooting/manifest.yaml` | PRESENT | 6 question IDs, 53 minutes |
| `cka-sim/packs/troubleshooting/coverage.yaml` | PRESENT | 9 tracker slugs |
| `cka-sim/packs/troubleshooting/README.md` | PRESENT | 6-row candidate table and disclaimer |
| `.planning/phases/06-troubleshooting-pack/06-VERIFICATION.md` | PRESENT | human_needed, 8 must-haves |

## Key Link Verification

| From | To | Via | Status |
|------|----|-----|--------|
| `setup.sh` | `lib/setup.sh` | source + helper calls | WIRED |
| `metadata.traps` | `catalog.yaml` | lint-packs pass E | WIRED |
| `coverage.yaml.tracker.*.questions` | `manifest.yaml.questions[].id` | lint-coverage | WIRED |
| `metadata.references[].target` beginning `cka-sim/packs/` | existing pack paths | D-05 cross-pack scan | WIRED |
| `troubleshooting/*.sh` | pass G forbidden-command guard | no live kube-system, kubelet data directory, Kubernetes config directory, or service-manager mutation | WIRED |

## Automated Checks

| Check | Command | Expected evidence |
|-------|---------|-------------------|
| Trap catalog schema | `bash cka-sim/scripts/lint-traps.sh` | schema OK on every entry |
| Pack lint | `bash cka-sim/scripts/lint-packs.sh` | `pack lint passed` including passes A..G |
| Coverage lint | `bash cka-sim/scripts/lint-coverage.sh` | `coverage lint passed (5 pack(s), 0 warning(s))` |
| Deprecated strings | `bash cka-sim/scripts/lint-deprecated-strings.sh` | exits 0 |
| Full harness | `bash cka-sim/scripts/test.sh` | `all N case(s) passed` and `test.sh complete` |

## Must-Haves Verification

### MH-1: Troubleshooting pack has >=1 question each for CoreDNS, kubectl debug node, NetworkPolicy, broken kubelet, static pod.

**Status:** PASS. `coverage.yaml` maps `troubleshoot-coredns` to Q03, `debug-kubectl-node` to Q04, `troubleshoot-netpol` to Q02, `kubelet-journalctl` to Q06, and control-plane/static-pod-related tracker slugs to Q05.

```bash
for slug in troubleshoot-coredns debug-kubectl-node troubleshoot-netpol kubelet-journalctl control-plane-pod-logs; do grep -qE "^  $slug:$" cka-sim/packs/troubleshooting/coverage.yaml || exit 1; done
```

### MH-2: Coverage-matrix lint reports 100% for troubleshooting AND for every pack collectively (closes PACK-07).

**Status:** PASS.

```bash
bash cka-sim/scripts/lint-coverage.sh troubleshooting
bash cka-sim/scripts/lint-coverage.sh
```

### MH-3: Every troubleshooting metadata.yaml has >=1 references[] entry whose target begins with `cka-sim/packs/` (D-05 cross-pack guarantee).

**Status:** PASS.

```bash
for f in cka-sim/packs/troubleshooting/*/metadata.yaml; do grep -q 'target: cka-sim/packs/' "$f" || { echo "missing cross-pack ref: $f"; exit 1; }; done
```

### MH-4: `cka-sim drill troubleshooting` can run every question without error (manual live check — human-gated).

**Status:** HUMAN — see Human Verification Required section below.

### MH-5: Every trap ID referenced is registered in `cka-sim/traps/catalog.yaml` (catalog + lint-packs pass E).

**Status:** PASS.

```bash
bash cka-sim/scripts/lint-traps.sh
bash cka-sim/scripts/lint-packs.sh
```

### MH-6: lint-packs.sh pass G (forbidden-command guard, added in P01) exits 0 against the full troubleshooting pack.

The guard rejects service-manager calls, live kube-system CoreDNS edits, and writes to live Kubernetes config or kubelet data paths.

**Status:** PASS.

```bash
grep -q 'pass G' cka-sim/scripts/lint-packs.sh
bash cka-sim/scripts/lint-packs.sh cka-sim/packs/troubleshooting
```

### MH-7: All 4 previously-existing lints exit 0 on the post-P08 tree (lint-traps, lint-packs, lint-coverage, lint-deprecated-strings).

**Status:** PASS.

```bash
bash cka-sim/scripts/lint-traps.sh
bash cka-sim/scripts/lint-packs.sh
bash cka-sim/scripts/lint-coverage.sh
bash cka-sim/scripts/lint-deprecated-strings.sh
```

### MH-8: `bash cka-sim/scripts/test.sh` exits 0 (round-trip fixtures for all 6 questions).

**Status:** PASS.

```bash
bash cka-sim/scripts/test.sh
```

## Requirements Traceability

| REQ-ID | Description | Source plan IDs | Status |
|--------|-------------|-----------------|--------|
| PACK-05 | Troubleshooting pack covers CoreDNS, kubectl debug node, NetworkPolicy, broken kubelet, static pod, and service/endpoints mismatch. | 06-03 through 06-09 | SATISFIED |
| PACK-06 | Troubleshooting subset uses 6-file question contract and metadata schema. | 06-03 through 06-08 | SATISFIED |
| PACK-07 | All 5 packs have complete v1.35 Tracker coverage. | 06-09 | SATISFIED |

## Anti-Patterns Scan

lint-packs passes A-G cover grader read-only idioms, mutating-verb rejection, setup cleanup ownership, six-file shape and executable bits, trap registration, hardcoded node-name rejection, and troubleshooting host-safety forbidden commands. Pass G is explicitly present:

```bash
grep -q 'pass G' cka-sim/scripts/lint-packs.sh
```

The negative-fixture test case `lint_packs_forbidden_command.sh` is in the green suite.

## Behavioral Spot-Checks

| Question | FAIL fixture | PASS fixture | Expected behavior |
|----------|--------------|--------------|-------------------|
| Q01 | 2/3 | 3/3 | endpoints oracle + 2 resource existence; trap on FAIL |
| Q02 | 4/6 | 6/6 | 4 structural + 2 probes |
| Q03 | 5/6 | 6/6 | 5 structural + 1 DNS probe |
| Q04 | 0/1 | 1/1 | D-10 gated oracle; answer + debug-source evidence both required for PASS |
| Q05 | 1/4 | 4/4 | file exists + parse + kind + dry-run |
| Q06 | 1/3 | 3/3 | exists + source-parseable + endpoint correct |

## Human Verification Required

MH-4 requires the 6-drill loop on the 1+2 kubeadm cluster plus 4 host-safety post-checks. Each drill must show fail-with-trap before the reference solution, pass-with-ref-solution after it, and clean reset.

```bash
sha256sum /var/lib/kubelet/kubeadm-flags.env > /tmp/q06-baseline.sha
ls -la /etc/kubernetes/manifests/ > /tmp/q05-manifests-baseline.txt
kubectl -n kube-system get cm coredns -o yaml > /tmp/q03-coredns-baseline.yaml

for i in 01 02 03 04 05 06; do
  echo "=== Drill troubleshooting $i ==="
  cka-sim drill troubleshooting --question "$i" --grade-broken
  cka-sim drill troubleshooting --question "$i" --ref-solution
  cka-sim drill troubleshooting --question "$i" --grade
  cka-sim drill troubleshooting --question "$i" --reset
done
cka-sim drill troubleshooting
cka-sim drill troubleshooting

diff /tmp/q03-coredns-baseline.yaml <(kubectl -n kube-system get cm coredns -o yaml)
kubectl get pods --all-namespaces -l 'kubectl.kubernetes.io/debug-source'
diff /tmp/q05-manifests-baseline.txt <(ls -la /etc/kubernetes/manifests/)
sha256sum -c /tmp/q06-baseline.sha
```

Per-question attention notes:

- Q01: web-canary reaches ImagePullBackOff within 30s; grader records the trap; ref-solution deletes the canary.
- Q02: two-stage fix (label-drift + DNS-allow); nslookup + `/dev/tcp` probes both exit 0 post-fix.
- Q03: kube-system/coredns ConfigMap UNCHANGED after drill (baseline diff per VALIDATION.md).
- Q04: NO debug pods survive reset (`kubectl get pods -A -l kubectl.kubernetes.io/debug-source` returns empty).
- Q05: `/etc/kubernetes/manifests/` listing UNCHANGED before/after drill.
- Q06: `/var/lib/kubelet/kubeadm-flags.env` sha256 UNCHANGED before/after drill.

## Deferred Items

| Ref | Note |
|-----|------|
| WR-01 (Phase 4) | Full vendoring of CSI + metrics-server manifests under cka-sim/vendor/ with recorded SHA256. |
| IN-04 (Phase 4) | cka_sim::grade::assert_custom helper + 6-grader retrofit. |
| DF-08 | Hint reveal (drill mode only). |
| Phase 1 live UAT | Tracked in 01-HUMAN-UAT.md; reopen via `/gsd-verify-work 1`. |
| Phase 5 live UAT | Tracked in 05-VERIFICATION.md; reopen via `/gsd-verify-work 5`. |

## Gaps Summary

No blocking gaps. Phase 6 completes all 3 PACK requirements (PACK-05 + PACK-06 Troubleshooting subset + PACK-07 final 100% coverage). MH-4 is human-gated per standard CONTEXT contract.
