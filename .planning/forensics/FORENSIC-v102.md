---
ledger: FORENSIC-v102
date: 2026-05-20
audit_run: kind v0.31.0 + Calico v3.27.3 cluster (cka-sim) — local Docker Desktop
audit_summary: 29/31 PASS, 1 FAIL, 1 errors, 3 skipped (BLG-02 unsupported-on-kind)
total_findings: 4
high_count: 2
med_count: 2
low_count: 0
status: open
raw_report: ./FORENSIC-v102-raw.md
---

# v1.0.2 Forensic Audit Ledger

Phase 18 forensic re-audit run on 2026-05-20 against a clean kind+Calico cluster (matching the GHA validate.yml recipe — kind v0.31.0 local, Calico v3.27.3, single control-plane + single worker, `disableDefaultCNI: true`, podSubnet `192.168.0.0/16`).

**Audit invocation:** `bash cka-sim/bin/cka-sim audit --report .planning/forensics/FORENSIC-v102-raw.md` after CRLF harness fix (see HARNESS-FIX section below).

## Executive Summary

| Metric | Value |
|--------|-------|
| Questions audited | 31 / 34 (3 BLG-02 skipped: cluster-architecture/02, storage/04, workloads-scheduling/06) |
| PASS | 29 |
| FAIL | 1 (cluster-architecture/04-pss-enforce) |
| ERROR | 1 (troubleshooting/05-static-pod-manifest setup.sh failed) |
| Findings classified | 4 (2 HIGH + 2 MED) |
| Pre-existing tech debt folded | 2 (Phase 17 carry-over) |

The audit found **far fewer bugs than v1.0.1's 15** — most of v1.0.2's expected-symptom drift was already closed in Phase 15-17. The remaining findings split between a real Linux-locale setup bug and harness/encoding edge cases.

## Bug Ledger

| ID | Question / Item | Bug Class | Severity | Symptom | Suggested Fix |
|----|-----------------|-----------|----------|---------|---------------|
| BUG-H07 | troubleshooting/05-static-pod-manifest | setup-drift | HIGH | `setup.sh` runs `grep -P '\t' "$sandbox/manifest-broken.yaml"` to assert the file contains a literal tab character. On Linux GHA runners with a non-UTF-8 locale, GNU grep refuses `-P`: `grep: -P supports only unibyte and UTF-8 locales` → setup.sh exits non-zero → audit reports ERROR. Local kind cluster reproduced this. | Replace `grep -P '\t'` with locale-independent shape — either set `LC_ALL=C.UTF-8` for the grep, or replace with `grep -F $'\t'` (no -P needed for a literal tab match). |
| BUG-H08 | cluster-architecture__05-audit-policy (unit suite) | grader-disagrees | HIGH | Unit-test red surfaced when GHA started running tests on Linux (P17 fix to tests/run.sh exec bit). Empty submission expects `SCORE: 0/1`, gets `SCORE: 0/4`. Fixture vs grader assertion-count drift, same class as v1.0.1 BUG-M10 / BLG-05. Routed from Phase 17 verification gaps_found. | Audit grade.sh assertion list against the case-file's authoritative `expected_empty_score=0/1`. Either reduce grader to 1 assertion, OR update fixture totals to match the grader's 4 assertions. Per CONTEXT D-15 the case-file is authoritative. |
| BUG-M11 | cluster-architecture/04-pss-enforce | harness-encoding (extends `grader-disagrees`) | MED | `_jsonpath_to_jq` in `cka-sim/lib/symptom-diff.sh` translates `metadata.labels.<key-with-dots>` correctly via the dotted-segment branch, but the resulting jq query against the namespace's labels emits a JSON-array string `[\n  "restricted"\n]` instead of a scalar `restricted` because the jq query path traverses an array intermediate. The label IS correctly applied (manual `kubectl get ns -o yaml` confirms `pod-security.kubernetes.io/enforce: restricted` as scalar). | Harness fix in `cka-sim/lib/symptom-diff.sh` — for `metadata.labels.X` paths, wrap the jq query so it returns the scalar value directly (`.metadata.labels."X" // ""`) without the `[]` array context. The current dotted-segment branch returns `.metadata.labels."pod-security.kubernetes.io/enforce"` which should already be scalar; the actual divergence may be a separate `\r` or unicode artifact in the captured JSON file. Investigate during Plan 20.x. |
| BUG-M12 | exam-mode `report_golden` test | report-rendering-drift (out-of-rubric) | MED | Exam-mode report rendering produces text differing from `tests/fixtures/exam/expected-report.md`. Surfaced on Linux GHA first-run. Not symptom-diff-detectable (exam-mode rendering, not per-question state). Routed from Phase 17 gaps_found. | Re-baseline the golden file by running exam-mode end-to-end, capturing the new output, comparing to the existing fixture line-by-line, and either updating the fixture (if the new output is correct) or fixing the renderer (if the fixture was authoritative). Pattern matches v1.0.1's BUG-M07 framing-fix shape. |

## Severity Distribution

- **HIGH (2):** BUG-H07 (setup.sh fails on Linux) + BUG-H08 (grader vs fixture drift). Both are correctness bugs that would actively mislead a candidate or break CI.
- **MED (2):** BUG-M11 (harness encoding edge case) + BUG-M12 (rendering drift). Both are visible to the candidate but don't change scoring/correctness.
- **LOW (0):** None this cycle.

## Root-Cause Class Distribution

- `setup-drift`: 1 (BUG-H07)
- `grader-disagrees`: 1 (BUG-H08)
- `harness-encoding` (extends grader-disagrees): 1 (BUG-M11)
- `report-rendering-drift` (out-of-rubric): 1 (BUG-M12)
- `question-prose-wrong`: 0
- `framing-mismatch`: 0 (mock-pack audit dropped per CONTEXT scope_reframe)

## Sub-Phase Generation Plan

Per CONTEXT D-15 / D-16, decimal sub-phases inserted post-Phase 18:

### Phase 19 (HIGH remediation)
- **Phase 19.1** — BUG-H07 close: locale-safe grep in troubleshooting/05-static-pod-manifest/setup.sh.
- **Phase 19.2** — BUG-H08 close: align cluster-architecture/05-audit-policy grader and fixture; same shape as v1.0.1 BLG-05 fixture-regen.

### Phase 20 (MED remediation)
- **Phase 20.1** — BUG-M11 close: investigate harness label-extraction in `cka-sim/lib/symptom-diff.sh`.
- **Phase 20.2** — BUG-M12 close: re-baseline report_golden fixture or fix exam-mode renderer.

(Sub-phase requirements `BUG-H07`, `BUG-H08`, `BUG-M11`, `BUG-M12` are this ledger's IDs; Phases 19.x and 20.x will declare them.)

## Harness Fix Captured This Phase

During the audit run, the audit harness was found to leak Windows MSYS `\r` carriage returns into namespace strings via the python-emitted parsed stream — `read -r` does not split on `\r`, so the trailing CR ended up in `$rns` and broke every kubectl get with `Error from server (NotFound): namespaces "cka-sim-audit-...\r" not found`. This produced 22 false-negative `<not-found>` failures in the first audit run.

**Fix:** Added `parsed="${parsed//$'\r'/}"` after the python parse pass in `cka_sim::symptom_diff::run_one` to strip carriage returns. Re-running the audit dropped failures from 22 to 1 (BUG-H07's real setup-drift bug remained).

This harness fix is **not** a forensic finding — it's a Phase 18 in-flight fix logged here for the audit-trail. Committed alongside this ledger.

## Pre-Existing Tech-Debt Folded

| Item | Source | Folded as |
|------|--------|-----------|
| Phase 17 unit-test red: cluster-architecture__05-audit-policy | 17-VERIFICATION.md gaps_found | BUG-H08 |
| Phase 17 unit-test red: report_golden | 17-VERIFICATION.md gaps_found | BUG-M12 |
| BLG-06 shellcheck/yamllint findings | Plan 17-05 follow-up | NOT folded — handled separately per Plan 17-05's documented flow (cka-sim/traps/catalog.yaml line-length + ShellCheck triage) |

## Audit Reproducibility

- **Cluster recipe:** `.github/workflows/validate.yml` symptom-diff job (lines 103-148).
- **Local cluster:** `kind create cluster --name cka-sim --config /tmp/kind-config.yaml --wait 120s` then `kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.3/manifests/calico.yaml` then wait for Available.
- **Audit invocation:** `export CKA_SIM_ROOT="$(pwd)/cka-sim"; bash cka-sim/bin/cka-sim audit --report .planning/forensics/FORENSIC-v102-raw.md`.
- **Required tools:** `python3` with `yaml` module (Windows MSYS may need a shim — see `.planning/phases/18-forensic-re-audit-blind/18-CONTEXT.md`), `jq`, `kubectl`.

## Closure Status

| ID | Status | Closed-by |
|----|--------|-----------|
| BUG-H07 | open | Phase 19.1 |
| BUG-H08 | open | Phase 19.2 |
| BUG-M11 | open | Phase 20.1 |
| BUG-M12 | open | Phase 20.2 |

This ledger updated by Phase 21 milestone close-out with `closed-by` commit references.
