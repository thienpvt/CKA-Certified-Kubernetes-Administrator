---
phase: 03-runtime-contract-drill-mode
reviewed: 2026-05-10T00:00:00Z
depth: standard
files_reviewed: 44
files_reviewed_list:
  - cka-sim/AUTHORING.md
  - cka-sim/lib/cmd/drill.sh
  - cka-sim/lib/traps.sh
  - cka-sim/scripts/lint-packs.sh
  - cka-sim/scripts/test.sh
  - cka-sim/traps/catalog.yaml
  - cka-sim/packs/cluster-architecture/manifest.yaml
  - cka-sim/packs/cluster-architecture/01-rbac-viewer/metadata.yaml
  - cka-sim/packs/cluster-architecture/01-rbac-viewer/setup.sh
  - cka-sim/packs/cluster-architecture/01-rbac-viewer/grade.sh
  - cka-sim/packs/cluster-architecture/01-rbac-viewer/reset.sh
  - cka-sim/packs/cluster-architecture/01-rbac-viewer/ref-solution.sh
  - cka-sim/packs/services-networking/manifest.yaml
  - cka-sim/packs/services-networking/01-networkpolicy-egress/metadata.yaml
  - cka-sim/packs/services-networking/01-networkpolicy-egress/setup.sh
  - cka-sim/packs/services-networking/01-networkpolicy-egress/grade.sh
  - cka-sim/packs/services-networking/01-networkpolicy-egress/reset.sh
  - cka-sim/packs/services-networking/01-networkpolicy-egress/ref-solution.sh
  - cka-sim/packs/storage/manifest.yaml
  - cka-sim/packs/storage/01-pvc-binding/metadata.yaml
  - cka-sim/packs/storage/01-pvc-binding/setup.sh
  - cka-sim/packs/storage/01-pvc-binding/grade.sh
  - cka-sim/packs/storage/01-pvc-binding/reset.sh
  - cka-sim/packs/storage/01-pvc-binding/ref-solution.sh
  - cka-sim/packs/troubleshooting/manifest.yaml
  - cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/metadata.yaml
  - cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/setup.sh
  - cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/grade.sh
  - cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/reset.sh
  - cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/ref-solution.sh
  - cka-sim/packs/workloads-scheduling/manifest.yaml
  - cka-sim/packs/workloads-scheduling/01-deployment-requests/metadata.yaml
  - cka-sim/packs/workloads-scheduling/01-deployment-requests/setup.sh
  - cka-sim/packs/workloads-scheduling/01-deployment-requests/grade.sh
  - cka-sim/packs/workloads-scheduling/01-deployment-requests/reset.sh
  - cka-sim/packs/workloads-scheduling/01-deployment-requests/ref-solution.sh
  - cka-sim/tests/cases/drill_load_pack.sh
  - cka-sim/tests/cases/drill_namespace_construction.sh
  - cka-sim/tests/cases/drill_orchestration_order.sh
  - cka-sim/tests/cases/drill_question_selection.sh
  - cka-sim/tests/cases/lint_packs_grade02.sh
  - cka-sim/tests/cases/lint_packs_metadata.sh
  - cka-sim/tests/cases/lint_packs_mutating_verb.sh
  - cka-sim/tests/cases/lint_packs_setup_guard.sh
findings:
  critical: 2
  warning: 6
  info: 6
  total: 14
status: issues_found
---

# Phase 3: Code Review Report

**Reviewed:** 2026-05-10T00:00:00Z
**Depth:** standard
**Files Reviewed:** 44
**Status:** issues_found

## Summary

Phase 3 lands the single-question drill loop, 5 reference packs, and lint coverage. Overall structure is disciplined: orchestration order matches TRIP-05, EXIT-trap cleanup is registered correctly, and the 6-file contract is enforced.

Two BLOCKERs found:
1. `detect_rbac_viewer_role_mismatch` produces a false negative when a pod-targeting Role rule has zero verbs (`verbs: []` or omitted) — `add` on `[[]]` returns `[]`, `@csv` returns the empty string, and the code's "no pod rule at all" branch fires by accident. The detector still happens to emit the correct id in this case, but for the wrong reason; if the same logic is reused with non-fall-through behavior it breaks.
2. `detect_service_label_mismatch` has an inverted miss-vs-error semantic on Endpoints fetch failure. When `kubectl get endpoints` fails (RBAC denial, transient API error) the function silently returns 0 (no hit), but when the Endpoints object simply doesn't exist yet (a real "no endpoints" miss) it ALSO returns 0 via the same path — and a separate code path treats empty json as a hit. The two cases are conflated.

Warnings cluster around (a) lint regex gaps (heredoc-embedded violations, mutating verbs split across lines), (b) test fixture drift (`drill_orchestration_order.sh` doesn't exercise the real EXIT trap), and (c) several pack `traps:` arrays listing aspirational ids the grader never detects.

Info items cover style inconsistency (`nginx:1.27` vs `nginx:1.27-alpine`), single-quote stripping gap in manifest parser, and a couple of comment/typing nits.

## Critical Issues

### CR-01: `detect_rbac_viewer_role_mismatch` conflates "no pod rule" with "pod rule with empty verbs"

**File:** `cka-sim/lib/traps.sh:312-338`
**Issue:** The jq pipeline is:
```
[.rules[]?
 | select(((.apiGroups // []) | index("")) != null)
 | select(((.resources // []) | index("pods")) != null)
 | (.verbs // [])
] | add // []
| @csv
```

Three different inputs collapse to the same output:
- No rule targets pods at all → outer array `[]` → `add` → `null` → `// []` → `[]` → `@csv` → `""`.
- A rule targets pods but `verbs: []` → outer array `[[]]` → `add` → `[]` → `@csv` → `""`.
- A rule targets pods with `verbs: null` (missing) → same collapse via `.verbs // []`.

The code branches on `[[ -z "$pod_rule_verbs" ]]` and emits `rbac-viewer-role-mismatch`, then `return 0`. The result is correct *by accident* — a viewer role with no pod rule and a viewer role with a pod rule but empty verbs are both genuine misconfigurations, so the same trap-id is the right answer. But the implementation cannot tell them apart, and the comment ("No rule targets pods at all -> trap") is wrong for the second case. If a future detector variant needs to distinguish (e.g., a different trap id for "rule exists but verbs empty"), this code silently reports the wrong cause.

There is also a real correctness gap: `@csv` on `[]` actually produces empty output, but `@csv` on a single-element array containing an empty string `[""]` produces `""` (two double-quotes). The `grep -cE '"(get|\*)"'` check then runs on input that contains `""` and matches **zero**, so the trap fires correctly. But the secondary check `if (( has_get == 0 )) || (( has_list == 0 ))` is only reached when `pod_rule_verbs` is non-empty AND non-`"null"` — and `[[ "$pod_rule_verbs" == "null" ]]` is dead code, because the jq pipeline never produces the literal string `null` (the `// []` guard fires first).

**Fix:** Make the two cases explicit and compute presence-of-pod-rule separately from verb-set:
```bash
local pod_rule_count
pod_rule_count=$(echo "$json" | jq -r '
  [.rules[]?
   | select(((.apiGroups // []) | index("")) != null)
   | select(((.resources // []) | index("pods")) != null)
  ] | length' 2>/dev/null)
if [[ ! "$pod_rule_count" =~ ^[0-9]+$ ]] || (( pod_rule_count == 0 )); then
  echo "rbac-viewer-role-mismatch"
  return 0
fi
local verbs_csv
verbs_csv=$(echo "$json" | jq -r '
  [.rules[]?
   | select(((.apiGroups // []) | index("")) != null)
   | select(((.resources // []) | index("pods")) != null)
   | .verbs[]?
  ] | unique | @csv' 2>/dev/null)
local has_get=0 has_list=0
grep -qE '"(get|\*)"'  <<<"$verbs_csv" && has_get=1
grep -qE '"(list|\*)"' <<<"$verbs_csv" && has_list=1
if (( has_get == 0 )) || (( has_list == 0 )); then
  echo "rbac-viewer-role-mismatch"
fi
```
Drop the dead `pod_rule_verbs == "null"` check.

### CR-02: `detect_service_label_mismatch` swallows real errors and inverts miss semantics on Endpoints

**File:** `cka-sim/lib/traps.sh:347-363`
**Issue:** Three sequenced checks:
```
kubectl get service "$svc" ... || return 0
ep_json=$(kubectl get endpoints "$svc" ...) || return 0
[[ -n "$ep_json" ]] || { echo "service-selector-empty-endpoints"; return 0; }
```

Failure modes are conflated:
1. **Service missing** → `return 0` (no hit). Comment says "different problem". OK.
2. **`kubectl get endpoints` exits non-zero** (RBAC deny, transient API error, NotFound on the Endpoints object) → `return 0` (no hit). But on Kubernetes, when a Service exists, the Endpoints/EndpointSlice controller creates an empty Endpoints object eagerly. A 404 on `kubectl get endpoints <svc>` strongly indicates the controller hasn't reconciled yet, NOT that the selector is fine. This produces a false negative.
3. **`kubectl get endpoints` succeeds but `$ep_json` is empty** → fires the trap. But empty stdout from `kubectl get -o json` of a real object is impossible; empty only happens on the failure path covered by case 2. So the `[[ -n "$ep_json" ]]` branch is effectively dead code under normal conditions but fires on stub-kubectl harness configurations.

Additionally: as of Kubernetes 1.21+, `Endpoints` is the legacy API; `EndpointSlice` is canonical. On clusters where the legacy `Endpoints` object is suppressed (some managed services do this), this detector reports a false positive even when the selector is correct. The pack target version is 1.35 (per `metadata.yaml verified_against`), where `EndpointSlice` is GA and authoritative.

**Fix:** Query EndpointSlice (which is authoritative on 1.21+) and treat `kubectl get` failure as "cannot determine" rather than "no hit". Suggested:
```bash
cka_sim::trap::detect_service_label_mismatch() {
  local ns="${1:?...}" svc="${2:?...}"
  kubectl get service "$svc" -n "$ns" -o name >/dev/null 2>&1 || return 0
  local addr_count
  addr_count=$(kubectl get endpointslice -n "$ns" \
    -l "kubernetes.io/service-name=$svc" -o json 2>/dev/null \
    | jq -r '[.items[]?.endpoints[]?.addresses[]?] | length' 2>/dev/null)
  [[ "$addr_count" =~ ^[0-9]+$ ]] || return 0   # cannot determine -> miss, not error
  if (( addr_count == 0 )); then
    echo "service-selector-empty-endpoints"
  fi
}
```

## Warnings

### WR-01: Lint pass A regex misses heredoc-embedded `kubectl get | grep`

**File:** `cka-sim/scripts/lint-packs.sh:43`
**Issue:** The pattern `^[[:space:]]*[^#]*kubectl[[:space:]]+get[[:space:]].*\|[[:space:]]*grep` requires `kubectl` to appear after only whitespace and non-`#` chars. A grader containing the violation inside a heredoc body (e.g. `<<EOF\nkubectl get x | grep y\nEOF`) is detected (good), but a violation prefixed by an opening `#` in any context is missed. More importantly, the regex does not match `kubectl get x|grep y` (no whitespace before `|`) — `.*\|` requires `\|` to appear anywhere on the line, but the regex does. Fine. However, it also does not match multi-line forms `kubectl get x \\\n  | grep y` — which is a common shell idiom.
**Fix:** Document the single-line limitation, or extend the rule to also match `kubectl[[:space:]]+get` on one line followed by `^[[:space:]]*\|[[:space:]]*grep` on the next. Acceptable to defer if v1 author guidance says "no line continuations in graders".

### WR-02: Lint pass B mutating-verb regex misses line-continuation and string-arg forms

**File:** `cka-sim/scripts/lint-packs.sh:55`
**Issue:** Pattern `kubectl[[:space:]]+(delete|create|apply|patch|edit|replace)([[:space:]]|$)` catches the canonical form but misses:
- `kubectl \\\n  delete ns foo` (line continuation)
- `kubectl --kubeconfig=/x apply -f -` (a flag between binary and verb)
- `bash -c "kubectl delete ..."` (verb inside quoted string is caught — the regex is content-only)

The middle case (a flag between binary and verb) is the realistic gap: nothing in pack-style says graders can't use `--kubeconfig=`, and a future grader with `kubectl --context=foo apply` would slip past. Probability of this in pack code is low but the lint is supposed to be the safety net.
**Fix:** Either document the convention "no flags between `kubectl` and the verb in graders" or extend the regex: `kubectl([[:space:]]+--[^[:space:]]+)*[[:space:]]+(delete|create|...)`. Defer is acceptable.

### WR-03: `drill_orchestration_order.sh` does not test the real EXIT trap

**File:** `cka-sim/tests/cases/drill_orchestration_order.sh:46-51`
**Issue:** The test simulates the order with four manual `bash` invocations:
```
bash "$qdir/reset.sh"
bash "$qdir/setup.sh"
bash "$qdir/grade.sh" >/dev/null
bash "$qdir/reset.sh"   # EXIT-trap simulation
```
This tests "running four scripts in this order produces this log", which is tautological. It does NOT test that `cka_sim::drill::main` actually registers the trap, that the trap fires on grade-failure (`exit "$grade_rc"` with non-zero), or that it fires on Ctrl-C (SIGINT). The Phase 3 contract is that EXIT-trap cleanup runs on every exit path — none of those exit paths are exercised.
**Fix:** Add a second test case that sources drill.sh, monkey-patches `CKA_SIM_QUESTION_DIR` to the stub dir, registers `trap cka_sim::drill::cleanup EXIT`, then `exit 1` from a subshell — and asserts `reset.sh` ran. (Phase 3 may legitimately defer this if integration coverage is planned for Phase 8; if so, mark this test as a smoke test in the comment.)

### WR-04: Several pack `traps:` arrays list aspirational ids the grader never detects

**Files:**
- `cka-sim/packs/cluster-architecture/01-rbac-viewer/metadata.yaml:5-8` — lists `default-sa-used`, `missing-dns-egress`; grader only calls `detect_rbac_viewer_role_mismatch`.
- `cka-sim/packs/services-networking/01-networkpolicy-egress/metadata.yaml:5-8` — lists `default-sa-used`, `hostpath-pv-without-nodeaffinity`; grader only calls `detect_missing_dns_egress` (and the pack has neither a PV nor a non-default SA to detect).
- `cka-sim/packs/storage/01-pvc-binding/metadata.yaml:5-8` — lists `pvc-wrong-storageclass`, `pv-accessmodes-mismatch`; grader only calls `detect_hostpath_pv_without_nodeaffinity`.
- `cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/metadata.yaml:5-8` — lists `default-sa-used`, `missing-dns-egress`; grader only calls `detect_service_label_mismatch`.
- `cka-sim/packs/workloads-scheduling/01-deployment-requests/metadata.yaml:5-8` — lists `hostpath-pv-without-nodeaffinity`; grader only calls `detect_default_sa_used` (no PV in the pack).

**Issue:** GRADE-04 requires ≥3 trap ids in metadata. The lint enforces that, but does not enforce that `grade.sh` actually invokes a detector for each listed id. Authors are using the metadata `traps:` array as filler to satisfy `>=3`. This silently downgrades the trap-recording contract: the report will never list those traps, regardless of state.
**Fix:** Either (a) author each pack with a setup that exercises all listed traps, or (b) extend lint-packs.sh to grep `grade.sh` for `detect_<trap-id-with-underscores>` for each metadata trap id. Option (b) is the rigorous fix; option (a) is the spirit of GRADE-04. At minimum, document the gap so reviewers know `traps:` is currently aspirational.

### WR-05: `setup.sh` bare `$i` loop variable triggers shellcheck SC2034 noise

**Files:** All five `setup.sh` files — e.g. `cka-sim/packs/storage/01-pvc-binding/setup.sh:19`
**Issue:** `for i in $(seq 1 10); do ... done` — `$i` is never referenced inside the loop body. With `set -u`, this is fine (the variable is assigned). With shellcheck this is SC2034. Conventional fix: `for _ in $(seq 1 10); do`.
**Fix:** Replace `for i in $(seq 1 10)` with `for _ in $(seq 1 10)` in all five `setup.sh` files. Also note the loop iterates 10 × 5s = 50s as the comment claims, which is correct — but the comment in `cluster-architecture/01-rbac-viewer/setup.sh:17-21` doesn't mention "50s" explicitly while the other packs do. Minor inconsistency.

### WR-06: Manifest parser silently drops fields whose key is not lowercase-only

**File:** `cka-sim/lib/cmd/drill.sh:76`
**Issue:** Pack-scope parser regex is `^\ \ ([a-z]+):\ (.+)$`. Snake-case (`my_field`), camelCase (`myField`), or PascalCase keys are silently skipped. A future manifest `extra_meta: x` would drop without warning, and lint-packs.sh has no manifest schema check (it only validates `metadata.yaml`). This is a forward-compat trap for Phase 4/5 pack expansion (PACK-01..PACK-05 may add fields).
**Fix:** Either (a) widen regex to `[a-zA-Z_]+`, or (b) add a manifest.yaml schema lint pass that whitelists known keys. Phase 3 acceptable as-is, but worth tracking.

## Info

### IN-01: `nginx:1.27` not pinned to alpine variant in workloads pack

**File:** `cka-sim/packs/workloads-scheduling/01-deployment-requests/setup.sh:45`
**Issue:** AUTHORING.md §2.3 specifies `nginx:1.27-alpine` as the canonical image pin. This pack uses `nginx:1.27` (debian-based, larger image). Other packs use the alpine variant.
**Fix:** Change to `nginx:1.27-alpine` for consistency and faster pull.

### IN-02: Manifest parser strips only double quotes, not single quotes

**File:** `cka-sim/lib/cmd/drill.sh:79-82, 89-90, 96-97, 103-105`
**Issue:** All four quote-strip blocks check `"${value:0:1}" == '"'` — only matches double-quote. A manifest written with `id: 'foo'` would parse to `'foo'` literal. The catalog parser at `lib/traps.sh:69-71` has the same single-quote gap. The lint helper `_strip_quotes` in `lint-packs.sh:34` DOES strip both, so a metadata file with single quotes lints OK but the runtime parser would mis-set `CKA_SIM_QUESTION_ID`.
**Fix:** Mirror `_strip_quotes` in the manifest/catalog parsers, or document "double quotes only" in AUTHORING.md.

### IN-03: `_validate_picked` uses `RANDOM % n` (modulo bias)

**File:** `cka-sim/lib/cmd/drill.sh:127`
**Issue:** `RANDOM % n` introduces modulo bias for large `n`. For pack sizes ≤ 100 (which is the realistic ceiling), the bias against the last few indices is < 0.4% — negligible for question selection. Flagged for documentation only.
**Fix:** No change required. Add comment explaining the bias is acceptable.

### IN-04: Dead `[[ "$pod_rule_verbs" == "null" ]]` branch

**File:** `cka-sim/lib/traps.sh:327`
**Issue:** The jq pipeline `add // []` cannot produce the literal string `"null"` because of the `// []` fallback. The disjunction `|| "$pod_rule_verbs" == "null"` is dead code.
**Fix:** Drop the disjunct. (Subsumed by CR-01 fix.)

### IN-05: `cleanup` warn message uses stale `$?` after `||`

**File:** `cka-sim/lib/cmd/drill.sh:229`
**Issue:** `bash "$CKA_SIM_QUESTION_DIR/reset.sh" || warn "reset.sh exited non-zero (rc=$?)"` — `$?` here expands to the exit status of `reset.sh`, which is what we want. Correct as written; flagging only because the pattern is fragile (any change to the surrounding expression can break it). A safer form is to capture first: `bash ... || { local rc_reset=$?; warn "reset.sh exited non-zero (rc=$rc_reset)"; }`.
**Fix:** Capture the exit code explicitly for resilience.

### IN-06: `drill_orchestration_order.sh` writes stub scripts but never invokes drill.sh

**File:** `cka-sim/tests/cases/drill_orchestration_order.sh:21-44`
**Issue:** The test creates a 6-file stub dir but only invokes scripts directly; it never sources `lib/cmd/drill.sh` nor calls `cka_sim::drill::load_pack` or `main`. The stub-dir setup is largely redundant with the inline `bash <script>` checks. Unify with WR-03 if addressed.
**Fix:** Either delete the stub-dir construction (use plain `mktemp` + log redirection) or actually source drill.sh and exercise its functions against the stub dir.

---

_Reviewed: 2026-05-10T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
