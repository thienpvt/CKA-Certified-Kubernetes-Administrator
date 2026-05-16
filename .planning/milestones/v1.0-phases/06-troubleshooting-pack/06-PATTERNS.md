# Phase 6: Troubleshooting Pack — Pattern Map

**Mapped:** 2026-05-12
**Files analyzed:** 49 (5 new questions × 6 files = 30 + 1 retrofit × ~4 edits + 1 catalog edit + 2 lint edits + 3 pack-root files + 5 fixture dirs + 1 VERIFICATION.md)
**Analogs found:** 49 / 49 (every new file has a strong in-repo analog; zero greenfield patterns required)

## 1. Files to Create

| Path | Role | Closest analog (file:line) | Why this analog |
|---|---|---|---|
| `cka-sim/packs/troubleshooting/02-netpol-dns-egress/setup.sh` | question-setup | `cka-sim/packs/services-networking/01-networkpolicy-egress/setup.sh:1-57` | Same pattern: netshoot probe pod + broken NetworkPolicy baseline, uses `ensure_lab_ns`/`wait_for_ns_active`. Delta: swap the baseline policy for the `netpol-label-key-drift` flavour (selector uses `app: web` against pod label `app.kubernetes.io/name=web`). |
| `cka-sim/packs/troubleshooting/02-netpol-dns-egress/grade.sh` | question-grade | `cka-sim/packs/services-networking/01-networkpolicy-egress/grade.sh:1-39` | Two-stage fix uses the same `kubectl exec nslookup` + `cka_sim::trap::detect_missing_dns_egress` idiom. Add a second detector for `netpol-label-key-drift` (jsonpath compare `spec.podSelector.matchLabels` vs target Pod labels). |
| `cka-sim/packs/troubleshooting/02-netpol-dns-egress/reset.sh` | question-reset | `cka-sim/packs/services-networking/01-networkpolicy-egress/reset.sh:1-7` | No sandbox files — single `kubectl delete namespace … --wait=false` line is the entire shape. |
| `cka-sim/packs/troubleshooting/02-netpol-dns-egress/ref-solution.sh` | question-ref-solution | `cka-sim/packs/services-networking/01-networkpolicy-egress/ref-solution.sh:1-40` | Re-apply the NetworkPolicy with corrected selector key + DNS allow block. |
| `cka-sim/packs/troubleshooting/02-netpol-dns-egress/metadata.yaml` | question-metadata | `cka-sim/packs/services-networking/06-netpol-endport/metadata.yaml:1-16` | 8-field shape with `references[]` carrying two entries (k8s-doc + pack prior-art). |
| `cka-sim/packs/troubleshooting/02-netpol-dns-egress/question.md` | question-prompt | `cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/question.md:1-27` | Symptoms-only prose pattern (D-04). |
| `cka-sim/packs/troubleshooting/03-coredns-resolution/setup.sh` | question-setup | `cka-sim/packs/services-networking/03-coredns-resolution/setup.sh:1-32` | Closest existing CoreDNS question. Delta: D-11 requires a per-question lab CoreDNS Deployment + ConfigMap (mirrors kube-system shape) instead of per-pod `dnsConfig: None`. Use the same `ensure_lab_ns` header + `kubectl apply -f -` block idiom. |
| `cka-sim/packs/troubleshooting/03-coredns-resolution/grade.sh` | question-grade | `cka-sim/packs/services-networking/03-coredns-resolution/grade.sh:1-28` | Same `kubectl exec … nslookup` assertion; swap the trap detector to fire on `coredns-sandbox-configmap-mount` (grep the lab CoreDNS Corefile volume name) and keep `coredns-forward-to-invalid-upstream` as the reused detector. |
| `cka-sim/packs/troubleshooting/03-coredns-resolution/reset.sh` | question-reset | `cka-sim/packs/services-networking/03-coredns-resolution/reset.sh:1-5` | Namespace-scoped; CoreDNS lab Deployment/ConfigMap go with the ns. |
| `cka-sim/packs/troubleshooting/03-coredns-resolution/ref-solution.sh` | question-ref-solution | `cka-sim/packs/services-networking/03-coredns-resolution/ref-solution.sh:1-29` | Re-apply Corefile ConfigMap with `forward . /etc/resolv.conf` (D-11 landmine: do not patch kube-system). |
| `cka-sim/packs/troubleshooting/03-coredns-resolution/metadata.yaml` | question-metadata | `cka-sim/packs/services-networking/03-coredns-resolution/metadata.yaml:1-16` | Same shape; add `cka-sim/packs/services-networking/03-coredns-resolution/` as pack reference per D-05. |
| `cka-sim/packs/troubleshooting/03-coredns-resolution/question.md` | question-prompt | `cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/question.md:1-27` | Symptoms-only: "Pods in lab ns cannot resolve external names; cluster-internal names also fail." |
| `cka-sim/packs/troubleshooting/04-debug-node/setup.sh` | question-setup | `cka-sim/packs/cluster-architecture/07-cri-dockerd-endpoint/setup.sh:1-21` | Closest sandbox-file question. Delta: seed `/tmp/q04-debug-node/` with an empty `answer.txt` target, and source `read_node_worker` (no hardcoded node-01/02 per BUG-3 pre-empt). |
| `cka-sim/packs/troubleshooting/04-debug-node/grade.sh` | question-grade | `cka-sim/packs/cluster-architecture/07-cri-dockerd-endpoint/grade.sh:1-37` | File-content grader pattern (`-s` + `grep -q`); compares candidate's `answer.txt` to `kubectl get node <worker> -o jsonpath='{.status.nodeInfo.kernelVersion}'` (oracle). Additional detector: `debug-pod-leaked-not-cleaned` by `kubectl get pods -A -l 'kubectl.kubernetes.io/debug-source'` jsonpath check. |
| `cka-sim/packs/troubleshooting/04-debug-node/reset.sh` | question-reset | `cka-sim/packs/cluster-architecture/07-cri-dockerd-endpoint/reset.sh:1-9` | Same sentinel-guarded `rm -rf` + ns delete. Extra: hunt and delete lingering debug pods across all namespaces (per-RESEARCH §9 landmine). |
| `cka-sim/packs/troubleshooting/04-debug-node/ref-solution.sh` | question-ref-solution | `cka-sim/packs/cluster-architecture/07-cri-dockerd-endpoint/ref-solution.sh:1-8` | Minimal: write the oracle value from the Node API into `/tmp/q04-debug-node/answer.txt`. Does not actually run `kubectl debug node/…` (D-10 host-safety; prompt lists the canonical command as guidance). |
| `cka-sim/packs/troubleshooting/04-debug-node/metadata.yaml` | question-metadata | `cka-sim/packs/cluster-architecture/07-cri-dockerd-endpoint/metadata.yaml:1-16` | Same shape; references[] points at `cka-sim/packs/cluster-architecture/02-etcd-backup-restore/` (D-05 cross-pack). |
| `cka-sim/packs/troubleshooting/04-debug-node/question.md` | question-prompt | `cka-sim/packs/cluster-architecture/07-cri-dockerd-endpoint/question.md:1-12` | Sandbox-path prose pattern — states the sandbox path, lists constraints (no host mutation, no editing live files). |
| `cka-sim/packs/troubleshooting/05-static-pod-manifest/setup.sh` | question-setup | `cka-sim/packs/cluster-architecture/05-audit-policy/setup.sh:1-25` | Sandbox-file question that seeds a YAML file into `/tmp/qNN-*`. Delta: seed two broken manifest variants (`manifest-broken.yaml` and `manifest-tagtypo.yaml`) with the deliberate YAML flaws from RESEARCH §4. |
| `cka-sim/packs/troubleshooting/05-static-pod-manifest/grade.sh` | question-grade | `cka-sim/packs/cluster-architecture/05-audit-policy/grade.sh:1-49` | Uses `python3 yaml.safe_load` + assertion pattern. Delta: replace audit-policy structural checks with Pod-kind/metadata/image validation. Also run `kubectl apply --dry-run=client -f …` as a secondary oracle. RESEARCH landmine: grader MUST NOT write to `/etc/kubernetes/manifests/`. |
| `cka-sim/packs/troubleshooting/05-static-pod-manifest/reset.sh` | question-reset | `cka-sim/packs/cluster-architecture/02-etcd-backup-restore/reset.sh:1-9` | Sentinel-guarded sandbox cleanup + ns delete. |
| `cka-sim/packs/troubleshooting/05-static-pod-manifest/ref-solution.sh` | question-ref-solution | `cka-sim/packs/cluster-architecture/07-cri-dockerd-endpoint/ref-solution.sh:1-8` | `cat > /tmp/q05-staticpod/manifest.yaml <<'EOF'` writing the canonical fixed manifest (nginx:1.27-alpine pinned per landmine). |
| `cka-sim/packs/troubleshooting/05-static-pod-manifest/metadata.yaml` | question-metadata | `cka-sim/packs/cluster-architecture/07-cri-dockerd-endpoint/metadata.yaml:1-16` | Same sandbox-file flavour; references[] pointing at `cka-sim/packs/services-networking/02-service-core/` OR a workloads-scheduling static-pod question if one exists (planner landmine). |
| `cka-sim/packs/troubleshooting/05-static-pod-manifest/question.md` | question-prompt | `cka-sim/packs/cluster-architecture/07-cri-dockerd-endpoint/question.md:1-12` | Sandbox-path prose; symptom-only per D-04 ("a static pod named `q05-cache` should be running … kubectl get pods -A shows it Pending/missing"). |
| `cka-sim/packs/troubleshooting/06-broken-kubelet/setup.sh` | question-setup | `cka-sim/packs/cluster-architecture/07-cri-dockerd-endpoint/setup.sh:1-21` | **Exact-role analog.** Seeds a broken `kubeadm-flags.env` into `/tmp/q06-kubelet-flags/`. Phase 6 delta: add `kubelet-flag-file-malformed-quoting` variant (stray quote or CRLF in `KUBELET_KUBEADM_ARGS`). |
| `cka-sim/packs/troubleshooting/06-broken-kubelet/grade.sh` | question-grade | `cka-sim/packs/cluster-architecture/07-cri-dockerd-endpoint/grade.sh:1-37` | Exact-role analog. Reuses three traps (`removed-container-runtime-flag`, `kubelet-runtime-flag-in-kubeconfig`, `cri-endpoint-unix-prefix-missing`). Add new `kubelet-flag-file-malformed-quoting` detector (subshell `source` + exit-code check). |
| `cka-sim/packs/troubleshooting/06-broken-kubelet/reset.sh` | question-reset | `cka-sim/packs/cluster-architecture/07-cri-dockerd-endpoint/reset.sh:1-9` | Sentinel-guarded `/tmp/q06-kubelet-flags/` removal. Landmine: MUST NOT `systemctl` and MUST NOT touch `/var/lib/kubelet/`. |
| `cka-sim/packs/troubleshooting/06-broken-kubelet/ref-solution.sh` | question-ref-solution | `cka-sim/packs/cluster-architecture/07-cri-dockerd-endpoint/ref-solution.sh:1-8` | Overwrite sandbox `kubeadm-flags.env` with the canonical fixed line. |
| `cka-sim/packs/troubleshooting/06-broken-kubelet/metadata.yaml` | question-metadata | `cka-sim/packs/cluster-architecture/07-cri-dockerd-endpoint/metadata.yaml:1-16` | Same; references[] points at `cka-sim/packs/cluster-architecture/07-cri-dockerd-endpoint/` (D-05 cross-pack — the natural prior-art). |
| `cka-sim/packs/troubleshooting/06-broken-kubelet/question.md` | question-prompt | `cka-sim/packs/cluster-architecture/07-cri-dockerd-endpoint/question.md:1-12` | Sandbox-path prose; D-04 symptoms-only phrasing. |
| `cka-sim/tests/fixtures/troubleshooting-02-netpol-dns-egress/{stub-responses.json,expected-fail-score.txt,expected-pass-score.txt}` | fixture | `cka-sim/tests/fixtures/storage-06-pvc-mount-pod/{stub-responses.json:1-33,expected-fail-score.txt:1,expected-pass-score.txt:1}` | 3-file kubectl-stub fixture shape used by every Phase 4/5 question. |
| `cka-sim/tests/fixtures/troubleshooting-03-coredns-resolution/{…}` | fixture | same as above | same shape. |
| `cka-sim/tests/fixtures/troubleshooting-04-debug-node/{…}` | fixture | same as above | same shape. |
| `cka-sim/tests/fixtures/troubleshooting-05-static-pod-manifest/{…}` | fixture | same as above | same shape. |
| `cka-sim/tests/fixtures/troubleshooting-06-broken-kubelet/{…}` | fixture | same as above | same shape. |
| `cka-sim/tests/fixtures/lint-packs/bad-forbidden-cmd/setup.sh` (and sibling bad-* variants as needed) | fixture | `cka-sim/tests/fixtures/lint-packs/bad-deletens/setup.sh:1-10` | Same shape (tiny shell file with the forbidden idiom — e.g. `systemctl restart kubelet`, `kubectl edit configmap coredns -n kube-system`). |
| `cka-sim/tests/cases/lint_packs_forbidden_command.sh` | fixture (test case) | `cka-sim/tests/cases/lint_packs_mutating_verb.sh:1-41` | Same test-case shape. Copies fixture into a temp tree, runs `CKA_SIM_LINT_PACKS_DIR=… bash lint-packs.sh`, asserts non-zero exit + a signature string in output (e.g. `FORBIDDEN-COMMAND`). |
| `.planning/phases/06-troubleshooting-pack/06-VERIFICATION.md` | verification-doc | `.planning/phases/05-services-networking-cluster-architecture-packs/05-VERIFICATION.md` | Phase 5 checklist shape (executable bash + live-cluster manual section). RESEARCH §8 enumerates the 7 criteria. |

## 2. Files to Modify

| Path | Role | Analog within repo | Insertion point |
|---|---|---|---|
| `cka-sim/packs/troubleshooting/manifest.yaml` | pack-manifest | `cka-sim/packs/services-networking/manifest.yaml:10-26` sentinel-guarded block | Append 5 question blocks (Q02-Q06) after the existing Q01 entry, using the `# BEGIN phase-06 new questions` / `# END phase-06 new questions` sentinel idiom that Phase 5 used in services-networking. |
| `cka-sim/packs/troubleshooting/coverage.yaml` | pack-coverage | `cka-sim/packs/services-networking/coverage.yaml:11-32` | Create file (currently absent — grep shows only 4 coverage.yaml files). Use the Phase 5 services-networking schema exactly; one `tracker.<slug>.questions[]` block per v1.35 Troubleshooting Tracker checkbox. Multi-question mapping on `understand-pending-pods` and `imagepullbackoff-diagnosis` per RESEARCH §2. |
| `cka-sim/packs/troubleshooting/README.md` | pack-doc | `cka-sim/packs/services-networking/README.md:9-23` | Replace the Phase 3 placeholder table (11 lines) with a 7-row table (Q01-Q06) using the services-networking pattern (Phase-5 sentinels for future appends optional). |
| `cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/setup.sh` | question-setup (retrofit) | RESEARCH §4 Q1 retrofit plan — see excerpt (3) below | Retrofit per RESEARCH §4: source `lib/setup.sh`, replace inline ns loop with helpers, add `imagepullbackoff-wrong-tag` trap variant. |
| `cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/grade.sh` | question-grade (retrofit) | Phase 5 retrofit pattern (see `services-networking/01-networkpolicy-egress/grade.sh:1-39`) | Add ImagePullBackOff detector (`kubectl get pods -n $NS -o jsonpath` → `record_trap imagepullbackoff-wrong-tag`). Leave endpoints-nonempty oracle unchanged. |
| `cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/ref-solution.sh` | question-ref-solution (retrofit) | current `ref-solution.sh:1-13` | Add second `kubectl patch` / delete step for the bad-tag replica. |
| `cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/metadata.yaml` | question-metadata (retrofit) | current `metadata.yaml:1-16` | Bump `traps[]` from 3 to 4 (add `imagepullbackoff-wrong-tag`); add `cka-sim/packs/services-networking/02-service-core/` reference; keep existing prior-art-exercise ref. |
| `cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/question.md` | question-prompt (retrofit) | current `question.md:1-27` | Append one sentence noting a secondary failure state, without naming "ImagePullBackOff" (D-04). |
| `cka-sim/traps/catalog.yaml` | catalog | Phase 5 appended block (see line 351 `static-pod-applied-via-kubectl-apply` onward) | Append 11 new trap entries (RESEARCH §3) at end-of-file. Each entry follows the 8-field schema + `references:` list. No schema changes. |
| `cka-sim/scripts/lint-packs.sh` | lint-script | existing pass C/D/F blocks (`lint-packs.sh:61-67, 152-179`) | Insert a new `pass G: D-09/D-11/D-12 forbidden-command guard` block scoped to `"$PACKS_DIR"/troubleshooting/**/*.sh`. Same grep-based idiom (comment-aware, line-by-line). Patterns enumerated in RESEARCH §6. |
| `cka-sim/scripts/test.sh` (optional) | test-driver | wired chain — lint-packs then tests/run.sh | No change likely needed. New `tests/cases/lint_packs_forbidden_command.sh` gets picked up by `tests/run.sh`'s `cases/*.sh` glob (see `tests/run.sh:34-40`). |

## 3. Excerpted Patterns (≤25 lines each)

### (A) Sandbox-file `setup.sh` shape (pattern for Q5, Q6; analog for Q4)

Source: `cka-sim/packs/cluster-architecture/07-cri-dockerd-endpoint/setup.sh:1-21`

```bash
#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

source "$CKA_SIM_ROOT/lib/setup.sh"

CKA_SIM_PACK="cluster-architecture"
CKA_SIM_QUESTION_ID="cluster-architecture-cri-dockerd-endpoint"
sandbox="/tmp/q07-kubelet-flags"
removed_flag="--container-runtime""=remote"   # string-split prevents lint-deprecated-strings trip

cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" "$CKA_SIM_PACK" "$CKA_SIM_QUESTION_ID"
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" "$CKA_SIM_PACK" "$CKA_SIM_QUESTION_ID"

mkdir -p "$sandbox"
touch "$sandbox/.cka-sim-sentinel"         # reset.sh uses this to confirm cleanup eligibility
[[ -f /var/lib/kubelet/kubeadm-flags.env ]] && cp -p /var/lib/kubelet/kubeadm-flags.env "$sandbox/kubeadm-flags.env"
printf 'KUBELET_KUBEADM_ARGS="%s …"\n' "$removed_flag" > "$sandbox/kubeadm-flags.env"
```

Phase 6 planner: replace pack/question-id identifiers, switch sandbox path to `/tmp/qNN-*`, adjust the seeded broken content per RESEARCH §4.

### (B) `grade.sh` shape — lib sourcing, explicit trap recording, emit_result finalisation

Source: `cka-sim/packs/cluster-architecture/07-cri-dockerd-endpoint/grade.sh:1-37`

```bash
#!/bin/bash
set -uo pipefail          # NOT -e: accumulate failed assertions
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"
source "$CKA_SIM_ROOT/lib/grade.sh"
# optional: source "$CKA_SIM_ROOT/lib/traps.sh" when using cka_sim::trap::detect_* helpers

sandbox="/tmp/q07-kubelet-flags"
flags="$sandbox/kubeadm-flags.env"

CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
if [[ -s "$flags" ]]; then
  CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 )); ok "kubeadm-flags.env exists"
else
  CKA_SIM_GRADE_FAILS+=("kubeadm-flags.env missing"); err "kubeadm-flags.env missing"
fi

if grep -q "$removed_flag" "$flags" 2>/dev/null; then
  cka_sim::grade::record_trap removed-container-runtime-flag
fi
# … additional `grep`/jsonpath-driven detector branches that each call record_trap …

cka_sim::grade::emit_result      # prints SCORE:N/M and Trap: lines — mandatory terminal call
```

Canonical idiom: manual `CKA_SIM_GRADE_TOTAL`/`PASSED`/`FAILS` bookkeeping for custom checks, helpers like `cka_sim::grade::assert_resource_exists`/`assert_field_eq`/`assert_endpoints_nonempty`/`assert_pod_ready` for boilerplate; every detector branch ends in `cka_sim::grade::record_trap <id>`; `emit_result` is the single finaliser.

### (C) Reset shape — sentinel-guarded sandbox + async ns delete

Source: `cka-sim/packs/cluster-architecture/07-cri-dockerd-endpoint/reset.sh:1-9`

```bash
#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"

sandbox="/tmp/q07-kubelet-flags"
if [[ -f "$sandbox/.cka-sim-sentinel" ]]; then
  rm -rf "$sandbox"
fi
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false
```

Plus for Q4 only, append (per RESEARCH §9 landmine):

```bash
kubectl get pods --all-namespaces -l 'kubectl.kubernetes.io/debug-source' -o name \
  | xargs -r kubectl delete --ignore-not-found
```

### (D) metadata.yaml shape with required cross-pack `references[]` entry (D-05)

Source: `cka-sim/packs/services-networking/06-netpol-endport/metadata.yaml:1-16` (good mixed-kind example)

```yaml
id: services-netpol-endport
domain: services-networking
estimatedMinutes: 7
verified_against: "1.35"
traps:
  - netpol-endport-missing-protocol
  - missing-dns-egress
  - default-sa-used
references:
  - kind: k8s-doc
    target: https://kubernetes.io/docs/concepts/services-networking/network-policies/
    note: NetworkPolicy port range endPort semantics
  - kind: roadmap-concern
    target: CONCERNS.md#CG-16
    note: NetworkPolicy endPort coverage gap
```

Phase 6 delta per D-05/D-07: each troubleshooting `metadata.yaml` MUST carry at least one `references[]` entry whose `target` starts with `cka-sim/packs/`. `kind` can be any value in the lint-enforced enum `{concerns-md, k8s-doc, prior-art-exercise, exam-objective, blog-post}` (see `lint-packs.sh:33`). Planner note: `prior-art-exercise` is the best semantic fit for a `cka-sim/packs/…` target; verify with lint on first authored metadata.

### (E) Pack-root `manifest.yaml` + `coverage.yaml` shapes with sentinel-guarded appends

Source: `cka-sim/packs/services-networking/manifest.yaml:1-26` and `coverage.yaml:1-33`

```yaml
# manifest.yaml
pack:
  id: troubleshooting
  domain: troubleshooting
  weight: 30
  description: "Troubleshooting 30% domain pack (PACK-05) -- full v1.35 Tracker coverage."
questions:
  - id: troubleshooting-deploy-svc-mismatch
    path: 01-deploy-svc-mismatch
    estimatedMinutes: 7
  # BEGIN phase-06 new questions (P04-P08 append one question block each below this line; idempotent via grep guard)
  - id: troubleshooting-netpol-dns-egress
    path: 02-netpol-dns-egress
    estimatedMinutes: 8
  # … 4 more
  # END phase-06 new questions
```

```yaml
# coverage.yaml (NEW file — shape from services-networking/coverage.yaml)
domain: troubleshooting
tracker:
  service-endpoints:
    label: "Troubleshoot Service endpoints + ImagePullBackOff"
    questions:
      - troubleshooting-deploy-svc-mismatch
  # BEGIN phase-06 new questions …
  # END phase-06 new questions
```

### (F) `lint-packs.sh` existing deny-list block (the slot-in idiom for the new forbidden-command guard)

Source: `cka-sim/scripts/lint-packs.sh:61-67` (pass C — D-09 guard)

```bash
info "pass C: D-09 runner-owns-cleanup guard (no 'kubectl delete ns' in setup.sh)"
while IFS= read -r setup_sh; do
  if grep -nE '^[[:space:]]*[^#]*kubectl[[:space:]]+delete[[:space:]]+(namespace|ns)([[:space:]]|$)' "$setup_sh" >/dev/null; then
    err "D-09: $setup_sh contains 'kubectl delete ns' — runner owns cleanup"
    errors=$(( errors + 1 ))
  fi
done < <(find "$PACKS_DIR" -name 'setup.sh' -type f)
```

Phase 6 planner: insert a new `pass G: FORBIDDEN-COMMAND guard (troubleshooting pack only)` block that walks `find "$PACKS_DIR/troubleshooting" -name '*.sh' -type f` and applies the 7 patterns from RESEARCH §6 using the same `grep -nE '^[[:space:]]*[^#]*<pattern>'` idiom. The comment-exclusion (`[^#]*`) and the `err`/`errors++` shape are repo-standard — copy verbatim and only change the pattern set and the signature string (`FORBIDDEN-COMMAND` or similar so tests can grep for it).

### (G) Test-fixture directory shape under `cka-sim/tests/fixtures/`

Source: `cka-sim/tests/fixtures/storage-06-pvc-mount-pod/` (canonical 3-file Phase 4/5 pattern)

```
troubleshooting-NN-<slug>/
  stub-responses.json         # kubectl-stub JSON: what `kubectl get …` replays
  expected-fail-score.txt     # SCORE: 0/N — pre-fix round-trip
  expected-pass-score.txt     # SCORE: N/N — post-fix round-trip
```

`stub-responses.json` is a single JSON object (not an array) — see `storage-06-pvc-mount-pod/stub-responses.json:1-33` for the Deployment shape. Paired expected-score files are 1-line SCORE strings matching `cka_sim::grade::emit_result` output.

### (H) Symptoms-only question.md shape (D-04)

Source: `cka-sim/packs/troubleshooting/01-deploy-svc-mismatch/question.md:1-27`

```markdown
# Troubleshooting: Service has no endpoints

**Domain:** Troubleshooting  |  **Estimated time:** 7 minutes

A `Deployment` named `web` and a `Service` named `web-svc` exist in your lab namespace. Users report they cannot reach the Service. The pods are Running but the Service is not routing traffic.

## Tasks
1. Inspect the `Deployment` `web`, its Pods, and the `Service` `web-svc` in `${CKA_SIM_LAB_NS}`.
2. Diagnose why `Service web-svc` has no endpoints despite the Deployment's Pods being Ready.
3. Modify the `Service` (not the Deployment) so that the Service routes traffic to the Deployment's Pods.

## Constraints
- Do NOT modify the Deployment or its pod template.
- Do NOT recreate the Service — patch it in place.
- The Pods should remain unchanged (same spec, same image, same replica count).

## Verify yourself
```

Planner note per D-04/D-06: prompts name observed symptoms ("DNS lookup from pod fails", "kubelet would fail to start"), never the root cause or topic ("fix CoreDNS", "fix static pod YAML"). Cross-pack `references[]` is metadata-only and MUST NOT appear in `question.md`.

## 4. Analog-to-Phase-6 Mapping (Wave 2 — P04-P08)

One row per new question with its strongest in-repo analog and the specific deltas the planner must enforce. (Wave 1 retrofits Q01 and scaffolds catalog/lint/fixtures; Wave 3 is pack-root finalisation. Both rely on the per-question patterns below.)

| Plan | Question | Primary analog (file:line) | Secondary analog | Deltas the planner must enforce |
|---|---|---|---|---|
| **P04** | `02-netpol-dns-egress` | `services-networking/01-networkpolicy-egress/` all 6 files | `services-networking/06-netpol-endport/grade.sh:18-28` (for per-jsonpath trap detector shape) | (1) Broken baseline is `netpol-label-key-drift` (selector key drift) PLUS no DNS egress — two-stage fix; (2) reference entry MUST point at `cka-sim/packs/services-networking/01-networkpolicy-egress/`; (3) seed_netpol_skeleton helper allows DNS by default — Q2 must explicitly strip the DNS-allow rule in setup.sh (RESEARCH §9); (4) image pin `nicolaka/netshoot:v0.13` per Phase 5 probe-pod convention; (5) symptoms-only prompt (RESEARCH §1); (6) estimatedMinutes 8 (inside [4,12]). |
| **P05** | `03-coredns-resolution` | `services-networking/03-coredns-resolution/` all 6 files | `cluster-architecture/05-audit-policy/setup.sh:15-25` (per-question ConfigMap seed idiom) | (1) D-11 — lab-ns CoreDNS Deployment + ConfigMap, NOT `dnsPolicy: None` per-pod hack (RESEARCH §4); (2) ConfigMap key exactly `Corefile` (capital C per v1.35 currency §11); (3) new traps `coredns-sandbox-configmap-mount` and `dnsconfig-policy-none-no-nameservers` registered first; (4) reference entry MUST point at `cka-sim/packs/services-networking/03-coredns-resolution/`; (5) grader MUST NOT `kubectl edit configmap coredns -n kube-system` — the forbidden-command lint will block it. |
| **P06** | `04-debug-node` | `cluster-architecture/07-cri-dockerd-endpoint/` shape for sandbox + file-content grader | `cluster-architecture/02-etcd-backup-restore/setup.sh:15-22` (sandbox sentinel pattern) | (1) D-10 — no host mutation in setup.sh (seed only `answer.txt` target); (2) oracle = Node API `{.status.nodeInfo.kernelVersion}` compared against candidate's `answer.txt` (RESEARCH §4); (3) ref-solution.sh MUST NOT actually invoke `kubectl debug node/…` (writes oracle value directly); (4) reset.sh hunts debug pods across all namespaces via `-l kubectl.kubernetes.io/debug-source` (RESEARCH §9 landmine); (5) `read_node_worker` helper mandatory — no hardcoded node-01/node-02 (lint-packs.sh pass F will reject); (6) reference entry points at `cka-sim/packs/cluster-architecture/02-etcd-backup-restore/`. |
| **P07** | `05-static-pod-manifest` | `cluster-architecture/05-audit-policy/` all 6 files (closest sandbox-YAML grader) | `cluster-architecture/07-cri-dockerd-endpoint/setup.sh:16-21` (sandbox sentinel + seed) | (1) Seed two broken variants (`manifest-broken.yaml` bad-yaml + `manifest-tagtypo.yaml` image typo) per RESEARCH §4; (2) grader uses `python3 yaml.safe_load` + `kubectl apply --dry-run=client -f /tmp/q05-staticpod/manifest.yaml` — NEVER copies to `/etc/kubernetes/manifests/`; (3) image pinned to `nginx:1.27-alpine` (avoids offline-lab pull gap, RESEARCH §9); (4) two new traps registered first (`static-pod-manifest-bad-yaml`, `static-pod-image-tag-typo`); (5) reference entry — planner MUST verify whether `cka-sim/packs/workloads-scheduling/` shipped a static-pod question; if yes, point there; otherwise fall back to `cka-sim/packs/cluster-architecture/02-etcd-backup-restore/`. |
| **P08** | `06-broken-kubelet` | `cluster-architecture/07-cri-dockerd-endpoint/` all 6 files — **exact-role analog, re-use heavily** | `cluster-architecture/02-etcd-backup-restore/reset.sh:1-9` (sentinel cleanup shape) | (1) Sandbox path `/tmp/q06-kubelet-flags/` — distinct from Phase 5 Q07's `/tmp/q07-kubelet-flags/` (fixtures + grader paths must differ); (2) add new trap `kubelet-flag-file-malformed-quoting` — grader validates via subshell `source /tmp/q06-kubelet-flags/kubeadm-flags.env` exit code (RESEARCH §4); (3) MUST NOT touch `/var/lib/kubelet/`, MUST NOT `systemctl` anything (forbidden-command lint blocks it); (4) reference entry points at `cka-sim/packs/cluster-architecture/07-cri-dockerd-endpoint/` — the natural prior-art; (5) image pin N/A (no pod seeded), but `read_node_worker` for any node reference. |

## 5. Shared Patterns (cross-cutting)

### Lib sourcing (applies to all setup.sh + grade.sh + reset.sh)
- `setup.sh`: `source "$CKA_SIM_ROOT/lib/setup.sh"` + `cka_sim::setup::ensure_lab_ns` + `cka_sim::setup::wait_for_ns_active`. Idempotent, fail-fast (`set -euo pipefail`).
- `grade.sh`: `source "$CKA_SIM_ROOT/lib/grade.sh"` always; add `source "$CKA_SIM_ROOT/lib/traps.sh"` whenever any `cka_sim::trap::detect_*` helper is used (Q1, Q2 retrofit/new). `set -uo pipefail` (NOT `-e` — must accumulate failures).
- `reset.sh`: `set -uo pipefail`, best-effort, always ends with `kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false`.

### Error/finalisation pattern (all grade.sh)
Every `grade.sh` MUST end with `cka_sim::grade::emit_result` as the sole terminal call. Every trap detector branch MUST call `cka_sim::grade::record_trap <id>` (not raw echo). Manual bookkeeping uses `CKA_SIM_GRADE_TOTAL`/`PASSED`/`FAILS`/`PASSES` exactly as in excerpt (B).

### Sandbox safety (Q4, Q5, Q6)
- All host-file-ish manipulation goes through `/tmp/qNN-*` sandbox dirs.
- Setup drops a `.cka-sim-sentinel` file; reset only `rm -rf` if sentinel present.
- Grader MUST NOT write to the sandbox (read-only) — per `lint-packs.sh` pass B (mutating-verb rejection).
- Grader MUST NOT write to `/etc/kubernetes/`, `/var/lib/kubelet/`, or any live system path — forbidden-command lint (new in this phase) will reject violations.

### Coverage-lint compliance (PACK-07 closure)
- Every new `metadata.yaml` id must appear in `troubleshooting/manifest.yaml.questions[*].id`.
- Every `manifest.yaml.questions[*].id` must be referenced in at least one `coverage.yaml.tracker.<slug>.questions[]` entry (otherwise it becomes an orphan warning — non-fatal but planner should avoid).
- Every `coverage.yaml.tracker.<slug>.questions[]` entry must resolve to a manifest id (lint-coverage.sh check 3, `lint-coverage.sh:142-150`).

### BUG-3 regression guard (all `packs/troubleshooting/**/*.sh`)
No hardcoded `node-01` / `node-02` literals anywhere except sentinel-opt-out files. Use `cka_sim::setup::read_node_worker`. See `lint-packs.sh:152-179`.

## 6. No Analog Found

None. Every Phase 6 file — including the new forbidden-command lint block, the static-pod sandbox grader, and the debug-node oracle grader — has a strong role+data-flow analog inside Phase 3-5 code. The only net-new content is 11 trap catalog entries (append-only, identical 8-field schema) and 7 grep patterns in the new lint pass.

## Metadata

- **Analog search scope:** `cka-sim/packs/**`, `cka-sim/scripts/*.sh`, `cka-sim/lib/*.sh`, `cka-sim/tests/fixtures/**`, `cka-sim/tests/cases/**`, `cka-sim/traps/catalog.yaml`.
- **Files scanned:** ~60 repo files read or grepped.
- **Pattern extraction date:** 2026-05-12.
- **Downstream note for `gsd-planner`:** All Wave 2 plans (P04-P08) can reuse the same 6-file scaffold; only the seeded broken content, trap-ID set, and question prose differ. Wave 1 (P01/P02/P03) blocks Wave 2 because the new traps must be registered before new metadata.yaml files pass `lint-packs.sh` pass E.
