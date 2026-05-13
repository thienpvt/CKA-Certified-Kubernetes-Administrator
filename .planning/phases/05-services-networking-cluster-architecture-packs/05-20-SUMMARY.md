---
phase: 05-services-networking-cluster-architecture-packs
plan: 20
status: complete
completed: 2026-05-13
gap_closure: true
gaps_closed: [4]
subsystem: cka-sim/packs/cluster-architecture/04-pss-enforce
tags: [cluster-architecture, pss, pod-security, gap-closure, traps]
requirements: [PACK-04, PACK-06, PACK-07, CI-02]
dependency_graph:
  requires:
    - cka-sim/lib/traps.sh (detect_pss_error_string_mismatch + detect_psp_fictional_pod_label_exemption)
    - cka-sim/lib/grade.sh (assert_* helpers + record_trap + emit_result)
    - cka-sim/lib/setup.sh (ensure_lab_ns + wait_for_ns_active)
  provides:
    - Q04 pss-enforce round-trip that reaches 5/5 rc=0 post-ref-solution
    - Detector-routed trap firing against candidate submission
    - Setup-owned admission-log evidence (no ref-solution clobber)
  affects:
    - UAT test 11 (cluster-architecture Q04 broken + ref-solution grade)
key_files:
  created: []
  modified:
    - cka-sim/packs/cluster-architecture/04-pss-enforce/setup.sh
    - cka-sim/packs/cluster-architecture/04-pss-enforce/grade.sh
    - cka-sim/packs/cluster-architecture/04-pss-enforce/ref-solution.sh
    - cka-sim/packs/cluster-architecture/04-pss-enforce/question.md
decisions:
  - Bare Pod admission capture (not Deployment dry-run) so apiserver emits canonical `violates PodSecurity "restricted:v1.35":` wording
  - Introduce candidate-violator.yaml as the single candidate-submission artifact; grader runs detectors against its raw text
  - grade.sh sources lib/traps.sh explicitly and routes both declared traps through registered detectors (single source of truth)
  - Admission-log regex broadened to accept both `violates` and `would violate` for defence-in-depth
  - Ref-solution writes ONLY candidate-violator.yaml; admission log and reference Pod are setup-owned evidence
  - Drop ref-solution's admission-config.yaml artifact (never applied, never inspected)
metrics:
  duration_minutes: ~25
  tasks_completed: 5
  commits: 4
  files_modified: 4
---

# Phase 5 Plan 20: Close UAT Gap 4 (CA Q04 pss-enforce) Summary

Rebuilt the cluster-architecture Q04 pss-enforce round-trip so every declared
trap is reachable and the live grade reaches 5/5 rc=0 after ref-solution. Four
design bugs compounded in the pre-plan state: admission captured from a
Deployment (wrong wording), compliant Deployment never waited, graders greped
the wrong data sources for traps, and ref-solution clobbered setup-owned
evidence. Each is now fixed in its owning file.

## Redesign Rationale

**Admission capture owner.** Setup now owns `violator-admission.log` and
writes it exactly once via a bare Pod (`apiVersion: v1, kind: Pod`)
submitted to the restricted namespace with `apply --dry-run=server`. The
Pod shape guarantees the documented `pods "q04-ref-violator" is
forbidden: violates PodSecurity "restricted:v1.35":` wording that
grade.sh's regex matches. Ref-solution no longer touches the log.

**Readiness wait.** Setup applies the q04-compliant Deployment and then
`kubectl wait --for=condition=Available deployment/q04-compliant
--timeout=120s` (trailing `|| true` so a slow cluster does not abort
setup). Grade.sh keeps a 30s defence-in-depth wait at the top for the
reset→setup→grade quick-loop case.

**Candidate submission path.** Setup seeds
`$sandbox/candidate-violator.yaml` with a broken stub containing both
trap triggers: a `# ...PodSecurityPolicy...` comment (deprecated-strings
lint comment carveout permits it; `detect_pss_error_string_mismatch`
fires on raw text) and a pod-level `pod-security.kubernetes.io/exempt:
"true"` label (matches `detect_psp_fictional_pod_label_exemption`'s
regex). Question.md now directs the candidate at this file.

**Detector-routed traps.** Grade.sh sources `lib/traps.sh` explicitly and
calls both registered detectors against the candidate file's raw text.
The pre-plan inline greps (legacy PSP literal against the admission log;
exempt-label pattern against `$sandbox/*.yaml` files) are gone — they
both targeted the wrong data sources. Admission regex broadens to
`(would violate|violates) PodSecurity "..."` so Deployment-Warning
wording is also accepted defensively.

**Ref-solution scope.** Ref-solution now writes ONLY a compliant Pod
manifest to `$sandbox/candidate-violator.yaml`. It does not touch the
admission log, does not re-apply the Deployment, does not re-label the
namespace, and does not write admission-config.yaml (that dead file is
dropped). Compliant Pod contains neither trigger string; both detectors
return empty and no traps fire on the ref path.

## Task-by-Task Commit Map

| Task | File | Type | Commit | What changed |
|------|------|------|--------|--------------|
| 1 | cka-sim/packs/cluster-architecture/04-pss-enforce/setup.sh | fix | `5d945de` | Bare Pod admission capture, Deployment wait, candidate-violator.yaml seed |
| 2 | cka-sim/packs/cluster-architecture/04-pss-enforce/grade.sh | fix | `1d0f8a9` | Source lib/traps.sh, detector-routed traps, broadened admission regex, drop inline greps |
| 3 | cka-sim/packs/cluster-architecture/04-pss-enforce/ref-solution.sh | fix | `17f8942` | Compliant candidate YAML only; stop clobbering setup-owned evidence; drop admission-config.yaml |
| 4 | cka-sim/packs/cluster-architecture/04-pss-enforce/question.md | docs | `1eb6ed7` | Point candidate at candidate-violator.yaml; spell out restricted-profile requirements; Verify section |
| 5 | (verification only — lints + test.sh) | — | — | No file changes |

## Verification Log

All five gates green on Windows bash (`C:\Program Files\Git\usr\bin\bash.exe`):

| Gate | Result |
|------|--------|
| `bash cka-sim/scripts/test.sh` | rc=0, 32 unit cases pass |
| `bash cka-sim/scripts/lint-packs.sh` | rc=0, 203 checks pass |
| `bash cka-sim/scripts/lint-coverage.sh` | rc=0, 4 packs OK |
| `bash cka-sim/scripts/lint-traps.sh` | rc=0, 36 catalog entries OK |
| `bash cka-sim/scripts/lint-deprecated-strings.sh` | rc=0, 940 file-pattern checks |

Deprecated-strings lint accepts the `PodSecurityPolicy` literal embedded in
setup.sh's candidate-stub heredoc (comment carveout — the literal appears
only inside a line whose first non-whitespace character is `#`). No hits in
grade.sh, ref-solution.sh, or question.md.

## Live Round-Trip Status

Deferred to UAT re-run on the live 1+2 kubeadm v1.35 cluster. Expected trace:

1. `cka-sim drill cluster-architecture --question 04 --grade-broken` →
   rc!=0. Assertions 1, 2, 3, 4, 5 pass (admission wording matches; deployment
   waited so readyReplicas positive). Both traps `pss-error-string-mismatch`
   and `psp-fictional-pod-label-exemption` recorded from the seeded candidate
   stub.
2. `cka-sim drill cluster-architecture --question 04 --ref-solution` →
   overwrites `candidate-violator.yaml` with a compliant Pod. No triggers.
3. `cka-sim drill cluster-architecture --question 04 --grade` → 5/5 rc=0
   with no traps.
4. `cka-sim drill cluster-architecture --question 04 --reset` → namespace
   deleted, `$sandbox` wiped via sentinel-guarded cleanup (reset.sh
   unchanged).

Note on broken-state semantics: the stub is deliberately "broken" from a
trap-detection perspective, not a PSS-admission perspective. A candidate who
writes a compliant Pod shape but leaves the `PodSecurityPolicy` comment
intact still trips `pss-error-string-mismatch` — intended; the trap exists to
catch legacy wording anywhere in the candidate artifact.

## Deviations from Plan

None. Plan executed exactly as written after two minor phrasings inside
ref-solution.sh comments — the plan's verify grep is a whole-file match, so
the comments originally containing `q04-compliant` and
`pod-security.kubernetes.io/exempt` as prose had to be rephrased to pass
the negative assertions. No behaviour change.

## Files Not Touched (per plan)

- `cka-sim/packs/cluster-architecture/04-pss-enforce/reset.sh`
- `cka-sim/packs/cluster-architecture/04-pss-enforce/metadata.yaml`
- `cka-sim/packs/cluster-architecture/04-pss-enforce/manifest.yaml`
- `cka-sim/packs/cluster-architecture/04-pss-enforce/coverage.yaml`
- `cka-sim/packs/cluster-architecture/04-pss-enforce/README.md`
- `.planning/STATE.md`, `.planning/ROADMAP.md` (orchestrator-owned)

Metadata trap list remains honest — both declared traps are now reachable
via the detector calls in grade.sh.

## Self-Check: PASSED

- `setup.sh` parses (bash -n clean); contains `ref-violator-pod.yaml`,
  `candidate-violator.yaml`, `kubectl wait --for=condition=Available
  deployment/q04-compliant`; `name: q04-violator` Deployment identifier
  absent.
- `grade.sh` parses; sources `lib/traps.sh`; calls both detectors; no
  `PodSecurityPolicy` literal; no banned `kubectl get | grep`; no mutating
  verbs; admission regex accepts both wordings.
- `ref-solution.sh` parses; writes ONLY `candidate-violator.yaml`; does not
  touch admission log or reference Pod; `runAsNonRoot: true` present; no
  `admission-config.yaml` output.
- `question.md` mentions `candidate-violator.yaml` 4 times (≥2 required);
  preserves `# Pod Security Standards Enforcement` heading; no reference to
  removed `/tmp/q04-pss-enforce/violator.yaml`; carries exempt-label
  warning.
- All four task commits present in `git log` (`5d945de`, `1d0f8a9`,
  `17f8942`, `1eb6ed7`).
- All 5 gates green (rc=0).
