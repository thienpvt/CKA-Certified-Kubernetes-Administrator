# Phase 17: v1.0.2 Backlog Cleanup - Context

**Gathered:** 2026-05-19
**Status:** Ready for planning
**Mode:** Pre-traced — STATE.md `v1.0.2 Backlog` section + GHA run 26070172071 head_sha af493ce supply concrete findings; this CONTEXT.md captures the locked fix decisions per pattern.

<domain>
## Phase Boundary

Close every Phase 15 GHA `symptom-diff` first-run failure pattern (A through D), the 2 pre-existing unit-suite reds, and the CI shellcheck red. Six requirements, six fixes, no new features. Pre-traced via STATE.md (v1.0.2 Backlog section) and GHA run 26070172071 against kind+Calico (head_sha af493ce).

This phase does NOT regenerate every expected-symptom.yaml from prose (that's Phase 18's manual prose-fidelity audit), does NOT introduce new questions, and does NOT modify the candidate-state baseline contract.
</domain>

<decisions>
## Implementation Decisions

### Pattern A — `${CKA_SIM_LAB_NS}` placeholder unsubstituted in resource `name` (BLG-01)

- **D-01:** Root cause: the python parser embedded in `cka-sim/lib/symptom-diff.sh` (extracted Phase 16 from `lint-question-symptom.sh:124-150`) substitutes `${CKA_SIM_LAB_NS}` in `namespace` fields and `expect` values, but NOT in resource `name`. When a YAML uses `name: ${CKA_SIM_LAB_NS}` (e.g. `cluster-architecture/04-pss-enforce` inspecting the lab namespace itself), kubectl looks for a resource literally named `${CKA_SIM_LAB_NS}` and fails.
- **D-02:** Fix: extend the python parser's `sub()` call to also substitute on `name`. One-line change in `cka-sim/lib/symptom-diff.sh` `cka_sim::symptom_diff::run_one` python heredoc — `print('R', kind, sub(name), ...)` and similarly for the `E` and `A` event types.
- **D-03:** Affected questions per GHA run 26070172071: 12 expected-symptom.yaml files known to use `name: ${CKA_SIM_LAB_NS}` or similar substitution-in-name (cluster-architecture/{03,04,05,06,07}, services-networking/05, troubleshooting/{04,05,06}, workloads-scheduling/05, plus two more identified by `grep`). Concrete fix is in the lib, not the YAMLs — the YAMLs are correct as authored.

### Pattern B — `setup.sh` fails on kind for 3 questions (BLG-02)

- **D-04:** Root cause: `setup.sh` for `cluster-architecture/02-etcd-backup-restore` (needs etcd snapshot CLI on the CP node), `storage/04-csi-volumesnapshot` (needs a CSI driver supporting VolumeSnapshots), and `workloads-scheduling/06-static-pod` (writes a manifest into `/etc/kubernetes/manifests/`) cannot complete on a kind+Calico cluster — these depend on host-level access patterns that kind containers don't provide.
- **D-05:** Fix shape: ship an `unsupported-on-kind: true` directive in the per-question `metadata.yaml` and skip those questions in both `lint-question-symptom.sh` and `cka-sim audit` driver loops. Lint-mode skips with a yellow warn (still rc=0); audit-mode skips with a yellow info line in the per-question output.
- **D-06:** The 3 affected questions remain VALID for live-cluster drill UAT against the lab cluster (Phase 21 batch); they are excluded only from the kind-based lint/audit harness.

### Pattern C — Phase 10 collateral expected-symptom drift (BLG-03)

- **D-07:** Root cause:
  - `storage/01-pvc-binding`: BUG-H01's setup reshape changed which resource holds the symptom (PV stays Available + PVC stays Pending instead of Pod-not-scheduling), but the YAML was already updated when v1.0.1 shipped — Plan 16-01's regression test confirmed it is current. **No-op for BLG-03 part 1.**
  - `cluster-architecture/08-priorityclass`: BUG-H04 fix changed the kubectl jsonpath behaviour for unset booleans — `globalDefault` returns `<missing>` (not `'false'`) when the field is unset on a PriorityClass. Current YAML claims `globalDefault: "false"`; lint will fail.
- **D-08:** Fix: rewrite `cluster-architecture/08-priorityclass/expected-symptom.yaml` `expect:` block to drop `globalDefault: "false"` (open-world handles unset fields silently) and instead claim a positive presence-only check (`expect: {}`) plus an `absent_resources:` entry asserting no PriorityClass with `globalDefault: true` exists in the cluster (the trap is "candidate accidentally sets globalDefault=true on q08-critical or q08-batch"). This matches the BUG-H04 jsonpath behaviour without re-encoding the bug.
- **D-09:** No other files touched for Pattern C — `storage/01-pvc-binding` was already updated.

### Pattern D — Calico-on-kind Deployment-Available timeout (BLG-04)

- **D-10:** Root cause: 3 questions (`troubleshooting/02-netpol-dns-egress`, `workloads-scheduling/01-deployment-requests`, `workloads-scheduling/07-native-sidecar`) claim `status.conditions[?(@.type=="Available")].status: "True"` for a Deployment in their YAML. On kind+Calico, the Calico BIRD pod takes ~60-90s to settle after Pod-network workloads start; the lint harness's per-question setup→capture cycle reaches the kubectl-get step before Calico marks the Deployment endpoints Ready, so `Available=False` is captured.
- **D-11:** Fix: extend `cka_sim::symptom_diff::run_one` (in `cka-sim/lib/symptom-diff.sh`) with an optional pre-capture `kubectl wait` step. Implementation: between the YAML parse pass and the first JSON-capture pass, for any expected resource of kind=`deploy` whose `expect:` block claims `status.conditions[?(@.type=="Available")].status: "True"`, run `kubectl wait deployment/<name> -n <ns> --for=condition=Available --timeout=90s` and tolerate timeout (still capture afterwards — failure to converge is itself a meaningful diff result). Both lint and audit benefit; no per-question YAML change.
- **D-12:** No `expected-symptom.yaml` content changes for the 3 affected questions — the claim is correct; the harness needed to wait for Calico convergence.

### BLG-05 — 2 unit-suite reds

- **D-13:** Root cause:
  - `storage__02-storageclass-dynamic`: ref-solution test expects `SCORE: 1/1`, gets `SCORE: 0/1`. Note 6: 07.1-04 was supposed to update fixtures via `--regen` when the grader was rewritten to `assert_resource_candidate_authored`. The v1.0.1 fixture totals stayed at 0/1 vs 1/1 (case header) but the post-ref-solution baseline.json is missing the candidate-authored marker the assert_resource_candidate_authored helper looks for, so the ref-solution scores 0 instead of 1.
  - `workloads-scheduling__05-daemonset`: ref-solution expects `SCORE: 4/4`, gets `SCORE: 3/4`. Identical class — fixture missed an Assertion when 07.1's grader rewrites landed.
- **D-14:** Fix: regenerate the post-ref-solution baseline.json fixtures for both questions so they capture the post-Phase-07.1 grader contract. Use the existing `--regen` flow if available (per case-file note 6); otherwise manually update the fixture files under `cka-sim/tests/fixtures/grading-honesty/<id>/post-ref-solution/baseline.json`.
- **D-15:** If a fixture regen does not close BLG-05 (i.e. the bug is in the grader, not the fixture), audit the grader's assertion list against `metadata.yaml`'s claimed total — fix whichever side drifted. The case-file `expected_ref_score` is authoritative; either the grader needs to reach that score or the fixture/grader needs alignment.

### BLG-06 — CI shellcheck job red

- **D-16:** Root cause: first-run shellcheck against the cka-sim corpus on Linux. Possible findings: SC2155 (declare-and-assign masks return value), SC2086 (word-splitting on unquoted vars), SC2128 (expanding array as string), SC1090/SC1091 (sourcing dynamic paths). Existing files have `# shellcheck disable=` directives for the known SC1091 source-path warnings; new findings are likely SC2155/SC2086/SC2128 in graders or library helpers.
- **D-17:** Fix: run `bash cka-sim/scripts/validate-local.sh` locally (skip the yamllint pass if yamllint isn't installed, but ensure shellcheck is). Triage each finding: fix in code if it's a real bug; add an inline `# shellcheck disable=<code>` directive with a one-line justification if the lint is over-strict for the project's style. Do NOT relax the lint config wholesale — keep per-finding accountability.
- **D-18:** Acceptance: GHA `validate-local.sh` shellcheck pass exits 0 on Linux. (yamllint pass orthogonal to BLG-06 — already green per Phase 15 ship.)

### Plan boundaries

- **D-19:** Phase 17 splits into 5 plans: `17-01` (BLG-01 lib fix), `17-02` (BLG-02 unsupported-on-kind), `17-03` (BLG-03 + BLG-04 YAML and harness fixes), `17-04` (BLG-05 fixture regen), `17-05` (BLG-06 shellcheck). All plans are single-wave because they touch disjoint files; planner may choose to keep them sequential for review clarity or run as one wave.

### Claude's Discretion

- Per-finding shellcheck disable codes (BLG-06) — pick the narrowest disable that covers the legitimate finding.
- Whether to use `--regen` (if it exists) or manual fixture update for BLG-05 — pick whichever is faster and produces auditable diffs.
- Whether `cluster-architecture/08-priorityclass` adds an `absent_resources:` block (D-08 recommendation) or simply drops the `globalDefault` line (open-world fallback). Both pass lint; the absent_resources variant is more expressive.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 15 artifacts under audit
- `cka-sim/scripts/lint-question-symptom.sh` — refactored Phase 16 to source `lib/symptom-diff.sh`. Patterns A and D fixes land in the lib; the lint script is unchanged.
- `cka-sim/lib/symptom-diff.sh` (Phase 16) — Pattern A fix (D-02) extends the python parser; Pattern D fix (D-11) adds the kubectl-wait pre-step.
- `cka-sim/packs/EXPECTED-SYMPTOM-SCHEMA.md` — schema reference; no edits.

### Pattern A affected files (12 of 12 confirmed via grep)
- `cka-sim/packs/cluster-architecture/{03,04,05,06,07}/expected-symptom.yaml`
- `cka-sim/packs/services-networking/05-kube-proxy-mode/expected-symptom.yaml`
- `cka-sim/packs/troubleshooting/{04,05,06}/expected-symptom.yaml`
- `cka-sim/packs/workloads-scheduling/05-daemonset/expected-symptom.yaml`
- (No edits — fix is in the lib)

### Pattern B affected files
- `cka-sim/packs/cluster-architecture/02-etcd-backup-restore/metadata.yaml`
- `cka-sim/packs/storage/04-csi-volumesnapshot/metadata.yaml`
- `cka-sim/packs/workloads-scheduling/06-static-pod/metadata.yaml`
- `cka-sim/lib/symptom-diff.sh` (skip honoring `unsupported-on-kind`)
- `cka-sim/scripts/lint-question-symptom.sh` (driver loop reads metadata.yaml)
- `cka-sim/lib/cmd/audit.sh` (audit driver also honors flag)

### Pattern C affected files
- `cka-sim/packs/cluster-architecture/08-priorityclass/expected-symptom.yaml` (D-08 rewrite)
- `cka-sim/packs/storage/01-pvc-binding/expected-symptom.yaml` (D-07 — already current; spot-verify only)

### Pattern D affected files
- `cka-sim/lib/symptom-diff.sh` (D-11 kubectl-wait pre-step)
- (No expected-symptom.yaml content changes for the 3 affected questions)

### BLG-05 affected files
- `cka-sim/tests/fixtures/grading-honesty/storage__02-storageclass-dynamic/post-ref-solution/baseline.json`
- `cka-sim/tests/fixtures/grading-honesty/workloads-scheduling__05-daemonset/post-ref-solution/baseline.json`
- `cka-sim/packs/storage/02-storageclass-dynamic/grade.sh` (verify alignment)
- `cka-sim/packs/workloads-scheduling/05-daemonset/grade.sh` (verify alignment)
- `cka-sim/tests/grading-honesty/storage__02-storageclass-dynamic.sh` (do not modify expected scores; they are authoritative)
- `cka-sim/tests/grading-honesty/workloads-scheduling__05-daemonset.sh` (do not modify)

### BLG-06 affected files
- `cka-sim/scripts/validate-local.sh` (the CI shellcheck driver)
- Any cka-sim/**/*.sh file flagged by shellcheck (triaged per finding)

### v1.0.2 milestone-level
- `.planning/STATE.md` — v1.0.2 Backlog section is the authoritative pre-trace
- `.planning/REQUIREMENTS.md` — BLG-01..06 definitions
- `.planning/ROADMAP.md` — Phase 17 success criteria
- GHA run reference: `26070172071`, head_sha `af493ce`
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`cka-sim/lib/symptom-diff.sh` (Phase 16)** — single point of fix for Patterns A and D. The python heredoc (lines ~120-150) needs the `sub()` extension for D-02; the JSON-capture pass (lines ~155-180) gets the kubectl-wait pre-step for D-11.
- **`cka-sim/scripts/lint-question-symptom.sh`** — driver loop for lint mode. Skips honoring `unsupported-on-kind: true` from metadata.yaml are added in this driver and the audit driver.
- **`cka-sim/lib/cmd/audit.sh` (Phase 16)** — audit-mode driver. Mirror lint's metadata.yaml skip logic.
- **`cka-sim/tests/fixtures/grading-honesty/*/post-ref-solution/baseline.json`** — Phase 07.1 grading-honesty fixtures. BLG-05 regen target.
- **`cka-sim/scripts/validate-local.sh`** — shellcheck + yamllint driver invoked by GHA.

### Established Patterns

- **Per-question `metadata.yaml`** is already a thing (every pack has one). Adding an `unsupported-on-kind: true` field is additive; no schema migration needed (existing graders ignore unknown keys).
- **`# shellcheck disable=` inline directives** are the project's idiom (see `cka-sim/scripts/lint-question-symptom.sh` headers). Do not relax `validate-local.sh`'s rule set; per-finding inline disables are the right shape.
- **Fixture regen via `--regen`** — the Phase 07.1 case-file note (storage__02-storageclass-dynamic.sh:7) references this. Locate the regen entry point or update fixtures by hand.

### Integration Points

- **`metadata.yaml` parser** — both lint and audit drivers will need to read `unsupported-on-kind` from per-question metadata.yaml. Use the existing pure-bash YAML walker pattern from `cka-sim/lib/cmd/drill.sh:_parse_manifest` if applicable, or a minimal grep-based check (`grep -qE '^unsupported-on-kind:[[:space:]]*true' "$q_dir/metadata.yaml"`).
- **`kubectl wait`** for Pattern D — already on PATH in lint-mode preflight (kubectl is required; jq/python3/yaml are required). No new dependency.
</code_context>

<specifics>
## Specific Ideas

- The Pattern A finding is the cleanest example of why Phase 16 was right to extract `lib/symptom-diff.sh` — one fix in the lib lands the same correction for both lint and audit modes simultaneously. The original pre-Phase-16 design would have required two parallel edits in two scripts.
- Pattern D's kubectl-wait pre-step is gated on Deployment + `Available=True` claim, not unconditional, so questions that intentionally claim `Available=False` (e.g. troubleshooting/03-coredns-resolution which encodes the broken-Corefile state) are not slowed down.
- BLG-05's two reds are pre-existing v1.0.1 carry-forward; the test cases assert authoritative scores, so the fix is fixture-side or grader-side, never test-case-side.
- BLG-06 shellcheck running on Linux first-time means there will be findings that never surfaced on Windows (where `validate-local.sh` was skipped pre-CI). Expect 5-30 findings; most will be SC2086 / SC2155 patterns fixable inline.
</specifics>

<deferred>
## Deferred Ideas

- **Live-cluster end-to-end retry of GHA run 26070172071** — Phase 18's forensic re-audit re-runs `cka-sim audit` against kind+Calico, naturally re-exercising the Phase 17 fixes against the same environment that surfaced the original failures.
- **Cluster-architecture/02 / storage/04 / workloads-scheduling/06 kind-specific setup variants** — Pattern B's "ship `unsupported-on-kind: true`" is the cheaper fix; kind-variant setup.sh authoring is deferred to v1.0.3+ if needed.
- **shellcheck per-rule waiver documentation** — if BLG-06 produces a large number of inline disables, add a `cka-sim/SHELLCHECK-CONVENTIONS.md` doc summarizing project-style disables. Defer until the BLG-06 fix is in hand and the count is known.
</deferred>

---

*Phase: 17-v1-0-2-backlog-cleanup*
*Context gathered: 2026-05-19 (pre-traced from STATE.md v1.0.2 Backlog + GHA run 26070172071)*
