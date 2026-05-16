# Phase 3: Runtime Contract + Drill Mode — Pattern Map

**Mapped:** 2026-05-10
**Files analyzed:** 36 (1 replace + 1 modify + 1 extend + 33 new)
**Analogs found:** 33 / 36 (the 3 with no in-repo analog are setup.sh, reset.sh, ref-solution.sh — pure k8s YAML idioms documented inline)

This phase is heavily de-risked: nearly every new file maps to an existing Phase 1+2 analog. The genuinely-new shapes (setup.sh / reset.sh / question.md / ref-solution.sh) are simple k8s+bash idioms that are fully spelled out in CONTEXT `<specifics>` and RESEARCH `Pattern 3`/`Pattern 4`/`Pattern 5`.

---

## File Classification

| File (new / modify / replace / extend) | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `cka-sim/lib/cmd/drill.sh` (REPLACE stub) | command/orchestrator | request-response (interactive CLI) | `cka-sim/lib/cmd/doctor.sh` + `cka-sim/lib/cmd/bootstrap.sh` | exact (shape) |
| `cka-sim/scripts/lint-packs.sh` (NEW) | lint script | batch validation | `cka-sim/scripts/lint-traps.sh` | exact |
| `cka-sim/scripts/test.sh` (MODIFY) | test orchestrator | sequential script | self (Phase 2 shape) | exact |
| `cka-sim/traps/catalog.yaml` (EXTEND ×3-5) | data/config | flat YAML | `cka-sim/traps/catalog.yaml` (8 existing entries) | exact |
| `cka-sim/packs/<domain>/manifest.yaml` (NEW ×5) | data/config | flat YAML | `cka-sim/traps/catalog.yaml` (parser idiom) | role-match |
| `cka-sim/packs/<domain>/README.md` (NEW ×5) | docs | static markdown | (no in-repo pack README) | no analog (use CONVENTIONS.md style) |
| `cka-sim/packs/<domain>/<NN>-<slug>/metadata.yaml` (NEW ×5) | data/config | flat YAML | `cka-sim/traps/catalog.yaml` entries (per-id field block) | role-match |
| `cka-sim/packs/<domain>/<NN>-<slug>/question.md` (NEW ×5) | content/prose | static markdown | RESEARCH §"question.md skeleton" + `exercises/<topic>/README.md` (prior-art only — do NOT copy) | no in-repo analog (RESEARCH provides skeleton) |
| `cka-sim/packs/<domain>/<NN>-<slug>/setup.sh` (NEW ×5) | setup/seeder | apply-heredoc + wait | (none in repo) | no analog (CONTEXT `<specifics>` + RESEARCH Pattern 3 are the spec) |
| `cka-sim/packs/<domain>/<NN>-<slug>/grade.sh` (NEW ×5) | grader/asserter | request-response (kubectl reads) | `cka-sim/tests/cases/grade_assert_pvc_bound.sh` (sources lib/grade.sh, calls helpers) + `cka-sim/tests/cases/traps_hostpath-pv-without-nodeaffinity.sh` (sources lib/traps.sh, calls detector) | role-match |
| `cka-sim/packs/<domain>/<NN>-<slug>/reset.sh` (NEW ×5) | teardown | fire-and-forget | (none in repo) | no analog (CONTEXT D-08 + RESEARCH Pattern 4 are the spec) |
| `cka-sim/packs/<domain>/<NN>-<slug>/ref-solution.sh` (NEW ×5) | reference fix | apply/patch sequence | (none in repo) | no analog (paired with the question's setup.sh) |
| `cka-sim/AUTHORING.md` (NEW partial) | docs | static markdown | RESEARCH §"question.md skeleton" + `.planning/codebase/CONVENTIONS.md` (style ref) | no in-repo analog |

---

## Pattern Assignments

### `cka-sim/lib/cmd/drill.sh` (REPLACE the 13-line stub) — orchestrator

**Analog A (overall shape, sourcing block, set options, top-level main pattern):** `cka-sim/lib/cmd/doctor.sh`

**Imports + set-options + CKA_SIM_ROOT guard** (`doctor.sh:1-16`, replace `-uo` with `-euo`):
```bash
#!/bin/bash
set -euo pipefail   # NOTE: doctor uses -uo (aggregate failures); drill uses -euo (fail-fast on orchestration errors)
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"
# shellcheck source=../colors.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/colors.sh"
# shellcheck source=../log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"
# shellcheck source=../preflight.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/preflight.sh"
```

**Preflight call pattern** (`doctor.sh:36-40, 52-58`):
```bash
if kubeconfig_path=$(cka_sim::preflight::check_kubeconfig); then ...
if cluster_counts=$(cka_sim::preflight::check_cluster_nodes); then ...
```
Drill.sh consumes both before reset.sh per RESEARCH `main()` skeleton lines 670-674. Use `>/dev/null` to suppress the path/counts since drill only needs the success/failure signal (vs. doctor which prints them).

**Confirmation prompt pattern** (`bootstrap.sh:39-48`, `_confirm` helper) — drill's `prompt_ready` follows the same shape:
```bash
_confirm() {
  local prompt="$1"
  local reply=""
  printf '%s [y/N] ' "$prompt" >&2
  read -r reply || reply=""    # <-- IMPORTANT: `|| reply=""` handles EOF (Pitfall 4)
  case "$reply" in ...
}
```
Drill's `cka_sim::drill::prompt_ready` mirrors this exactly: `printf` to stderr, `IFS= read -r`, EOF → "skip" default, case-block returns the action. RESEARCH §"Drill orchestrator skeleton" lines 622-630 is the verbatim implementation.

**Header + step logging pattern** (`bootstrap.sh:52, 54-57, 59-65, 99-191` — `header`/`info`/`ok`/`warn`/`die` from log.sh):
```bash
header "cka-sim bootstrap"
info "checking kubeconfig"
ok "kubeconfig: $kubeconfig_path"
```
Drill.sh uses identical idiom: `header "drill: $pack / $qid (lab ns: $ns)"`, then `info "step 1/4: reset"`, etc.

**Trap+cleanup pattern** (NEW — no Phase 1 analog, but standard bash idiom; see RESEARCH Pitfall 1+2 for the EXIT-trap discussion). Trap registration MUST live in `main()` body (not inside the cleanup function — see RESEARCH Pitfall 2 anti-pattern).

**Replication notes:**
- Copy doctor.sh's source-block verbatim, ADD `lib/preflight.sh` (already in doctor) but DO NOT source `lib/grade.sh` or `lib/traps.sh` (RESEARCH Pitfall 5 — graders source themselves).
- Use `set -euo pipefail` (drill is fail-fast orchestration), unlike doctor's `set -uo pipefail` (aggregate failures).
- Function namespace `cka_sim::drill::*` per RESEARCH §"Established Patterns".
- Use `mktemp` + atomic `mv` for the report file per RESEARCH Pitfall 1 — DO NOT use `bash grade.sh | tee "$report"`.

**Differences from doctor.sh:**
- Drill is interactive (reads stdin); doctor is read-only.
- Drill registers an EXIT trap; doctor does not.
- Drill captures grade.sh stdout to a tempfile then atomic-mv; doctor only emits to stderr.
- Drill's exit code is grade.sh's exit code (or 130 on skip); doctor's is `failures > 0 ? 1 : 0`.

---

### `cka-sim/scripts/lint-packs.sh` (NEW) — pack lint

**Analog:** `cka-sim/scripts/lint-traps.sh` (Phase 2)

**Header + REPO_ROOT + sourcing block** (`lint-traps.sh:1-16`):
```bash
#!/bin/bash
set -euo pipefail
CKA_SIM_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$CKA_SIM_ROOT/.." && pwd)"
source "$CKA_SIM_ROOT/lib/colors.sh"
source "$CKA_SIM_ROOT/lib/log.sh"
header "trap catalog lint"
```
lint-packs.sh changes only the `header` text and ADDS `source "$CKA_SIM_ROOT/lib/traps.sh"` (for `is_valid_id` + `id_exists` reuse per CONTEXT D-12(c) and RESEARCH §"Don't Hand-Roll").

**Wave-0 graceful skip pattern** (`lint-traps.sh:18-27`):
```bash
catalog="$CKA_SIM_ROOT/traps/catalog.yaml"
if [[ ! -f "$catalog" ]]; then
  warn "catalog not found: $catalog — skipping lint (expected during plan 02-03 scaffold verification)"
  exit 0
fi
```
lint-packs uses the identical idiom for missing `cka-sim/packs/`:
```bash
[[ -d "$CKA_SIM_ROOT/packs" ]] || { warn "no packs/ dir — skipping lint (expected during scaffold)"; exit 0; }
```
Verbatim per RESEARCH §"lint-packs.sh skeleton" lines 734-735.

**State machine + per-entry validator pattern** (`lint-traps.sh:68-115` — `_validate_entry` + the line walk loop). For each `metadata.yaml`:
- Parse the file with the same `[[ "$line" =~ ... ]]` + `BASH_REMATCH` idiom.
- Track `current_id`, `current_fields[]`, `current_traps[]`, `current_refs[]`.
- On end of entry, check required-fields completeness, RFC-1123 id, enum membership.

**Reuse `is_valid_id` + `id_exists`** (`lint-traps.sh:32, 90`):
```bash
source "$CKA_SIM_ROOT/lib/traps.sh"   # imports is_valid_id + id_exists
...
if ! cka_sim::trap::is_valid_id "$current_id"; then
  err "trap[$current_id]: id is not RFC 1123 ..."
fi
```
lint-packs.sh reuses BOTH functions — `is_valid_id` for metadata.yaml's `id:` field (and its declared trap-ids), `id_exists` for verifying every metadata trap-id is registered in catalog.yaml (per CONTEXT D-12(c)).

**Quote-stripping helper** (`lint-traps.sh:117-122`, `_strip_quotes`):
```bash
_strip_quotes() {
  local v="$1"
  v="${v#\"}"; v="${v%\"}"
  v="${v#\'}"; v="${v%\'}"
  printf '%s' "$v"
}
```
Copy verbatim into lint-packs.sh.

**Error counter + final report pattern** (`lint-traps.sh:55-57, 193-200`):
```bash
errors=0
checked=0
...
if (( errors > 0 )); then
  err "$errors lint error(s) across $checked entr(ies). Fix before pushing."
  exit 1
else
  ok "catalog lint passed ($checked entr(ies))."
  exit 0
fi
```
lint-packs.sh follows the identical pattern with `checked=` counting question dirs (or grade.sh files).

**GRADE-02 regex pattern** (NEW — no Phase 2 analog; RESEARCH Pitfall 2 + §"lint-packs.sh skeleton" lines 743-752 is the spec):
```bash
# Pass A: kubectl get ... | grep
grep -nE '^[[:space:]]*[^#]*kubectl[[:space:]]+get[[:space:]].*\|[[:space:]]*grep' "$grade_sh"
# Pass B: kubectl get -A
grep -nE '^[[:space:]]*[^#]*kubectl[[:space:]]+get[[:space:]]+-A([[:space:]]|$)' "$grade_sh"
```
Both regexes use `[^#]*` after the leading whitespace to skip commented lines. Pair with positive + negative test fixtures (RESEARCH §"Wave 0 Gaps").

**setup.sh `kubectl delete ns` guard** (NEW per CONTEXT D-12(f)):
```bash
grep -nE '^[[:space:]]*[^#]*kubectl[[:space:]]+delete[[:space:]]+(namespace|ns)([[:space:]]|$)' "$setup_sh"
```
Same shape as the GRADE-02 regex — line-anchored, comment-skipping. RESEARCH §"lint-packs.sh skeleton" lines 776-781.

**File-existence + executable check** (NEW per CONTEXT D-12(d)(e)):
```bash
for f in metadata.yaml question.md setup.sh grade.sh reset.sh ref-solution.sh; do
  [[ -e "$q_dir/$f" ]] || { err "$q_dir: missing $f"; errors=$(( errors + 1 )); }
done
for f in setup.sh grade.sh reset.sh ref-solution.sh; do
  [[ -x "$q_dir/$f" ]] || { err "$q_dir/$f: not executable"; errors=$(( errors + 1 )); }
done
```

**Replication notes:**
- Copy lint-traps.sh's structure 1:1 — header, set-options, REPO_ROOT, sourcing, error counter, final-report epilogue.
- Reuse `_strip_quotes` and `_in_array` helpers verbatim.
- Reuse `cka_sim::trap::is_valid_id` and `cka_sim::trap::id_exists` (DO NOT re-implement).
- Add the four NEW lint passes: GRADE-02 regex, kubectl-delete-ns-in-setup guard, six-files presence, four-files executable.
- Add metadata.yaml schema validator (id, domain ∈ closed enum, estimatedMinutes ∈ [4,12], verified_against == "1.35", traps[] ≥ 3, references[]).
- Wave-0 graceful skip for missing `packs/`.

**Differences from lint-traps.sh:**
- Walks a directory tree (`find ... -name 'metadata.yaml'`) instead of a single file.
- Two file types to lint: `metadata.yaml` (schema) AND `grade.sh` / `setup.sh` (regex bans).
- No "seed completeness" check (lint-traps had `seed_ids` to enforce all 8 GRADE-05 ids present; lint-packs does NOT need this — packs grow over time).
- Reuses traps.sh's `id_exists` (lint-traps owned the catalog; lint-packs is downstream of it).

---

### `cka-sim/scripts/test.sh` (MODIFY — add lint-packs.sh call) — test orchestrator

**Self-analog:** `cka-sim/scripts/test.sh` (current Phase 2 shape, lines 18-24).

**Existing pattern** (`test.sh:18-24`):
```bash
info "step 1: lint trap catalog"
"$CKA_SIM_ROOT/scripts/lint-traps.sh"
ok "catalog lint passed"

info "step 2: run bash unit cases"
"$CKA_SIM_ROOT/tests/run.sh"
ok "all unit cases passed"
```

**Modification:** Insert a step 2 before the run.sh call (and renumber):
```bash
info "step 2: lint packs"
"$CKA_SIM_ROOT/scripts/lint-packs.sh"
ok "pack lint passed"

info "step 3: run bash unit cases"
"$CKA_SIM_ROOT/tests/run.sh"
ok "all unit cases passed"
```
Per CONTEXT D-12 ("Wired into `cka-sim/scripts/test.sh` after `lint-traps.sh`"). Per RESEARCH `Code Examples` no GHA workflow change needed — `bash-tests` already runs `test.sh`.

**Replication notes:**
- Three-line insertion. No structural change.
- Optional: add the bash-version guard from RESEARCH Pitfall 7 at the top of test.sh (`[[ "${BASH_VERSINFO[0]}" -ge 4 ]] || die "bash >= 4.2 required"`).

**Differences:** None — pure extension.

---

### `cka-sim/traps/catalog.yaml` (EXTEND with 3-5 new entries) — trap registry

**Self-analog:** existing 8 entries in `cka-sim/traps/catalog.yaml` (lines 9-149).

**Per-entry block pattern** (`catalog.yaml:78-94` — `hostpath-pv-without-nodeaffinity` is the closest schema example for a state-based trap):
```yaml
  - id: hostpath-pv-without-nodeaffinity
    name: hostPath PV without nodeAffinity
    description: "hostPath PV declared without spec.nodeAffinity; works on single-node but breaks silently on multi-node clusters."
    remediation_hint: Add spec.nodeAffinity pinning the PV to a specific node, or use a non-hostPath StorageClass.
    severity: warn
    domain: storage
    source: concerns-md
    references:
      - kind: concerns-md
        target: .planning/codebase/CONCERNS.md
        note: "Security Example Hygiene - hostPath PVs everywhere, no node-pinning"
      - kind: prior-art-exercise
        target: exercises/12-storage-pv-pvc/
        note: Exercise PV missing nodeAffinity
      - kind: k8s-doc
        target: "https://kubernetes.io/docs/concepts/storage/volumes/#hostpath"
        note: hostPath docs
```

**Replication notes:**
- 8 fields per entry, in the EXACT order: `id, name, description, remediation_hint, severity, domain, source, references`. Field order is enforced by lint-traps.sh.
- Indentation is fixed: `  - id:` (2-space), `    <field>:` (4-space), `      - kind:` (6-space dash for ref items), `        target:` (8-space).
- `severity ∈ {info, warn, error}`; `domain ∈ {troubleshooting, cluster-architecture, services-networking, workloads-scheduling, storage}`; `source ∈ {cncf-curriculum, concerns-md, community}` per `lint-traps.sh:35-38`.
- For new traps not in CONCERNS.md, set `source: community` (per CONTEXT `<code_context>` "Catalog extension"). Skip `references[].kind == concerns-md` if there's no CONCERNS anchor.
- `references[].target` for `kind == concerns-md` or `kind == prior-art-exercise` MUST resolve under repo root (lint-traps.sh:106-110 enforces).
- IDs must pass `cka_sim::trap::is_valid_id` — RFC 1123 (`[a-z0-9]([a-z0-9-]*[a-z0-9])?`, ≤63 chars).

**Candidate new IDs (per RESEARCH Pattern 5 + CONTEXT `<specifics>` D-10):**
- `pvc-wrong-storageclass` (storage)
- `pv-accessmodes-mismatch` (storage)
- `deployment-missing-requests` (workloads-scheduling)
- `service-selector-empty-endpoints` (troubleshooting)
- `deployment-svc-label-mismatch` (troubleshooting)

**Differences:** None — additive only. Order MUST be: catalog extension lands BEFORE any metadata.yaml that references new IDs (RESEARCH Open Q5).

---

### `cka-sim/packs/<domain>/manifest.yaml` (NEW ×5) — pack manifest

**Analog:** `cka-sim/traps/catalog.yaml` (parser idiom + flat YAML shape).

**Schema** (per CONTEXT D-02):
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

**Parser pattern (used by drill.sh `load_pack`):** RESEARCH Pattern 2 lines 195-225 spells out the exact `[[ =~ ]]` + `BASH_REMATCH` walk. Mirrors `traps.sh:60-114` two-state-machine: `pack:` vs `questions:` scope tracked by `in_questions=0/1` flag.

**Replication notes:**
- 4-space indent for `pack:` fields, 2-space dash for `questions:` items (matching catalog.yaml's idiom — though the indent levels differ).
- Pack `id` must equal directory name (e.g., `storage` ↔ `cka-sim/packs/storage/`).
- Pack `domain` must be in the same enum as `lint-traps.sh:36`.
- Question `id` is referenced by metadata.yaml's `id:` field — they MUST match (lint-packs cross-checks).
- Question `path` is the directory slug under the pack (e.g., `01-pvc-binding`); decouples from `id` so slugs can drift.
- `estimatedMinutes` MUST equal the per-question metadata.yaml value (lint enforces).

**Differences from catalog.yaml:**
- Two-section structure (pack-meta + questions list) vs catalog's flat trap list.
- New keys (`weight`, `description`, `path`) not in catalog schema.

---

### `cka-sim/packs/<domain>/<NN>-<slug>/metadata.yaml` (NEW ×5) — per-question metadata

**Analog:** A single trap entry in `cka-sim/traps/catalog.yaml` (top-level keys + a `references:` sub-list).

**Schema** (per CONTEXT D-12(b) + `<specifics>` "Sample metadata.yaml"):
```yaml
id: storage-pvc-binding
domain: storage
estimatedMinutes: 8
verified_against: "1.35"
traps:
  - hostpath-pv-without-nodeaffinity
  - pvc-wrong-storageclass
  - pv-accessmodes-mismatch
references:
  - kind: prior-art-exercise
    target: exercises/12-storage-pv-pvc/
    note: Prior prose version
  - kind: k8s-doc
    target: https://kubernetes.io/docs/concepts/storage/persistent-volumes/
    note: PV/PVC concepts
```

**Replication notes:**
- Top-level fields (no `pack:` wrapper, unlike manifest.yaml). Six required fields per CONTEXT D-12(b): `id`, `domain`, `estimatedMinutes ∈ [4,12]`, `verified_against == "1.35"`, `traps: [≥3]`, `references: []`.
- `id` MUST equal the manifest.yaml `questions[*].id` for the same question.
- `domain` MUST match the parent pack's `domain`.
- `traps[]` MUST have ≥3 entries; every entry MUST be in catalog.yaml (lint enforces via `id_exists`).
- `references[]` shape mirrors catalog.yaml's references sub-list (kind/target/note). Same enum constraint on `kind`.

**Differences from catalog.yaml entry:**
- No top-level `- id:` dash (metadata.yaml is one entry per file, not a list).
- Adds `traps:` list (catalog has none — it IS the catalog).
- Adds `verified_against:` (catalog has no version pinning).
- Adds `estimatedMinutes:` (catalog has none).

---

### `cka-sim/packs/<domain>/<NN>-<slug>/grade.sh` (NEW ×5) — grader

**Analog A (sourcing + lib/grade.sh assertion call shape):** `cka-sim/tests/cases/grade_assert_pvc_bound.sh`

**Sourcing block** (`grade_assert_pvc_bound.sh:3-10`):
```bash
#!/bin/bash
set -uo pipefail   # NOTE: -uo, NOT -euo — graders accumulate failures per Phase 2 D-05
: "${CKA_SIM_ROOT:?must be set}"
source "$CKA_SIM_ROOT/lib/grade.sh"
source "$CKA_SIM_ROOT/lib/traps.sh"
```
Test cases additionally source `tests/lib/assert.sh` and reset accumulators — production grade.sh files do NOT do those things (lib/grade.sh's `declare -ag CKA_SIM_GRADE_*=()` initializes them on first source per `grade.sh:21-25`).

**Assertion call pattern** (`grade_assert_pvc_bound.sh:22`):
```bash
cka_sim::grade::assert_pvc_bound cka-sim-test data || true
```
Production grade.sh per CONTEXT `<specifics>` "Sample grade.sh contract":
```bash
cka_sim::grade::assert_pvc_bound "$CKA_SIM_LAB_NS" "app-data"
cka_sim::grade::assert_pod_ready "$CKA_SIM_LAB_NS" "app"
```
NOTE: production graders DROP the `|| true` — `set -uo pipefail` (no `-e`) means a failed assertion returns 1 but the script continues (Phase 2 D-06 guarantee).

**Analog B (detector call shape):** `cka-sim/tests/cases/traps_hostpath-pv-without-nodeaffinity.sh`

**Detector call pattern** (`traps_hostpath-pv-without-nodeaffinity.sh:16, 21, 26`):
```bash
r=$(cka_sim::trap::detect_hostpath_pv_without_nodeaffinity data-hostpath || true)
```
Production grade.sh per CONTEXT `<specifics>`:
```bash
tid=$(cka_sim::trap::detect_hostpath_pv_without_nodeaffinity "app-pv")
[[ -n "$tid" ]] && cka_sim::grade::record_trap "$tid"
```
Use `record_trap` (Phase 2 lib/grade.sh) to register hits — DO NOT manually format `Trap N:` lines.

**Finalize pattern** (CONTEXT `<specifics>`):
```bash
cka_sim::grade::emit_result    # prints SCORE: N/M + Trap N: lines to stdout
```
Phase 2 D-07 owns the format; do not re-implement.

**Env-var consumption** (CONTEXT D-12(c) integration):
```bash
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"
```
Drill.sh exports these (RESEARCH `load_pack` line 619); graders read them without hardcoding.

**Replication notes:**
- `set -uo pipefail` (NOT `-euo` — failed assertions must not abort the grader).
- Source ONLY `lib/grade.sh` and `lib/traps.sh` (lib/grade.sh transitively sources colors.sh, log.sh, traps.sh).
- Use ONLY the 7 assertion helpers + 8 detectors from Phase 2. Do not invent new detectors in Phase 3 — extend the catalog and add custom logic per-question if needed.
- Forbidden idioms (lint-packs enforces): `kubectl get | grep`, `kubectl get -A`, `kubectl create/delete/apply/patch/edit/replace` (RESEARCH Open Q2 recommends adding the latter as a Claude's-Discretion lint).
- Per-question detector wirings — copy from RESEARCH Pattern 5 (verified per-question kubectl idioms for all 5 reference questions).
- For services-networking/01: assertion helper `assert_egress_allowed` is TCP-only (`/dev/tcp`); use a custom `kubectl exec ... nslookup` probe for UDP/53 DNS instead (RESEARCH Pattern 5 footnote).
- For workloads-scheduling/01: ADD `kubectl wait --for=condition=Available deployment/load-app -n "$CKA_SIM_LAB_NS" --timeout=60s` BEFORE the `default-sa-used` detector call (RESEARCH Assumption A4).

**Differences from test fixtures:**
- Production graders skip the `|| true` after each assertion (production graders use `-uo`, not `-euo`).
- Production graders never reset accumulators (lib/grade.sh initializes them; tests reset to isolate cases).
- Production graders end with `cka_sim::grade::emit_result`; tests end with `exit "$case_failed"`.

---

### `cka-sim/packs/<domain>/<NN>-<slug>/setup.sh` (NEW ×5) — seeder

**Analog:** No in-repo bash-script analog. The closest reference is **CONTEXT `<specifics>` "Sample setup.sh"** (lines 248-289 of CONTEXT) and **RESEARCH Pattern 3** (lines 229-290).

**Header pattern** (CONTEXT `<specifics>`):
```bash
#!/bin/bash
set -euo pipefail   # fail-fast on any setup error
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
```

**Idempotent ns create + Active wait pattern** (CONTEXT `<specifics>` + RESEARCH Pattern 3, RESEARCH Pitfall 3):
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${CKA_SIM_LAB_NS}
  labels:
    cka-sim/pack: storage
    cka-sim/question-id: storage-pvc-binding
EOF

# Wait up to 50s for ns to be Active (handles prior reset --wait=false leaving Terminating ns)
for i in $(seq 1 10); do
  phase=$(kubectl get ns "$CKA_SIM_LAB_NS" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
  [[ "$phase" == "Active" ]] && break
  sleep 5
done
[[ "$phase" == "Active" ]] || { echo "ns $CKA_SIM_LAB_NS not Active after 50s (phase=$phase)" >&2; exit 1; }
```

**Resource seeding pattern** (CONTEXT `<specifics>`):
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: q01-app-pv         # cluster-scoped → q<NN>- prefix per TRIP-03
spec:
  ...
EOF
```

**Replication notes:**
- `set -euo pipefail` (fail-fast — setup is one-shot).
- ALWAYS `kubectl apply -f - <<EOF` heredoc; NEVER bare `kubectl create` (TRIP-02). For imperative-only resources (secret with `--from-literal`, configmap from file): pipe `kubectl create ... --dry-run=client -o yaml | kubectl apply -f -`.
- Cluster-scoped resources (PV, ClusterRole, ClusterRoleBinding, StorageClass): name MUST start with `q<NN>-` prefix matching the question's path index (TRIP-03; RESEARCH Pitfall 6).
- Namespace-scoped resources: use bare names (no `q<NN>-` prefix; the namespace itself is the isolation boundary).
- The wait loop is REQUIRED on every setup.sh — RESEARCH Pitfall 3 documents the failure mode without it.
- DO NOT include `kubectl delete ns` at the top — lint-packs rejects (CONTEXT D-09; RESEARCH `lint-packs.sh` skeleton lines 776-781).
- Image pinning: `nginx:1.27`/`nginx:1.28`, `busybox:1.36`/`busybox:1.37`. Never `:latest`. apiVersion pinning per CONVENTIONS.md (NetworkPolicy = `networking.k8s.io/v1`, RBAC = `rbac.authorization.k8s.io/v1`, HPA = `autoscaling/v2`).
- For services-networking/01: pod image MUST include bash (e.g., `nicolaka/netshoot:v0.13` or `ubuntu:22.04`) — busybox/alpine `sh` is dash and lacks `/dev/tcp` (RESEARCH Assumption A3).
- Inline gotcha comments are encouraged on the seeded YAML (RESEARCH §"Project Constraints" final bullet) — but DO NOT comment the trap line itself (the candidate must discover it).

**Differences:** None — pure new pattern.

---

### `cka-sim/packs/<domain>/<NN>-<slug>/reset.sh` (NEW ×5) — teardown

**Analog:** No in-repo analog. CONTEXT D-08 + RESEARCH Pattern 4 are the spec.

**Pattern** (RESEARCH Pattern 4 lines 297-311):
```bash
#!/bin/bash
set -uo pipefail   # NO -e — multi-resource deletes run to completion

: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"

# 1. Async ns delete (returns ~immediately)
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

# 2. Cluster-scoped (q<NN>-prefix per TRIP-03)
kubectl delete pv q01-app-pv --ignore-not-found
# (one line per cluster-scoped resource the setup.sh creates)

exit 0
```

**Replication notes:**
- `set -uo pipefail` (NO `-e` — partial failures are expected; CONTEXT D-08).
- ALWAYS `--ignore-not-found` (TRIP-04). Never use `kubectl delete ... || true` — `--ignore-not-found` is the canonical idiom.
- `--wait=false` on the namespace delete (CONTEXT D-08 — avoids 30s finalizer stall).
- One explicit `kubectl delete <kind> <name>` line per cluster-scoped resource the paired setup.sh creates (no `--all` sweeps — too coarse).
- Final `exit 0` so partial deletion failures don't propagate exit codes.

**Differences:** None — pure new pattern.

---

### `cka-sim/packs/<domain>/<NN>-<slug>/ref-solution.sh` (NEW ×5) — reference fix

**Analog:** No in-repo analog. CONTEXT D-11 + RESEARCH §"Open Question Q1" specify behavior.

**Pattern (inferred from CONTEXT D-11):**
```bash
#!/bin/bash
# Reference solution for storage/01-pvc-binding.
# Invoked by GRADE-06 round-trip CI: bash setup.sh && bash ref-solution.sh && bash grade.sh → expect SCORE = max + 0 traps.
# Candidates NEVER see this file during drills.

set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

# Patch the PV to add nodeAffinity (the trap fix)
kubectl patch pv q01-app-pv --type=json -p='[
  {"op": "add", "path": "/spec/nodeAffinity", "value": {
    "required": {
      "nodeSelectorTerms": [{
        "matchExpressions": [{
          "key": "kubernetes.io/hostname",
          "operator": "Exists"
        }]
      }]
    }
  }}
]'
```

**Replication notes:**
- `set -euo pipefail` (fail-fast — ref-solution is the canonical answer; if it fails, the question is broken).
- Use `kubectl patch` / `kubectl apply` / `kubectl create … --dry-run=client -o yaml | kubectl apply -f -` to make the trap-fixing changes ONLY. Do not re-create the namespace or re-apply the seeded manifests — setup.sh already did that.
- The script must produce the cluster state where every assertion in grade.sh passes AND no detector fires (per GRADE-06).
- Make ref-solution.sh executable (`chmod +x`); lint-packs.sh enforces (D-12(e)).
- DO NOT reference candidate-discoverable hints; this is the answer key.

**Differences:** None — pure new pattern. Per RESEARCH Open Q1, GRADE-06 round-trip is HUMAN VERIFICATION in Phase 3 (DF-12 deferred); ref-solution.sh is shipped but not exercised in CI.

---

### `cka-sim/packs/<domain>/<NN>-<slug>/question.md` (NEW ×5) — candidate prompt

**Analog:** RESEARCH §"question.md skeleton" lines 791-816. `exercises/12-storage-pv-pvc/README.md` etc. are PRIOR-ART (referenced via `metadata.yaml:references[]`) — DO NOT copy prose from them.

**Pattern** (RESEARCH skeleton):
```markdown
# storage/01-pvc-binding

**Domain:** Storage  |  **Estimated time:** 8 minutes

A `PersistentVolumeClaim` named `app-data` is in your lab namespace. It needs to bind to a `PersistentVolume` so a future pod can mount it.

## Tasks

1. Inspect the existing PV `q01-app-pv` and the PVC `app-data` in `${CKA_SIM_LAB_NS}`.
2. The PVC is stuck Pending. Diagnose why — read the PV's events and spec carefully.
3. Make whatever changes are necessary so the PVC binds successfully.

## Constraints

- Do not delete or recreate the PV — modify it in place.
- The lab cluster has 1 control-plane + 2 worker nodes. The PV must remain usable on the cluster's worker nodes.

## Verify yourself

Before typing 'done', confirm:

```
kubectl get pvc app-data -n ${CKA_SIM_LAB_NS}    # STATUS should be Bound
```
```

**Replication notes:**
- PSI-exam-style phrasing: tell the candidate the SYMPTOM and DESIRED OUTCOME; never spell out the trap.
- Always reference `${CKA_SIM_LAB_NS}` (not a hardcoded ns name) so the prompt is consistent with whatever ns the runner constructs.
- Always reference cluster-scoped resources by their `q<NN>-` prefixed names (TRIP-03).
- Tasks numbered 1-3 (max 5). Estimated time matches metadata.yaml's `estimatedMinutes` (must be 4-12 per CONTEXT D-12(b)).
- Constraints subsection is optional but encouraged — it limits the candidate's solution space (e.g., "do not delete the PV" forces them to discover the patch path).
- "Verify yourself" subsection gives the candidate a self-check before grading. Use only `kubectl get`/`describe` (no scoring affect).
- Optionally embed `<details><summary>Hint</summary>...` blocks per DF-08 (deferred, but the markdown can be authored to support a future `--hint` flag).

**Differences from `exercises/<topic>/README.md`:**
- Question prompts are SHORT (≤200 words); exercises READMEs are tutorials with explanation.
- Question prompts NEVER include solutions or hints in the open prose.
- Question prompts use ${CKA_SIM_LAB_NS} placeholders; exercises hardcode `default` or example names.

---

### `cka-sim/packs/<domain>/README.md` (NEW ×5) — pack-level overview

**Analog:** None in-repo. Style ref: `.planning/codebase/CONVENTIONS.md` "What tripped me up" pattern (CONTEXT canonical_refs).

**Recommended skeleton** (no spec is locked — Claude's discretion per CONTEXT):
```markdown
# Storage Pack

**Domain:** Storage (10% of CKA blueprint v1.35)

## Questions

| # | Slug | Topic | Time |
|---|------|-------|------|
| 01 | pvc-binding | PVC stuck Pending on hostPath PV without nodeAffinity | 8 min |

## Authoring

See `cka-sim/AUTHORING.md` for the question authoring contract.

## Running

```bash
cka-sim drill storage          # random question
cka-sim drill storage 1        # 1-based index
```
```

**Replication notes:**
- One README per pack at the pack root.
- Mirror the `manifest.yaml` `questions[]` list as a markdown table (Claude can keep them in sync manually in Phase 3; lint enforcement is Phase 8).
- Pack-level README is candidate-facing (briefly describes what the pack covers + how to run).

**Differences:** None — new shape.

---

### `cka-sim/AUTHORING.md` (NEW partial) — authoring guide

**Analog:** None. Phase 8 (DOC-02) ships the full version. Phase 3 ships a partial covering ONLY the contract that Phase 3 itself depends on.

**Recommended sections for Phase 3 partial:**
1. **Directory layout** (CONTEXT D-01).
2. **6-files-per-question contract** (with role of each — link to setup.sh / grade.sh / reset.sh / ref-solution.sh patterns documented in this PATTERNS.md).
3. **manifest.yaml + metadata.yaml schema** (inline, with comments — full SCHEMA.md is Phase 8 DOC-03).
4. **Lint rules summary** (one paragraph per CONTEXT D-12 rule).
5. **Cluster-scoped naming** (TRIP-03 — `q<NN>-<name>` prefix).
6. **Idempotency contract** (CONTEXT D-07/D-08 — `kubectl apply` heredoc + ns wait loop + reset's `--ignore-not-found --wait=false`).
7. **What's NOT covered** (full version Phase 8; SCHEMA.md Phase 8; CI round-trip DF-12).

**Replication notes:**
- Markdown only. No code that the runtime reads.
- Reference back to actual files (`cka-sim/packs/storage/01-pvc-binding/` as the canonical example) so the doc stays in sync via grep.
- Explicit version note: "Phase 3 partial — full guide ships in Phase 8 (DOC-02)."

**Differences:** New file.

---

## Shared Patterns

### Bash style (applies to drill.sh, lint-packs.sh, all setup.sh, reset.sh, ref-solution.sh, grade.sh)

**Source:** `.planning/codebase/CONVENTIONS.md` §"Bash / shell script style"; `cka-sim/lib/cmd/doctor.sh:1-16`; `cka-sim/lib/cmd/bootstrap.sh:1-30`.

```bash
#!/bin/bash               # always line 1; LF endings (.gitattributes enforces)
set -euo pipefail         # for fail-fast scripts (drill.sh, lint-packs.sh, setup.sh, ref-solution.sh)
# OR
set -uo pipefail          # for accumulating scripts (grade.sh, reset.sh) — NO -e
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"
# shellcheck source=<rel> disable=SC1091
source "$CKA_SIM_ROOT/lib/<module>.sh"
```

**Apply to:** All bash files in this phase. Choice of `-euo` vs `-uo` is per CONTEXT/RESEARCH:
- `set -euo pipefail`: drill.sh, lint-packs.sh, setup.sh, ref-solution.sh
- `set -uo pipefail`: grade.sh, reset.sh

### Logging (applies to drill.sh and lint-packs.sh)

**Source:** `cka-sim/lib/log.sh` (Phase 1) — provides `header` / `info` / `ok` / `warn` / `err` / `die`. Already the convention in `bootstrap.sh:52-65, 99-191` and `doctor.sh:23-105`.

```bash
header "<command name>"        # banner (stderr)
info "<status message>"        # progress (stderr)
ok "<success>"                 # green check (stderr)
warn "<warning>"               # yellow (stderr)
err "<failure>"                # red (stderr)
die "<fatal>"                  # red + exit 1 (stderr)
```

**Apply to:** drill.sh and lint-packs.sh. Per CONTEXT `<code_context>` "Stderr for status, stdout for parseable output" — log.sh's helpers ALL go to stderr; only grade.sh's `SCORE:`/`Trap N:` lines go to stdout.

### Pure-bash YAML parser (applies to drill.sh's `load_pack` + lint-packs.sh's metadata.yaml validator)

**Source:** `cka-sim/lib/traps.sh:51-128` (catalog parser) + `cka-sim/scripts/lint-traps.sh:124-180` (companion validator).

```bash
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "${line//[[:space:]]/}" ]] && continue   # skip blank
  [[ "${line#"${line%%[![:space:]]*}"}" == "#"* ]] && continue   # skip comment
  if [[ "$line" =~ ^\ \ -\ id:\ (.+)$ ]]; then
    current_id="${BASH_REMATCH[1]}"
    ...
  elif [[ "$line" =~ ^\ \ \ \ ([a-z_]+):\ (.+)$ ]]; then
    field="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    ...
  fi
done < "$path"
```

**Apply to:** drill.sh's `load_pack`, lint-packs.sh's metadata.yaml walk. NEVER use `yq` (Phase 2 D-04 locks pure-bash). Reuse `_strip_quotes` helper from `lint-traps.sh:117-122`.

**Critical gotcha** (`lint-traps.sh:131-133`):
> capture `BASH_REMATCH[1]` BEFORE calling any helper that does its own `[[ =~ ]]` — `cka_sim::trap::is_valid_id` clobbers BASH_REMATCH.

### RFC 1123 id validation (applies to lint-packs.sh)

**Source:** `cka-sim/lib/traps.sh:36-41` — `cka_sim::trap::is_valid_id`.

```bash
source "$CKA_SIM_ROOT/lib/traps.sh"
cka_sim::trap::is_valid_id "$id" || err "$id not RFC 1123"
```

**Apply to:** lint-packs.sh — validates metadata.yaml `id:` and every `traps[]` entry. NEVER re-implement the regex.

### Catalog id existence check (applies to lint-packs.sh)

**Source:** `cka-sim/lib/traps.sh:135-140` — `cka_sim::trap::id_exists`.

```bash
source "$CKA_SIM_ROOT/lib/traps.sh"
cka_sim::trap::id_exists "$tid" || err "$tid not in catalog"
```

**Apply to:** lint-packs.sh — for every `metadata.yaml` `traps[]` entry. Lazy-loads the catalog on first call; no manual init needed.

### Wave-0 graceful skip (applies to lint-packs.sh)

**Source:** `cka-sim/scripts/lint-traps.sh:18-27`.

```bash
[[ -d "$CKA_SIM_ROOT/packs" ]] || { warn "no packs/ dir — skipping lint (expected during scaffold)"; exit 0; }
```

**Apply to:** lint-packs.sh — lets early-wave plans land and pass CI before all packs exist.

### Env-var contract (applies to drill.sh + every setup.sh, grade.sh, reset.sh, ref-solution.sh)

**Source:** CONTEXT `<code_context>` "Drill command sets env vars for graders".

```bash
# Drill exports these (drill.sh's load_pack populates + exports):
CKA_SIM_PACK_ID="storage"
CKA_SIM_QUESTION_ID="storage-pvc-binding"
CKA_SIM_LAB_NS="cka-sim-storage-01"
CKA_SIM_QUESTION_DIR="$CKA_SIM_ROOT/packs/storage/01-pvc-binding"
CKA_SIM_ROOT=...   # already exported by bin/cka-sim router

# Per-question scripts read with the `: "${VAR:?...}"` guard:
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"
```

**Apply to:** Every setup.sh / grade.sh / reset.sh / ref-solution.sh starts with `: "${CKA_SIM_LAB_NS:?...}"`. Graders additionally need `: "${CKA_SIM_ROOT:?...}"` for the source line.

### kubectl idiom selection (applies to all setup.sh / grade.sh / reset.sh / ref-solution.sh)

**Source:** RESEARCH §"Anti-patterns to Avoid" + §"State of the Art".

| Forbidden | Use Instead | Why |
|---|---|---|
| `kubectl create <kind>` | `kubectl apply -f -` heredoc | Idempotent (TRIP-02) |
| `kubectl get foo \| grep bar` | `kubectl get foo -o jsonpath='{.field}'` or `-l label=value` | GRADE-02 lint rejects |
| `kubectl get -A` | `kubectl get foo -n <ns>` | GRADE-02 lint rejects |
| `kubectl delete <kind> --all` | explicit `kubectl delete <kind> <name> --ignore-not-found` | TRIP-04 — narrow blast radius |
| `kubectl delete ... || true` | `kubectl delete ... --ignore-not-found` | Canonical k8s idiom |
| `kubectl exec ... -it` | `kubectl exec ... --` (no `-it`) in grade.sh | grade.sh is non-interactive |

**Apply to:** Every script that calls kubectl in this phase.

---

## No Analog Found

| File | Role | Reason | Mitigation |
|---|---|---|---|
| `cka-sim/packs/<domain>/<NN>-<slug>/setup.sh` (×5) | seeder | No prior bash-script that does `apply -f - <<EOF` heredocs in this repo | CONTEXT `<specifics>` "Sample setup.sh" + RESEARCH Pattern 3 are the literal spec |
| `cka-sim/packs/<domain>/<NN>-<slug>/reset.sh` (×5) | teardown | No prior bash-script that does `kubectl delete --ignore-not-found --wait=false` in this repo | CONTEXT D-08 + RESEARCH Pattern 4 are the literal spec |
| `cka-sim/packs/<domain>/<NN>-<slug>/ref-solution.sh` (×5) | reference fix | New shape | CONTEXT D-11 + per-question patch derived from each question's seeded trap |
| `cka-sim/packs/<domain>/README.md` (×5) | docs | New shape | This PATTERNS.md provides the skeleton |
| `cka-sim/packs/<domain>/<NN>-<slug>/question.md` (×5) | content | New shape | RESEARCH §"question.md skeleton" + CKA exam phrasing convention |
| `cka-sim/AUTHORING.md` | docs | New shape | This PATTERNS.md provides the partial-section outline |

For all of the above, the planner should reference (a) the relevant CONTEXT decision, (b) the RESEARCH pattern, and (c) the per-question detector wirings in RESEARCH Pattern 5.

---

## Metadata

**Analog search scope:**
- `cka-sim/lib/cmd/` (Phase 1 commands)
- `cka-sim/lib/` (Phase 1+2 libraries)
- `cka-sim/scripts/` (Phase 2 lint + test orchestrator)
- `cka-sim/tests/cases/` (Phase 2 test fixtures)
- `cka-sim/traps/` (Phase 2 catalog)
- `exercises/` (prior-art prose, referenced not copied)
- `.planning/codebase/CONVENTIONS.md` (style rules)

**Files scanned:**
- `cka-sim/lib/cmd/doctor.sh` (full)
- `cka-sim/lib/cmd/bootstrap.sh` (full)
- `cka-sim/lib/cmd/drill.sh` (stub, full)
- `cka-sim/lib/preflight.sh` (lines 1-80)
- `cka-sim/lib/grade.sh` (lines 1-80)
- `cka-sim/lib/traps.sh` (full)
- `cka-sim/scripts/lint-traps.sh` (full)
- `cka-sim/scripts/test.sh` (full)
- `cka-sim/traps/catalog.yaml` (full)
- `cka-sim/tests/cases/grade_assert_pvc_bound.sh` (full)
- `cka-sim/tests/cases/traps_hostpath-pv-without-nodeaffinity.sh` (full)
- Phase 3 CONTEXT.md + RESEARCH.md (load-bearing context)

**Pattern extraction date:** 2026-05-10

## PATTERN MAPPING COMPLETE
