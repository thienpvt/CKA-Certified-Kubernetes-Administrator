# Authoring Questions for cka-sim

> **Scope:** Partial authoring guide — Phase 3. Covers what a question-author
> needs to ship a correct question today. The full authoring guide (style,
> schema deep-dive, coverage-matrix workflow, CI integration) ships in Phase 8
> (DOC-02). If a topic here reads as incomplete, that is intentional.

## 1. Directory layout

Every question is a directory under `cka-sim/packs/<domain>/<NN>-<slug>/`
containing exactly six files:

| File | Role |
|------|------|
| `metadata.yaml` | Schema-validated question metadata (id, domain, traps, references) |
| `question.md` | Prompt the candidate reads. PSI-style; do NOT spoil the trap. |
| `setup.sh` | Seeds the lab namespace with the broken state |
| `grade.sh` | Asserts post-fix state + records trap ids |
| `reset.sh` | Tears down the lab (idempotent) |
| `ref-solution.sh` | Applies the reference fix; consumed by GRADE-06 round-trip |

The pack itself has two more files at `cka-sim/packs/<domain>/`:

- `manifest.yaml` — pack-level metadata + ordered question list
- `README.md` — one-page pack summary

See `cka-sim/packs/storage/01-pvc-binding/` for the canonical exemplar.

## 2. The six-file contract

### 2.1 metadata.yaml

Required fields (lint-packs.sh enforces):

| Field | Rule |
|-------|------|
| `id` | RFC 1123 (lowercase, `[a-z0-9-]`, ≤63 chars) — unique across all packs |
| `domain` | One of: storage, workloads-scheduling, services-networking, cluster-architecture, troubleshooting |
| `estimatedMinutes` | Integer in `[4, 12]` |
| `verified_against` | Exact string `"1.35"` (the CKA blueprint version the question is validated against) |
| `traps` | List of ≥3 trap ids, each registered in `cka-sim/traps/catalog.yaml` |
| `references` | List of `{kind, target, note}` objects. `kind` ∈ {prior-art-exercise, k8s-doc, concerns-md, community} |

### 2.2 question.md

PSI-style prose. Rules:

- Address the candidate directly: "A Deployment named `web` is running..."
- State the symptom, not the root cause. Do NOT mention the trap.
- List 1–3 numbered tasks. Keep them verb-first and concrete.
- Add a `## Constraints` section that steers the fix (what the candidate
  may and may NOT modify).
- Add a `## Verify yourself` section with the exact kubectl command the
  candidate should run before typing `done` — this becomes their own
  correctness check.
- Use `${CKA_SIM_LAB_NS}` as the namespace placeholder; the drill runner
  substitutes the actual namespace when presenting the prompt.

### 2.3 setup.sh

Seeds the broken state. Rules (D-07, D-09):

- `#!/bin/bash` then `set -euo pipefail`
- Hard-require `CKA_SIM_LAB_NS`: `: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"`
- Use `kubectl apply -f - <<EOF ... EOF` heredocs for every resource. Never
  `kubectl create` without `--dry-run=client -o yaml | kubectl apply -f -`.
- Wait up to 50s for the namespace to become `Active` after apply — prior
  `reset.sh` uses `--wait=false` and the namespace may be Terminating.
  (10 retries × 5s sleep.)
- Cluster-scoped resources MUST be prefixed with `q<NN>-` (e.g.,
  `q01-app-pv`) — TRIP-03 name-collision guard.
- Pin container images to a specific tag (`nginx:1.27-alpine`, not `:latest`;
  `nicolaka/netshoot:v0.13`, not `:latest`). Reproducibility matters more
  than being current.
- **DO NOT self-guard against prior state.** The runner (`lib/cmd/drill.sh`)
  owns cleanup via `reset.sh → setup.sh`. `kubectl delete ns ...` at the
  top of `setup.sh` is rejected by lint-packs.sh.

### Grading Honesty

All graders MUST use the delta-aware assertion helpers to avoid scoring setup state.
See [GRADING-HONESTY.md](GRADING-HONESTY.md) for the full baselining contract,
helper API reference, and caveats.

### 2.4 grade.sh

Asserts post-fix state + records trap ids. Rules (D-01 from Phase 2, GRADE-02):

- `#!/bin/bash` then `set -uo pipefail` (NOT `-e` — assertions accumulate)
- Hard-require `CKA_SIM_LAB_NS` and `CKA_SIM_ROOT`
- `source "$CKA_SIM_ROOT/lib/grade.sh"` and `source "$CKA_SIM_ROOT/lib/traps.sh"`
- Use the 7 assertion helpers (`cka_sim::grade::assert_*`) — these own
  the accumulator state and emit the ✓/✗ live output.
- Call detector functions explicitly: `tid=$(cka_sim::trap::detect_X ...)`
  then `[[ -n "$tid" ]] && cka_sim::grade::record_trap "$tid"`.
- End with `cka_sim::grade::emit_result`.
- **BANNED patterns** (lint-packs.sh rejects):
  - `kubectl get ... | ... grep` — use `kubectl get ... -o jsonpath=` or
    `-o name` instead (GRADE-02).
  - `kubectl get -A ...` — namespace-scope every query.
  - `kubectl (delete|create|apply|patch|edit|replace)` — graders never
    mutate cluster state. Allowed verbs: `get`, `auth can-i`, `exec`,
    `describe`, `wait`, `logs`.

### 2.5 reset.sh

Tears down the lab. Rules (D-08):

- `#!/bin/bash` then `set -uo pipefail` (NOT `-e` — multi-resource deletes
  proceed even if one 404s)
- `kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false`
- For cluster-scoped resources (the `q<NN>-` prefixed ones),
  `kubectl delete <kind> <name> --ignore-not-found`, one line each.
- `exit 0` at the end — reset is advisory, not blocking.

### 2.6 ref-solution.sh

Applies the reference fix. Rules (D-11, GRADE-06):

- `#!/bin/bash` then `set -euo pipefail`
- Hard-require `CKA_SIM_LAB_NS`
- The smallest set of kubectl invocations that takes the broken state
  from setup.sh to a state where grade.sh passes all assertions.
- Candidates do NOT see or run this file during drills. Only the GRADE-06
  round-trip (§3) invokes it.

## 3. GRADE-06 round-trip — human verification

The GRADE-06 contract says every question must round-trip cleanly: under
setup alone the grader fails; under setup + ref-solution the grader
passes. Phase 3 enforces this as a **human-verification step** on the
CP node — a live kubectl-backed CI fixture (a kind cluster job) is
explicitly deferred (DF-12, revisit in v1.x).

Procedure (runs in ~2 minutes per question on a healthy cluster). Use a
**fresh namespace per round** — `reset.sh` uses `kubectl delete ns
--wait=false`, so re-using the same namespace across rounds can collide
with a still-`Terminating` ns and time out `setup.sh`'s 50s Active-wait:

```bash
export CKA_SIM_ROOT=$(pwd)/cka-sim
cd cka-sim/packs/<domain>/<NN>-<slug>

# 1. Round-trip FAIL path (fresh ns)
export CKA_SIM_LAB_NS=verify-fail-$(date +%s%N)
bash reset.sh >/dev/null
bash setup.sh
bash grade.sh ; fail_rc=$?     # expect non-zero (assertions fail, trap recorded)
bash reset.sh >/dev/null

# 2. Round-trip PASS path (fresh ns)
export CKA_SIM_LAB_NS=verify-pass-$(date +%s%N)
bash reset.sh >/dev/null
bash setup.sh
bash ref-solution.sh
bash grade.sh ; pass_rc=$?     # expect zero (all assertions pass, no unresolved trap)
bash reset.sh >/dev/null

[[ $fail_rc -ne 0 && $pass_rc -eq 0 ]] && echo "round-trip OK" || echo "BROKEN"
```

What lint-packs.sh enforces instead (catches most round-trip breakage
statically):

- All four scripts are syntactically valid (`bash -n`)
- All four scripts are executable (`chmod +x`)
- ref-solution.sh exists
- No setup.sh starts with `kubectl delete ns` (runner-owned-cleanup)
- No grade.sh uses banned idioms (`get | grep`, `get -A`, mutating verbs)
- metadata.yaml schema matches (6 required fields; trap ids in catalog)

## 4. Extending the trap catalog

Add a new entry to `cka-sim/traps/catalog.yaml` when a question needs a
detector that does not already exist. Schema (D-13 in Phase 2):

| Field | Rule |
|-------|------|
| `id` | RFC 1123 (Phase 2 `is_valid_id`) |
| `name` | Human-readable short name |
| `description` | Single sentence explaining what the trap is |
| `remediation_hint` | Single sentence explaining the fix |
| `references` | List of `{kind, target, note}` |
| `severity` | One of: info, warn, error |
| `domain` | Matches the pack domain |
| `source` | One of: cncf-curriculum, concerns-md, community |

Every new id MUST have a paired `cka_sim::trap::detect_<id>` function in
`cka-sim/lib/traps.sh`. `lint-traps.sh` + `lint-packs.sh` both enforce
the id registration; the detector function must echo the exact same id
on hit.

## 5. lint-packs.sh — rule summary

Run `bash cka-sim/scripts/test.sh` to execute the full lint + test suite.
Individual rules enforced by `lint-packs.sh`:

| Pass | Rule |
|------|------|
| A | `grade.sh` has no `kubectl get ... \| ... grep` (comment-stripped) |
| A | `grade.sh` has no `kubectl get -A` |
| B | `grade.sh` uses no mutating verbs (`delete`/`create`/`apply`/`patch`/`edit`/`replace`) |
| C | `setup.sh` does NOT start with `kubectl delete ns` (D-09 guard) |
| D | Every question directory has all 6 required files; 4 scripts are executable |
| E | `metadata.yaml` has all 6 required fields with valid values; every trap id registered in `traps/catalog.yaml` |

## 6. What lives in Phase 8 instead

Intentionally deferred to the full authoring guide (DOC-02):

- Stylistic guidance for PSI-voice question prose
- Detailed schema reference (`SCHEMA.md`) for metadata.yaml and manifest.yaml
- Coverage-matrix authoring workflow (PACK-07)
- How to co-evolve `question.md`, the trap catalog, and reference exercises
- Contributor walkthrough (from-scratch question template)
- CI-run expectations and failure-triage patterns

If you need any of the above today, read `cka-sim/packs/storage/01-pvc-binding/`
as the working exemplar and the decisions in
`.planning/phases/03-runtime-contract-drill-mode/03-CONTEXT.md`.

## Style Guide

Question prose in `question.md` follows PSI-style conventions:

- Use imperative voice addressing the candidate directly: "Create a PVC...", "Fix the Deployment..."
- State the symptom, never the root cause. Do not mention the trap by name.
- Include the context namespace using `${CKA_SIM_LAB_NS}` — the runner substitutes it.
- State the expected outcome clearly: "The Pod should reach Running state within 60s."
- Keep tasks numbered (1-3 max), verb-first, concrete and unambiguous.
- Add `## Constraints` (what the candidate may/may not modify) and `## Verify yourself` (the kubectl command to self-check).

## Schema Deep-Dive

Full field reference for `metadata.yaml`:

| Field | Type | Rule |
|-------|------|------|
| `id` | string | RFC 1123 — lowercase `[a-z0-9-]`, ≤63 chars, unique across all packs |
| `domain` | enum | One of: storage, workloads-scheduling, services-networking, cluster-architecture, troubleshooting |
| `estimatedMinutes` | integer | Range `[4, 12]` — time budget for a prepared candidate |
| `verified_against` | string | Exact k8s version the question was validated on (currently `"1.35"`) |
| `traps` | array | ≥3 trap IDs, each must exist in `cka-sim/traps/catalog.yaml` |
| `references` | array | Objects with `{kind, target, note}`. `kind` ∈ {prior-art-exercise, k8s-doc, concerns-md, community} |

See `cka-sim/SCHEMA.md` for full YAML examples of all schemas.

## Coverage-Matrix Workflow

When adding a new question to a domain pack:

1. Create the question directory: `cka-sim/packs/<domain>/<NN>-<slug>/` with all 6 required files
2. Add the question entry to the pack's `manifest.yaml` (id, path, estimatedMinutes)
3. Update `coverage.yaml` to reflect the new topic/trap coverage
4. Run `bash cka-sim/scripts/lint-coverage.sh` to verify no gaps or duplicates
5. Run `bash cka-sim/scripts/test.sh` to confirm the full suite passes

The coverage matrix tracks which CKA curriculum objectives have drill coverage and which traps are exercised. Gaps show up as warnings in lint output.

## CI Integration

`lint-packs.sh` runs automatically in the test suite and enforces these passes:

| Pass | What it checks |
|------|----------------|
| A | No `kubectl get ... \| grep` or `kubectl get -A` in grade.sh |
| B | No mutating verbs in grade.sh (delete/create/apply/patch/edit/replace) |
| C | setup.sh does not start with `kubectl delete ns` (runner owns cleanup) |
| D | All 6 required files present; 4 scripts are executable |
| E | metadata.yaml schema valid; all trap IDs registered in catalog |
| F | Exam manifest structure and weighting totals |
| G | Pack manifest question ordering matches directory numbering |
| H | Coverage.yaml consistency with manifest entries |

Run locally: `bash cka-sim/scripts/lint-packs.sh`. Any failure blocks a PR merge. Fix the reported pass letter and re-run.

## Trap Registration Flow

To add a new trap to the system:

1. Add an entry to `cka-sim/traps/catalog.yaml` with all required fields (id, name, description, remediation_hint, references, severity, domain, source)
2. Write a `cka_sim::trap::detect_<id>` function in `cka-sim/lib/traps.sh` — it must echo the exact trap ID on detection, empty string otherwise
3. Add fixture files under `cka-sim/tests/fixtures/` that reproduce the trap condition
4. Add a test case in the appropriate test file that exercises the detector
5. Run `bash cka-sim/scripts/test.sh` — lint-traps.sh verifies every catalog ID has a paired detector function
