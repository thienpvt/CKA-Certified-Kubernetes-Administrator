# Phase 15: Live-Cluster Symptom-Diff CI — Context

**Gathered:** 2026-05-17
**Status:** Ready for planning
**Mode:** Interactive discuss (autonomous --interactive)

<domain>
## Phase Boundary

Build the durable safety net that catches future BUG-H01 / BUG-M08-class drift at PR time: a per-question `expected-symptom.yaml` + a CI step that runs `setup.sh` against a live kind cluster and diffs the resulting cluster state against the expectation.

**In scope:**
- `cka-sim/scripts/lint-question-symptom.sh` (CI-01 diff orchestrator)
- A per-question `expected-symptom.yaml` for ALL 38 questions across 5 packs
- Wire kind-cluster-bootstrap + symptom-diff into `.github/workflows/validate.yml`
- Synthetic regression test demonstrating the lint catches BUG-H01-class drift

**Out of scope:**
- Real-cluster CI for full ref-solution UAT (per REQUIREMENTS.md "Out of Scope" — v2.0)
- Domain coverage gap closure (file-baseline support for etcd snapshot, audit-policy YAML, node-level files — v2.0)
- Modifying any existing question.md / setup.sh / grade.sh content (Phases 10-14 already do that work)
</domain>

<canonical_refs>
## Canonical References

- `.planning/forensics/report-20260517-091657-full-audit.md` — recommended actions §8 ("Add a 'claimed-symptom verification' CI step"); BUG-H01 and BUG-M08 as motivating examples
- `.planning/REQUIREMENTS.md` — CI-01
- `.planning/ROADMAP.md` — Phase 15 success criteria (4 numbered items including "every question in all 5 domain packs ships an expected-symptom.yaml")
- `.github/workflows/validate.yml` — existing CI workflow with bash-tests + shellcheck jobs
- `cka-sim/scripts/test.sh` / `lint-packs.sh` / `lint-traps.sh` / `lint-coverage.sh` / `lint-deprecated-strings.sh` — sibling lints (style + structure to mirror)
- `cka-sim/lib/setup.sh` — `ensure_lab_ns`, `wait_for_ns_active` (per-question setup pattern)
- 38 question dirs under `cka-sim/packs/{storage,workloads-scheduling,services-networking,cluster-architecture,troubleshooting}/<NN>-*/`
- `cka-sim/scripts/validate-local.sh` — local validator (precedent for local-vs-CI parity)

No external docs/ADRs cited.
</canonical_refs>

<decisions>
## Implementation Decisions

### Cluster runtime — kind in GitHub Actions

**Decision:** kind cluster spun up in GHA runner; CNI = calico (or kindnetd with NP-aware fallback) so NetworkPolicy enforcement matches a kubeadm cluster's surface area.

**Why:**
- kind is closer to kubeadm topology than k3s (both use kubelet + containerd + standard CNI).
- Faster than provisioning real GCP VMs; runs inside a single GHA runner.
- ROADMAP success criterion 2 explicitly names "kind/k3s cluster" — kind is the more faithful choice.

**Implementation outline:**
- New CI job `symptom-diff` in `.github/workflows/validate.yml`.
- Steps: install kind + kubectl + calico (helm or manifests), create cluster, run lint-question-symptom.sh, capture artifacts on failure.
- Use existing `actions/cache` patterns if present in the repo for kind images.
- ~5-7 min CI time additional. Acceptable for v1.0.1.

### Expected-symptom format — Per-question YAML

**Schema (planner finalizes; pattern locked here):**

Each question dir gets `expected-symptom.yaml` with shape:

```yaml
# expected-symptom.yaml — describes the post-setup.sh cluster state question.md claims.
question: storage-pvc-binding
namespace: ${CKA_SIM_LAB_NS}   # or "kube-system" / cluster-scoped indicator
resources:
  - kind: PersistentVolume
    name: q01-app-pv
    expect:
      status.phase: Bound       # or Pending; only fields that question.md claims
      spec.storageClassName: manual
  - kind: Pod
    name: q01-consumer
    namespace: ${CKA_SIM_LAB_NS}
    expect:
      status.phase: Pending     # the symptom claim
      status.conditions[?(@.type=="PodScheduled")].reason: Unschedulable
absent_resources:               # optional: kinds/names that MUST NOT exist
  - kind: Service
    name: q01-app-svc
```

- Fields under `expect:` are jsonpath-rooted; the diff checks only listed fields (open-world: extra fields don't fail).
- `${CKA_SIM_LAB_NS}` substitutes at lint time.
- Cluster-scoped resources use `namespace: null` or are listed without namespace.
- Optional `absent_resources` for negative claims.

### Diff implementation — Pure bash + jq + python yaml

**Why:** matches the project's tech-stack constraint (bash-only, no Go/Python CLIs except python3 yaml/json which is already used elsewhere). Sibling lints (`lint-traps.sh`, `lint-packs.sh`) use the same toolchain.

**Implementation outline (planner refines):**

1. `cka-sim/scripts/lint-question-symptom.sh` walks `cka-sim/packs/*/*/expected-symptom.yaml`.
2. For each question:
   - Source `setup.sh` against a per-question lab namespace (use `cka_sim::setup::ensure_lab_ns` + a unique CKA_SIM_LAB_NS per question to avoid cross-pollination).
   - Wait for setup-spawned resources to settle (re-use the project's standard 60-120s wait pattern).
   - Capture `kubectl get <kinds-listed-in-expected> -o json` for the question's namespace + cluster-scoped.
   - Parse `expected-symptom.yaml` (python3 yaml).
   - For each `resources[i]`: jsonpath into the captured JSON, extract field, compare to expected. Mismatch → emit `q<NN>-<slug>: <field> expected '<E>', got '<G>'` with file:line.
   - For each `absent_resources[i]`: confirm the resource is NOT present.
   - Run question's `reset.sh` to clean up before moving to next question.
3. Exit 1 on any divergence; exit 0 if clean.

**Local-vs-CI parity:** lint-question-symptom.sh runs identically locally (against an existing kubeadm cluster) and in CI (against kind). Local invocation: `bash cka-sim/scripts/lint-question-symptom.sh [pack/question]` for individual questions during authoring.

**Hook into test.sh** so `bash cka-sim/scripts/test.sh` includes the symptom-diff (skipped if no live cluster — gated on `kubectl cluster-info` returning OK).

### Question coverage — All 38 questions

**Decision:** ship expected-symptom.yaml for all 38 questions in v1.0.1.

**Wave plan (planner refines):**
- Wave 0: lint script + per-question YAML schema + CI wire-up (testable on 1-2 questions inline).
- Wave 1: author expected-symptom.yaml for all 38 questions in parallel (one plan per pack, 5 plans).
- Wave 2: synthetic regression test + final UAT against full pack set + documentation.

**Authoring shortcut:** For each question, the author derives `expected-symptom.yaml` directly from question.md's claimed symptoms (NOT from running setup.sh — that would auto-generate the wrong-claim drift this CI is meant to catch). Where question.md says "PVC stuck Pending", expected says PVC.status.phase=Pending. Where question.md says "Deploy is unhealthy", expected says deployment readyReplicas=0 / status.conditions[Available]=False.

**Effort estimate:** ~30-45 min per question for authoring + lint runs = 19-28 person-hours, parallelizable across 5 pack-authors → 4-6 hours wall-clock if planned as 5 parallel plans.

### Synthetic regression test

Per ROADMAP success criterion 4: revert the storage/01 fix from Phase 10 and confirm the symptom-diff fails at PR time with file:line evidence.

**Implementation:**
- Add a CI-only test fixture or a dedicated test script that:
  1. Captures a baseline (post-Phase 10 expected-symptom.yaml for storage/01).
  2. Creates a synthetic regression (revert setup.sh to pre-Phase 10 state, OR mutate expected-symptom.yaml temporarily).
  3. Runs lint-question-symptom.sh and confirms exit 1 + clear citation.
  4. Restores baseline.

This can live as a unit test in `cka-sim/scripts/test.sh` invoking lint-question-symptom.sh against a synthetic-corrupt fixture.
</decisions>

<code_context>
## Existing Code Insights

**Sibling lint scripts (style):**
- `cka-sim/scripts/lint-packs.sh` — walks pack dirs, validates pack-level structure
- `cka-sim/scripts/lint-traps.sh` — pure-bash YAML state machine for catalog.yaml
- `cka-sim/scripts/lint-coverage.sh` — measures Tracker coverage
- All use `set -euo pipefail`, `source lib/colors.sh`, `source lib/log.sh` for `header`/`ok`/`err`/`warn`
- `cka-sim/scripts/test.sh` orchestrates all lints — extension point for symptom-diff

**Existing CI workflow:**
- `.github/workflows/validate.yml` already has `bash-tests` and `shellcheck` jobs running on push + PR
- New `symptom-diff` job extends this without disturbing existing jobs

**Per-question setup pattern (lib/setup.sh):**
- `cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" "$pack" "$question_id"` creates ns + labels
- `cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" "$pack" "$question_id" 120` blocks until Active
- Per-question namespace isolation makes the symptom-diff per-question safe

**Questions count:**
- storage: 6
- workloads-scheduling: 8
- services-networking: 6
- cluster-architecture: 8
- troubleshooting: 6
- TOTAL: 34 in domain packs (forensic report says 34; ROADMAP says "every question in all 5 domain packs"; mock-exam packs reference questions, so total expected-symptom.yaml count = 34, NOT 38).
- Decision: phase ships 34 expected-symptom.yaml (one per question in domain packs). The earlier "38" in PROJECT.md includes mock-exam pack manifests that compose by reference — those don't need their own symptom YAML.

**RFC 1123 names + idempotent setup/reset preserved** — symptom diff doesn't change any existing convention.
</code_context>

<specifics>
## Specific Ideas

- For BUG-H01 demo: storage/01-pvc-binding's expected-symptom.yaml after Phase 10 fix should claim `Pod q01-consumer status.phase=Pending` AND `PV status.phase=Bound`. Reverting the Phase 10 fix would make the lint fail.
- For BUG-M08 demo: troubleshooting/03-coredns-resolution's expected-symptom.yaml after Phase 14 fix should claim CoreDNS Deployment unhealthy (matching the question.md framing fix).
- Use `kubectl get <kind> <name> -o json` and extract via `jq` for field-by-field diff. python3 yaml.safe_load for the YAML side.
- Resource kinds to support in v1.0.1: pvc, pv, pod, svc, deploy, networkpolicy, configmap, secret, namespace, role, rolebinding, clusterrole, clusterrolebinding, serviceaccount, hpa, daemonset, replicaset, priorityclass, storageclass, volumesnapshot, volumesnapshotclass, ingress.
- Skip resources for which kind isn't installed in kind cluster (e.g. ingresscontroller-specific kinds) — emit a warn and skip.
- Use kind v0.23.0+ for K8s 1.35 compatibility.
- Calico via `kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.3/manifests/calico.yaml` is the canonical install pattern in CI.
- The lint script should run questions in parallel where possible (per-pack? per-question?) to keep CI time down. Planner decides.

## Number correction

The forensic report and PROJECT.md cite "38 questions" but the domain-pack count is **34** (storage 6 + ws 8 + sn 6 + ca 8 + ts 6). The "38" includes 4 questions that exist as mock-exam-pack-only references. ROADMAP success criterion 1 says "every question in all 5 domain packs" → 34 expected-symptom.yaml files. Verify during planning.
</specifics>

<deferred>
## Deferred Ideas

- Real-cluster CI running ref-solution.sh end-to-end (full UAT) — explicitly out of scope per REQUIREMENTS.md (v2.0).
- Multi-CNI test matrix (kindnetd + calico + cilium) — overkill; one CNI sufficient for v1.0.1.
- Auto-generating expected-symptom.yaml from a "source of truth" question taxonomy — out of scope; manual authoring catches drift.
- Drift detection for mock-exam-pack questions (those that reference domain-pack questions) — covered by domain-pack diffs.
- Deletion of stale `expected-symptom.yaml` if a question gets removed — out of scope; lint will surface naturally.
</deferred>
