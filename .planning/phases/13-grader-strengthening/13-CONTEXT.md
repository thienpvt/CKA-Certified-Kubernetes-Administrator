# Phase 13: Grader-Strengthening — Context

**Gathered:** 2026-05-17
**Status:** Ready for planning
**Mode:** Interactive discuss (autonomous --interactive)

<domain>
## Phase Boundary

Strengthen 3 MED-severity graders that currently rubber-stamp structural shape so they enforce the precise values the question demands. Each fix tightens an existing grader's scoring assertions; question.md text is unchanged.

**In scope:**
- `services-networking/06-netpol-endport` (BUG-M04 — CNI-enforcement gate + over-permissive-NP detection)
- `cluster-architecture/05-audit-policy` (BUG-M05 — per-resource level mapping + omitStages)
- `workloads-scheduling/04-hpa-metrics-server` (BUG-M06 — averageUtilization=50, target.type=Utilization)

**Out of scope:**
- Question framing changes (Phase 14 covers BUG-M07..M09 + LIB-01)
- Trap-coverage lint (Phase 12)
- HIGH-severity graders (Phases 10-11)
</domain>

<canonical_refs>
## Canonical References

- `.planning/forensics/report-20260517-091657-full-audit.md` — DRIFT-MED detail for `services-networking/06-netpol-endport`, `cluster-architecture/05-audit-policy`, `workloads-scheduling/04-hpa-metrics-server`
- `.planning/REQUIREMENTS.md` — BUG-M04, BUG-M05, BUG-M06
- `.planning/ROADMAP.md` — Phase 13 success criteria (4 numbered items)
- `cka-sim/lib/grade.sh` — assertion helpers (`assert_field_eq`, `assert_resource_candidate_authored`, score counters)
- `cka-sim/lib/baseline.sh` / `cka-sim/lib/traps.sh` — existing helpers
- Per-question files for the 3 questions in scope (question.md, setup.sh, grade.sh, ref-solution.sh, metadata.yaml)

No external docs/ADRs cited.
</canonical_refs>

<decisions>
## Implementation Decisions

### BUG-M04 services-networking/06-netpol-endport — Setup-time CNI gate + over-permissive-NP detection

**Root cause:**
- Current grader's "wget to :8095 fails" assertion proves only that the server doesn't listen on 8095 (the q06-server Pod binds 8080-8090 only). An over-permissive NP that allows 8080-8095 still passes.
- No CNI-enforcement gate: on a non-enforcing CNI (e.g., flannel without NetworkPolicy plugin), even the candidate's correct NP doesn't block traffic — but the grader's reachability assertions still try to prove deny via wget.

**Fix path:**

1. **Setup-time CNI probe** — extend `setup.sh` to detect whether the lab cluster's CNI enforces NetworkPolicy:
   - Apply a temporary deny-all NP scoped to a probe pair (or to existing q06-server with a specific label) before the question's main NPs land.
   - From a probe client (or q06-client), wget to a port the deny-NP should block.
   - If the wget succeeds → CNI does NOT enforce → write sentinel `/tmp/q06-netpol-endport/.cni-enforces=false`.
   - If wget fails → CNI enforces → write sentinel `.cni-enforces=true`.
   - Clean up the temporary deny-all NP before main setup proceeds.
   - Idempotent and safely re-runnable.

2. **Grader strengthening:**
   - Read sentinel `/tmp/q06-netpol-endport/.cni-enforces`.
   - **If CNI does not enforce:** Skip reachability assertions (current 8085-allowed and 8095-blocked checks). Score only NP authoring (existence + port=8080 + endPort=8090 + protocol=TCP). Emit a clear "CNI non-enforcing — reachability not gradable" message. This honestly limits what the grader can prove.
   - **If CNI enforces:** Run a stronger reachability probe matrix:
     - 8085 reachable (in-range, allowed)
     - 8090 reachable (boundary, in-range)
     - 8080 reachable (boundary, in-range)
     - **NEW:** 8079 NOT reachable (one below range — needs server to listen there OR alternate path)
     - 8095 NOT reachable (out of range — keeps current check, but only validates NP enforcement when CNI enforces)
   - For "over-permissive NP fails" (success criterion 1 from ROADMAP): add a per-port spec assertion that `endPort` is exactly `8090` and `port` is exactly `8080` — anything wider fails the field-eq check, before any reachability test runs. This is the structural over-permissive guard.

3. **Setup support for boundary check (optional):** if listing q06-server on 8079 is desirable (so the grader can prove "blocked by NP" not "blocked by absence of listener"), add an extra container or extend the loop to include 8079 + 8091. This is the most rigorous fix and aligns with success criterion 1's "over-permissive NP fails" intent. Planner decides if this is in-scope or if structural endPort=8090 + port=8080 assertion alone is sufficient.

4. Trap entries (`netpol-endport-missing-protocol`) stay; no new traps.

**Score budget:** Adjust to keep max points stable while accommodating the CNI-enforcing/non-enforcing branches. Empty submission still scores 0.

### BUG-M05 cluster-architecture/05-audit-policy — Per-resource level mapping + omitStages

**Root cause:** `grade.sh:31-52` validates only structural shape: `apiVersion`, `kind`, `rules` non-empty, every `rules[].level in allowed_levels`, `omitStages[] in allowed_stages`. Does NOT enforce: Secrets→Metadata, ConfigMaps→Request, Events→None, presence of `RequestReceived` in omitStages.

**Fix path:**

1. Replace the single "audit policy structure valid" assertion (currently weight=1) with 4 weight=1 scoring assertions:
   - **Assertion A:** Some rule has `level: Metadata` AND its `resources[].resources` contains `secrets` (and `apiGroups: [""]` if specified). The rule must NOT be a catch-all that also captures other resources at Metadata level — so check the rule's resources list specifically includes secrets.
   - **Assertion B:** Some rule has `level: Request` AND covers `configmaps`.
   - **Assertion C:** Some rule has `level: None` AND covers `events`.
   - **Assertion D:** `omitStages` contains `RequestReceived`.

2. Keep weight=0 informational checks (file exists, has at least one rule).

3. Implementation: extend the existing python yaml block (or add a second python invocation) to iterate `rules[]` and confirm each mapping. Use sets for resource lists to handle ordering.

4. Trap detector `audit-policy-wrong-stage-verbosity` stays; no new traps.

5. Test cases (manual UAT in execute):
   - Empty submission → 0/4 scoring assertions.
   - Setup's stub → 0/4 (no levels assigned).
   - Ref-solution's correct policy → 4/4.
   - Synthetic regression: flip Secrets→Request → 3/4 (Assertion A fails).

**Score budget:** scoring assertions go from 1 → 4. Total max increases. ROADMAP success criterion 4 ("ref-solutions still score max/max") preserved by writing a complete ref-solution.

### BUG-M06 workloads-scheduling/04-hpa-metrics-server — averageUtilization=50, target.type=Utilization

**Root cause:** `grade.sh:32-33` Assertion 4 validates only `spec.metrics[?(@.type=="Resource")].resource.name == cpu`. Does NOT enforce `target.type == Utilization` or `target.averageUtilization == 50`. A candidate-submitted HPA with `averageUtilization: 80` (or `target.type: AverageValue`) passes.

**Fix path:**

1. Add 2 weight=1 scoring assertions immediately after the current Assertion 4:
   - **Assertion 5:** `spec.metrics[?(@.type=="Resource")].resource.target.type == "Utilization"`
   - **Assertion 6:** `spec.metrics[?(@.type=="Resource")].resource.target.averageUtilization == "50"`

2. Renumber the existing "behavioural — kubectl top pod" assertion (current Assertion 5) to Assertion 7. Keep its retry/sleep logic.

3. Use existing `cka_sim::grade::assert_field_eq` helper with the same jsonpath filter pattern as Assertion 4.

4. Test cases:
   - Candidate-submitted HPA with `averageUtilization: 80` → fails Assertion 6.
   - Ref-solution's HPA → all assertions pass.

**Score budget:** scoring assertions go from 5 → 7. Total max increases. Empty submission still scores 0 (HPA missing → assert_resource_candidate_authored fails everything).
</decisions>

<code_context>
## Existing Code Insights

**Grader patterns:**
- All 3 graders use `assert_field_eq <kind> <name> <jsonpath> <value> [-n <ns>]` for value-precise checks. Pattern is established and reusable.
- Audit-policy grader uses inline `python3 - "$file" <<'PY' ... PY` heredoc for YAML parsing. Pattern works for the 4-assertion expansion.
- HPA grader uses jsonpath filter `[?(@.type=="Resource")]` already — extend the path to nested target fields.

**Setup patterns for BUG-M04 CNI probe:**
- `cka-sim/lib/setup.sh:218` `seed_netpol_skeleton` already creates baseline NP infra. The CNI probe should reuse this infra style.
- Sentinel files in `/tmp/q##-*` are an established pattern (e.g., `.cka-sim-sentinel`, `.setup-seeded-mode`).
- 30-60s wget timeouts elsewhere in graders — match for the probe.

**Idempotency:** All 3 setup scripts are idempotent today. Adding a CNI probe to BUG-M04 setup.sh must remain idempotent (re-running setup overwrites the sentinel based on the probe result, doesn't accumulate state).

**Backward compat:** No callers outside the 3 questions touch these graders. No library API changes proposed.
</code_context>

<specifics>
## Specific Ideas

- For BUG-M04 CNI probe, use `nicolaka/netshoot` (already used by q06) as the probe client image to avoid image churn.
- For BUG-M04, prefer adding a structural over-permissive guard (`port==8080` + `endPort==8090` exact) before reachability — it catches over-permissive NPs even on non-enforcing CNIs.
- For BUG-M05, the python YAML check should iterate `policy.rules` and look for the FIRST rule whose `resources` list intersects each target resource. Multiple rules covering the same resource is not a violation; missing-coverage is.
- For BUG-M06, jsonpath filter `[?(@.type=="Resource")]` reaches the right metric. The full path: `{.spec.metrics[?(@.type=="Resource")].resource.target.averageUtilization}` — confirm assert_field_eq tolerates the nested filter.
- Run `cka-sim drill <pack> <question>` against live cluster after each fix.
- Add synthetic regression cases per ROADMAP success criteria (over-permissive NP fails BUG-M04; flipped audit mapping fails BUG-M05; averageUtilization=80 fails BUG-M06). Encode as minimal candidate fixtures or document for the live UAT.
</specifics>

<deferred>
## Deferred Ideas

- A reusable "audit policy schema validator" library function — could grow but out of scope for one question.
- Auto-detecting CNI implementation by name (calico, cilium, flannel, kindnet) — sentinel-via-probe is more robust and CNI-agnostic.
- Per-port reachability matrix beyond 8079/8080/8085/8090/8095 for BUG-M04 — out of scope; criterion 1 only requires "over-permissive NP fails".
- Generalizing target.type validation across all HPA metric kinds — Phase 13 only handles the CPU Resource metric required by question.md.
</deferred>
