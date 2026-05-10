# Phase 3: Runtime Contract + Drill Mode — Research

**Researched:** 2026-05-10
**Domain:** Bash CLI orchestration + kubectl idiomatic detectors + pure-bash YAML lint + per-question content authoring
**Confidence:** HIGH on bash/kubectl mechanics and pure-bash patterns (verified against in-repo Phase 1+2 code and Kubernetes 1.35 docs); MEDIUM on per-question content choices (require user judgement during plan execution); LOW on the GRADE-06 round-trip CI strategy (genuine open question — see §Open Questions Q1).

---

## Summary

Phase 3 closes the single-question loop. The orchestrator (`lib/cmd/drill.sh`) is a ~250-LOC bash command that:
1. Loads a pack manifest via the same pure-bash YAML parser idiom Phase 2 used for `traps/catalog.yaml`
2. Picks a question (random or 1-based index)
3. Runs `reset.sh → setup.sh → cat question.md → read-line prompt → grade.sh | tee report` against namespace `cka-sim-<pack>-<NN>`
4. Cleans up via an EXIT trap

All real implementation risk lives in **four** spots:
- the **EXIT-trap-+-tee** interaction (drill.sh runs grade.sh, tees its stdout, then EXIT-traps reset.sh — get this wrong and the report is truncated or reset.sh races the tee)
- the **`lint-packs.sh` regex for GRADE-02** (trivially over-broad regexes will false-positive on legitimate `kubectl get -o jsonpath` calls inside graders)
- the **pure-bash manifest.yaml parser** (must reuse Phase 2's parser idiom — there is now a precedent at `cka-sim/lib/traps.sh:51-128` and `cka-sim/scripts/lint-traps.sh:124-180`)
- **GRADE-06 round-trip without a live cluster** (the kubectl stub is wired only for static fixtures keyed by `CKA_SIM_TEST_CURRENT`, not for free-form `kubectl apply -f -` from setup.sh — so true round-trip CI requires either DF-12 (`kind`), or a documented human-verification step matching Phase 1's pattern)

**Primary recommendation:** Implement drill.sh's grade phase as a single backgrounded grade.sh whose stdout is captured to a `mktemp` temp file via a `process substitution` writer, then the EXIT trap concatenates the report header + temp file at the documented final path — sidestepping every `tee | trap | reset.sh` race condition. For GRADE-06: document round-trip as a human verification procedure (mirroring Phase 1's bootstrap verification), with a static structural CI check that grade.sh references ref-solution.sh's effects (e.g., greps for the assertion symbols ref-solution.sh creates).

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Pack discovery + manifest parse | `lib/cmd/drill.sh` (orchestrator) | — | One-time read, drill-local. Not worth a `lib/pack.sh` module until exam mode reuses it (Phase 7 reconsideration explicitly noted in CONTEXT). |
| Question selection (random / index) | `lib/cmd/drill.sh` | — | Trivial `$(( RANDOM % n ))`; no need to abstract. |
| Lab-namespace lifecycle (create/wait/delete) | `setup.sh` (per-question) + `reset.sh` (per-question) | `lib/cmd/drill.sh` (orchestrates the two) | Per CONTEXT D-09: runner owns the *sequence*; setup/reset own the *manifests*. |
| Candidate prompt (`done`/`skip`) | `lib/cmd/drill.sh` | — | Pure bash `read` — no helper module. |
| Grade execution + tee'd report | `lib/cmd/drill.sh` (tee) + `grade.sh` (assertions) + `lib/grade.sh` (helpers — Phase 2) | `lib/traps.sh` (Phase 2) | Phase 2 owns the assertion + trap library; Phase 3 owns the file-IO of the report and the header. |
| EXIT-trap cleanup | `lib/cmd/drill.sh` | — | Bash trap is process-local; cannot be delegated. |
| Pack lint (GRADE-02 + PACK-06) | `scripts/lint-packs.sh` | `lib/traps.sh::is_valid_id` (reused) | Mirrors Phase 2's `lint-traps.sh` standalone shape. |
| Reference questions (5) | `packs/<domain>/01-<slug>/{6 files}` | — | Content authoring; not a software tier. |
| Catalog extension (3-5 new traps) | `traps/catalog.yaml` | `lib/traps.sh` (parser unchanged) | Catalog is the data; parser is the consumer. Per CONTEXT canonical_refs §"Catalog extension". |

---

## Standard Stack

### Core (already in repo from Phase 1+2 — no new dependencies)
| Module | Version | Purpose | Why Standard |
|--------|---------|---------|--------------|
| `bash` | 5.1+ (Ubuntu 22.04 default) | All scripts | `[VERIFIED: in-repo]` per Phase 1+2 conventions; `set -euo pipefail` semantics + `declare -gA` arrays + `BASH_REMATCH` are the load-bearing features. |
| `kubectl` | matches cluster (1.35.x) | All k8s I/O | `[VERIFIED: in-repo]` per BOOT-07 doctor check; `kubectl wait`, `--dry-run=client -o yaml`, `-o jsonpath` are the idioms. |
| `jq` | apt-default (≥1.6) | JSON munging in detectors | `[VERIFIED: in-repo]` Phase 2 detectors (`traps.sh:190-208`) and Phase 1 preflight already require it. |
| `tee` | coreutils | Report duplication | `[VERIFIED: in-repo]` standard utility; ships in Ubuntu base. |

### Supporting (new, but trivially in scope)
| Module | Version | Purpose | When to Use |
|--------|---------|---------|-------------|
| `lib/cmd/drill.sh` | new | Orchestrator (replaces stub) | Phase 3 plan 03-01 / 03-02 |
| `scripts/lint-packs.sh` | new | GRADE-02 + PACK-06 lint | Phase 3 plan 03-04 |
| `packs/<domain>/01-<slug>/{6}` | new | 5 reference questions | Phase 3 plan 03-03 |
| `AUTHORING.md` (partial) | new | Authoring guide stub | Phase 3 plan 03-05 (full version Phase 8 per DOC-02) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Pure-bash YAML parsing for `manifest.yaml`/`metadata.yaml` | `yq` | `[VERIFIED: rejected per Phase 2 D-04]` — locks deps to apt-default, parser already exists in `traps.sh`. |
| `tee` for tee'd report | `exec >(tee ...)` redirection | `[CITED: linuxize.com/bash-strict-mode]` Process substitution `>(...)` makes EXIT-trap ordering opaque. `tee` with explicit pipe is debuggable. See Pitfall 1. |
| Bash `read` for prompt | `whiptail`/`dialog` | Adds dep; CONTEXT D-04 explicitly rejects. |
| `mktemp` for report staging | Write directly to final path | Direct write means a Ctrl-C mid-grade leaves a partial report at the canonical name. `mktemp` + atomic `mv` is the idiom. |

**Installation:** None. Phase 1's `cka-sim doctor` already verifies `kubectl jq ssh ssh-keygen etcdctl crictl`. No new binaries.

**Version verification:**
```bash
# All already verified by cka-sim doctor (Phase 1) on the target Ubuntu 22.04 CP node.
# No new packages installed in Phase 3.
bash --version | head -1   # expect 5.1+
kubectl version --client   # expect 1.35.x matching cluster
jq --version               # expect 1.6+
```

---

## Architecture Patterns

### System architecture diagram (data flow)

```
candidate
  │
  │ $ cka-sim drill storage [N]
  ▼
bin/cka-sim ───dispatch──► lib/cmd/drill.sh (NEW)
                            │
                            ├─► preflight (Phase 1: check_kubeconfig, check_cluster_nodes)
                            │
                            ├─► load_pack: parse packs/<pack>/manifest.yaml (pure-bash, mirrors traps.sh:51)
                            │     └─► sets CKA_SIM_QUESTION_DIR, CKA_SIM_LAB_NS, CKA_SIM_QUESTION_ID, CKA_SIM_PACK_ID
                            │
                            ├─► trap cka_sim::drill::cleanup EXIT  ◄─── (registers reset.sh runner)
                            │
                            ├─► bash $CKA_SIM_QUESTION_DIR/reset.sh   (defensive cleanup of prior state)
                            ├─► bash $CKA_SIM_QUESTION_DIR/setup.sh   (creates ns + seeds the trap)
                            ├─► cat $CKA_SIM_QUESTION_DIR/question.md (presents prompt to candidate)
                            ├─► info "Lab ns: $CKA_SIM_LAB_NS"
                            │
                            ├─► prompt: read action  ◄─── candidate types 'done' or 'skip'
                            │     │
                            │     ├─[skip]── exit 130 (EXIT trap fires → reset.sh)
                            │     │
                            │     └─[done]──► report=$HOME/.cka-sim/reports/<ts>-<pack>-<qid>.md
                            │                  ├─► render header (10 lines: ts, pack, qid, est-min, actual-min, catalog-version)
                            │                  ├─► bash $CKA_SIM_QUESTION_DIR/grade.sh > $tmpfile  (NOT a tee pipeline — see Pitfall 1)
                            │                  ├─► cat header + tmpfile to stdout AND to report (atomic mv)
                            │                  └─► exit code = grade.sh's exit code
                            │
                            └─► EXIT trap fires:
                                  bash $CKA_SIM_QUESTION_DIR/reset.sh  (kubectl delete ns --wait=false + cluster-scoped)
                                  print "session cleaned up" to stderr
```

Key invariants:
- **Every path** through drill.sh ends with reset.sh executed (success, fail, skip, Ctrl-C, error). EXIT trap is the only enforcement.
- **stdout** of drill.sh is the SCORE/Trap block ONLY (parseable for Phase 7's `cka-sim score`); status/headers/colors all go to **stderr** via Phase 1's log.sh.
- **report file** is the same content the candidate sees on stdout, plus a 10-line header prepended.
- The grade.sh subprocess inherits `CKA_SIM_LAB_NS`, `CKA_SIM_QUESTION_ID`, `CKA_SIM_PACK_ID`, `CKA_SIM_QUESTION_DIR`, and `CKA_SIM_ROOT` (the latter is the gateway to `lib/grade.sh` + `lib/traps.sh`).

### Recommended project structure
```
cka-sim/
├── lib/
│   └── cmd/
│       └── drill.sh                  # REPLACE Phase 1 stub (currently 13 lines, becomes ~250)
├── packs/                            # NEW
│   ├── storage/
│   │   ├── manifest.yaml             # NEW
│   │   ├── README.md                 # NEW
│   │   └── 01-pvc-binding/
│   │       ├── metadata.yaml
│   │       ├── question.md
│   │       ├── setup.sh              # +x
│   │       ├── grade.sh              # +x
│   │       ├── reset.sh              # +x
│   │       └── ref-solution.sh       # +x
│   ├── workloads-scheduling/01-deployment-requests/{6 files} + manifest.yaml + README.md
│   ├── services-networking/01-networkpolicy-egress/{6 files} + manifest.yaml + README.md
│   ├── cluster-architecture/01-rbac-viewer/{6 files} + manifest.yaml + README.md
│   └── troubleshooting/01-deploy-svc-mismatch/{6 files} + manifest.yaml + README.md
├── scripts/
│   ├── test.sh                       # MODIFY — invoke lint-packs.sh after lint-traps.sh
│   └── lint-packs.sh                 # NEW
├── tests/cases/                      # NEW (drill.sh unit tests)
│   ├── drill_load_pack.sh
│   ├── drill_question_selection.sh
│   └── drill_namespace_construction.sh
├── traps/catalog.yaml                # EXTEND — 3 to 5 new entries
└── AUTHORING.md                      # NEW (partial; full = Phase 8)
```

### Pattern 1: Sourceable command-module shape
**What:** Phase 1's `lib/cmd/*.sh` are not sourced — `bin/cka-sim` `exec`s them. drill.sh follows the same shape: top-level `main "$@"` + `set -euo pipefail` + `: "${CKA_SIM_ROOT:?...}"`.
**When to use:** Always — match Phase 1's `bootstrap.sh` and `doctor.sh`.
**Example:**
```bash
#!/bin/bash
# Source: cka-sim/lib/cmd/doctor.sh:1-16 (verbatim shape, replace -uo with -euo)
set -euo pipefail
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"
source "$CKA_SIM_ROOT/lib/colors.sh"
source "$CKA_SIM_ROOT/lib/log.sh"
source "$CKA_SIM_ROOT/lib/preflight.sh"
# (drill.sh additionally sources lib/traps.sh + lib/grade.sh ONLY if it needs to validate
# trap-ids before launching grade.sh — and it doesn't, because grade.sh sources them itself.
# Drill.sh does not need to source either — see Pitfall 5.)
```
`[VERIFIED: cka-sim/lib/cmd/doctor.sh:1-16]`

### Pattern 2: Pure-bash flat-YAML parser
**What:** Phase 2's `traps.sh` parses catalog.yaml using only `[[ =~ ]]` regex and `BASH_REMATCH`. The same idiom MUST be used for `manifest.yaml` and `metadata.yaml` (per Phase 2 D-04 — "no yq").
**When to use:** Every YAML read in Phase 3.
**Example:**
```bash
# Source: cka-sim/lib/traps.sh:60-114 (parse loop)
# Source: cka-sim/scripts/lint-traps.sh:124-180 (companion validator)
#
# Manifest format (D-02):
#   pack:
#     id: storage
#     domain: storage
#     weight: 10
#     description: "Storage 10% domain pack"
#   questions:
#     - id: storage-pvc-binding
#       path: 01-pvc-binding
#       estimatedMinutes: 8

declare -ag CKA_SIM_PACK_QUESTION_IDS=()
declare -ag CKA_SIM_PACK_QUESTION_PATHS=()
declare -ag CKA_SIM_PACK_QUESTION_MINUTES=()
declare -gA CKA_SIM_PACK_META=()
local in_questions=0 current_q_id=""

while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "${line//[[:space:]]/}" ]] && continue
  [[ "${line#"${line%%[![:space:]]*}"}" == "#"* ]] && continue
  if [[ "$line" =~ ^questions:[[:space:]]*$ ]]; then in_questions=1; continue; fi
  if (( in_questions == 0 )); then
    # pack: scope — match `^  <key>: <value>`
    if [[ "$line" =~ ^\ \ ([a-z]+):\ (.+)$ ]]; then
      CKA_SIM_PACK_META["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
    fi
  else
    # questions: scope — `  - id: <id>` then `    path: <p>` / `    estimatedMinutes: <n>`
    if [[ "$line" =~ ^\ \ -\ id:\ (.+)$ ]]; then
      current_q_id="${BASH_REMATCH[1]}"
      CKA_SIM_PACK_QUESTION_IDS+=("$current_q_id")
      CKA_SIM_PACK_QUESTION_PATHS+=("")     # placeholder
      CKA_SIM_PACK_QUESTION_MINUTES+=("")   # placeholder
    elif [[ "$line" =~ ^\ \ \ \ path:\ (.+)$ ]]; then
      local last=$(( ${#CKA_SIM_PACK_QUESTION_PATHS[@]} - 1 ))
      CKA_SIM_PACK_QUESTION_PATHS[$last]="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^\ \ \ \ estimatedMinutes:\ (.+)$ ]]; then
      local last=$(( ${#CKA_SIM_PACK_QUESTION_MINUTES[@]} - 1 ))
      CKA_SIM_PACK_QUESTION_MINUTES[$last]="${BASH_REMATCH[1]}"
    fi
  fi
done < "$manifest_path"
```
`[VERIFIED: in-repo, mirrors lib/traps.sh:60-114]`

### Pattern 3: Idempotent setup via apply-heredoc + ns-stuck-Terminating wait loop
**What:** Per CONTEXT D-07/D-08, every `setup.sh` uses `kubectl apply -f - <<EOF` heredocs, never `kubectl create` (not idempotent). For the namespace itself, after the apply, a 10-iteration wait loop polls `.status.phase == Active` to handle the case where a prior `reset.sh --wait=false` left the ns in `Terminating`.
**When to use:** Every `setup.sh` in Phase 3's 5 reference questions.
**Example:**
```bash
# Source: CONTEXT.md <specifics> "Sample setup.sh"
#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"

# 1. Create ns idempotently
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${CKA_SIM_LAB_NS}
  labels:
    cka-sim/pack: storage
    cka-sim/question-id: storage-pvc-binding
EOF

# 2. Wait for Active (handles prior reset --wait=false)
for i in $(seq 1 10); do
  phase=$(kubectl get ns "$CKA_SIM_LAB_NS" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
  [[ "$phase" == "Active" ]] && break
  sleep 5
done
[[ "$phase" == "Active" ]] || { echo "ns $CKA_SIM_LAB_NS not Active after 50s (phase=$phase)" >&2; exit 1; }

# 3. Apply seeded-trap manifest (PV without nodeAffinity — the trap)
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: q01-app-pv         # cluster-scoped → q<id>- prefix per TRIP-03
spec:
  capacity:
    storage: 1Gi
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /tmp/q01-app-pv
  # NOTE: nodeAffinity omitted intentionally — this IS the trap.
EOF

# 4. Apply PVC (will stay Pending until candidate fixes the PV)
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data
  namespace: ${CKA_SIM_LAB_NS}
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 500Mi
  storageClassName: manual
EOF
```
`[VERIFIED: in-repo CONTEXT.md <specifics>; cross-referenced kubectl 1.35 apply docs]`

### Pattern 4: Reset using async ns delete + ignore-not-found everywhere
**What:** `reset.sh` runs `kubectl delete namespace --ignore-not-found --wait=false` so it returns in <1s. Cluster-scoped resources (each prefixed with `q<id>-` per TRIP-03) get explicit `kubectl delete <kind> <name> --ignore-not-found` lines. The script uses `set -uo pipefail` (NO `-e`) so a partial cleanup runs to completion.
**When to use:** Every `reset.sh`.
**Example:**
```bash
#!/bin/bash
# Source: CONTEXT.md D-08
set -uo pipefail   # NO -e — multi-resource deletes run to completion

: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set by drill runner}"

# 1. Async ns delete (returns ~immediately)
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

# 2. Cluster-scoped (q01-prefix per TRIP-03)
kubectl delete pv q01-app-pv --ignore-not-found
# (no other cluster-scoped resources for this question)

exit 0
```
`[VERIFIED: in-repo CONTEXT.md D-08]`

### Pattern 5: Idiomatic kubectl detectors for the 5 reference questions

The seeded detectors in `lib/traps.sh` (Phase 2) already do the heavy lifting. Each reference question's `grade.sh` ALSO calls assertion helpers from `lib/grade.sh` to enforce the *desired end state*. Below are the recommended assertion + detector wirings — these are the actually-correct kubectl idioms verified against k8s 1.35:

#### storage/01-pvc-binding (hostpath-pv-without-nodeaffinity)
```bash
# grade.sh
source "$CKA_SIM_ROOT/lib/grade.sh"
source "$CKA_SIM_ROOT/lib/traps.sh"

# Assertions (the candidate must achieve these)
cka_sim::grade::assert_pvc_bound "$CKA_SIM_LAB_NS" "app-data"
cka_sim::grade::assert_field_eq pv q01-app-pv \
  '{.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].key}' \
  'kubernetes.io/hostname'

# Trap detector (already in lib/traps.sh:214-225)
tid=$(cka_sim::trap::detect_hostpath_pv_without_nodeaffinity q01-app-pv)
[[ -n "$tid" ]] && cka_sim::grade::record_trap "$tid"

cka_sim::grade::emit_result
```

#### workloads-scheduling/01-deployment-requests (default-sa-used)
```bash
# Assertions: deployment exists, has resources.requests.cpu, uses dedicated SA
cka_sim::grade::assert_resource_exists deployment load-app -n "$CKA_SIM_LAB_NS"
cka_sim::grade::assert_field_eq deployment load-app \
  '{.spec.template.spec.containers[0].resources.requests.cpu}' '50m' \
  -n "$CKA_SIM_LAB_NS"

# Detector: pod uses default SA (Phase 2 traps.sh:170-178)
# Need to check the deployment's first running pod
pod=$(kubectl get pod -n "$CKA_SIM_LAB_NS" -l app=load-app -o jsonpath='{.items[0].metadata.name}')
tid=$(cka_sim::trap::detect_default_sa_used "$CKA_SIM_LAB_NS" "$pod")
[[ -n "$tid" ]] && cka_sim::grade::record_trap "$tid"
```

#### services-networking/01-networkpolicy-egress (missing-dns-egress)
```bash
# Assertions: deployment ready + DNS egress works in-pod
cka_sim::grade::assert_pod_ready "$CKA_SIM_LAB_NS" "$pod_name"
cka_sim::grade::assert_egress_allowed "$CKA_SIM_LAB_NS" "$pod_name" "kube-dns.kube-system.svc.cluster.local" 53
# NOTE: assert_egress_allowed uses /dev/tcp (TCP); for DNS UDP we may need a custom probe
# OR rely on the trap detector + a different positive assertion (e.g. "nslookup kubernetes succeeds")

# Detector (Phase 2 traps.sh:186-208)
tid=$(cka_sim::trap::detect_missing_dns_egress "$CKA_SIM_LAB_NS" "deny-egress")
[[ -n "$tid" ]] && cka_sim::grade::record_trap "$tid"
```
**Note:** `assert_egress_allowed` from Phase 2 uses `/dev/tcp/<host>/<port>` which is TCP-only — UDP/53 DNS probing requires `kubectl exec ... -- nslookup` instead. This is a Phase 3 implementation detail; the planner should add a custom in-grader probe (a single `kubectl exec ... nslookup` line wrapped in a fail-counter) rather than extend Phase 2's helpers.

#### cluster-architecture/01-rbac-viewer (as-flag-format-wrong)
```bash
# Assertions: role + binding exist, can-i succeeds with correct --as
cka_sim::grade::assert_resource_exists role view-pods -n "$CKA_SIM_LAB_NS"
cka_sim::grade::assert_resource_exists rolebinding view-pods-binding -n "$CKA_SIM_LAB_NS"
cka_sim::grade::assert_can_i list pods -n "$CKA_SIM_LAB_NS" \
  --as "system:serviceaccount:$CKA_SIM_LAB_NS:viewer-sa"

# Detector: detect_as_flag_format_wrong takes <text> — Phase 3 must capture
# what the candidate typed and pass it. Easiest: stash candidate's last command
# in a file the runner records, then grep. OR: skip this detector for the
# RBAC question (the trap is text-based, not state-based — see Open Question Q3)
```
**See Open Questions Q3 below** — the text-based detectors (`as-flag-format-wrong`, `pss-error-string-mismatch`, etc.) require a "captured candidate input" pipeline that Phase 3 must design. Recommended: drop the text-based detector for this question's grade.sh and rely solely on `assert_can_i` (which catches the wrong-format `--as` automatically because it returns "no").

#### troubleshooting/01-deploy-svc-mismatch (selector/endpoints)
```bash
# Assertions: deployment ready, service has non-empty endpoints
cka_sim::grade::assert_resource_exists deployment app -n "$CKA_SIM_LAB_NS"
cka_sim::grade::assert_resource_exists service app-svc -n "$CKA_SIM_LAB_NS"
cka_sim::grade::assert_endpoints_nonempty "$CKA_SIM_LAB_NS" "app-svc"

# This question's traps are PER-QUESTION ADDITIONS (CONTEXT D-10 noted "TBD").
# Candidate-discretion to add 2 new catalog entries:
#   - service-selector-empty-endpoints
#   - deployment-svc-label-mismatch
# (Phase 3 planner finalizes ids per CONTEXT Claude's Discretion.)
```

### Anti-patterns to Avoid
- **`kubectl create ns X` then `kubectl create ...`** — both fail with `AlreadyExists` on second run, breaking TRIP-02. Always `kubectl apply -f -` heredocs.
- **`kubectl delete ns X --wait=true`** in reset.sh — finalizers can stall for 30+ seconds, making drills feel sluggish. Use `--wait=false` (CONTEXT D-08).
- **`kubectl get foo | grep bar`** in grade.sh — banned by GRADE-02. Use `kubectl get foo -o jsonpath` or `kubectl get foo -l label=value`.
- **Self-guards in setup.sh** (e.g., `kubectl delete ns ... || true; kubectl create ns ...`) — duplicates the runner's responsibility (D-09). lint-packs.sh rejects.
- **Sourcing grade.sh from drill.sh** — grade.sh has its own `set -uo pipefail`, accumulators, and `emit_result`; sourcing it would corrupt drill.sh's state. **Run grade.sh as a subprocess** (`bash $CKA_SIM_QUESTION_DIR/grade.sh`).
- **Using `read` without `-r`** — backslashes in candidate input get mangled. Always `read -r action`.
- **Trapping EXIT inside a function** — bash EXIT traps are process-scope, not function-scope. The `trap ... EXIT` MUST live in `main`'s body, not inside `cka_sim::drill::cleanup`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| YAML parsing | A new YAML parser | Reuse Phase 2's pure-bash regex idiom (`lib/traps.sh:60-114`) | Already proven, lint-tested, RFC-1123-aware. |
| Catalog ID validation | Re-implement RFC 1123 regex | Call `cka_sim::trap::is_valid_id` from `lib/traps.sh:36-41` | Single source of truth per Phase 2 D-15(b). lint-packs.sh `source`s lib/traps.sh and reuses. |
| Per-assertion accumulator | New counter logic in drill.sh | grade.sh already exports `CKA_SIM_GRADE_PASSED/TOTAL/FAILS/PASSES/TRAPS`; just consume from grade.sh stdout | Phase 2 D-06 shipped this. |
| Stable score-line format | Custom report formatter | Phase 2's `cka_sim::grade::emit_result` already prints `SCORE: N/M` + `Trap N: ...` | D-07 locked it; Phase 7 parses it. |
| Trap-id catalog lookup | New catalog parser in lint-packs | `source $CKA_SIM_ROOT/lib/traps.sh` then call `cka_sim::trap::id_exists` | lint-traps.sh already does this `[VERIFIED: scripts/lint-traps.sh:32]`. |
| Namespace-stuck-Terminating wait | Polling on `kubectl get ns` from drill.sh | Per-question `setup.sh` does the wait (CONTEXT D-08) | Author's responsibility per the runtime contract; drill.sh stays generic. |
| Color/log helpers | New ANSI escapes | `source $CKA_SIM_ROOT/lib/log.sh` (provides `info`/`ok`/`err`/`die`/`header`/`warn`) | Phase 1 |
| Cluster preflight | New connectivity check | `cka_sim::preflight::check_kubeconfig` + `check_cluster_nodes` | Phase 1 `lib/preflight.sh:36-75`. drill.sh runs these before reset.sh. |

**Key insight:** Phase 3 has been heavily de-risked by Phase 2's library work. The drill.sh command itself is mostly **gluing existing helpers together**; the only genuinely-new code is (1) manifest parsing, (2) the EXIT-trap orchestration, (3) the report-header rendering, and (4) the lint rules. Everything else delegates to Phase 1+2.

---

## Common Pitfalls

### Pitfall 1: `bash grade.sh | tee report.md` corrupts the EXIT-trap report path
**What goes wrong:** The naive implementation `bash grade.sh | tee "$report"` runs grade.sh and tee in a subshell pipeline. With `set -euo pipefail`, if grade.sh exits non-zero (which it WILL for any failing answer — this is the normal happy path of a drill!), the pipeline's exit status is grade.sh's non-zero code. The EXIT trap then sees that non-zero code and fires reset.sh — fine — BUT: tee may still be flushing buffered output when the EXIT trap's `kubectl delete ns` starts running. If grade.sh emits `Trap 1: ...` to stdout late, tee's write to disk can race with reset.sh's namespace deletion (which doesn't affect the file, but feels disorderly). Worse: **`tee` doesn't propagate SIGPIPE cleanly** — if the candidate Ctrl-Cs during grade.sh, tee may receive SIGPIPE and the EXIT trap fires before tee has finished writing the partial report, leaving a truncated file at the canonical name.

**Why it happens:** `tee` writes to multiple outputs and is not designed for partial-output recovery. SIGPIPE and pipefail interact subtly per [help-bash thread on pipe failures](https://lists.gnu.org/archive/html/help-bash/2018-11/msg00057.html) and [Baeldung on piped exit status](https://www.baeldung.com/linux/exit-status-piped-processes).

**How to avoid:** Three-step pattern that sidesteps tee entirely:
```bash
# 1. Stage grade.sh output to a tempfile
tmp_out=$(mktemp -t cka-sim-drill-XXXXXX.md)
trap 'rm -f "$tmp_out"' EXIT  # nest trap chain — see below
bash "$CKA_SIM_QUESTION_DIR/grade.sh" > "$tmp_out"   # captures stdout; stderr goes to terminal directly
grade_rc=$?

# 2. Render header + concat + atomic mv
report="$HOME/.cka-sim/reports/$(date -u +%Y%m%dT%H%M%SZ)-$pack-$question_id.md"
{ render_header; cat "$tmp_out"; } > "$report.partial"
mv "$report.partial" "$report"   # atomic on local fs

# 3. Echo the captured output to candidate's stdout (so they see SCORE: too)
cat "$tmp_out"

# 4. Cleanup-trap chain: register reset BEFORE grade so it fires even if grade dies
# (pattern: install reset trap first; chain a second trap for tmpfile)
```

**Warning signs:** Truncated report files in `~/.cka-sim/reports/`; "Trap N:" lines missing from report but present on terminal (or vice-versa); intermittent failure-count differences between report and what candidate saw.

`[VERIFIED via WebSearch — multiple sources on bash pipefail + tee + SIGPIPE interactions]`

### Pitfall 2: GRADE-02 lint regex over-matches legitimate `kubectl get -o jsonpath`
**What goes wrong:** A first-instinct regex `kubectl get .*\| .*grep` can ALSO match a multi-line shell construct like `kubectl get pod $(kubectl get ... | grep ...) -o jsonpath=...` where the inner grep is not a grader assertion but a shell-glue pipe. Worse: `kubectl get -A` is sometimes used legitimately for `kubectl get -A -o name | xargs ...` style operations, but lint-packs MUST reject it on grade.sh per CONTEXT D-12(a).

**Why it happens:** Bash text matched by simple grep doesn't distinguish "argument to grep" from "structural pipe."

**How to avoid:** Two-pass lint for grade.sh files:
- **Pass 1 (line-anchored, false-positive-resistant):** `grep -nE '^[[:space:]]*kubectl[[:space:]]+get([[:space:]]+|$)' "$grade_sh"` — finds every line where `kubectl get` is the first command on the line. Then for each such line, check if the SAME line contains ` | grep ` or starts the line with `kubectl get -A`.
- **Pass 2 (comment-strip):** Skip lines whose first non-whitespace char is `#`.
- **Final check:** `grep -nE '^[[:space:]]*[^#]*kubectl[[:space:]]+get[[:space:]]+-A([[:space:]]|$)' "$grade_sh"` — catches `kubectl get -A` in any non-comment line.

Concrete regex Phase 3 should ship in `lint-packs.sh`:
```bash
# False positives to AVOID matching:
#   1. # kubectl get | grep   (commented out)
#   2. echo "see kubectl get -A docs"   (string literal — accept the false negative on string-quoted refs; lint-packs is not a parser)
#
# Pass A: line is grep'd kubectl
grep -nE '^[[:space:]]*[^#]*kubectl[[:space:]]+get[[:space:]].*\|[[:space:]]*grep' "$grade_sh"
# Pass B: line is kubectl get -A
grep -nE '^[[:space:]]*[^#]*kubectl[[:space:]]+get[[:space:]]+-A([[:space:]]|$)' "$grade_sh"
```
Either non-empty result = lint failure for that file.

**Warning signs:** lint-packs.sh fails on a `grade.sh` that uses the legitimate idiom `kubectl get pods -o jsonpath="{.items[?(@.metadata.name=='foo')].status.phase}"` — if it does, the regex is over-matching. Add a unit test under `cka-sim/tests/cases/lint_packs_*.sh` for both positive AND negative cases (the lint-packs script itself needs hit + miss fixtures, mirroring D-12 from Phase 2).

### Pitfall 3: namespace stuck Terminating defeats `kubectl create ns`
**What goes wrong:** With CONTEXT D-08's `--wait=false` reset, calling drill twice in <30s can hit a window where ns is still in `Terminating`. Then `setup.sh`'s `kubectl apply -f -` for the namespace returns OK (apply is idempotent against the existing-but-terminating ns) BUT the subsequent `kubectl apply -f -` for resources INSIDE the ns fail with `unable to create new content in namespace cka-sim-storage-01 because it is being terminated`.

**Why it happens:** Namespace termination runs a cluster-internal finalizer that can take 5-30s; during that window, no new objects can be created in the ns. `[CITED: redhat.com/blog/troubleshooting-terminating-namespaces]`

**How to avoid:** CONTEXT D-08 already prescribes this — setup.sh's wait loop polls `.status.phase == Active` for up to 50s (10 retries × 5s). Critical: the wait loop must check `phase == Active`, not just "ns exists." A `Terminating` ns shows up in `kubectl get ns` but cannot accept new objects.

```bash
# THE wait loop, verbatim, that every setup.sh must use after the ns apply:
for i in $(seq 1 10); do
  phase=$(kubectl get ns "$CKA_SIM_LAB_NS" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
  [[ "$phase" == "Active" ]] && break
  sleep 5
done
[[ "$phase" == "Active" ]] || exit 1
```

**Warning signs:** `cannot create ...: namespace ... is being terminated` errors from `setup.sh` when re-running drill quickly; `kubectl get ns | grep Terminating` returns rows.

`[VERIFIED via WebSearch — RedHat, Google Cloud, Azure docs on Terminating-state namespaces]`

### Pitfall 4: `read -r action` swallows EOF differently than expected
**What goes wrong:** When stdin is closed (e.g., piped script: `echo done | cka-sim drill storage`), `read -r action` returns immediately with empty `$action`. If drill.sh treats empty as `skip`, fine. If it treats empty as "ask again" or "fall through to grade", the drill becomes non-deterministic depending on TTY/non-TTY invocation.

**Why it happens:** `read` returns non-zero on EOF; many implementations also return non-zero on read error vs. legitimately-empty input. CONTEXT D-04 says "read one line via bash's read" — be explicit about the EOF contract.

**How to avoid:**
```bash
cka_sim::drill::prompt_ready() {
  local action=""
  printf "Type 'done' to grade, 'skip' to abandon: " >&2
  if ! IFS= read -r action; then
    # EOF (e.g., piped stdin or terminal closed) — treat as skip
    action="skip"
  fi
  case "$action" in
    done) printf 'done\n' ;;
    skip|"") printf 'skip\n' ;;     # empty input also = skip (safer default)
    *) warn "unknown action '$action' — treating as skip"; printf 'skip\n' ;;
  esac
}
```
Document in AUTHORING.md that drill mode requires interactive stdin OR `echo done` piped explicitly.

**Warning signs:** drill.sh hangs forever (the prompt is waiting for stdin in a non-TTY context) — or completes silently without grading (read returned EOF and was treated as `done`).

### Pitfall 5: Sourcing `lib/grade.sh` from drill.sh corrupts state
**What goes wrong:** Tempting design: drill.sh sources lib/grade.sh so it can pre-validate accumulator state, then `bash grade.sh` runs the question's grader. But lib/grade.sh declares `declare -ag CKA_SIM_GRADE_*=()` at the file top — sourcing it ZEROES OUT any state, AND sourcing in drill.sh's process means drill.sh's `set -euo pipefail` interacts badly with grade.sh's `set -uo pipefail` expectations (no `-e` in graders is load-bearing per Phase 2 D-05).

**Why it happens:** grade.sh is designed to be sourced by `grade.sh` (the per-question one) — NOT by the runner. The runner's contract is "run the per-question grade.sh as a subprocess and capture its stdout."

**How to avoid:** drill.sh runs grade.sh as a subprocess (`bash "$CKA_SIM_QUESTION_DIR/grade.sh"`), captures stdout via `> "$tmp_out"`, and ignores the runtime accumulators entirely. The grade.sh subprocess sources `lib/grade.sh` and `lib/traps.sh` itself — drill.sh does NOT source either.

**Warning signs:** Test runs of drill.sh report `SCORE: 0/0` even when grade.sh runs assertions; trap-id validation errors during drill.sh load.

### Pitfall 6: cluster-scoped resource collisions across questions
**What goes wrong:** Two questions in the same pack both create a PV named `app-pv`. First drill works; second drill's setup.sh's `kubectl apply` on the SECOND PV updates the first PV's spec instead of failing — because PVs are cluster-scoped and apply is name-based. Candidate sees stale state from question 1 leaking into question 2.

**Why it happens:** TRIP-03 mandates cluster-scoped resources be prefixed with question-id (`q<id>-<name>`), but this is only enforced by lint-packs.sh's collision check (which CONTEXT D-12 leaves out — D-12 only checks per-question structure, not cross-question collisions). Phase 4+ adds the collision check (CI-03 mentions cluster-scoped-name collisions across questions in a pack).

**How to avoid:** Phase 3 establishes the **convention** (every cluster-scoped name = `q<NN>-<name>`, where NN matches the pack's question index). lint-packs.sh in Phase 3 should at minimum enforce that every cluster-scoped resource (`kubectl apply` for PV, ClusterRole, ClusterRoleBinding, StorageClass, etc.) in setup.sh has a name starting with `q01-`, `q02-`, ... matching the question's path-NN. Cross-question collision detection is a Phase 4 lint extension.

**Warning signs:** Two reference questions (e.g., storage/01 + storage/02 in a future expansion) share a PV name; running them back-to-back leaves stale state.

### Pitfall 7: `bash --version` 4 vs 5 affects `[[ =~ ]]` behavior
**What goes wrong:** Ubuntu 22.04 ships bash 5.1.16. macOS dev machines may have bash 3.2 (Apple's frozen-pre-GPLv3 default) or 5.x via Homebrew. Phase 2's pure-bash YAML parser uses `BASH_REMATCH` — works in 3.2+, but `declare -gA` (associative array, global scope) requires bash 4.2+. Phase 3 inherits this constraint.

**Why it happens:** The repo is target-Ubuntu-22.04 (per CONTEXT Platform), but contributors may run tests locally on macOS.

**How to avoid:** Phase 1 already established this constraint implicitly via `cka-sim doctor`'s required-binaries check. Phase 3 should add a one-line bash version check in `cka-sim/scripts/test.sh` that fails fast if bash < 4.2:
```bash
[[ "${BASH_VERSINFO[0]}" -ge 4 ]] || die "bash >= 4.2 required (found ${BASH_VERSION})"
```
**Warning signs:** `declare: -A: invalid option` errors when running test.sh on macOS bash 3.2.

---

## Code Examples

### Drill orchestrator skeleton (verified-against-Phase-1+2 patterns)
```bash
#!/bin/bash
# cka-sim/lib/cmd/drill.sh — Phase 3 implementation
# Source: replaces stub at lib/cmd/drill.sh:1-13

set -euo pipefail
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

source "$CKA_SIM_ROOT/lib/colors.sh"
source "$CKA_SIM_ROOT/lib/log.sh"
source "$CKA_SIM_ROOT/lib/preflight.sh"

# State populated by load_pack
declare -g CKA_SIM_PACK_ID="" CKA_SIM_QUESTION_ID="" CKA_SIM_QUESTION_DIR=""
declare -g CKA_SIM_LAB_NS="" CKA_SIM_QUESTION_INDEX="" CKA_SIM_QUESTION_MIN=""
declare -g CKA_SIM_DRILL_TMP=""

cka_sim::drill::usage() {
  cat >&2 <<EOF
usage: cka-sim drill <pack> [<n>]
  <pack>  one of: storage workloads-scheduling services-networking cluster-architecture troubleshooting
  <n>     1-based index into the pack's manifest.yaml (default: random)
EOF
}

cka_sim::drill::load_pack() {
  local pack="$1" picked="${2:-}"
  local manifest="$CKA_SIM_ROOT/packs/$pack/manifest.yaml"
  [[ -r "$manifest" ]] || die "pack manifest not found: $manifest"
  # ... pure-bash YAML parser as in Pattern 2 above ...
  # populates: CKA_SIM_PACK_QUESTION_IDS[], CKA_SIM_PACK_QUESTION_PATHS[], etc.

  local n=${#CKA_SIM_PACK_QUESTION_IDS[@]}
  (( n > 0 )) || die "pack '$pack' has no questions"

  local idx
  if [[ -z "$picked" ]]; then
    idx=$(( RANDOM % n ))
  elif [[ "$picked" =~ ^[0-9]+$ ]] && (( picked >= 1 && picked <= n )); then
    idx=$(( picked - 1 ))
  else
    die "invalid question index '$picked' (pack has $n questions, use 1-$n)"
  fi

  CKA_SIM_PACK_ID="$pack"
  CKA_SIM_QUESTION_ID="${CKA_SIM_PACK_QUESTION_IDS[$idx]}"
  CKA_SIM_QUESTION_INDEX=$(( idx + 1 ))
  CKA_SIM_QUESTION_DIR="$CKA_SIM_ROOT/packs/$pack/${CKA_SIM_PACK_QUESTION_PATHS[$idx]}"
  CKA_SIM_LAB_NS="cka-sim-${pack}-$(printf '%02d' $CKA_SIM_QUESTION_INDEX)"
  CKA_SIM_QUESTION_MIN="${CKA_SIM_PACK_QUESTION_MINUTES[$idx]}"

  # Verify the 6 question files exist + executable
  local f
  for f in metadata.yaml question.md setup.sh grade.sh reset.sh ref-solution.sh; do
    [[ -e "$CKA_SIM_QUESTION_DIR/$f" ]] || die "missing $f in $CKA_SIM_QUESTION_DIR"
  done
  for f in setup.sh grade.sh reset.sh ref-solution.sh; do
    [[ -x "$CKA_SIM_QUESTION_DIR/$f" ]] || die "$CKA_SIM_QUESTION_DIR/$f not executable"
  done

  export CKA_SIM_PACK_ID CKA_SIM_QUESTION_ID CKA_SIM_LAB_NS CKA_SIM_QUESTION_DIR
}

cka_sim::drill::prompt_ready() {
  local action=""
  printf "\nType 'done' to grade, 'skip' to abandon: " >&2
  if ! IFS= read -r action; then action="skip"; fi
  case "$action" in
    done) printf 'done' ;;
    *) printf 'skip' ;;          # treat anything else (incl. empty) as skip
  esac
}

cka_sim::drill::cleanup() {
  local rc=$?
  warn "cleaning up lab namespace $CKA_SIM_LAB_NS"
  bash "$CKA_SIM_QUESTION_DIR/reset.sh" || warn "reset.sh exited non-zero (rc=$?)"
  [[ -n "${CKA_SIM_DRILL_TMP:-}" ]] && rm -f "$CKA_SIM_DRILL_TMP"
  exit "$rc"
}

cka_sim::drill::render_header() {
  local report="$1"
  local catalog_version
  catalog_version=$(grep -c '^[[:space:]]*-[[:space:]]*id:' "$CKA_SIM_ROOT/traps/catalog.yaml")
  cat <<EOF
# cka-sim drill report

- timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- pack: $CKA_SIM_PACK_ID
- question-id: $CKA_SIM_QUESTION_ID
- question-index: $CKA_SIM_QUESTION_INDEX
- lab-ns: $CKA_SIM_LAB_NS
- estimated-minutes: $CKA_SIM_QUESTION_MIN
- actual-minutes: $(( ($(date +%s) - DRILL_START_TS) / 60 ))
- trap-catalog-entries: $catalog_version
- cka-sim-root: $CKA_SIM_ROOT
- report-path: $report

---

EOF
}

main() {
  case "${1:-}" in
    -h|--help|"") cka_sim::drill::usage; exit 0 ;;
  esac

  local pack="$1" picked="${2:-}"

  cka_sim::preflight::check_kubeconfig >/dev/null \
    || die "no readable kubeconfig (run 'cka-sim doctor')"
  cka_sim::preflight::check_cluster_nodes >/dev/null \
    || die "cluster topology check failed (run 'cka-sim doctor')"
  mkdir -p "$HOME/.cka-sim/reports"

  cka_sim::drill::load_pack "$pack" "$picked"

  declare -g DRILL_START_TS=$(date +%s)

  trap cka_sim::drill::cleanup EXIT
  header "drill: $CKA_SIM_PACK_ID / $CKA_SIM_QUESTION_ID  (lab ns: $CKA_SIM_LAB_NS)"

  info "step 1/4: reset"
  bash "$CKA_SIM_QUESTION_DIR/reset.sh"
  info "step 2/4: setup"
  bash "$CKA_SIM_QUESTION_DIR/setup.sh"
  info "step 3/4: prompt"
  cat "$CKA_SIM_QUESTION_DIR/question.md"
  info "Lab ns: $CKA_SIM_LAB_NS"

  local action
  action=$(cka_sim::drill::prompt_ready)
  if [[ "$action" == "skip" ]]; then
    warn "skipped"
    exit 130
  fi

  info "step 4/4: grade"
  CKA_SIM_DRILL_TMP=$(mktemp -t cka-sim-drill-XXXXXX.md)
  local report="$HOME/.cka-sim/reports/$(date -u +%Y%m%dT%H%M%SZ)-$CKA_SIM_PACK_ID-$CKA_SIM_QUESTION_ID.md"
  local grade_rc=0
  bash "$CKA_SIM_QUESTION_DIR/grade.sh" > "$CKA_SIM_DRILL_TMP" || grade_rc=$?

  # Compose final report
  { cka_sim::drill::render_header "$report"; cat "$CKA_SIM_DRILL_TMP"; } > "$report.partial"
  mv "$report.partial" "$report"

  # Echo to candidate
  cat "$CKA_SIM_DRILL_TMP"
  info "report saved to: $report"

  exit "$grade_rc"
}

main "$@"
```
`[VERIFIED: composes Phase 1 patterns from doctor.sh + Phase 2 grade.sh integration model]`

### lint-packs.sh skeleton (mirrors lint-traps.sh)
```bash
#!/bin/bash
# cka-sim/scripts/lint-packs.sh — GRADE-02 + PACK-06 lint
# Mirror of cka-sim/scripts/lint-traps.sh shape (Phase 2)

set -euo pipefail
CKA_SIM_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$CKA_SIM_ROOT/.." && pwd)"
source "$CKA_SIM_ROOT/lib/colors.sh"
source "$CKA_SIM_ROOT/lib/log.sh"
source "$CKA_SIM_ROOT/lib/traps.sh"   # for is_valid_id + id_exists

header "pack lint"

# Wave-0 graceful: if no packs/ exists yet (early plans not landed), skip
[[ -d "$CKA_SIM_ROOT/packs" ]] || { warn "no packs/ dir — skipping lint (expected during scaffold)"; exit 0; }

errors=0
checked=0

# (a) grade.sh GRADE-02 lint
while IFS= read -r grade_sh; do
  checked=$(( checked + 1 ))
  # Pass A: kubectl get ... | grep
  if grep -nE '^[[:space:]]*[^#]*kubectl[[:space:]]+get[[:space:]].*\|[[:space:]]*grep' "$grade_sh" >/dev/null; then
    err "GRADE-02: $grade_sh contains banned 'kubectl get | grep'"
    errors=$(( errors + 1 ))
  fi
  # Pass B: kubectl get -A
  if grep -nE '^[[:space:]]*[^#]*kubectl[[:space:]]+get[[:space:]]+-A([[:space:]]|$)' "$grade_sh" >/dev/null; then
    err "GRADE-02: $grade_sh contains banned 'kubectl get -A'"
    errors=$(( errors + 1 ))
  fi
done < <(find "$CKA_SIM_ROOT/packs" -name 'grade.sh' -type f)

# (b/c) metadata.yaml schema + trap-id registration
while IFS= read -r meta_yaml; do
  # Parse pure-bash (mirrors lint-traps.sh state machine), validate:
  #   - id, domain, estimatedMinutes ∈ [4,12], verified_against == "1.35", traps[] (≥3), references[]
  #   - every trap-id in traps[] passes cka_sim::trap::id_exists
  # ... (omitted for brevity; identical idiom to lint-traps.sh:124-180)
  :
done < <(find "$CKA_SIM_ROOT/packs" -name 'metadata.yaml' -type f)

# (d) every question dir has the 6 required files
while IFS= read -r q_dir; do
  for f in metadata.yaml question.md setup.sh grade.sh reset.sh ref-solution.sh; do
    [[ -e "$q_dir/$f" ]] || { err "$q_dir: missing $f"; errors=$(( errors + 1 )); }
  done
  # (e) setup/grade/reset/ref-solution executable
  for f in setup.sh grade.sh reset.sh ref-solution.sh; do
    [[ -x "$q_dir/$f" ]] || { err "$q_dir/$f: not executable"; errors=$(( errors + 1 )); }
  done
done < <(find "$CKA_SIM_ROOT/packs" -mindepth 2 -maxdepth 2 -type d)

# (f) no setup.sh contains 'kubectl delete ns' at top (runner-owned cleanup guard)
while IFS= read -r setup_sh; do
  if grep -nE '^[[:space:]]*[^#]*kubectl[[:space:]]+delete[[:space:]]+(namespace|ns)([[:space:]]|$)' "$setup_sh" >/dev/null; then
    err "D-09: $setup_sh contains 'kubectl delete ns' — runner owns cleanup"
    errors=$(( errors + 1 ))
  fi
done < <(find "$CKA_SIM_ROOT/packs" -name 'setup.sh' -type f)

if (( errors > 0 )); then
  err "$errors pack lint error(s) across $checked grade.sh file(s)"
  exit 1
fi
ok "pack lint passed ($checked grade.sh file(s) checked)"
```

### question.md skeleton (CKA-style prompt without spoilering the trap)
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

This style follows real PSI exam phrasing: tells the candidate the *symptom* and the *desired outcome*, never spells out the trap. The trap ("PV missing nodeAffinity") is in the data, the candidate must read `kubectl describe pv` to find it.

---

## Runtime State Inventory

> Phase 3 is greenfield (creates new packs and a new orchestrator), not a rename or migration. No existing runtime state needs sweeping. Skipping this section per the rubric.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| bash 4.2+ | drill.sh, lint-packs.sh, all setup/grade/reset.sh | ✓ (Ubuntu 22.04 ships 5.1.16) | 5.1.16 `[VERIFIED: Ubuntu 22.04 default]` | None — repo is target-Ubuntu |
| kubectl matching cluster | drill.sh, all setup/grade/reset.sh | Verified by Phase 1 `cka-sim doctor` (BOOT-07) | 1.35.x | None — required by the runtime contract |
| jq ≥ 1.6 | grade.sh detectors (Phase 2 already requires) | Verified by Phase 1 doctor | apt-default | None |
| coreutils (mktemp, tee, cat, date) | drill.sh report rendering | ✓ | apt-default | None — system base |
| 1+2-node Kubernetes 1.35 cluster (live) | GRADE-06 round-trip + manual drill verification | Per Phase 1 outstanding verification (still pending — see STATE.md) | varies | DF-12 deferred; document as human verification step (see Open Question Q1) |

**Missing dependencies with no fallback:** None. Phase 3's CI suite (lint-packs + bash unit tests) needs only what Phase 2 needs (apt-default jq, bash 5.x).

**Missing dependencies with fallback:** Live cluster for GRADE-06 round-trip — deferred per CONTEXT Claude's Discretion §"Test fixtures for Phase 3" to a documented human-verification step.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Pure-bash test harness (Phase 2's `cka-sim/tests/run.sh` + `cka-sim/tests/lib/assert.sh`) |
| Config file | None — convention-based (`tests/cases/*.sh` + `tests/fixtures/<scenario>/*.json`) |
| Quick run command | `bash cka-sim/scripts/test.sh` |
| Full suite command | `bash cka-sim/scripts/test.sh` (one-and-the-same — runs lint-traps + lint-packs + run.sh) |
| Live-cluster fixture | None — DF-12 deferred. Round-trip = human verification step. |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| TRIP-01 | Each question ships 6 files, all `chmod +x` | static (lint-packs) | `bash cka-sim/scripts/lint-packs.sh` | ❌ Wave 0 (lint-packs.sh new in plan 03-04) |
| TRIP-02 | setup.sh idempotent (runs twice, no AlreadyExists) | manual + structural | structural: `grep -L 'kubectl create' packs/**/setup.sh` (every line should be `kubectl apply`); manual: human re-runs `cka-sim drill` twice | ❌ Wave 0 (CKA cluster needed) |
| TRIP-03 | Lab ns named `cka-sim-<pack>-NN`; cluster-scoped resources prefixed `q<NN>-` | unit | `bash cka-sim/tests/cases/drill_namespace_construction.sh` | ❌ Wave 0 |
| TRIP-04 | reset.sh idempotent + uses --ignore-not-found | static (lint-packs) | `grep -L 'ignore-not-found' packs/**/reset.sh` returns empty | ❌ Wave 0 |
| TRIP-05 | Runner runs reset.sh before setup.sh | unit | `bash cka-sim/tests/cases/drill_orchestration_order.sh` (mock setup/reset/grade as bash logging stubs) | ❌ Wave 0 |
| TRIP-06 | Sentinel guards on append-only mutations | structural | grep for sentinel comments in any setup.sh that writes outside the ns | ❌ Wave 0 (likely no Phase 3 question hits this — note in plan) |
| GRADE-02 | grade.sh has no `kubectl get | grep` or `kubectl get -A` | static (lint-packs) | `bash cka-sim/scripts/lint-packs.sh` | ❌ Wave 0 |
| GRADE-03 | grade.sh emits `SCORE: N/M` + `Trap N: ...` | unit | `bash cka-sim/tests/cases/grade_emit_result.sh` (already exists from Phase 2 — extend to verify round-trip with the new questions' grade.sh files) | ⚠️ Partial (Phase 2 covers emit_result; Phase 3 adds question-specific cases) |
| GRADE-04 | metadata.yaml declares ≥3 trap-ids, all registered in catalog | static (lint-packs) | `bash cka-sim/scripts/lint-packs.sh` | ❌ Wave 0 |
| GRADE-06 | setup→grade FAILS; setup→ref-solution→grade PASSES | manual (human verification) | DF-12 deferred; document as procedure in 03-SUMMARY.md | ❌ Wave 0 (kind cluster fixture deferred) |
| RUN-02 | `cka-sim drill <pack> [<n>]` runs end-to-end | unit + manual | unit: `drill_load_pack.sh` for parsing/selection; manual: human runs `cka-sim drill storage` on CP node | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `bash cka-sim/scripts/test.sh` (runs lint-traps + lint-packs + all test cases — should complete in <10s)
- **Per wave merge:** `bash cka-sim/scripts/test.sh` + `bash -n` syntax check on every new .sh
- **Phase gate:** Full `test.sh` green AND human verification procedure documented in 03-SUMMARY.md, mirroring Phase 1's pending live-cluster steps

### Wave 0 Gaps
- [ ] `cka-sim/scripts/lint-packs.sh` — covers GRADE-02 + PACK-06 (D-12)
- [ ] `cka-sim/tests/cases/drill_load_pack.sh` — covers manifest parsing + pack selection logic
- [ ] `cka-sim/tests/cases/drill_question_selection.sh` — covers `$RANDOM`-bounded picking + 1-based index
- [ ] `cka-sim/tests/cases/drill_namespace_construction.sh` — covers `cka-sim-<pack>-NN` formatting
- [ ] `cka-sim/tests/cases/drill_orchestration_order.sh` — covers reset→setup→prompt→grade→reset call order via stub setup/grade/reset that log to stdout
- [ ] `cka-sim/tests/cases/lint_packs_grade02.sh` — positive AND negative fixtures for the GRADE-02 regex (a fixture grade.sh that uses `kubectl get -o jsonpath` legitimately must NOT trip the lint)
- [ ] `cka-sim/tests/fixtures/manifest/{storage,workloads-scheduling,...}.yaml` — sample manifests for the parser unit tests
- [ ] (Optional) `cka-sim/tests/fixtures/lint-packs/{good,bad-grep,bad-getall,bad-deletens}/grade.sh` — fixtures for lint-packs unit tests

---

## Project Constraints (from CLAUDE.md)

CLAUDE.md was not present in the working directory at research time. Only `~/.claude/projects/...MEMORY.md` provides a git-identity reminder (use `-c user.email=pvtcwd@gmail.com -c user.name=thienpv` for one-shot commits in this repo). No further project-level coding constraints to surface.

CONVENTIONS.md (`.planning/codebase/CONVENTIONS.md`) MANDATES:
- `#!/bin/bash` shebang on line 1 of every .sh
- LF line endings (`.gitattributes` already enforces `*.sh text eol=lf`)
- `set -euo pipefail` on validation/CI scripts (drill.sh, lint-packs.sh)
- `set -uo pipefail` (NO `-e`) on aggregate-failure scripts (every grade.sh, every reset.sh)
- ANSI color via `RED`/`GREEN`/`YELLOW`/`NC` from `lib/colors.sh` (TTY-aware)
- `REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"` idiom in scripts/
- All Kubernetes resource names = RFC 1123 (`[a-z0-9]([a-z0-9-]*[a-z0-9])?$`, ≤63 chars). lib/traps.sh's `is_valid_id` is the canonical implementation; lint-packs.sh MUST source and reuse, not re-implement.
- `apiVersion` pinning per CONVENTIONS.md table (e.g., NetworkPolicy = `networking.k8s.io/v1`, RBAC = `rbac.authorization.k8s.io/v1`, HPA = `autoscaling/v2`).
- Image pinning: `nginx:1.27`/`nginx:1.28`, `busybox:1.36`/`busybox:1.37` — never `:latest`.
- Inline gotcha comments encouraged in YAML manifests (the trap is also a teaching moment when revealed in the report — comment the seeded YAML lines that AREN'T the trap so the candidate has scaffold context, but DO NOT comment the trap line itself).

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `kubectl create -f` | `kubectl apply -f` | Always (idempotency) | Phase 3 NEVER `kubectl create` (TRIP-02). |
| `kubectl get foo \| grep bar` | `kubectl get foo -o jsonpath='{.field}'` or `-l label=value` | GRADE-02 (since Phase 0 of cka-sim) | lint-packs rejects the old idiom. |
| `kubectl run ... --requests=...` (deprecated flag) | YAML deployment with `resources.requests` | k8s 1.18+ | workloads-scheduling/01 uses YAML form via apply heredoc. |
| `--container-runtime=remote` flag | `--container-runtime-endpoint=unix:///...` | k8s 1.27 | Catalog already has this trap; no new question. |
| PSP (`PodSecurityPolicy`) | Pod Security Standards (`pod-security.kubernetes.io/enforce` ns label) | k8s 1.25 | Catalog already has `pss-error-string-mismatch`; not exercised by Phase 3's 5 reference questions (deferred to Phase 5 cluster-architecture pack). |
| `kubectl get endpoints` (still works in 1.35 but slated for deprecation) | `kubectl get endpointslices` | k8s 1.33+ | Phase 2's `assert_endpoints_nonempty` uses `kubectl get endpoints` — works in 1.35; revisit in v1.x if cluster moves to 1.34/1.35-default-EndpointSlice. |

**Deprecated/outdated:**
- `kubectl create ns` without dry-run pipe — fails on second run; Phase 3 never uses bare form.
- `kubectl exec ... -it` in non-interactive contexts — grade.sh runs non-interactively, so `kubectl exec ... --` (no `-it`) is correct.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | macOS-bash-3.2 contributors will fail test.sh; Linux contributors won't | Pitfall 7 | Low — adding the version check is one line; failure is loud and obvious. |
| A2 | Phase 7's `cka-sim score` parser will accept the 10-line markdown header proposed in the drill.sh skeleton | drill.sh skeleton + report header design | Medium — Phase 7 is far enough out that the parser can adapt to whatever header Phase 3 ships, but if Phase 7 demands JSON sidecar (not markdown), Phase 3's design needs revising. RECOMMEND: phrase the header as YAML front-matter (`---`-delimited) inside the .md so Phase 7 can choose markdown OR yaml-front-matter parsing. |
| A3 | `kubectl exec ... -- timeout 3 sh -c "echo > /dev/tcp/$h/$p"` (Phase 2's `assert_egress_allowed`) works for TCP probes against pod IPs in the lab ns | services-networking/01 grade design | Medium-High — `/dev/tcp` is a bash feature inside the pod; if the pod's image is `busybox` or `alpine`, `sh` is `ash`/`dash` which DON'T support `/dev/tcp`. Phase 3 must use an image that includes bash (e.g., `ubuntu:22.04` or a netcat-equipped image like `nicolaka/netshoot`). Plan 03-03 should pick the image deliberately and document. |
| A4 | The 5 reference questions can each be implemented with ONLY assertion helpers + 1-2 detectors from Phase 2 | Pattern 5 + per-question grade.sh sketches | Medium — workloads-scheduling/01 needs `assert_field_eq` on a deployment field (covered) + `default-sa-used` detector that reads from a Pod, requiring the test to wait for the deployment's pod to schedule. If pod is Pending (e.g., no node has CPU capacity), the detector returns nothing — false negative. Plan 03-03 must include a `kubectl wait --for=condition=Available deployment/load-app -n $ns --timeout=60s` before the detector call. |
| A5 | The catalog version (number of entries) is a useful header field for Phase 7 aggregation | drill.sh `render_header` | Low — if Phase 7 doesn't need it, harmless. |
| A6 | `kubectl auth can-i list pods --as system:serviceaccount:foo:viewer` correctly probes RBAC for cluster-architecture/01 | Pattern 5 RBAC question | High-confidence — `[VERIFIED: kubernetes.io/docs/reference/access-authn-authz/authentication/#user-impersonation]` |
| A7 | `assert_egress_allowed` for the DNS question can be replaced with a custom `kubectl exec ... nslookup` probe | Pattern 5 networking question | Low — straightforward bash. |
| A8 | DRILL_START_TS captured at top of main() is close enough to "actual minutes spent" for the report | drill.sh skeleton | Low — actual-minutes is informational, not load-bearing. |

---

## Open Questions

### Q1: GRADE-06 round-trip without a live cluster — automated CI or human verification?
**What we know:** CONTEXT Claude's Discretion §"Test fixtures for Phase 3" explicitly leaves this to plan execution. DF-12 (kind-cluster fixture) is deferred. The PATH-shadowed kubectl stub from Phase 2 keys fixtures by `CKA_SIM_TEST_CURRENT` — it cannot satisfy `setup.sh`'s free-form `kubectl apply -f - <<EOF ...EOF` without per-fixture pre-canned fixture matching, which is brittle.

**What's unclear:** Whether Phase 3 accepts a "human verification on the CP node" step (mirroring Phase 1's outstanding verification per STATE.md) — or commits to building enough kubectl-stub support to fake the round-trip in CI.

**Recommendation:** **Human verification.** Mirror Phase 1's pattern. Document in 03-SUMMARY.md a 5-minute procedure per question: "Run `cka-sim drill <pack> 1`. Don't fix anything. Type 'done'. Expect SCORE < max + ≥1 Trap line. Run `cka-sim drill <pack> 1` again. This time, before typing 'done', `bash $CKA_SIM_QUESTION_DIR/ref-solution.sh`. Then type 'done'. Expect SCORE = max + 0 traps." Total verification time: 25 minutes for all 5 questions. CI does the structural lint (lint-packs catches missing ref-solution.sh, missing +x, etc.) but NOT the behavioral round-trip. This is consistent with the v1.0 milestone's explicit "no kind fixture CI" policy.

### Q2: trapping EXIT inside drill.sh when subprocesses also have their own EXIT traps
**What we know:** Bash EXIT traps are per-process. drill.sh's EXIT trap fires only on drill.sh's exit. setup.sh / grade.sh / reset.sh run as subprocesses; their own internal traps don't propagate up. So setup.sh setting `trap 'echo "setup interrupted"' EXIT` is safe — it fires when setup.sh exits, not when drill.sh exits.

**What's unclear:** What happens if grade.sh ITSELF installs a trap that does `kubectl delete ...` cleanup? The expectation is that grade.sh is read-only (it should never mutate cluster state — only assert), but Phase 3 doesn't enforce this. Should lint-packs reject grade.sh files containing `kubectl delete|create|apply|patch|edit`?

**Recommendation:** Add to lint-packs.sh: reject grade.sh containing `kubectl (delete|create|apply|patch|edit|replace)`. Allowed verbs in grade.sh: `get`, `auth can-i`, `exec`, `describe`, `wait`, `logs`. Document the rule in AUTHORING.md. This is a Phase 3 lint extension beyond CONTEXT D-12 — flag as Claude's Discretion in the plan.

### Q3: Text-based detectors (`as-flag-format-wrong`, `pss-error-string-mismatch`) require captured candidate input
**What we know:** Phase 2 shipped 4 text-based detectors that take `<text>` as input — they grep candidate-submitted YAML/error-text/command-text for known wrong patterns. But Phase 3's drill mode never explicitly captures the candidate's *input* (their kubectl commands, their YAML files). It only captures the *cluster state* after the candidate types 'done'.

**What's unclear:** How do the 5 reference questions' grade.sh scripts feed candidate input to these detectors?

**Recommendation:** For Phase 3's 5 reference questions, **avoid the text-based detectors entirely**. The 5 traps mapped in CONTEXT D-10 are all state-based (hostpath-pv-without-nodeaffinity, default-sa-used, missing-dns-egress detect cluster state directly via kubectl). The text-based detectors stay in the catalog for future questions where candidate input IS captured (e.g., a future "submit your YAML" question style — out of scope for v1.0). One exception: cluster-architecture/01-rbac-viewer has `as-flag-format-wrong` mapped — the recommendation is to **demote** this to a state-based assertion (`assert_can_i list pods --as system:serviceaccount:...` returning "yes") and skip the text detector. Update CONTEXT D-10 (note Plan flag this for re-confirmation with user) — OR keep the trap mapping but document that the detector fires only via Phase 8's "submit-input" workflow if added.

### Q4: Should the lab-namespace name include the pack-domain or just the pack-id?
**What we know:** CONTEXT D-08 says `cka-sim-<pack>-<NN>`. Pack ids match domain ids per D-01 (e.g., `storage`, `services-networking`). So `cka-sim-services-networking-01` is the namespace name. RFC 1123: 25 chars — well under 63.

**What's unclear:** No issue — confirmed within budget.

### Q5: What if a question's `metadata.yaml` lists a trap-id NOT yet in the catalog?
**What we know:** CONTEXT D-12(c) requires every metadata.yaml trap-id be registered in `traps/catalog.yaml`. CONTEXT also says Phase 3 "extends the catalog with up to 5 new ids." Order matters: lint-packs.sh fires AFTER lint-traps.sh in test.sh; if a question's metadata references a not-yet-added trap, lint-packs fails.

**Recommendation:** Plan execution order MUST add the new catalog entries (plan 03-? for catalog extension) BEFORE the questions that reference them (plan 03-? for the questions). Suggest: catalog extension is its own early plan in the wave, questions are later plans depending on it. Phase 3 plan-checker should verify the wave dependency graph.

---

## Sources

### Primary (HIGH confidence)
- `cka-sim/lib/grade.sh` (Phase 2) — assertion helpers, accumulator state, emit_result format
- `cka-sim/lib/traps.sh` (Phase 2) — 8 detectors, pure-bash YAML parser pattern (lines 60-114), `is_valid_id`
- `cka-sim/lib/log.sh` (Phase 1) — `info`/`ok`/`err`/`die`/`header`/`warn` (all stderr)
- `cka-sim/lib/preflight.sh` (Phase 1) — `check_kubeconfig`, `check_cluster_nodes`
- `cka-sim/lib/cmd/doctor.sh` (Phase 1) — analog for drill.sh's command-module shape
- `cka-sim/lib/cmd/drill.sh` (Phase 1 stub) — slot to be filled
- `cka-sim/scripts/lint-traps.sh` (Phase 2) — analog for lint-packs.sh
- `cka-sim/scripts/test.sh` (Phase 2) — orchestrator, extend to invoke lint-packs.sh
- `cka-sim/tests/run.sh` + `cka-sim/tests/lib/assert.sh` + `cka-sim/tests/bin/kubectl` (Phase 2) — test harness
- `cka-sim/traps/catalog.yaml` (Phase 2) — 8 seeded entries, schema reference for new entries
- `.planning/codebase/CONVENTIONS.md` — bash style, RFC 1123, image pinning, apiVersion pinning
- `.planning/REQUIREMENTS.md` — TRIP-01..07, GRADE-02..06, RUN-02, PACK-06
- `.planning/phases/02-trap-framework-assertion-library/02-CONTEXT.md` — Phase 2 contract (16 decisions)
- `.planning/phases/02-trap-framework-assertion-library/02-PATTERNS.md` — pattern excerpts for the analogous Phase 3 lints/tests

### Secondary (MEDIUM confidence)
- [Red Hat: Troubleshooting Terminating Namespaces](https://www.redhat.com/en/blog/troubleshooting-terminating-namespaces) — root cause of `kubectl create ns` failures during reset's --wait=false window (verifies Pitfall 3)
- [GKE: Namespace Stuck in Terminating](https://docs.cloud.google.com/kubernetes-engine/docs/troubleshooting/terminating-namespaces) — corroborates the finalizer story for the wait loop
- [Linuxize: Bash Strict Mode Explained](https://linuxize.com/post/bash-strict-mode/) — interaction of `set -e` + `pipefail` + tee (Pitfall 1)
- [Baeldung: Exit Status of Piped Processes](https://www.baeldung.com/linux/exit-status-piped-processes) — PIPESTATUS array, why pipeline failures need explicit handling

### Tertiary (LOW confidence — flagged for validation)
- [help-bash thread: When Pipes Fail](https://lists.gnu.org/archive/html/help-bash/2018-11/msg00057.html) — SIGPIPE behavior in subshells (Pitfall 1, supplementary)
- [Pixelbeat: SIGPIPE Handling](http://www.pixelbeat.org/programming/sigpipe_handling.html) — system-level SIGPIPE doc

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — entirely composed of Phase 1+2 artifacts that already pass CI
- Architecture (drill.sh shape): HIGH — directly mirrors Phase 1's `doctor.sh`/`bootstrap.sh` shape
- Pure-bash manifest parsing: HIGH — `lib/traps.sh:60-114` is the verified template
- Pitfalls 1 (tee + EXIT trap): MEDIUM-HIGH — well-known bash trap; recommendation (mktemp + atomic mv) is the textbook fix
- Pitfall 2 (GRADE-02 regex): MEDIUM — regex shipped in this doc has been hand-traced but not yet unit-tested; plan must include positive + negative fixtures
- Pitfall 3 (ns stuck Terminating): HIGH — Kubernetes-documented behavior, multiple sources
- Pattern 5 (per-question detector wirings): MEDIUM — assumes Phase 2 detectors work as specified (they do per Phase 2 unit tests), but the workloads-scheduling/01 pod-readiness assumption (Assumption A4) needs the `kubectl wait` guard
- GRADE-06 round-trip: LOW — Open Question Q1; recommendation is to defer to human verification, but final call is on the user
- Text-based detectors in Phase 3: LOW — Open Question Q3; recommendation is to demote `as-flag-format-wrong` from CONTEXT D-10 to a state-based assertion

**Research date:** 2026-05-10
**Valid until:** 2026-06-10 (Kubernetes 1.35 is stable; bash 5.x is stable; no near-term breaking changes expected). If the cluster moves to 1.36 before Phase 3 ships, re-verify the EndpointSlice deprecation status.

## RESEARCH COMPLETE
