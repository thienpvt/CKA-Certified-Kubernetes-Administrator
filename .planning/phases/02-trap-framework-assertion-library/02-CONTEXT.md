# Phase 2: Trap Framework + Assertion Library — Context

**Gathered:** 2026-05-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Ship the shared trap-detection library (`cka-sim/lib/traps.sh`), the assertion helpers (`cka-sim/lib/grade.sh`), and the seeded trap catalog (`cka-sim/traps/catalog.yaml` with 8 CONCERNS-derived content-bug entries) — plus a self-contained bash unit-test harness — so every grader from Phase 3 onward can compose assertions and emit trap IDs without reinventing the wheel.

### Success criteria (from ROADMAP.md)
1. `lib/traps.sh` exports ≥8 detector functions, each returning a stable trap ID string on detection and empty otherwise
2. `lib/grade.sh` exports ≥7 assertion helpers (`assert_resource_exists`, `assert_field_eq`, `assert_pod_ready`, `assert_pvc_bound`, `assert_can_i`, `assert_egress_allowed`, `assert_endpoints_nonempty`) and an `emit_result` finalizer
3. `traps/catalog.yaml` has all 8 seeded entries with required fields and passes schema lint
4. Unit tests execute known-bad fixtures and confirm each seeded detector fires; known-good and benign fixtures confirm no false positives
5. All trap IDs, assertion helper names, and catalog keys conform to RFC 1123 (TRIP-07)

### Requirements in scope
GRADE-01, GRADE-05, TRIP-07

### Requirements explicitly NOT in scope for Phase 2
- GRADE-02, GRADE-03, GRADE-04, GRADE-06 — depend on grader authoring (Phase 3+ uses these)
- All `PACK-*` content authoring — Phases 4–6
- CI lint extensions for `kubectl get | grep` / `kubectl get -A` (GRADE-02) — Phase 3 wires the first real grader; CI gates land then or in Phase 8
- Live cluster verification — static / fixture-only at Phase 2 close (deferred per DF-12 to v1.x)

</domain>

<decisions>
## Implementation Decisions

### Detector contract (4 decisions)
- **D-01: Explicit per-trap call from grader.** Each `grade.sh` manually invokes the detectors it cares about: `tid=$(cka_sim::trap::detect_default_sa_used "$ns" "$pod"); [ -n "$tid" ] && cka_sim::grade::record_trap "$tid"`. No auto-fire on assertion failure; no tag-list iteration. Rationale: every grader explicitly opts into the traps relevant to its question, no surprise fires from unrelated detectors, debugging stays trivial.
- **D-02: Detector signature = positional args, stdout returns trap-id on hit, empty on miss.** Example: `cka_sim::trap::detect_default_sa_used <namespace> <pod-name>`. Each detector documents required args at the top of its function. Composable in `$(...)`; trivially testable in isolation; no global state.
- **D-03: Detector returns trap-id only; finalizer formats the `Trap N: <name>: <description>` line from catalog at emit time.** Catalog is the single source of truth for trap text. Renaming a trap doesn't require touching detectors. Missing catalog entry MUST fail the grader (lint-enforceable + runtime check per D-15).
- **D-04: Pure-bash parser for the catalog's flat shape.** `lib/traps.sh` parses `traps/catalog.yaml` at sourcing time using `awk`/`grep` into bash associative arrays (one array per field — `CKA_SIM_TRAP_NAME[id]`, `CKA_SIM_TRAP_DESC[id]`, etc.). No `yq` dependency. Schema lint (D-13) MUST enforce the flat shape so the parser's assumptions hold.

### Grader output state machine (4 decisions)
- **D-05: Failed assertions accumulate; grader keeps running.** `assert_X` records the failure into accumulator arrays (`CKA_SIM_GRADE_FAILS=()`, `CKA_SIM_GRADE_PASSES=()`) and returns non-zero, but does NOT `die`. `grade.sh` uses `set -uo pipefail` (no `-e`) — same pattern as Phase 1's `doctor.sh`. Candidate sees ALL their mistakes per drill, not just the first. Lint rule (Phase 3+): grader scripts must NOT contain `|| die` after assertion calls.
- **D-06: Each assertion = 1 point; max = total assertions invoked.** `cka_sim::grade::assert_X` increments `CKA_SIM_GRADE_TOTAL` on entry and `CKA_SIM_GRADE_PASSED` on success. `emit_result` prints `SCORE: ${PASSED}/${TOTAL}`. Optional weight arg (default 1) reserved on every helper signature for future per-question tuning, but Phase 2 leaves all weights at 1.
- **D-07: Output channels — per-assertion live status to stderr; SCORE + Trap summary block to stdout.**
  Live (stderr, via existing `lib/log.sh`):
  ```
  ✓ pod 'web' is Ready
  ✗ PVC 'data' is Bound (got status=Pending)
  ```
  Final block (stdout, emitted by `emit_result`):
  ```
  SCORE: 4/6
  Trap 7: default-sa-used: pod uses default ServiceAccount with auto-mounted token
  Trap 3: missing-dns-egress: NetworkPolicy denies UDP/53 egress
  ```
  Exit code: 0 if `PASSED == TOTAL` and no traps recorded; 1 otherwise. (GRADE-03: ≥1 trap on failure — enforced by lint at Phase 3+.)
- **D-08: Trap deduplication by id; one `Trap N: ...` line per unique id per grader run.** `record_trap` checks accumulator before append. Forward-compatible with DF-02 (cross-session trap-frequency aggregation deferred to v1.x).

### Test harness approach (4 decisions)
- **D-09: PATH-shadowed `kubectl` stub.** `cka-sim/tests/bin/kubectl` is a bash script that reads argv, looks up a fixture file under `cka-sim/tests/fixtures/<test-case>/<argv-fingerprint>.json`, and cats it. Test runner exports `PATH="$REPO/cka-sim/tests/bin:$PATH"` before sourcing detectors. Detectors run unchanged — no test-mode branches in production code. Stub also handles `kubectl exec`, `kubectl auth can-i`, `kubectl get --raw`. Argv fingerprinting: stable hash over normalized args, with a small in-stub dispatcher for the common shapes (`get <res> -o json`, `auth can-i <verb> <res>`, etc.).
- **D-10: Plain bash test runner — no bats, no shellspec.** `cka-sim/tests/run.sh` walks `cka-sim/tests/cases/*.sh`, sources each, reports pass/fail counts. Tiny in-tree helpers (`expect_eq`, `expect_empty`, `expect_contains`) under `cka-sim/tests/lib/assert.sh`. Zero new dependencies — matches Phase 1's "pure bash, only apt-default deps" constraint. Per-case files declare `setUp`/`tearDown` functions optionally.
- **D-11: Invocation = `cka-sim/scripts/test.sh` + new GHA job.** Mirrors Phase 1's standalone-script pattern. CI extends `.github/workflows/validate.yml` with a `bash-tests` job (after the existing yamllint job) that runs `bash cka-sim/scripts/test.sh`. Local: candidate runs `bash cka-sim/scripts/test.sh`. NOT a `cka-sim` subcommand — testing is a developer concern, not a candidate concern, and `cka-sim test` would collide naming-wise with drill flow.
- **D-12: Fixture coverage = hit + miss + benign per detector.** 8 detectors × 3 scenarios = 24 fixtures. (a) known-bad fires the trap; (b) known-good (correctly-configured resource) does not fire; (c) benign-shape (empty namespace, unrelated resource) does not fire. Catches both false-negative bugs AND false-positive bugs that would corrupt grading on the candidate's real cluster. Same pattern applies to assertion helpers (≥7) — at least one happy-path and one sad-path test per helper.

### Catalog schema + lint (4 decisions)
- **D-13: Catalog entry schema has 8 required fields.** Per entry: `id` (RFC 1123), `name` (human-readable, ≤80 chars), `description` (one-sentence what fires this), `remediation_hint` (one-sentence what to do instead), `severity` (`info|warn|error`), `domain` (one of `troubleshooting`, `cluster-architecture`, `services-networking`, `workloads-scheduling`, `storage`), `source` (`cncf-curriculum|concerns-md|community`), `references` (structured list per D-14). All 8 seeded traps from CONCERNS.md will carry `source: concerns-md`. Schema is intentionally flat (no nested objects beyond `references`) so D-04's pure-bash parser works.
- **D-14: `references` is a structured list.** Each item: `{kind, target, note}` where `kind ∈ {concerns-md, k8s-doc, prior-art-exercise, exam-objective, blog-post}` (closed enum, lint-enforced). `target` is a relative path or absolute URL; for `concerns-md` and `prior-art-exercise` kinds, the path MUST exist on disk (lint-checked). `note` is one-line free prose. This makes provenance traceable and renders cleanly in Phase 8 docs.
- **D-15: New `cka-sim/scripts/lint-traps.sh` enforces schema, naming, paths, and seed-completeness.** Specific rules: (a) every entry has all 8 required fields; (b) `id` matches `^[a-z0-9]([a-z0-9-]*[a-z0-9])?$` (RFC 1123 DNS label, ≤63 chars, no leading/trailing hyphens); (c) `severity` ∈ enum; (d) `domain` ∈ the 5-value enum; (e) `source` ∈ enum; (f) every `references[].kind` ∈ enum; (g) for `kind: concerns-md` or `prior-art-exercise`, `target` path resolves (exists on disk); (h) the 8 seeded IDs MUST all be present and exactly spelled per GRADE-05. Wired into `cka-sim/scripts/test.sh` and the new GHA `bash-tests` job. Standalone (not folded into `scripts/validate-local.sh` because that script is YAML/legacy-paths focused).
- **D-16: `record_trap` validates trap-id at runtime.** When `cka_sim::grade::record_trap <id>` is called from a grader, it checks the in-memory catalog map. If `<id>` is not registered, `die "unknown trap-id '$id' — register it in traps/catalog.yaml first"`. Fast feedback during grader development; impossible to ship a grader that emits a phantom trap. Satisfies GRADE-04. No CI-static-grep duplicate; runtime check is sufficient.

### Claude's Discretion
- **Exact `id` spelling for the 8 seeded traps:** REQUIREMENTS.md GRADE-05 lists them; planner copies verbatim. Examples: `pss-error-string-mismatch`, `kubelet-runtime-flag-in-kubeconfig`, `removed-container-runtime-flag`, `hostpath-pv-without-nodeaffinity`, `as-flag-format-wrong`, `default-sa-used`, `missing-dns-egress`, `psp-fictional-pod-label-exemption`.
- **Per-trap `domain` mapping:** Planner / executor assigns based on subject-matter (e.g., `pss-error-string-mismatch` → `cluster-architecture`, `missing-dns-egress` → `services-networking`, `default-sa-used` → `cluster-architecture`/`workloads-scheduling`). Single domain per trap (can be revisited if a trap genuinely cuts across).
- **Argv-fingerprint algorithm in the kubectl stub:** Implementation detail; a small dispatcher table covering `get`/`describe`/`auth can-i`/`exec`/`get --raw` is enough for Phase 2.
- **Helper internal layout under `cka-sim/lib/`:** Stick with single files (`traps.sh`, `grade.sh`) for Phase 2 — splitting per-detector files is premature until catalog grows past ~30 traps.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & policy
- `.planning/REQUIREMENTS.md` §"Grader" — GRADE-01, GRADE-05 (8 seeded trap IDs verbatim) — locked
- `.planning/REQUIREMENTS.md` §"Runtime contract" — TRIP-07 (RFC 1123 naming) applies to every trap-id, helper name, catalog key
- `.planning/REQUIREMENTS.md` §"Future Requirements" — DF-02 (cross-session trap aggregation) and DF-12 (kind-cluster fixture CI) are explicitly DEFERRED; Phase 2 emits forward-compatible data shapes but does NOT implement these

### Trap content origins
- `.planning/codebase/CONCERNS.md` §"Content Accuracy & Version Drift" — origin of `pss-error-string-mismatch`, `psp-fictional-pod-label-exemption`, `removed-container-runtime-flag`, `kubelet-runtime-flag-in-kubeconfig`
- `.planning/codebase/CONCERNS.md` §"Security Example Hygiene" — origin of `hostpath-pv-without-nodeaffinity`, `default-sa-used`
- `.planning/codebase/CONCERNS.md` §"Script Fragility" — context for `kubelet-runtime-flag-in-kubeconfig` (the `/var/lib/kubelet/kubeadm-flags.env` vs `/etc/kubernetes/kubelet.conf` confusion)

### Style & conventions
- `.planning/codebase/CONVENTIONS.md` §"Bash / shell script style" — `#!/bin/bash`, `set -euo pipefail` on validation scripts, `set -uo pipefail` on accumulating-failure scripts (mirrors Phase 1's `doctor.sh`), ANSI color helpers, `REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"` idiom, LF line endings via `.gitattributes`
- `.planning/codebase/TESTING.md` §"No traditional test framework" — current state; Phase 2 is the FIRST bash test harness in the repo; Phase 8 will extend `.github/workflows/validate.yml`'s `paths:` filter to include `cka-sim/**`

### Phase 1 carry-forward
- `.planning/phases/01-cluster-bootstrap-runner-skeleton/01-CONTEXT.md` — locked decisions on bash style, sentinel-block patterns, `lib/` layout, helper module shape
- `cka-sim/lib/log.sh` — `info`/`ok`/`warn`/`err`/`die`/`header`/`verbose` helpers (all to stderr); reuse for live per-assertion status
- `cka-sim/lib/colors.sh` — TTY-aware ANSI vars; reuse
- `cka-sim/lib/preflight.sh` — pattern reference for sourceable shared helpers
- `cka-sim/bin/cka-sim` — router that already dispatches `drill`/`exam`/`score` to stub modules; Phase 3 will be the first consumer of `lib/grade.sh`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `cka-sim/lib/log.sh` — every assertion helper's live-status line (`✓ pod 'web' is Ready`) goes through `cka_sim::log::ok`/`cka_sim::log::err` for consistent ANSI formatting and stderr routing.
- `cka-sim/lib/colors.sh` — TTY detection already handled.
- `cka-sim/lib/fileblock.sh` — sentinel-block pattern (proven idempotent in Phase 1) is NOT directly reused in Phase 2 but documents the team's idempotency-via-sentinel idiom — applies if any future trap detector needs to write state.
- `.gitattributes` — already pins LF on `*.sh`; new test fixtures and `*.yaml` need the same treatment if any are committed with CRLF risk.

### Established Patterns
- **Module-per-file under `cka-sim/lib/`:** Phase 1 shipped 4 sourceable lib modules + 8 cmd modules. Phase 2 adds 2 more lib modules (`traps.sh`, `grade.sh`) — same shape.
- **`set -uo pipefail` on aggregate-failure scripts:** Phase 1's `doctor.sh` uses this so all 8 preflight checks run before exit. Phase 2's `grade.sh`-sourced graders inherit this pattern (D-05).
- **Function namespacing:** `cka_sim::log::ok`, `cka_sim::preflight::check_ssh_batchmode` — Phase 2 follows: `cka_sim::trap::detect_<id>`, `cka_sim::grade::assert_<thing>`, `cka_sim::grade::record_trap`, `cka_sim::grade::emit_result`.
- **Stderr for status, stdout for parseable output:** matches Phase 1's `doctor.sh` (status to stderr, exit code to caller). Phase 2's grader follows: live `✓`/`✗` to stderr, `SCORE:` + `Trap N:` to stdout.

### Integration Points
- **Phase 3's reference graders source `cka-sim/lib/grade.sh` and `cka-sim/lib/traps.sh`.** The `grade.sh` for any question is `source "$CKA_SIM_ROOT/lib/grade.sh"; source "$CKA_SIM_ROOT/lib/traps.sh"; ...`. Phase 2 must export the helper namespace cleanly (no leaked locals).
- **Phase 7's exam aggregator parses `SCORE:` and `Trap N:` lines from each grader's stdout.** Output format (D-07) is forward-locked here; changing it later breaks Phase 7.
- **CI workflow `.github/workflows/validate.yml`:** Phase 2 adds a `bash-tests` job. The existing `paths:` filter does NOT yet include `cka-sim/**` — Phase 2's CI patch must extend it (or the new job will never trigger). This is a one-line YAML change.
- **`scripts/validate-local.sh`** stays untouched — Phase 2's harness is `cka-sim/scripts/test.sh`, separate.

</code_context>

<specifics>
## Specific Ideas

### Directory layout (concrete)
```
cka-sim/
├── lib/
│   ├── traps.sh                    # NEW: 8+ detector functions + record_trap + catalog parser
│   ├── grade.sh                    # NEW: 7+ assertion helpers + emit_result + accumulators
│   ├── (existing) log.sh, colors.sh, fileblock.sh, preflight.sh
│   └── cmd/ (unchanged)
├── traps/
│   └── catalog.yaml                # NEW: 8 seeded entries, schema per D-13/D-14
├── tests/
│   ├── bin/
│   │   └── kubectl                 # NEW: PATH-shadow stub (D-09)
│   ├── lib/
│   │   └── assert.sh               # NEW: expect_eq / expect_empty / expect_contains
│   ├── fixtures/                   # NEW: 24 detector fixtures + ~14 assertion-helper fixtures
│   │   ├── default-sa-used/{hit,miss,benign}.json
│   │   ├── missing-dns-egress/{hit,miss,benign}.json
│   │   └── ... (one dir per detector + helper)
│   ├── cases/
│   │   ├── traps_default-sa-used.sh
│   │   ├── traps_missing-dns-egress.sh
│   │   ├── grade_assert_pod_ready.sh
│   │   └── ... (one case file per detector + helper)
│   └── run.sh                      # NEW: walks cases/, sources each, reports
└── scripts/
    ├── test.sh                     # NEW: orchestrates lint-traps + run.sh
    └── lint-traps.sh               # NEW: schema + path + naming lint per D-15
```

### Sample `traps/catalog.yaml` shape (one entry, illustrating D-13 + D-14)
```yaml
traps:
  - id: removed-container-runtime-flag
    name: Removed --container-runtime=remote flag
    description: kubelet uses --container-runtime=remote (removed in 1.27); only --container-runtime-endpoint remains in 1.35
    remediation_hint: Set --container-runtime-endpoint=unix:///run/cri-dockerd.sock in /var/lib/kubelet/kubeadm-flags.env
    severity: error
    domain: cluster-architecture
    source: concerns-md
    references:
      - kind: concerns-md
        target: .planning/codebase/CONCERNS.md
        note: CRI-dockerd kubelet flag — removed in 1.27
      - kind: prior-art-exercise
        target: exercises/26-cri-dockerd-setup/
        note: Exercise that contains the bug
      - kind: k8s-doc
        target: https://kubernetes.io/docs/setup/production-environment/container-runtimes/
        note: Authoritative configuration reference
```

### Sample detector function signature (illustrating D-02 + D-03)
```bash
# cka_sim::trap::detect_default_sa_used <namespace> <pod-name>
#   Echoes "default-sa-used" if pod uses the default ServiceAccount; empty otherwise.
cka_sim::trap::detect_default_sa_used() {
  local ns="$1" pod="$2"
  local sa
  sa=$(kubectl get pod "$pod" -n "$ns" -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null)
  if [[ -z "$sa" || "$sa" == "default" ]]; then
    echo "default-sa-used"
  fi
}
```

### Sample assertion helper signature (illustrating D-05 + D-06)
```bash
# cka_sim::grade::assert_pod_ready <namespace> <pod-name> [<weight>]
#   Records pass/fail into accumulators. Returns 0 on pass, 1 on fail.
cka_sim::grade::assert_pod_ready() {
  local ns="$1" pod="$2" weight="${3:-1}"
  CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + weight ))
  local ready
  ready=$(kubectl get pod "$pod" -n "$ns" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
  if [[ "$ready" == "True" ]]; then
    CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + weight ))
    cka_sim::log::ok "pod '$pod' is Ready"
    return 0
  fi
  CKA_SIM_GRADE_FAILS+=("pod '$pod' is not Ready (got: '${ready:-<missing>}')")
  cka_sim::log::err "pod '$pod' is not Ready (got: '${ready:-<missing>}')"
  return 1
}
```

### Platform
- Target: Ubuntu 22.04 (bash 5.1, OpenSSH 8.9, coreutils, jq from Phase 1's bootstrap)
- Dev: shellcheck available locally. Tests run in pure bash — no bats/shellspec dependency.

</specifics>

<deferred>
## Deferred Ideas

- **DF-02 cross-session trap-frequency aggregation** — Phase 2's `record_trap` dedup-by-id (D-08) keeps the data shape forward-compatible, but writing a session-history aggregator is v1.x.
- **DF-12 fixture CI against `kind`** — Phase 2 stays static (PATH-shadowed `kubectl`). Real-cluster fixture CI lands in v1.x.
- **Per-detector file split** under `cka-sim/lib/traps/` — premature optimization; revisit only if catalog grows past ~30 traps.
- **`cka-sim test` subcommand** — promoting the test runner into the candidate-facing CLI was rejected (testing is a dev concern, not a candidate concern).
- **yq-based catalog parsing** — rejected; pure-bash parser per D-04 stays as long as catalog schema stays flat.
- **Auto-fire detectors on every assertion failure** — rejected per D-01; explicit per-trap call is cleaner.
- **Per-assertion fractional weights** — D-06 reserves the weight arg in the helper signature but Phase 2 leaves all weights at 1; revisit only if a real grader needs it during Phases 3–6.
- **Severity-driven exit-code shading** — Phase 2 ignores `severity` at runtime (it's metadata for Phase 7's report); making `severity: info` traps non-failing could be a v1.x feature.

</deferred>

---

*Phase: 2-Trap Framework + Assertion Library*
*Context gathered: 2026-05-09*
