# Phase 3: Runtime Contract + Drill Mode — Context

**Gathered:** 2026-05-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Close the end-to-end single-question loop. `cka-sim drill <pack>` picks a question, runs `reset.sh` → `setup.sh` → prompt the candidate → `grade.sh` → trap emission → report, against a clean lab namespace. Ship 5 reference questions (one per CKA domain) that prove the contract on real content. This phase turns Phase 2's library into usable-by-candidates product.

### Success criteria (from ROADMAP.md)
1. Running `cka-sim drill storage` with no prior state creates `cka-sim-storage-01` namespace, presents `question.md`, and on completion emits `SCORE: N/M` + ≥1 `Trap N:` line when graded against a wrong solution
2. Running `cka-sim drill storage` twice in a row never produces `AlreadyExists` errors (TRIP-02 idempotency verified)
3. All 5 reference questions round-trip correctly: setup + grade emits FAIL with ≥1 trap; setup + reference-solution + grade emits PASS (GRADE-06)
4. Authoring template for the triplet is documented and lives under `cka-sim/AUTHORING.md` (partially — full doc lands in Phase 8)
5. CI lint fails any `grade.sh` containing `kubectl get | grep` or `kubectl get -A` (GRADE-02 enforcement)

### Requirements in scope
TRIP-01, TRIP-02, TRIP-03, TRIP-04, TRIP-05, TRIP-06, GRADE-02, GRADE-03, GRADE-04, GRADE-06, RUN-02

### Requirements explicitly NOT in scope for Phase 3
- PACK-01..07 (the 5 full domain packs) — Phases 4, 5, 6
- PACK-06 verification coverage matrix across all checkboxes — Phases 4–6
- MOCK-01..03 (exam blueprints) — Phases 7, 8
- RUN-03..06 (timer, session JSON, resume, signal handling) — Phase 7
- REPORT-01/02 (aggregate score report) — Phase 7
- Full `AUTHORING.md` / `SCHEMA.md` — Phase 8

</domain>

<decisions>
## Implementation Decisions

### Pack/question layout + manifest (3 decisions)
- **D-01: Directory layout.** `cka-sim/packs/<domain>/<NN>-<slug>/` holds each question as a directory. Files: `metadata.yaml`, `question.md`, `setup.sh`, `grade.sh`, `reset.sh`, `ref-solution.sh`. Sibling `cka-sim/packs/<domain>/manifest.yaml` + `cka-sim/packs/<domain>/README.md` at the pack root. 7 files per question (6 per question-dir + 2 per pack). `<domain>` ∈ {`storage`, `workloads-scheduling`, `services-networking`, `cluster-architecture`, `troubleshooting`}.
- **D-02: Pack manifest shape.** Full pack metadata + ordered question list:
  ```yaml
  pack:
    id: storage
    domain: storage
    weight: 10                         # v1.35 CKA blueprint weight
    description: "Storage 10% domain pack"
  questions:
    - id: storage-pvc-binding
      path: 01-pvc-binding
      estimatedMinutes: 8
  ```
  `weight:` feeds Phase 7's blueprint math; `id:` is cross-referenced by blueprint manifests (MOCK-01); `path:` decouples the authoring slug from the question id so slugs can drift without breaking references.
- **D-03: Question selection.** `cka-sim drill <pack>` picks a random question via `$RANDOM` mod manifest-length. `cka-sim drill <pack> <N>` (1-based index into `manifest.yaml:questions`) picks a specific question. No history tracking in Phase 3 — that's DF-02 territory.

### `cka-sim drill` CLI contract (3 decisions)
- **D-04: Question presentation.** `cat` `question.md` to stdout after a header, then print the lab namespace (`Lab ns: cka-sim-<pack>-<NN>`), then `Type 'done' to grade, 'skip' to abandon:`; read one line via `bash`'s `read`. On `done` → run `grade.sh`. On `skip` → fall through to EXIT trap (which runs `reset.sh`), exit 130 with a "skipped" log line. No `$PAGER`, no tmux. Matches real-exam's terminal-only surface.
- **D-05: Grade output = live stdout + persisted report.** Grader's stderr (per-assertion ✓/✗) and stdout (`SCORE:` / `Trap N:` block) go to the candidate's terminal; the runner simultaneously `tee`s stdout into `~/.cka-sim/reports/<ts>-<pack>-<question-id>.md` with a ~10-line header (timestamp, pack, question-id, estimatedMinutes, actual-minutes, trap-catalog version). File is forward-compatible with Phase 7's `cka-sim score [<ts>]` lookup and DF-02 aggregation.
- **D-06: EXIT trap enforces cleanup.** `cka-sim drill` registers a bash `trap cka_sim::drill::cleanup EXIT` that runs `reset.sh` regardless of exit path (normal, Ctrl-C, error, `exit 130` from skip). Cluster stays clean between drills. Documented tradeoff: candidate cannot inspect post-drill state; learning-by-inspection deferred to a later `--inspect` flag if the workflow needs it (not scoped to Phase 3).

### Idempotency + reset/setup pattern (3 decisions)
- **D-07: `setup.sh` style.** `kubectl apply -f -` heredocs for manifests; `kubectl create X --dry-run=client -o yaml | kubectl apply -f -` for imperatives that don't have a native apply (secrets with `--from-literal`, configmaps from files). `kubectl label --overwrite`. `kubectl patch` is naturally idempotent. Never `kubectl create` without the dry-run-pipe. `setup.sh` starts with `set -euo pipefail`.
- **D-08: `reset.sh` style.** `kubectl delete namespace cka-sim-<pack>-<NN> --ignore-not-found --wait=false` for the lab ns (async — no 30s finalizer stall). For cluster-scoped resources (prefixed with the question id per TRIP-03, e.g., `q<id>-<name>`), an explicit list of `kubectl delete <kind> <name> --ignore-not-found`. `setup.sh` handles the "ns stuck Terminating" case with a 10-retry wait-loop on `kubectl create ns` (5s per retry = 50s max, matching worst-case finalizer). `reset.sh` starts with `set -uo pipefail` (no `-e` — multi-resource deletes run to completion even if one fails per TRIP-04's `--ignore-not-found` mandate).
- **D-09: Runner-owned orchestration.** `cka-sim/lib/cmd/drill.sh` runs the fixed sequence `reset.sh → setup.sh → prompt → grade.sh → EXIT-trap reset` in order. Individual `setup.sh` scripts DO NOT self-guard against prior state — the runner guarantees a clean slate (TRIP-05 is the runner's contract, not the author's). `setup.sh` is documented as runner-invoked only; running `bash packs/.../setup.sh` directly is unsupported. CI lint (`lint-packs.sh`) rejects `kubectl delete ns` at the top of any `setup.sh` as a banned pattern to keep the runner's guarantee honest.

### 5 reference questions + GRADE-02 lint + ref-solution (3 decisions)
- **D-10: 5 reference questions, one per domain, each mapped to a seeded trap.**
  | Pack | Slug | Topic | Seeded trap exercised |
  |------|------|-------|------------------------|
  | storage | 01-pvc-binding | PVC stuck Pending on hostPath PV without `nodeAffinity` | `hostpath-pv-without-nodeaffinity` |
  | workloads-scheduling | 01-deployment-requests | Deployment has no `resources.requests`; HPA can't scale | `default-sa-used` (dedicated SA not used) |
  | services-networking | 01-networkpolicy-egress | NetworkPolicy deny-all egress blocks DNS resolution | `missing-dns-egress` |
  | cluster-architecture | 01-rbac-viewer | Role/RoleBinding for 'view' verbs; tested via `kubectl auth can-i --as` | `as-flag-format-wrong` |
  | troubleshooting | 01-deploy-svc-mismatch | Deployment label set doesn't match Service selector; endpoints empty | (selector/endpoints-specific; additional non-seeded traps TBD) |

  Each question exercises at least one of the 7 assertion helpers AND one seeded trap. Per PACK-06, each `metadata.yaml` declares ≥3 traps (the seeded one + ≥2 per-question additional — those additional trap ids may NOT be in `traps/catalog.yaml` yet; Phase 3 extends the catalog with up to 5 new ids as needed, one per question).
- **D-11: `ref-solution.sh` is an executable bash script.** `packs/<domain>/<NN>-<slug>/ref-solution.sh`. Invoked by the CI GRADE-06 round-trip check between `setup.sh` and `grade.sh`: `bash setup.sh && bash grade.sh && assert_fails` — then restore — `bash setup.sh && bash ref-solution.sh && bash grade.sh && assert_passes`. Candidates never see this file during drills; drill mode does not touch it. `chmod +x` enforced by lint (D-12).
- **D-12: New `cka-sim/scripts/lint-packs.sh` covering GRADE-02 + PACK-06.** Rules: (a) every `packs/**/grade.sh` is rejected if it contains `kubectl get .*|.*grep` or `kubectl get -A` (grep with comment-filter); (b) every `metadata.yaml` has required fields: `id`, `domain`, `estimatedMinutes` ∈ [4,12], `verified_against: "1.35"`, `traps: [≥3]`, `references: []`; (c) every `metadata.yaml` trap id is registered in `traps/catalog.yaml` (reuses traps.sh's `id_exists` via source); (d) every question has the 6 required files (metadata, question, setup, grade, reset, ref-solution); (e) `setup.sh`, `grade.sh`, `reset.sh`, `ref-solution.sh` are executable; (f) no `setup.sh` contains `kubectl delete ns` at the top (runner-owned-cleanup guard per D-09). Wired into `cka-sim/scripts/test.sh` after `lint-traps.sh`, same GHA `bash-tests` job — no new job needed.

### Claude's Discretion
- **Exact manifest.yaml schema vs metadata.yaml schema** (avoiding redundancy): `domain` and `estimatedMinutes` are in per-question `metadata.yaml`; `manifest.yaml` carries pack-level metadata + question `id` + `path` + `estimatedMinutes` (duplicated for blueprint composition convenience). Lint enforces they match.
- **Exact question content authoring:** The 5 topics in D-10 are locked but per-question task wording, exact pod names, exact RFC-1123-compliant resource names, and wording of the `question.md` prompts are Claude's call during plan execution. Each question gets a 5–12 minute time budget per the domain weight and PACK-06.
- **New trap catalog entries** for per-question non-seeded traps: Phase 3 can extend `traps/catalog.yaml` with additional entries as needed (e.g., `pvc-wrong-storageclass`, `deployment-missing-requests`, `service-label-mismatch`). Catalog lint must still pass (8 required fields per entry).
- **Integration between `drill.sh` command and `lib/grade.sh` state:** `grade.sh` scripts `source $CKA_SIM_ROOT/lib/grade.sh` and `source $CKA_SIM_ROOT/lib/traps.sh` — Phase 2 libraries. The drill command's orchestration sets `CKA_SIM_QUESTION_ID`, `CKA_SIM_LAB_NS` env vars that graders may read.
- **Test fixtures for Phase 3:** The 5 reference questions will be live-cluster-run during CI via an ephemeral `kind` cluster fixture IF convenient, OR just statically-verified (bash -n, lint-packs green, structural checks) with the round-trip test documented as a human verification step. Phase 3 plans can pick the cheapest path; DF-12 remains explicitly deferred.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & policy
- `.planning/REQUIREMENTS.md` §"Runtime contract" — TRIP-01..07 (triplet shape, idempotency, namespace naming, reset semantics, RFC 1123)
- `.planning/REQUIREMENTS.md` §"Grader" — GRADE-02 (banned `kubectl get | grep`), GRADE-03 (SCORE + Trap line format), GRADE-04 (≥3 traps per question, registered in catalog), GRADE-06 (round-trip self-check)
- `.planning/REQUIREMENTS.md` §"Runner" — RUN-02 (`cka-sim drill <pack> [<n>]`)
- `.planning/REQUIREMENTS.md` §"Domain packs" — PACK-06 (front-matter schema) and PACK-07 (coverage matrix — full enforcement deferred to Phase 4+)
- `.planning/REQUIREMENTS.md` §"Future Requirements" — DF-02 (history aggregation), DF-08 (hint reveal), DF-09 (retake re-randomization), DF-11 (`cka-sim author lint`), DF-12 (kind-cluster fixture CI) — all explicitly DEFERRED

### Phase 2 contract (hard dependency)
- `.planning/phases/02-trap-framework-assertion-library/02-CONTEXT.md` — 16 locked decisions; especially D-01 (explicit per-trap call), D-07 (stderr live + stdout SCORE/Trap), D-13 (8-field catalog schema), D-15 (lint-traps.sh), D-16 (runtime record_trap validation)
- `cka-sim/lib/grade.sh` — 7 assertion helpers, `record_trap`, `emit_result`, accumulator state model
- `cka-sim/lib/traps.sh` — 8 detectors + catalog parser + `is_valid_id`
- `cka-sim/traps/catalog.yaml` — 8 seeded entries (Phase 3 may add more, maintaining the schema)
- `cka-sim/scripts/lint-traps.sh` — reference style for the new `lint-packs.sh`
- `cka-sim/scripts/test.sh` — orchestrator (extended to call `lint-packs.sh`)
- `.github/workflows/validate.yml` — `bash-tests` job (no changes needed — test.sh already runs lint-traps + test cases)

### Phase 1 carry-forward
- `.planning/phases/01-cluster-bootstrap-runner-skeleton/01-CONTEXT.md` — locked decisions on bash style, router shape, state dirs, log.sh helpers
- `cka-sim/bin/cka-sim` — router that dispatches `drill` to `lib/cmd/drill.sh` (currently a stub)
- `cka-sim/lib/cmd/drill.sh` — stub to be filled (Phase 1 left it as "Not implemented yet — phase 3")
- `cka-sim/lib/preflight.sh` — may be reused for pre-drill cluster checks (`check_cluster_nodes`, `check_kubeconfig`)
- `~/.cka-sim/{sessions,history,reports,logs}` — state dirs created by `cka-sim bootstrap`

### Style & conventions
- `.planning/codebase/CONVENTIONS.md` §"Bash / shell script style" — shebang, set options, ANSI colors, REPO_ROOT idiom, LF endings
- `.planning/codebase/CONVENTIONS.md` §"Edge-case / failure-mode authoring" — the "What tripped me up" pattern maps to how `question.md` should frame the mistake in prose (not Phase 3 directly, but informs question authoring)

### Content authoring references (for the 5 reference questions)
- `exercises/12-storage-pv-pvc/` — prior-art for storage/01-pvc-binding (do NOT copy; use as `references` field only)
- `exercises/16-hpa/` — prior-art for workloads-scheduling/01-deployment-requests
- `exercises/05-networkpolicy/` — prior-art for services-networking/01-networkpolicy-egress
- `exercises/04-rbac/` — prior-art for cluster-architecture/01-rbac-viewer
- `exercises/11-troubleshoot-cluster/` — prior-art for troubleshooting/01-deploy-svc-mismatch
- `.planning/codebase/CONCERNS.md` — content-bug anchors for trap references

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`cka-sim/lib/grade.sh`** (Phase 2) — 7 assertion helpers with accumulator state. Every `grade.sh` in Phase 3 sources this. `set -uo pipefail` pattern is the grader contract.
- **`cka-sim/lib/traps.sh`** (Phase 2) — 8 detectors + `record_trap` + catalog parser. Graders `source` this for detector access; drills' `grade.sh` calls detectors explicitly per D-01 (Phase 2).
- **`cka-sim/lib/log.sh`** (Phase 1) — `info`/`ok`/`err`/`die`/`header`/`warn` for drill command's status output.
- **`cka-sim/lib/preflight.sh`** (Phase 1) — `check_kubeconfig`, `check_cluster_nodes`. Drill command calls these before running reset.sh (fail fast if cluster unreachable).
- **`cka-sim/bin/cka-sim` router** (Phase 1) — already dispatches `drill` to `lib/cmd/drill.sh`; the stub just says "Not implemented yet — phase 3". Phase 3 replaces that stub body, not the router.
- **`cka-sim/scripts/test.sh`** (Phase 2) — Phase 3 adds `lint-packs.sh` call between `lint-traps.sh` and `run.sh`.
- **`.github/workflows/validate.yml`** (Phase 2) — `bash-tests` job already runs `test.sh`. No workflow changes needed; Phase 3 just extends what test.sh runs.

### Established Patterns
- **Module-per-file under `cka-sim/lib/`:** Phase 3 adds at most one new lib module (`lib/drill.sh` or embedded in `lib/cmd/drill.sh`). Prefer embedding in `lib/cmd/drill.sh` unless Phase 7's exam mode clearly needs to share the orchestrator (revisit in Phase 7).
- **`set -uo pipefail` on accumulating scripts; `set -euo pipefail` on fail-fast.** Graders use `-uo`; setup/reset/ref-solution use `-euo`; `lib/cmd/drill.sh` uses `-euo` with an EXIT trap.
- **Function namespacing:** `cka_sim::drill::run`, `cka_sim::drill::cleanup`, `cka_sim::drill::prompt_ready`.
- **Stderr for status, stdout for parseable output:** `drill` prints its own status (`info "Running setup..."`) to stderr via log.sh; the grader's `SCORE:` / `Trap N:` lines (already stdout-only per Phase 2 D-07) `tee` cleanly into the persisted report.
- **RFC 1123 resource names** (TRIP-07) — extends to pack ids, domain ids, question ids, cluster-scoped resource names (`q<id>-<name>`).

### Integration Points
- **Drill command sets env vars for graders:** `CKA_SIM_QUESTION_ID`, `CKA_SIM_LAB_NS`, `CKA_SIM_PACK_ID`, `CKA_SIM_QUESTION_DIR` — graders read these for context; `grade.sh` can do `kubectl -n "$CKA_SIM_LAB_NS"` without hardcoding.
- **Report path pattern:** `~/.cka-sim/reports/<ISO-ts>-<pack>-<question-id>.md`. Phase 7's `cka-sim score` globs this directory.
- **Catalog extension:** Phase 3 may add 3–5 new trap entries (pvc-wrong-storageclass, deployment-missing-requests, service-label-mismatch, etc.). Catalog lint still enforces the 8-field schema; new entries carry `source: concerns-md` if CONCERNS-derived, else `source: community`.
- **CI extension surface:** `cka-sim/scripts/lint-packs.sh` is called by `test.sh`; `.github/workflows/validate.yml` needs no changes.

</code_context>

<specifics>
## Specific Ideas

### Directory layout (concrete)
```
cka-sim/
├── lib/
│   └── cmd/
│       └── drill.sh                  # REPLACE stub — full drill command (~250 LOC)
├── packs/                            # NEW
│   ├── storage/
│   │   ├── manifest.yaml
│   │   ├── README.md
│   │   └── 01-pvc-binding/
│   │       ├── metadata.yaml
│   │       ├── question.md
│   │       ├── setup.sh
│   │       ├── grade.sh
│   │       ├── reset.sh
│   │       └── ref-solution.sh
│   ├── workloads-scheduling/
│   │   ├── manifest.yaml, README.md
│   │   └── 01-deployment-requests/{6 files}
│   ├── services-networking/
│   │   ├── manifest.yaml, README.md
│   │   └── 01-networkpolicy-egress/{6 files}
│   ├── cluster-architecture/
│   │   ├── manifest.yaml, README.md
│   │   └── 01-rbac-viewer/{6 files}
│   └── troubleshooting/
│       ├── manifest.yaml, README.md
│       └── 01-deploy-svc-mismatch/{6 files}
├── scripts/
│   └── lint-packs.sh                 # NEW (GRADE-02 + PACK-06 lint per D-12)
├── traps/
│   └── catalog.yaml                  # EXTEND — 3–5 new entries for per-question traps
├── AUTHORING.md                      # NEW — partial authoring guide (full ships Phase 8)
└── scripts/test.sh                   # MODIFY — invoke lint-packs.sh after lint-traps.sh
```

### `lib/cmd/drill.sh` skeleton
```bash
#!/bin/bash
set -euo pipefail
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set by bin/cka-sim router}"

source "$CKA_SIM_ROOT/lib/log.sh"
source "$CKA_SIM_ROOT/lib/preflight.sh"
source "$CKA_SIM_ROOT/lib/traps.sh"
source "$CKA_SIM_ROOT/lib/grade.sh"

cka_sim::drill::usage() { ... }   # prints RUN-02 signature
cka_sim::drill::load_pack() { ... }  # parses packs/<pack>/manifest.yaml, picks question (D-03)
cka_sim::drill::cleanup() { ... }    # EXIT trap runs reset.sh + emits exit status
cka_sim::drill::prompt_ready() { ... }  # reads 'done'/'skip'

main() {
  local pack="${1:?usage: cka-sim drill <pack> [<n>]}"
  local picked_n="${2:-}"
  cka_sim::preflight::check_kubeconfig
  cka_sim::preflight::check_cluster_nodes   # ≥3 nodes
  cka_sim::drill::load_pack "$pack" "$picked_n"  # sets CKA_SIM_QUESTION_DIR, CKA_SIM_LAB_NS, etc.
  trap cka_sim::drill::cleanup EXIT
  bash "$CKA_SIM_QUESTION_DIR/reset.sh"
  bash "$CKA_SIM_QUESTION_DIR/setup.sh"
  cat "$CKA_SIM_QUESTION_DIR/question.md"
  info "Lab ns: $CKA_SIM_LAB_NS"
  cka_sim::drill::prompt_ready   # sets action=done|skip
  [[ "$action" == "skip" ]] && exit 130
  # Grade path: tee to stdout + report file
  local report="$HOME/.cka-sim/reports/$(date -u +%Y%m%dT%H%M%SZ)-$pack-$question_id.md"
  { cka_sim::drill::report_header "$pack" "$question_id" ; bash "$CKA_SIM_QUESTION_DIR/grade.sh"; } | tee "$report"
}
main "$@"
```

### Sample `metadata.yaml` (illustrating PACK-06)
```yaml
id: storage-pvc-binding
domain: storage
estimatedMinutes: 8
verified_against: "1.35"
traps:
  - hostpath-pv-without-nodeaffinity
  - pvc-wrong-storageclass         # NEW, added to catalog
  - pv-accessmodes-mismatch        # NEW, added to catalog
references:
  - kind: prior-art-exercise
    target: exercises/12-storage-pv-pvc/
    note: Prior prose version
  - kind: k8s-doc
    target: https://kubernetes.io/docs/concepts/storage/persistent-volumes/
    note: PV/PVC concepts
```

### Sample `setup.sh` (illustrating D-07 + TRIP-05)
```bash
#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"

# Idempotent ns create via apply heredoc
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${CKA_SIM_LAB_NS}
  labels:
    cka-sim/pack: storage
    cka-sim/question-id: storage-pvc-binding
EOF

# Wait for ns to be Active (handles stuck-Terminating from prior reset per D-08)
for i in $(seq 1 10); do
  phase=$(kubectl get ns "$CKA_SIM_LAB_NS" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
  [[ "$phase" == "Active" ]] && break
  sleep 5
done

# ... create PV without nodeAffinity (the trap) + PVC waiting for binding ...
```

### Sample `grade.sh` contract (illustrating Phase 2 integration + D-01)
```bash
#!/bin/bash
set -uo pipefail
: "${CKA_SIM_LAB_NS:?}"
: "${CKA_SIM_ROOT:?}"
source "$CKA_SIM_ROOT/lib/grade.sh"
source "$CKA_SIM_ROOT/lib/traps.sh"

# Assertions
cka_sim::grade::assert_pvc_bound "$CKA_SIM_LAB_NS" "app-data"
cka_sim::grade::assert_pod_ready "$CKA_SIM_LAB_NS" "app"

# Explicit trap detectors
tid=$(cka_sim::trap::detect_hostpath_pv_without_nodeaffinity "app-pv")
[[ -n "$tid" ]] && cka_sim::grade::record_trap "$tid"

# Finalize
cka_sim::grade::emit_result
```

### Platform
- Target: Ubuntu 22.04 on CP node; real kubectl against 1+2 cluster.
- Dev: shellcheck. Unit tests for drill command logic (pack loading, id parsing, manifest lookup) via Phase 2's test harness — live-cluster behavior verified by user, not in static CI.

</specifics>

<deferred>
## Deferred Ideas

- **DF-02 trap-frequency aggregation across sessions** — report files carry forward-compat metadata; aggregator is v1.x.
- **DF-08 hint reveal (drill mode only)** — `question.md` may embed `<details>` hints but the drill command does not surface a `--hint` flag in Phase 3.
- **DF-09 retake with re-randomised draw** — not needed for drill mode (random selection per D-03 is already random); blueprint re-shuffle is Phase 7's `exam --retake` concern.
- **DF-11 `cka-sim author lint <q-dir>`** — authoring-time lint for new questions. The CI `lint-packs.sh` covers the core needed for Phase 3; a candidate-facing authoring CLI is v1.x.
- **DF-12 fixture CI against `kind` cluster** — Phase 3 keeps live-cluster verification as a user-performed step, mirroring Phase 1's pattern.
- **Mid-drill kubectl shell / tmux split** — rejected per D-04 (cat + read is sufficient; matches real exam).
- **Inspect-after-drill** (keep lab alive post-grade) — rejected per D-06; could be reintroduced as `cka-sim drill --inspect <pack>` in v1.x if candidate workflow demands it.
- **Adaptive question selection / first-unsolved** — rejected per D-03; randomness is the drill-mode contract.
- **Shared `cka-sim/lib/drill.sh` orchestration library for exam reuse** — rejected for Phase 3; re-evaluate in Phase 7 if exam mode needs to reuse the drill sequence.
- **Full authoring doc (`cka-sim/AUTHORING.md`)** — Phase 3 ships a partial; complete version lands in Phase 8 (DOC-02).
- **SCHEMA.md for metadata.yaml / manifest.yaml** — Phase 8 (DOC-03). Phase 3 inlines the schema as comments in sample files.

</deferred>

---

*Phase: 3-Runtime Contract + Drill Mode*
*Context gathered: 2026-05-10*
