# Pitfalls Research

**Domain:** CKA exam simulator (bash-only kubectl-driven runner against learner's own 1+2 Ubuntu/kubeadm cluster, K8s v1.35)
**Researched:** 2026-05-07
**Verified against v1.0 milestone scope on 2026-05-07** — all 14 pitfalls remain in scope for the locked stack (bash-only, Ubuntu 22.04, kubeadm 1.35, 1+2 GCP). No pitfalls invalidated by scope changes.
**Confidence:** HIGH for content/curriculum drift (verified against Context7 KEPs and the in-tree `.planning/codebase/CONCERNS.md`); MEDIUM for runner-construction patterns (verified against bash/kubectl semantics, but specific killer.sh internals were not directly accessible during research and are flagged where used)

> Each pitfall below is **specific to a CKA-simulator** — not generic software-engineering hygiene. Generic items (e.g. "log errors", "validate inputs") are intentionally omitted.

---

## Critical Pitfalls

### Pitfall 1: Non-idempotent `setup.sh` poisons the lab on re-run

**What goes wrong:**
A `setup.sh` like `kubectl create ns exercise-07 && kubectl apply -f broken-pod.yaml -n exercise-07` works the first time. Re-running it after a failed grade emits `AlreadyExists` errors, leaves stale objects from the previous attempt, or — worse — leaves the namespace in `Terminating` if a finalizer is stuck. The candidate's second drill of the same question grades against state that the new `setup.sh` could not actually rebuild.

**Why it happens:**
Bash + kubectl idempotence is not free. `kubectl create` errors on existing objects; `kubectl apply` is idempotent for the spec but leaves orphans (objects from a previous shape of the lab that the new manifest no longer mentions); `kubectl delete ns ... && kubectl create ns ...` race-conditions with `Terminating` namespaces; finalizers (NetworkPolicy, PVCs with retain, ValidatingAdmissionPolicy bindings) can hang forever.

**How to avoid:**
Author a setup template, not free-form scripts. Every `setup.sh` MUST follow this skeleton:

```bash
#!/bin/bash
set -euo pipefail
NS="exercise-NN"

# 1. Force-delete the namespace if it exists, wait for terminate
kubectl get ns "$NS" >/dev/null 2>&1 && {
  kubectl delete ns "$NS" --wait=false --timeout=10s 2>/dev/null || true
  # bounded wait, then nuke finalizers
  for i in $(seq 1 30); do
    kubectl get ns "$NS" >/dev/null 2>&1 || break
    sleep 1
  done
  kubectl get ns "$NS" >/dev/null 2>&1 && \
    kubectl get ns "$NS" -o json | jq '.spec.finalizers=[]' | \
    kubectl replace --raw "/api/v1/namespaces/$NS/finalize" -f - >/dev/null
}

# 2. Recreate with kubectl apply (NOT create)
kubectl create ns "$NS" --dry-run=client -o yaml | kubectl apply -f -

# 3. Cluster-scoped objects: name-spaced by question (e.g. cr-q07-viewer, pv-q07-data) and apply, not create
kubectl apply -f - <<'EOF'
...
EOF

# 4. Wait for the broken state to actually exist (so grader doesn't race)
kubectl wait --for=condition=PodScheduled pod/foo -n "$NS" --timeout=30s || true
```

**Warning signs:**
- A `setup.sh` contains `kubectl create` for namespaced or cluster-scoped objects without a preceding `kubectl delete || true`
- No `set -euo pipefail` at the top
- Cluster-scoped objects (ClusterRole, PV, StorageClass, ValidatingAdmissionPolicy, PriorityClass) without a question-prefixed name (`q07-cr-viewer`, not `viewer`) — guarantees collision when two questions ship the same generic name
- Second-run output contains `AlreadyExists` or `error: timed out`

**Phase to address:**
Phase that defines the question runtime contract (the `setup.sh`/`grade.sh`/`reset.sh` triplet). Add a **CI check** that runs every `setup.sh` twice in succession against a kind/k3s cluster — second run must exit 0 with no `AlreadyExists` warnings.

**Cross-ref to existing CONCERNS.md:** `scripts/exam-setup.sh` already has this exact disease — `cat <<'EOF' >> ~/.vimrc` appends N copies on N runs. The new runtime template must not repeat this pattern.

---

### Pitfall 2: Grader false positives — passes when the candidate solved it the wrong way

**What goes wrong:**
Question: "Create a NetworkPolicy in namespace `exercise-05` that lets pods labelled `app=web` reach pods labelled `app=db` on TCP/5432." The grader runs `kubectl get netpol -n exercise-05 | grep web-to-db && echo PASS`. A candidate who created `web-to-db` with `policyTypes: [Ingress]` but no DNS egress rule passes the grader, then gets a flat `0` on the real exam where `kubectl exec web -- nslookup db` fails.

**Why it happens:**
Existence checks are easy to write; **behavioural** checks are hard. Authoring graders is harder than authoring questions, so pressure-to-ship pushes graders toward `kubectl get | grep`. This is the most common failure mode of every public CKA-practice repo.

**How to avoid:**
Every grader assertion must be **behavioural-or-structural**, not name-existence:

| Bad assertion | Good assertion |
|---------------|----------------|
| `kubectl get netpol web-to-db -n NS` | `kubectl run probe --image=busybox:1.37 --rm -it --restart=Never -n NS -- wget -T2 -qO- db:5432` |
| `kubectl get pod foo -n NS \| grep Running` | `kubectl wait --for=condition=Ready pod/foo -n NS --timeout=10s` |
| `kubectl get ds -A \| grep node-exporter` | `[ "$(kubectl get ds -n monitoring node-exporter -o jsonpath='{.status.numberReady}')" -eq "$(kubectl get nodes -o name \| wc -l)" ]` |
| `kubectl get rolebinding foo -o yaml \| grep ServiceAccount` | `kubectl auth can-i get pods --as=system:serviceaccount:NS:foo -n NS` (returns `yes`/`no`) |
| `kubectl get pv pv-data \| grep Bound` | `kubectl get pvc -n NS my-pvc -o jsonpath='{.spec.volumeName}'` and assert it equals `pv-data` |
| `kubectl get hpa foo \| grep 2/5` | `kubectl get hpa foo -n NS -o jsonpath='{.spec.minReplicas},{.spec.maxReplicas}'` and parse |

Behavioural assertions that **act like the user** (`auth can-i`, `kubectl exec ... wget`, `kubectl wait`, `kubectl run probe`) are immune to the most common false-positive classes.

**Warning signs:**
- Grader uses `grep` on `kubectl get` output (almost always brittle)
- Grader does not use any of `auth can-i`, `kubectl wait`, `kubectl exec ... -- <probe>`, or jsonpath comparison
- Grader passes if the object exists, regardless of `.spec.*`

**Phase to address:**
Phase that defines the grader contract. Ship a **grader-assertion library** (`lib/assert.sh`) with reusable functions: `assert_pod_ready NS NAME`, `assert_can_i SA NS VERB RES`, `assert_egress_allowed FROM_NS FROM_LABEL TO_HOST PORT`, `assert_pvc_bound NS NAME`, `assert_field NS KIND NAME JSONPATH EXPECTED`. Every grader sources this lib and uses these — never raw grep.

---

### Pitfall 3: Grader false negatives — passes locally, fails because the cluster is "noisy"

**What goes wrong:**
Q3's grader runs `kubectl get pods -A | wc -l` and expects exactly 4 pods. A previous question left a coredns probe pod alive in `kube-system`, or the candidate has metrics-server running. Grader fails. Candidate spends 4 min of exam time re-doing a question they got right.

**Why it happens:**
Graders implicitly assume a clean global cluster state. They aren't, in practice — kube-system, monitoring, ingress controllers, prior-question artefacts in cluster-scoped namespaces all leak. `kubectl get pods -A | wc -l` and `kubectl get clusterrole | grep foo` are the two most common ways to write this bug.

**How to avoid:**
- **Always scope queries to the question's namespace.** `-n exercise-NN` on every namespaced lookup. Never `-A` in graders.
- **For cluster-scoped objects** (ClusterRole, PV, StorageClass, PriorityClass, ValidatingAdmissionPolicy, etc.), prefix names with the question id (`q07-cr-viewer`, not `viewer`) so other questions / pre-existing cluster state cannot collide.
- **Use `--field-selector` / `--selector` not regex on `get` output.** `kubectl get pods -n NS -l role=app -o name` is robust; `kubectl get pods -n NS | grep app` matches `app-foo`, `app-bar`, and a stray `myapp-canary` indistinguishably.
- **For node assertions, target the specific node by name** that the question wrote to (e.g. `kubectl get node node-01 -o jsonpath=...`), not "the worker that has X label", which can drift.
- **Tolerate ordering.** `jsonpath='{.spec.containers[?(@.name=="web")].image}'` not `jsonpath='{.spec.containers[0].image}'` (the candidate may have reordered containers).

**Warning signs:**
- Grader uses `kubectl get -A`, `kubectl get pods | wc -l`, or `kubectl get cr | grep`
- Grader uses `[0]` / `[1]` index in jsonpath instead of a `?(@.name==...)` filter
- Grader fails on a fresh cluster but passes after `setup.sh` — usually means setup is creating the thing the grader checks for, instead of the candidate

**Phase to address:**
Same phase as Pitfall 2 — the grader-assertion library should make scoping easy and `-A`/`grep` hard. Add a **lint rule** to the CI (a regex check) that fails any `grade.sh` containing `kubectl get -A` or `kubectl get [^|]*| *grep`.

---

### Pitfall 4: Cross-question state leak inside one exam session

**What goes wrong:**
Q2 creates `clusterrole/viewer`. Q5 also creates `clusterrole/viewer` with different rules. The candidate finishes Q2, moves to Q5, runs Q5's `setup.sh` — which apply-overwrites Q2's CR, breaking re-grading. At end-of-exam, the runner re-grades all questions for the score report; Q2 is now `FAIL` because its CR was clobbered.

**Why it happens:**
Cluster-scoped state is global. A 17-question exam touches the cluster 17 times, and any naming clash silently mutates a previously-passed question. Compounded by a Reset-not-running-between-questions design choice (because resetting between Qs is exam-realistic — the real exam doesn't reset).

**How to avoid:**
- **Per-question name-spacing for cluster-scoped objects** (see Pitfall 3). Mandate prefix `q<NN>-` on every cluster-scoped name a question creates.
- **End-of-exam grading reads from a snapshot, not the live cluster.** When the candidate clicks "submit" or the timer ends, `cka-sim` does the per-Q `grade.sh` runs immediately, in question-order, and stores `PASS|FAIL|TRAP-N` in `~/.cka-sim/sessions/<id>/results.json`. No re-grading later.
- **Document a clear "do not modify prior-question state" rule** in the exam-pack metadata, and have the runner refuse to start an exam if cluster-scoped objects from a prior unfinished session are still present (`cka-sim exam --resume` or a hard reset prompt).

**Warning signs:**
- Two questions in the same pack create cluster-scoped objects with the same name
- Re-grading the same session produces different results
- A question's `reset.sh` deletes a cluster-scoped object that another question depended on

**Phase to address:**
Phase that wires up the multi-question runner (after the per-question triplet works). Add a **pack-level lint** that diffs cluster-scoped object names across all questions in a pack and fails on collision.

---

### Pitfall 5: Bash signal handling — Ctrl-C orphans the timer subshell

**What goes wrong:**
The runner spawns a background timer (`(while true; do tput cup ...; sleep 1; done) &`) to draw the wall clock. Candidate hits Ctrl-C to flag-and-skip a question. Bash propagates SIGINT to the foreground shell and the timer subshell. Either: (a) timer subshell becomes a zombie because no `wait`; (b) Ctrl-C kills the runner entirely instead of "flag this Q"; (c) timer keeps drawing into the next question's prompt and corrupts the screen.

**Why it happens:**
`tput`-based timers in pure bash are tricky. The standard pattern (background subshell with `&`, `tput sc`/`tput rc`/`tput cup`) requires explicit `trap` setup, careful TTY save/restore, and consideration of `SIGINT` vs `SIGTERM` vs `SIGTSTP` (Ctrl-Z).

**How to avoid:**
- **Use `trap` aggressively** in the runner entrypoint:

  ```bash
  trap 'cleanup_and_persist' EXIT
  trap 'flag_current_question; resume_prompt' INT  # Ctrl-C = flag, NOT exit
  trap 'pause_session' TSTP                         # Ctrl-Z = pause
  ```

- **Track the timer PID explicitly** (`TIMER_PID=$!`) and `kill "$TIMER_PID" 2>/dev/null` in `cleanup_and_persist`.
- **Save/restore the cursor** around every timer redraw (`tput sc; tput cup ...; tput rc`).
- **Persist session state on every keystroke** (`~/.cka-sim/sessions/<id>/state.json`). If the runner is killed by `kill -9`, `cka-sim resume <id>` must work — the timer's elapsed time, the question index, and any flags are recoverable.
- **Test with `bash --posix` and `dash`-incompatibilities** explicitly disallowed; we target bash 5.x on Ubuntu 22.04, document it, and CI-test in that exact image.

**Warning signs:**
- Runner uses `&` without `trap`
- Quitting the runner leaves a `(while true; ...) &` process visible in `ps`
- Ctrl-C kills the whole exam instead of flagging the current Q
- `tput` output appears on the next prompt after the runner exits

**Phase to address:**
Phase that builds the runner CLI (after question content + grading is solid). Write a **5-line acceptance test** for the runner: start exam, hit Ctrl-C in Q3, verify (a) Q3 is marked flagged, (b) timer is alive, (c) prompt is clean. Run on Ubuntu 22.04 + bash 5.x.

---

### Pitfall 6: Trap diagnostics that are too generic ("you got it wrong")

**What goes wrong:**
Grader prints `FAIL` and a hint like `"check your network policy"` or `"the pod is not running, see kubectl describe"`. Candidate has no idea whether they (a) put it in the wrong namespace, (b) used wrong selector, (c) forgot DNS egress, (d) typo'd the port. Trap diagnostics that are vague are pedagogically equivalent to a binary pass/fail — and binary pass/fail is what the prose mock-exams already give. The differentiator is GONE.

**Why it happens:**
Writing a *named* trap requires the question author to enumerate the top 3-5 actual mistakes a candidate would make on this question. That's hard, and there's a temptation to ship `Trap 1: incorrect configuration` as a placeholder.

**How to avoid:**
- **Authoring template requires ≥3 named traps per question** with the structure:

  ```
  Trap N: <one-line class of mistake>
  Detection: <kubectl-driven check that returns true iff the candidate fell into this trap>
  Remediation hint: <one-line pointer, e.g. "RoleBinding subject must use --as=system:serviceaccount:<ns>:<sa>, not :<sa>">
  ```

- **Grader tries each trap detection in order on FAIL.** The runner prints the first matching trap. If no trap matches, prints `Trap 0: unrecognised failure — re-run setup.sh and try again`.
- **Trap names enter a global trap-catalog** (`packs/<pack>/TRAP-CATALOG.md`) so the end-of-exam report can aggregate frequencies across questions ("you hit `wrong-namespace` 4 times, `missing-dns-egress` 2 times").
- **Cross-reference traps to the existing `.planning/codebase/CONCERNS.md` content bugs** so the new graders teach the right mental model from day one. Concrete required traps to ship in the catalog:
  - `pss-error-string-mismatch` — candidate expects `violates PodSecurityPolicy:` (the wrong wording from old PSP). Real wording is `violates PodSecurity "<level>:<version>"`. Ref: CONCERNS.md item 1.
  - `psp-fictional-pod-label-exemption` — candidate writes `pod-security.kubernetes.io/exempt: 'true'` on a Pod. No such label. Ref: CONCERNS.md item 2.
  - `kubelet-runtime-flag-in-kubeconfig` — candidate edits `/etc/kubernetes/kubelet.conf` (the kubeconfig) instead of `/var/lib/kubelet/kubeadm-flags.env`. Ref: CONCERNS.md item "CRI-dockerd kubelet flag".
  - `removed-container-runtime-flag` — candidate uses `--container-runtime=remote` (removed in 1.27). Should be `--container-runtime-endpoint`. Ref: CONCERNS.md.
  - `hostpath-pv-without-nodeaffinity` — candidate creates `hostPath` PV with no `nodeAffinity`; works on single-node, fails silently on the 1+2 cluster. Ref: CONCERNS.md "Security Example Hygiene".
  - `as-flag-format-wrong` — candidate uses `--as=foo` instead of `--as=system:serviceaccount:<ns>:<sa>`. Ref: existing exercise 04 conventions.
  - `default-sa-used` — candidate omits `serviceAccountName`, defaulting to `default` SA. Ref: CONCERNS.md.
  - `missing-dns-egress` — NetworkPolicy without UDP/53 egress to kube-dns. Ref: existing exercise 05.

**Warning signs:**
- A question ships with `Trap 1: configuration error` (vague language)
- The same trap text appears on more than 3 questions (it's a universal placeholder, not a real diagnostic)
- The end-of-exam report shows `Trap 1: configuration error` as the most-frequent trap (reveals the placeholder)

**Phase to address:**
Phase that authors the first 5 questions (canonical pack). Make a question's PR mergeable only if it (a) ships ≥3 named traps, (b) those names appear in `TRAP-CATALOG.md`, and (c) at least one trap detection has been verified by deliberately failing the question.

---

### Pitfall 7: Question time budgets that don't match the real exam's 7-8 min/question

**What goes wrong:**
Question pack ships with arbitrary times: `Q1: 10 min, Q2: 5 min, Q3: 15 min`. Total is 145 minutes for 17 questions. Candidate practises against this and gets a false sense of pacing. On the real exam — 120 minutes for ~17 questions, ~7 min/Q average — they run out of time on Q14.

**Why it happens:**
Authors estimate based on how long it took *them* (with full knowledge of the answer) to complete the task, not how long it takes a candidate working under stress.

**How to avoid:**
- **Pack-level budget invariant:** sum of question times in any 17-question exam pack = 110-120 minutes (matches the real exam's 120 min for ~17 questions).
- **Per-question budget range:** 4 min (trivial) to 12 min (multi-step). Average 7. Reject any single question budgeted at >15 min in an exam pack — split it.
- **Question difficulty tags drive the budget**, not the author's estimate. `Easy = 5 min`, `Medium = 8 min`, `Hard = 12 min`. Rerun the math at pack-build time.
- **Calibration drill:** the runner records actual time-to-pass for the user. After 5 sessions, surface the delta vs the budgeted time so the user knows which questions are mis-budgeted (and the pack maintainer can adjust).

**Warning signs:**
- Pack sum > 130 min for 17 questions
- Single question budgeted > 15 min
- "Time" tag in the exercise table doesn't match the pack metadata

**Phase to address:**
Phase that builds the first mock-exam pack. Add a **pack validator script** (`scripts/validate-pack.sh`) that fails CI if budgets sum out of range or any single Q exceeds 12 min.

---

### Pitfall 8: Question depends on cluster features the learner's cluster doesn't have

**What goes wrong:**
Question requires `metrics-server` (HPA), or Calico-specific NetworkPolicy `egress.to.dns`, or a CSI driver that supports `VolumeSnapshot`, or Gateway API CRDs. Learner's vanilla kubeadm + default-CNI cluster doesn't have it. Setup.sh fails or, worse, succeeds-but-with-different-semantics, and the grader fails for reasons unrelated to the candidate's solution.

**Why it happens:**
Authors test on their own well-equipped cluster (killer.sh, kind-with-metrics-server, GKE) and forget that the target topology is **bare kubeadm 1+2 on Ubuntu 22.04 with whatever the candidate's CNI was at provisioning time**.

**How to avoid:**
- **Question metadata declares prerequisites explicitly.** `requires: [metrics-server, gateway-api-crd, networkpolicy-cni]`. The runner refuses to drill a question whose prereqs aren't met (`cka-sim drill workloads/16-hpa` → `prerequisite metrics-server not installed; run cka-sim install metrics-server first`).
- **Provide a `cka-sim install <component>` subcommand** that bootstraps the standard add-ons (metrics-server, gateway-api-crd, calico if needed) using their official upstream YAML. Idempotent. Documented version-pinned URLs.
- **Default to vendor-neutral primitives.** No `cilium-cli`, no `tigera-operator`-specific CRDs, no GKE PDs. NetworkPolicy questions use the upstream `networking.k8s.io/v1` API, which any conformant CNI implements.
- **Cluster sniffing on session start.** `cka-sim exam <pack>` runs `kubectl api-resources`, `kubectl get nodes`, `kubectl get crd` once and caches the capability profile. Question setup checks against it.

**Warning signs:**
- Setup.sh installs CNI-specific CRDs as part of the question
- Question references an annotation prefixed with a vendor (`projectcalico.org/`, `cilium.io/`)
- Setup.sh fails on a fresh kubeadm cluster that worked on the author's

**Phase to address:**
Phase that defines the question metadata schema (front-matter on each question's `meta.yaml`). The cluster-bootstrap script (already in scope per `PROJECT.md` Active item 1) is the right home for `cka-sim install`.

---

### Pitfall 9: Practising imperative `kubectl edit` skills against a slow PSI no-paste shell

**What goes wrong:**
Question solution shows `cat <<EOF | kubectl apply -f -` with 40 lines of YAML. Candidate practises by pasting that block. On the real exam, the PSI Chromebook environment has clipboard restrictions and no full-fidelity copy-paste — the candidate has to type 40 lines under time pressure or recall the equivalent imperative `kubectl create deployment ... --dry-run=client -o yaml | k apply -f -`. They lose 4 minutes per question doing what was 4 seconds at home.

**Why it happens:**
YAML-from-memory is what learners *want* to practise; imperative-kubectl is what the exam *requires*. Authors who write solutions in YAML transmit the wrong skill.

**How to avoid:**
- **Solution authoring rule:** every solution must demonstrate the **imperative** path first (`kubectl create deployment foo --image=nginx:1.28 --replicas=3 -- ...`) and only fall back to YAML for fields the imperative can't set (e.g. tolerations, init containers, native sidecars). YAML edits should use `kubectl edit` or `$do | sed | kubectl apply` — not heredocs.
- **The runner doesn't run the candidate's solution; it runs `grade.sh` against whatever final state the candidate produced.** This is automatic — the candidate is free to use whatever they want. The teaching pressure is in the *Solution* section of the question.
- **Bake the existing alias contract** (`$do = --dry-run=client -o yaml`, `$now = --force --grace-period=0`) into every solution. Already in `scripts/exam-setup.sh`.
- **Discourage "long YAML" solutions** in the authoring template — a question whose solution is 60 lines of YAML is probably the wrong shape for an exam.

**Warning signs:**
- Solution starts with `cat <<EOF | kubectl apply -f -` and has > 30 lines of YAML
- Solution uses `vim` or `kubectl edit` for fields that `kubectl create` could set imperatively
- No `$do` or `$now` aliases in the solution

**Phase to address:**
Phase that authors the first canonical question. The authoring template (in `CONTRIBUTING.md` for the simulator) should embed an "imperative-first" rule and a YAML-line budget.

---

### Pitfall 10: Practising on minikube/kind, then sitting the exam on real multi-node kubeadm

**What goes wrong:**
A common outcome with single-node practice: hostPath PVs work, NodeAffinity is forgiving, all pods land on the same node so cross-node networking issues never surface, taints/tolerations are theoretical. On the real multi-node exam, the candidate's solution that worked at home has six new failure modes (DNS over the pod-network CIDR, NodePort-vs-ClusterIP, scheduler-fairness, cross-node NetworkPolicy enforcement).

**Why it happens:**
minikube/kind are easier to install. The friction-free path teaches the wrong cluster shape.

**How to avoid:**
- **PROJECT.md already mandates 1+2 on Ubuntu 22.04 (kubeadm).** Lock this in as a hard requirement in the cluster-bootstrap script: `cka-sim doctor` must verify `kubectl get nodes` returns ≥3 nodes with at least one labelled `node-role.kubernetes.io/control-plane=` and ≥2 workers, and refuse to start a session if not.
- **Question content that exercises multi-node specifics**: at least 2 questions per pack must require `nodeSelector` / `nodeAffinity` / `tolerations` / cross-node Service routing — features that are no-ops on single-node and only fail on multi-node.
- **Forbid `hostPath` PVs without `nodeAffinity`** in setup.sh. Ref CONCERNS.md `hostPath PVs everywhere, no node-pinning`.
- **Document the cluster topology** in the runner banner so the candidate can't forget it.

**Warning signs:**
- `cka-sim doctor` not run, or returns < 3 nodes
- Question setup creates a `hostPath` PV without `nodeAffinity`
- Cross-node behaviour never tested in any question

**Phase to address:**
Phase that builds the cluster-bootstrap script (already PROJECT.md Active item 1). Wire `cka-sim doctor` into the runner's exam-start path.

---

### Pitfall 11: Content drift to v1.32-v1.34 deprecations / pre-release features stated as GA

**What goes wrong:**
The repo authors a question against PSP (removed in 1.25), or `--container-runtime=remote` (removed in 1.27), or `gitRepo` volumes (removed in 1.32 per KEP-5040), or assumes Validating Admission Policy is alpha when it went GA in 1.30. Candidate practises the wrong answer, then fails the real v1.35 exam.

**Why it happens:**
Author's training data / past notes are stale. The existing repo already shipped this bug (CONCERNS.md items 1, 2, 3, "CRI-dockerd kubelet flag", "Dockershim removal version misstated"). It WILL recur if not gated.

**How to avoid:**
- **Maintain a "current as of v1.35" feature matrix** in `packs/_meta/v1_35_feature_matrix.md` listing the GA/Beta/Alpha/Removed status of every API touched by any question. Concrete v1.35-relevant entries (verified via Context7 KEP):
  - **Validating Admission Policy**: GA in 1.30 (KEP-3488). Use `admissionregistration.k8s.io/v1`. Available in v1.35.
  - **Native Sidecar Containers** (`initContainer.restartPolicy: Always`): GA in 1.33 (KEP-753). Available in v1.35. Default-on, no feature gate needed.
  - **Gateway API**: GA at API level (gateway.networking.k8s.io/v1) but **CRDs are not installed by default** — questions must declare it as a prereq and the bootstrap script must offer to install the upstream CRDs.
  - **PodSecurity Admission**: GA in 1.25. PSP is **gone** (no PSP API, no PSP error string). PSS error wording: `violates PodSecurity "<level>:<version>"`.
  - **Dockershim**: removed in 1.24 (NOT 1.35 — the existing repo gets this wrong, ref CONCERNS.md).
  - **`gitRepo` volume**: removed (KEP-5040 verified via Context7). Don't author against it.
  - **Mutating Admission Policy** (CEL-based): may still be alpha/beta in 1.35; treat as out-of-scope for CKA exam questions.
  - **kubelet runtime flag**: `--container-runtime` (removed 1.27); use `--container-runtime-endpoint` only.
- **CI lint** that scans every question's setup/grade/solution for deprecated strings: `PodSecurityPolicy`, `--container-runtime=remote`, `policy/v1beta1`, `extensions/v1beta1`, `gitRepo:`, `dockershim`, etc. Fail PR if matched.
- **Question front-matter declares the K8s minor version** it was authored/verified against. CI fails if any question declares < 1.35.
- **Periodic audit at every K8s minor release** (every ~4 months). Owner reviews the K8s release notes and updates the feature matrix.

**Warning signs:**
- Any string from the deprecated-strings list appears in a question file
- Question front-matter `verified_against: 1.34` (or older)
- Solution YAML uses `policy/v1beta1`, `extensions/v1beta1`, `apps/v1beta1`, `rbac.authorization.k8s.io/v1beta1`
- A grader checks for an error message that doesn't match v1.35's actual wording

**Phase to address:**
Phase that builds the question content (parallel with the runner). The CI lint goes in the same phase as the existing `.github/workflows/validate.yml` — extend that workflow rather than create a parallel one.

---

### Pitfall 12: Missing v1.35 syllabus topics → simulator under-tests current exam

**What goes wrong:**
The 31 existing exercises don't cover (per CONCERNS.md "Coverage Gaps"): CRDs, kube-proxy modes, kube-scheduler customisation, metrics-server bootstrap, VolumeSnapshot, native sidecar (despite GA in 1.33), NetworkPolicy `endPort` / `ipBlock.except`, audit policy. The new simulator inherits the same gaps if authoring focuses on porting existing exercises rather than reading the v1.35 CNCF curriculum directly.

**Why it happens:**
Path-dependence: it's faster to convert an existing exercise to a triplet than to author net-new from a syllabus.

**How to avoid:**
- **PROJECT.md already mandates "Rebuild from the Study Progress Tracker checklist rather than retro-fit existing 31 exercises"** (Key Decisions table). Honor it.
- **Domain-coverage map matrix:** every checkbox in the v1.35 study tracker maps to ≥1 question. CI lint fails if any checkbox has zero questions.
- **Required v1.35-specific questions to add** (not in current 31):
  - CRD basics (`kubectl create -f crd.yaml; kubectl get <crd-kind>; finalizer behaviour`)
  - VolumeSnapshot (`VolumeSnapshotClass`, `VolumeSnapshot`, restore from snapshot)
  - Native sidecar (`initContainers[*].restartPolicy: Always`, ordering vs main containers, restart semantics)
  - Validating Admission Policy (`admissionregistration.k8s.io/v1` CEL-based admission)
  - kube-proxy mode inspection (iptables vs ipvs vs nftables; debugging Service ClusterIP misses)
  - Metrics-server bootstrap (so HPA questions can be self-contained)
  - Audit policy file + `kubectl auth whoami` (1.28+)
  - NetworkPolicy `endPort` and `ipBlock.except`
- **Don't add CKAD/CKS scope** (PROJECT.md Out of Scope).

**Warning signs:**
- A "v1.35 readiness" check at end-of-pack-authoring shows fewer than 1 question per syllabus checkbox
- Native-sidecar / VAP / VolumeSnapshot questions absent
- Exam-pack mix doesn't match weights `30/25/20/15/10`

**Phase to address:**
Phase that authors content. Build the coverage matrix first; author against gaps.

---

### Pitfall 13: SSH bootstrap pitfalls (host keys, agent forwarding, /etc/hosts)

**What goes wrong:**
- First-time `ssh node-01` prompts `Are you sure you want to continue connecting (yes/no)?` — interactive, breaks scripted setup.
- `ssh node-01` fails because `/etc/hosts` on the control-plane has no `node-01` entry; only the IPs are routable.
- `authorized_keys` accumulates duplicate keys on each `cka-sim doctor` run (non-idempotent append, ref CONCERNS.md `exam-setup.sh` issue).
- Agent forwarding is on by default and the candidate's local laptop key gets forwarded into the cluster — security smell, not exam-realistic.
- `ssh-keygen` runs without `-f` / non-interactive flags, prompts for passphrase mid-bootstrap.

**Why it happens:**
SSH UX assumes interactive use. Scripting it requires explicit `-o StrictHostKeyChecking=accept-new`, `-o BatchMode=yes`, idempotent `authorized_keys` updates via `ssh-copy-id` (which is idempotent) or `grep -qF KEY ~/.ssh/authorized_keys || echo KEY >> ~/.ssh/authorized_keys`.

**How to avoid:**
- **Cluster-bootstrap script handles ssh setup once, idempotently**:
  ```bash
  # Generate key only if missing
  [ -f ~/.ssh/id_ed25519 ] || ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519
  # Distribute idempotently
  for n in node-01 node-02; do
    ssh-copy-id -o StrictHostKeyChecking=accept-new "$n" 2>/dev/null || true
    # idempotency guard for /etc/hosts
    grep -qE "[[:space:]]$n([[:space:]]|$)" /etc/hosts || \
      echo "$(getent hosts "$n" | awk '{print $1}') $n" | sudo tee -a /etc/hosts
  done
  # Disable agent forwarding for exam realism
  printf '\nHost node-*\n  ForwardAgent no\n  StrictHostKeyChecking accept-new\n  UserKnownHostsFile ~/.ssh/known_hosts.cka\n' >> ~/.ssh/config
  ```
- **`/etc/hosts` populated from cluster Node addresses**: `kubectl get nodes -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{" "}{.metadata.name}{"\n"}{end}'` is the source of truth.
- **`cka-sim doctor` verifies non-interactive ssh works**: `ssh -o BatchMode=yes node-01 hostname` must return the hostname in < 3 seconds, no prompts.
- **Each `setup.sh` that needs node access uses `ssh -o BatchMode=yes`** so an unbootstrapped cluster fails fast with a clear error, not an interactive prompt.
- **Document `ssh node-NN` topology mirrors the real exam** — same hostname pattern (node-01, node-02), same one-hop-from-control-plane shape, no jump host.

**Warning signs:**
- `ssh node-01` prompts during a setup.sh run
- `~/.ssh/authorized_keys` contains duplicate keys after a re-bootstrap
- `/etc/hosts` has no `node-NN` entries but the candidate is expected to `ssh node-01`
- Setup.sh uses raw `cat key >> authorized_keys` (non-idempotent) instead of `ssh-copy-id` or grep-guarded append

**Phase to address:**
Phase 1 (cluster bootstrap, already PROJECT.md Active item). Add a `cka-sim doctor` ssh acceptance test that fails the entire bootstrap if any worker is non-`BatchMode`-reachable.

---

### Pitfall 14: yq/jq/kubectl version drift — assumes tools that aren't on stock Ubuntu 22.04

**What goes wrong:**
A grader uses `yq eval '.spec.containers[0].image' file` (mikefarah's yq, Go-based) — but Ubuntu 22.04 ships `python3-yq` (kislyuk's yq, Python wrapper around jq) which has different syntax. Or a grader uses `kubectl-neat`, `stern`, `kubectl-tree` — none of which are on stock Ubuntu 22.04 or the real exam VM.

**Why it happens:**
Authors install convenience tools on their dev box and forget they're not standard. Worse, two different `yq` binaries exist and ship in different distros.

**How to avoid:**
- **Tool whitelist** (the only tools graders may invoke): `bash`, `kubectl`, `jq`, `awk`, `grep`, `sed`, `cut`, `wc`, `tr`, `sort`, `uniq`, `head`, `tail`, `xargs`, `curl`, `ssh`, `crictl`, `etcdctl`, `systemctl`, `journalctl`. Anything else → CI lint fail.
- **Specifically forbid `yq`** (ambiguous binary). Use `kubectl get -o jsonpath` or `kubectl get -o json | jq` instead. `jq` ships in Ubuntu 22.04 main; `yq` does not unambiguously.
- **Bootstrap script installs `jq` once** (`apt-get install -y jq`) and verifies its presence in `cka-sim doctor`.
- **No bundling of binaries.** The repo stays pure-bash + standard `apt-get` deps.

**Warning signs:**
- Grader script invokes `yq`, `stern`, `kubectl-neat`, `argocd`, `helm` (helm is fine if the question is about helm — but flag it as a prereq)
- `cka-sim doctor` doesn't verify `jq --version` succeeds

**Phase to address:**
Phase that defines the runner-installation contract. Same phase as Pitfall 1 (setup.sh template) — they share the same authoring boundary.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Grader uses `kubectl get \| grep` for existence-check | Author writes Q in 10 min instead of 30 | False positives mask wrong solutions; trap diagnostics impossible | **Never** for graders. OK for `setup.sh` self-check only. |
| `setup.sh` uses `kubectl create` (not `apply`) | One fewer line | Re-run breaks on `AlreadyExists` | **Never**. Always idempotent. |
| Skip `reset.sh` ("just delete the namespace") | Fewer files per question | Cluster-scoped objects leak across questions | OK only if the question creates **zero** cluster-scoped objects. CI verifies. |
| Inline YAML in `setup.sh` heredoc instead of separate file | Fewer files | YAML can't be linted by validate-local.sh; harder to review | OK for ≤ 30 lines. Above that, split out and reference. |
| Single global trap-catalog instead of per-pack | Less to maintain | Naming collisions across packs; pack-specific traps go missing | **Always single global catalog** — collisions are a feature; traps are universal. |
| Test-only on Linux | Author's box works | Windows/WSL learners hit issues | **Always test on Ubuntu 22.04 in CI** — that's the real exam env. WSL is the candidate's problem. |
| Authoring against killer.sh's question shape | Reuse familiar layout | Their layout is theirs (and copyrighted); we need our own | **Never copy questions**; do study their *meta-shape* (timer + ssh + grade) only. |
| Skip `cka-sim doctor` on session start | Faster start | Setup.sh fails 30 seconds in with confusing error | **Never** — `doctor` runs on every session start. |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| `kubectl wait` | `--for=condition=Ready` on a Pod that has no `Ready` condition yet (Pod just-created, races with kubelet) | Always pair with `--timeout=30s`; ensure setup.sh gives the kubelet ≥1 second before calling wait |
| `kubectl auth can-i` | Drops the `--as=system:serviceaccount:<ns>:<sa>` prefix; uses `--as=<sa>` only | Always full SUBJECT form; `kubectl auth can-i get pods --as=system:serviceaccount:exercise-04:viewer -n exercise-04` |
| `etcdctl` | Forgetting `ETCDCTL_API=3` and the cert/key/ca trio | Bootstrap exports `ETCDCTL_API=3` and an `etcdctl` wrapper with the kubeadm cert paths preset (`scripts/exam-setup.sh` already does this for ETCDCTL_API; extend it) |
| `crictl` | Defaults to no runtime endpoint, errors with `failed to connect: connection refused` | Set `CONTAINER_RUNTIME_ENDPOINT=unix:///run/containerd/containerd.sock` in the exam env |
| `kubectl edit` | Editor unset → falls back to `vi` → candidate panics | Bootstrap sets `KUBE_EDITOR=vim` and the 5-line `~/.vimrc` (already in `scripts/exam-setup.sh`) |
| Static pod manifests | Candidate runs `kubectl apply` instead of editing `/etc/kubernetes/manifests/*.yaml` | Trap detection: if `setup.sh` injects a static-pod failure and the candidate's solution has `kubectl apply` against the static pod's name, name the trap `static-pod-via-apply` |
| Service / kube-dns | Service exists but has no endpoints because selector typo'd | Grader probe: `kubectl get endpoints -n NS svc-name -o jsonpath='{.subsets[*].addresses[*].ip}'` — empty = trap |
| ValidatingAdmissionPolicy | Author binds policy with `matchConstraints.resourceRules` mismatch; rule never fires | Grader must trigger the rule with a known-bad request and assert rejection, not just "the policy exists" |
| Native sidecar | Author writes a `containers:` entry instead of `initContainers[].restartPolicy: Always`; works on 1.34 with feature gate, fails differently on 1.35 GA | Solution must use `initContainers[].restartPolicy: Always`; grader asserts via jsonpath `.spec.initContainers[?(@.name=="sidecar")].restartPolicy == Always` |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Setup.sh runs on every drill, repulling images | `kubectl run` takes 30s every drill; learner blames cluster | Use `imagePullPolicy: IfNotPresent` and pre-pin a small image set (`busybox:1.37`, `nginx:1.28`); pre-pull in `cka-sim install`. | At every session restart |
| Grader does N `kubectl exec`s sequentially | 17-question end-of-exam re-grade takes 10 minutes | Per-question grade cap of 30s wall time; parallelise re-grade across packs only (not within a Q) | At >5 networking questions per pack |
| `kubectl wait` without `--timeout` | Grader blocks forever on an unrecoverably-broken setup | Mandate `--timeout=30s` on every wait | Whenever setup.sh has a bug |
| Re-creating namespaces synchronously in a loop | `setup.sh` takes 2-5 min as Terminating namespaces serialize | Use `kubectl delete ns --wait=false` and a bounded poll, then finalizer-nuke (see Pitfall 1) | Always, on a re-run |
| Per-question SSH spawn | 17 questions × ssh handshake = 17×~500ms latency tax | `ControlMaster auto` in `~/.ssh/config` so subsequent `ssh node-NN` are free | At full-exam re-grade |
| `kubectl get -A` in graders | Linear in cluster size; slow on busy clusters; brittle | Always namespace-scope (Pitfall 3) | Always |

---

## Security Mistakes

> CKA simulator security risks are about **honest assessment** (no leakage of solutions) and **cluster hygiene**, not OWASP. The cluster is the candidate's; the threat model is "the candidate accidentally trains themselves wrong" or "a malformed setup.sh damages their cluster".

| Mistake | Risk | Prevention |
|---------|------|------------|
| Solution YAML in a file the candidate can `cat` mid-question | Self-cheating; degrades drill value | Solutions live in `<question>/.solution.md.gpg` or `<question>/.solution.md` with `.gitignore` flag; runner unlocks only on `cka-sim solve <id>` after submit. (Soft barrier — single-learner mode means this is honor-system, not crypto.) |
| `setup.sh` runs `kubectl delete ns kube-system` (or any system namespace) under any branch | Bricks the cluster | CI lint: regex `delete\s+ns(?:pace)?\s+(kube-system\|kube-public\|kube-node-lease\|default)` → fail PR |
| `setup.sh` writes outside `/tmp`, `~/.cka-sim/`, or `exercise-NN` namespace | Pollutes user's home / system | CI lint forbids `>>` redirects to anywhere except `~/.cka-sim/` and `/tmp` |
| `setup.sh` runs as root or invokes `sudo` mid-question | Escalation surprise; user expects single-non-root context | Forbid `sudo` in setup.sh / grade.sh / reset.sh. Cluster bootstrap is the **only** script allowed `sudo` (and uses it explicitly with prompts) |
| Question front-matter declares `verified_against: 1.35` but solution uses `policy/v1beta1` | Teaches the wrong API | CI lint deprecated-strings check (Pitfall 11) |
| Sharing real CKA exam questions / wording | CNCF NDA violation; decertification of the user | Disclaimer banner mandatory in every pack README; PR template includes "I have not used real CKA exam content" checkbox |
| Privileged pods used as setup state without a comment | Learner generalises the wrong shape | Pod with `privileged: true` in setup.sh requires inline `# Educational counter-example` comment (matches existing CONCERNS.md remediation) |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| End-of-exam report is plain text, no per-domain percentage | Candidate doesn't know which domain to drill | Markdown-formatted report with per-domain table, sorted by lowest score, one-line "next: drill `cka-sim drill troubleshooting`" suggestion |
| Trap aggregation only shows top trap | Hides patterns | Show top 5 traps with counts + which questions hit each |
| No way to resume a paused exam | Real exam allows bathroom breaks ("focus interruption") — simulator should too | `cka-sim pause` / `cka-sim resume <id>`; persist to `~/.cka-sim/sessions/<id>/state.json` after every Q |
| Timer always visible; cannot be hidden | Some learners want stress, some want focused-no-clock practice | `cka-sim drill --no-timer` flag; `cka-sim exam` always shows it (exam realism) |
| `cka-sim` requires arg parsing the user can't remember | Drill takes 4 tries to start | Top-level `cka-sim` with no args prints usage + a "what would you like to drill" picker |
| Errors print bash stack traces | Looks broken | All user-facing errors via a `die()` helper that prints `cka-sim: error: <human message> (run cka-sim doctor)` |
| Cleanup after Ctrl-C leaves the cluster in a setup-state | User has to manually delete namespaces | Trap on EXIT runs the current question's `reset.sh` if the user actually quit (not paused) |
| No audit log of what graders did | Candidate can't tell why a grade was a FAIL | Per-session `events.log` recording every kubectl call the grader made, surfaced via `cka-sim explain <session> <q>` |

---

## "Looks Done But Isn't" Checklist

- [ ] **`setup.sh` triplet:** ships all three of `setup.sh` / `grade.sh` / `reset.sh` — verify all three present and `chmod +x` in CI
- [ ] **Idempotent setup:** `setup.sh; setup.sh` (back-to-back) exits 0 with no `AlreadyExists` — verify in CI
- [ ] **Idempotent reset:** `reset.sh; reset.sh` exits 0 — verify in CI
- [ ] **Round-trip:** `setup.sh && grade.sh` (no candidate solution) → FAIL with at least one named trap (proves grader actually graded). Verify in CI.
- [ ] **Reference-solution round-trip:** `setup.sh && bash <solution.sh> && grade.sh` → PASS. Verify in CI.
- [ ] **Trap diagnostics:** ≥3 named traps in front-matter; each has a detection step that has been observed firing — verify by deliberate-failure unit test
- [ ] **Time budget:** documented in question front-matter, between 4-12 min; pack sum 110-120 min — verify in pack lint
- [ ] **Domain tag:** matches one of the v1.35 5-domain taxonomy; pack mix matches weights — verify in pack lint
- [ ] **Prereqs declared:** every external requirement (metrics-server, gateway-api, network policy CNI) is listed; runner blocks if absent
- [ ] **API versions:** all `apiVersion` fields are v1.35-current (no `v1beta1` / removed APIs) — verify in CI deprecated-strings check
- [ ] **Tool whitelist:** grader uses only whitelist tools — verify in CI
- [ ] **Namespace scoping:** grader has zero `kubectl get -A` and zero `| grep` patterns — verify in CI
- [ ] **Naming hygiene:** cluster-scoped objects prefixed with question id — verify in pack lint
- [ ] **Cluster topology assumption:** runs on a 1+2 multi-node cluster; tested via `cka-sim doctor` — verify on session start
- [ ] **`reset.sh` returns to baseline:** running `setup.sh && reset.sh && setup.sh` works (proves reset is true inverse)
- [ ] **No `sudo` in setup/grade/reset:** verify in CI
- [ ] **Disclaimer banner present** in every pack README

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Non-idempotent setup poisons cluster | LOW | `cka-sim reset --hard <pack>` runs every reset.sh in the pack, then `kubectl delete ns -l cka-sim/owned=true` |
| Grader false positive (passed wrong solution) | HIGH | Audit shipped questions; fix grader; bump pack version. No way to retroactively re-grade past sessions — flag them as "graded with deprecated grader vN" |
| State leak across questions | MEDIUM | Per-session results.json (Pitfall 4) means past results are immutable; new sessions get the fixed pack |
| Bash signal handler bug orphans timer | LOW | `cka-sim doctor` includes `pgrep -f cka-sim-timer` and offers `cka-sim cleanup` to nuke orphans |
| Trap diagnostic too generic | MEDIUM | Trap-catalog audit — flag questions whose top trap is `Trap 0` more than 50% of the time. Author rewrites. |
| Question depends on missing cluster feature | LOW | Question's `requires:` front-matter; runner refuses to drill until prereq installed. No cluster damage. |
| Deprecated API in shipped question | MEDIUM | CI catches at PR; if shipped, fix in patch release; old session results stay valid (the question still graded the candidate's solution) |
| SSH bootstrap left junk in `authorized_keys` | LOW | `cka-sim doctor` detects duplicates; `cka-sim doctor --fix` deduplicates |

---

## Pitfall-to-Phase Mapping

Suggested phase ordering (research recommendation only — roadmap will finalise):

| # | Pitfall | Prevention Phase | Verification Mechanism |
|---|---------|------------------|------------------------|
| 1 | Non-idempotent setup.sh | **Phase: Question runtime contract** (the triplet) | CI: run setup.sh twice; assert second run has no AlreadyExists |
| 2 | Grader false positives | **Phase: Question runtime contract** | Mandate grader-assertion library; CI lint `kubectl get \| grep` |
| 3 | Grader false negatives | **Phase: Question runtime contract** | CI lint forbids `kubectl get -A`; mandate jsonpath filters |
| 4 | Cross-question state leak | **Phase: Multi-question runner** | Pack lint detects cluster-scope name collisions |
| 5 | Bash signal handling | **Phase: Runner CLI** | Acceptance test: Ctrl-C in mid-Q must not kill timer |
| 6 | Generic trap diagnostics | **Phase: First canonical pack** (sets the precedent) | Authoring template enforces ≥3 named traps; PR review checklist |
| 7 | Time-budget mis-calibration | **Phase: First mock-exam pack** | Pack validator: 110-120 min total, 4-12 per Q |
| 8 | Cluster-feature dependency | **Phase: Cluster bootstrap** | `cka-sim doctor` capability sniff; question front-matter `requires:` |
| 9 | YAML-from-memory practice | **Phase: First canonical pack** (authoring template) | Solution lint: < 30 lines YAML; imperative path required |
| 10 | Single-node practice habit | **Phase: Cluster bootstrap** | `cka-sim doctor` requires ≥3 nodes |
| 11 | Content drift to deprecated APIs | **Phase: First canonical pack** + ongoing | CI deprecated-strings lint; v1.35 feature matrix |
| 12 | Missing v1.35 syllabus topics | **Phase: Content authoring** | Coverage-matrix lint; 1-question-per-checkbox minimum |
| 13 | SSH bootstrap fragility | **Phase: Cluster bootstrap** | `cka-sim doctor` ssh acceptance |
| 14 | Tool whitelist drift (yq, stern, etc.) | **Phase: Question runtime contract** | CI lint scans for non-whitelisted binaries |

---

## Sources

- **`.planning/codebase/CONCERNS.md`** — authoritative for the 10 highest-priority content drift bugs already in the existing 31 exercises. Every "must avoid" item in Pitfalls 6 and 11 traces to a CONCERNS.md row. (HIGH confidence — these are facts about the current repo, not training data.)
- **`.planning/codebase/CONVENTIONS.md`** — exercise template, alias contract, lab-namespace convention `exercise-NN`. The new triplet's authoring template builds on this. (HIGH confidence.)
- **`.planning/codebase/TESTING.md`** — `## Verify` block as the closest existing analog to a grader; the new grader.sh contract is its automation. (HIGH confidence.)
- **Context7: `/kubernetes/enhancements`**, KEP-3488 (ValidatingAdmissionPolicy), KEP-753 (SidecarContainers), KEP-5040 (gitRepo removal), KEP-3962 (MutatingAdmissionPolicy). Verified GA / removal status of v1.30+ features. (HIGH confidence — direct from upstream KEP READMEs.)
- **Context7: `/websites/kubernetes_io`** — `kubectl wait` semantics, `--for=condition`, `--for=jsonpath`, `--for=delete` for behavioural assertions in graders. (HIGH confidence.)
- **Bash signal handling** — standard reference (`man bash` TRAP, `tput` semantics for cursor save/restore, `ControlMaster` for ssh). (HIGH confidence — well-known shell semantics.)
- **CKA real-exam shape** (PSI Chromebook, ssh node-NN topology, kubectl/kubernetes/helm.io docs allowance, 120 min / ~17 Q): synthesised from `.planning/PROJECT.md` Context section. NOT independently verified during this research session — flagged as MEDIUM confidence on exam-fidelity claims. (Owner has firsthand knowledge; treat PROJECT.md as the source of truth for exam shape.)
- **killer.sh / dgkanatsios style references**: WebSearch was denied during this research; specific killer.sh internals not directly verified. The runner-construction patterns above (timer, ssh, grade triplet) are derived from general bash/kubectl best practice and PROJECT.md's stated design — flagged where applicable. (MEDIUM confidence on "what other simulators do".)

---
*Pitfalls research for: CKA exam simulator (bash-only, single-learner, existing 1+2 kubeadm v1.35 cluster)*
*Researched: 2026-05-07*
