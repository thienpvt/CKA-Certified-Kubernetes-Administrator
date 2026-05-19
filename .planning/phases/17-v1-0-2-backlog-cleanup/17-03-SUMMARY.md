---
plan: 17-03
phase: 17-v1-0-2-backlog-cleanup
requirements: [BLG-03, BLG-04]
status: complete
date: 2026-05-19
---

# Plan 17-03 Summary — BLG-03 + BLG-04 YAML and harness fixes

## Outcome

Pattern C (BLG-03) closed by rewriting `cluster-architecture/08-priorityclass/expected-symptom.yaml` to drop the BUG-H04-broken `globalDefault: "false"` claim and rely on the open-world contract (presence-only check). Pattern D (BLG-04) closed by adding a between-passes `kubectl wait` pre-step to `cka_sim::symptom_diff::run_one`, gated on Deployment + `Available=True` claim.

Both fixes shipped together because the testing surface is shared (the lib).

## Files Modified (2) + Created (1)

| File | Change |
|------|--------|
| `cka-sim/packs/cluster-architecture/08-priorityclass/expected-symptom.yaml` | Rewritten: presence-only `expect: {}` for q08-critical and q08-batch; BUG-H04 rationale documented in header comment. |
| `cka-sim/lib/symptom-diff.sh` | Wait pre-step added inside `run_one` between YAML parse and First pass JSON capture. Gate: kind=deploy, jp matches `status.conditions[?(@.type=="Available")].status`, expected=True. 90s timeout, tolerated via `\|\| true`. |
| `cka-sim/tests/cases/symptom-diff-deploy-wait.sh` | NEW. 6 sub-tests: positive (deploy/Available/True), negative (Available=False, non-deploy kind, non-Available jp, Available=Unknown, R event). |

## BLG-03 — priorityclass YAML diff

```diff
 # cluster-architecture/08-priorityclass — symptom: q08-critical + q08-batch
-# both exist, both globalDefault=false.
+# both exist as PriorityClasses. Their globalDefault field is intentionally
+# unset (post-BUG-H04 setup); kubectl jsonpath returns <missing> not 'false'
+# for unset booleans, so we do not encode globalDefault here. Open-world
+# handles missing fields silently. The trap "candidate sets globalDefault=true"
+# is detected by grade.sh's PriorityClass parsing, not by symptom-diff.
 question: cluster-architecture-priorityclass
 resources:
   - kind: priorityclass
     name: q08-critical
-    expect:
-      globalDefault: "false"
+    expect: {}
   - kind: priorityclass
     name: q08-batch
-    expect:
-      globalDefault: "false"
+    expect: {}
```

**Rationale:** EXPECTED-SYMPTOM-SCHEMA.md documents `expect: {}` as a presence-only check. The open-world contract (only listed fields are diffed) means the unset `globalDefault` is silently accepted — the symptom is "both PriorityClasses exist", which is what the prose claims. The `globalDefault=true` candidate trap is detected by `grade.sh`, not by symptom-diff (different layer, different concern). No `absent_resources:` block was added because the schema's `absent_resources` requires a kind+name match (cannot express label/field selectors); adding label-selector support is out of scope and deferred to Phase 18 if needed.

storage/01-pvc-binding was verified current per CONTEXT D-07 — no edit.

## BLG-04 — wait gate placement + regex

**Placement:** Inside `cka_sim::symptom_diff::run_one`, immediately after the `parsed=...` here-string assignment and BEFORE the First pass JSON-capture loop. The wait runs once per matching E event before any kubectl-get fires.

**Gate:**
```bash
[[ "$w_tag" == "E" ]] || continue
[[ "$w_kind" == "deploy" ]] || continue
[[ "$w_jp" =~ ^(status|spec)\.conditions\[\?\(@\.type==\"Available\"\)\]\.status$ ]] || continue
[[ "$w_expected" == "True" ]] || continue
```

**Namespace lookup:** E events do not carry a namespace (only R events do). The wait pre-step looks up the matching R event's `$rns` field for the same kind+name pair. This correctly maps Deployment q-name → ns under both lint (`cka-sim-lint-…`) and audit (`cka-sim-audit-…`) prefix schemes.

**Timeout strategy:** `kubectl wait --timeout=90s … || true`. Failure to converge is tolerated — the subsequent kubectl-get captures the actual state regardless, and the diff layer reports the divergence as a meaningful FAIL. The wait simply gives Calico time to settle in the happy case.

**Negative-case carve-out:** `troubleshooting/03-coredns-resolution` claims `Available=False` (intentional broken-Corefile state). The `"$w_expected" == "True"` predicate skips it, so the audit doesn't burn 90s waiting for a deployment that's supposed to fail.

## Test Suite Delta

| Metric | Before | After |
|--------|--------|-------|
| Total cases | 87 | **88** |
| Passing | 87 | **88** |
| Failing | 0 | **0** |
| `bash cka-sim/scripts/test.sh` exit code | 0 | **0** |

All Phase 16 + Plans 17-01 + 17-02 + 17-04 cases continue to PASS. New deploy-wait case PASSes.

## Acceptance Criteria

| Check | Result |
|-------|--------|
| priorityclass YAML parses, no globalDefault claim, both names listed | ✓ Confirmed via grep + read |
| `kubectl wait deployment/$w_name` invocation present in lib | ✓ |
| Available=True gate predicate present | ✓ |
| BLG-04 tag in lib | ✓ in info line + comment |
| Lint exit 0 / audit exit 2 unchanged on no-cluster | ✓ Preflight gates fire before run_one |
| Test suite green | ✓ 88/88 pass |

## Live-Cluster Verification

Deferred to Phase 18 (forensic re-audit): the wait pre-step's actual 90s timeout behaviour against kind+Calico, and the priorityclass YAML's lint-mode pass under the substituted ns, both surface naturally when `cka-sim audit` runs end-to-end against a fresh cluster. This plan ships the unit-tested contract; Phase 18 closes the live-cluster loop.

## BLG-03 + BLG-04 Closed

All 4 Pattern C/D root causes have a code-side fix in this branch. The remaining BLG (BLG-06 shellcheck triage) is being handled out-of-band per Plan 17-05's explicit follow-up flow.
