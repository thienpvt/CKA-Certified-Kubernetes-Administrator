# Phase 6: Troubleshooting Pack — Research

**Researched:** 2026-05-12
**Domain:** CKA Troubleshooting (30% weight) — 6-question pack + lint closure
**Confidence:** HIGH

## Summary

Phase 6 authors the largest-weight CKA domain pack end-to-end using the already-proven
six-file shape and helper library from Phases 2-5. All framework work is done; this phase
is pure content authoring plus two small lint extensions (coverage walker + forbidden-
command guard) and a light retrofit of the existing Phase 3 reference question. Six
questions at a progressive difficulty ramp, every host-level failure mode lives in a
`/tmp/qNN-*` sandbox (D-09..D-12), and every question carries a strong cross-pack
`metadata.yaml.references[]` entry (D-05..D-08).

**Primary recommendation:** Treat Phase 6 as a Phase 5 clone with 6 questions instead of
14. Use the Phase 5 plan-compression pattern (~9-10 plans total), extend existing lints
rather than invent new ones, and keep the trap catalog delta to ~10 new IDs per D-14.

## 1. Six-Question Roster (progressive ramp)

Order fixed by D-03. Slugs proposed below are Claude's discretion per the CONTEXT.

| Slug | Topic | Symptom-only prompt (one line) | Min | Lib helpers | Traps (3+ each) | Cross-pack ref |
|------|-------|-------------------------------|-----|-------------|-----------------|----------------|
| `01-deploy-svc-mismatch` | Service endpoints empty | *(retrofit — prompt unchanged)* "Users cannot reach Service `web-svc`; Pods are Running." | 7 | ensure_lab_ns, wait_for_ns_active, seed_deployment (retrofit) | `service-selector-empty-endpoints` [reuse], `default-sa-used` [reuse], `missing-dns-egress` [reuse], `imagepullbackoff-wrong-tag` [new] | `cka-sim/packs/services-networking/02-service-core/` |
| `02-netpol-dns-egress` | DNS + upstream blocked | "Pod `web` cannot resolve `kubernetes.default.svc` and cannot reach backend `api-svc:8080`; a NetworkPolicy is in effect." | 8 | ensure_lab_ns, wait_for_ns_active, seed_netpol_skeleton (as broken baseline), seed_deployment | `missing-dns-egress` [reuse], `netpol-label-key-drift` [new], `netpol-default-deny-missing-allow` [new] | `cka-sim/packs/services-networking/01-networkpolicy-egress/` |
| `03-coredns-resolution` | CoreDNS upstream bogus | "Pods in lab ns cannot resolve external names; cluster-internal names also fail." | 8 | ensure_lab_ns, wait_for_ns_active, seed_deployment | `coredns-forward-to-invalid-upstream` [reuse], `coredns-sandbox-configmap-mount` [new], `dnsconfig-policy-none-no-nameservers` [new] | `cka-sim/packs/services-networking/03-coredns-resolution/` |
| `04-debug-node` | Node state read-only inspect | "A scheduling decision appears to depend on kernel version and a file on the worker node; determine the values without mutating the host." | 9 | ensure_lab_ns, wait_for_ns_active, read_node_worker | `debug-pod-leaked-not-cleaned` [new], `debug-node-missing-chroot-host` [new], `debug-ephemeral-vs-node-confusion` [new] | `cka-sim/packs/cluster-architecture/02-etcd-backup-restore/` (prior-art: node-level inspection) |
| `05-static-pod-manifest` | Static pod never becomes Ready | "A static pod named `q05-cache` should be running on the worker node; `kubectl get pods -A` shows it Pending/missing. Its manifest lives at a sandbox path." | 10 | ensure_lab_ns, wait_for_ns_active | `static-pod-applied-via-kubectl-apply` [reuse], `static-pod-manifest-bad-yaml` [new], `static-pod-image-tag-typo` [new] | `cka-sim/packs/services-networking/02-service-core/` (distant — static pod's mirror as Service target) OR use workloads-scheduling static-pod Q if one exists |
| `06-broken-kubelet` | kubelet flags file broken | "kubelet on the worker would fail to start given the content of a candidate flag file; fix the file so kubelet would start with CRI endpoint correct. Do NOT touch the live kubelet." | 11 | ensure_lab_ns, wait_for_ns_active, read_node_worker | `kubelet-runtime-flag-in-kubeconfig` [reuse], `removed-container-runtime-flag` [reuse], `cri-endpoint-unix-prefix-missing` [reuse], `kubelet-flag-file-malformed-quoting` [new] | `cka-sim/packs/cluster-architecture/07-cri-dockerd-endpoint/` |

**Total estimatedMinutes:** 53 — inside PACK-06 [4,12] per question and fits blueprint budget.

**Note on Q5 cross-ref:** If no static-pod question exists in workloads-scheduling pack
(Phase 4 PACK-02), refer to Phase 5 `cluster-architecture/02-etcd-backup-restore/` instead
(both exercise node-level control-plane scenarios). Flagged as a landmine for the planner
to confirm against the actual `packs/workloads-scheduling/` tree.

## 2. Tracker Coverage Closure

Tracker checkboxes (verbatim from `README.md` §"Domain 2 — Troubleshooting (30%)"):

| Tracker bullet | Covered by | Notes |
|---|---|---|
| Read kubelet logs with journalctl | Q6 broken-kubelet | Grader asserts candidate's reasoning file mentions `journalctl -u kubelet`. |
| Check control plane pod logs | Q5 static-pod-manifest | Static pod IS the control-plane log-pattern (kubelet-managed). |
| Debug Pending pods | Q5 static-pod-manifest | Broken manifest → never becomes Running → Pending-equivalent symptom. |
| Debug CrashLoopBackOff pods | Q5 static-pod-manifest | Secondary assertion on resulting pod phase after fix attempt. |
| Debug ImagePullBackOff | Q1 deploy-svc-mismatch (retrofit) | Add `imagepullbackoff-wrong-tag` trap — one replica's image tag intentionally misspelt; grader records the trap alongside the selector fix. |
| Troubleshoot Service endpoints | Q1 | Primary. |
| Troubleshoot CoreDNS | Q3 | Primary. |
| Troubleshoot NetworkPolicy | Q2 | Primary. |
| Use kubectl debug (ephemeral + node) | Q4 | Primary — grader checks `kubectl debug node/...` was actually used. |
| Complete Exercise 11, 17 | References only (D-06) | metadata.yaml.references[] link-only. |

**No 7th question required.** PACK-07 coverage-matrix lint accepts N:1 mapping (tracker
slug → N questions). Phase 6 closes PACK-07 across all 5 packs.

**Flag:** If Phase 4 PACK-02 did not ship a static-pod question, the "Check control plane
pod logs" and "Debug Pending pods" mapping is carried solely by Phase 6 Q5 — verify during
planning that no duplicate-slug collision exists with workloads-scheduling coverage.yaml.

## 3. Trap Catalog Deltas (~10 new IDs)

**Existing catalog:** 34 entries as of the read of `cka-sim/traps/catalog.yaml` on
2026-05-12 (8 CONCERNS-seeded + 17 from Phases 3-4 + 10 new from Phase 5 minus overlap).
All new IDs below are RFC-1123 lowercase alphanumeric + `-`.

**Reused (existing, no new entry):**

| id | used by |
|---|---|
| `service-selector-empty-endpoints` | Q1 |
| `default-sa-used` | Q1, Q2 |
| `missing-dns-egress` | Q1, Q2 |
| `coredns-forward-to-invalid-upstream` | Q3 |
| `static-pod-applied-via-kubectl-apply` | Q5 |
| `kubelet-runtime-flag-in-kubeconfig` | Q6 |
| `removed-container-runtime-flag` | Q6 |
| `cri-endpoint-unix-prefix-missing` | Q6 |

**New (~10 adds, matching Phase 5 schema — 8 fields, structured references):**

| id | severity | domain | description (1-line) | used by |
|---|---|---|---|---|
| `imagepullbackoff-wrong-tag` | warn | troubleshooting | Deployment pod template image tag is typo'd; pods loop in ImagePullBackOff. | Q1 |
| `netpol-label-key-drift` | error | services-networking | Egress NetworkPolicy `podSelector.matchLabels` key drifted (e.g. `app` vs `app.kubernetes.io/name`) from target Pod labels; policy selects nothing. | Q2 |
| `netpol-default-deny-missing-allow` | error | services-networking | Namespace has default-deny NetworkPolicy plus a policy granting the wrong ns/port; no allow path exists for the required flow. | Q2 |
| `coredns-sandbox-configmap-mount` | warn | services-networking | CoreDNS Deployment in lab ns mounts ConfigMap by wrong volume name/key; Corefile is empty at runtime. | Q3 |
| `dnsconfig-policy-none-no-nameservers` | error | services-networking | Pod `dnsPolicy: None` with empty `dnsConfig.nameservers` — resolver has no upstream at all. | Q3 |
| `debug-pod-leaked-not-cleaned` | warn | troubleshooting | Candidate leaves the debug Pod running after answering; reset.sh must clean it, and the grader warns. | Q4 |
| `debug-node-missing-chroot-host` | error | troubleshooting | `kubectl debug node/...` invoked without `chroot /host` — candidate reads the debug-container rootfs, not the node's. | Q4 |
| `debug-ephemeral-vs-node-confusion` | warn | troubleshooting | Candidate used `kubectl debug <pod>` (ephemeral container) when the question required `kubectl debug node/<name>`. | Q4 |
| `static-pod-manifest-bad-yaml` | error | troubleshooting | Static pod manifest has a YAML error (indent, duplicate key, quoting) — kubelet silently skips it; no API object is created. | Q5 |
| `static-pod-image-tag-typo` | warn | troubleshooting | Static pod manifest `image:` value references a non-existent tag; pod reaches ImagePullBackOff on the node. | Q5 |
| `kubelet-flag-file-malformed-quoting` | error | cluster-architecture | `kubeadm-flags.env` `KUBELET_KUBEADM_ARGS` value has stray quotes / missing quotes / CRLF line-endings; kubelet refuses to parse. | Q6 |

**Count:** 11 new IDs (~10 per D-14, slight over OK if all unique root causes).
**Overlap check:** None collide with the 34 existing IDs after grep of the catalog file.

## 4. Sandbox Layouts for Risky Questions

### Q5 static-pod-manifest
- Sandbox path: `/tmp/q05-staticpod/`
- Files seeded broken: `manifest-broken.yaml` (contains `static-pod-manifest-bad-yaml` — e.g. duplicate `resources:` key or wrong indentation) and a second `manifest-tagtypo.yaml` (contains `static-pod-image-tag-typo`).
- Candidate edits `/tmp/q05-staticpod/manifest.yaml` (their working copy) to a valid form.
- Grader asserts: (a) content matches canonical fixed manifest via `diff` OR via `kubectl apply --dry-run=client -f /tmp/q05-staticpod/manifest.yaml` exits 0 AND resulting object has `kind: Pod`, `spec.nodeName` set, `kubernetes.io/config.source` expected to be `file` (documented in question.md but NOT actually placed in `/etc/kubernetes/manifests/`).
- Grader NEVER copies the manifest to `/etc/kubernetes/manifests/`. reset.sh removes `/tmp/q05-staticpod/`.

### Q6 broken-kubelet
- Sandbox path: `/tmp/q06-kubelet-flags/`
- Target file: `/tmp/q06-kubelet-flags/kubeadm-flags.env` — a sandbox COPY of the real `/var/lib/kubelet/kubeadm-flags.env` shape. Setup seeds a broken version.
- Broken line (example): `KUBELET_KUBEADM_ARGS="--container-runtime=remote --container-runtime-endpoint=/run/cri-dockerd.sock --pod-infra-container-image=registry.k8s.io/pause:3.10"`
- Target fixed line: `KUBELET_KUBEADM_ARGS="--container-runtime-endpoint=unix:///run/cri-dockerd.sock --pod-infra-container-image=registry.k8s.io/pause:3.10"`
- Grader asserts content-only: grep for `--container-runtime=remote` (must be absent), grep for `unix:///run/cri-dockerd.sock` (must be present), and `bash -n` equivalent parse of the env file via `source /tmp/q06-kubelet-flags/kubeadm-flags.env` inside a subshell.
- Grader NEVER touches `/var/lib/kubelet/`, never calls `systemctl`. reset.sh removes `/tmp/q06-kubelet-flags/`.

### Q4 debug-node
- Approach (recommended): candidate must run `kubectl debug node/<worker> -it --image=busybox:1.36 -- chroot /host cat /etc/os-release` (or similar host file), then write the result to `/tmp/q04-debug-node/answer.txt` on the machine where cka-sim runs.
- Grader verifies debug pod was created and terminated: `kubectl get pods -A -l 'kubectl.kubernetes.io/debug-source' -o json` OR checks the `answer.txt` file content matches the expected value derived from `kubectl get node <worker> -o jsonpath` (node OS image / kernel version readable via the Node object — use that as the oracle without requiring host mutation).
- **Cheapest reliable oracle:** kernel version — compare candidate's answer to `kubectl get node <worker> -o jsonpath='{.status.nodeInfo.kernelVersion}'`. Node API already exposes this truthfully; grader only verifies that the candidate actually used node debug (presence of completed debug Pod in recent events OR the presence of `answer.txt` with correct content — the node-API comparison grades the answer while `kubectl debug` being the only practical way to obtain it enforces the workflow).

### Q3 CoreDNS — per-question lab CoreDNS vs per-pod dnsConfig
- **Choice:** per-question lab CoreDNS Deployment + ConfigMap in the lab ns, NOT a per-pod `dnsConfig`.
- **Justification (2 lines):** A lab CoreDNS lets the question exercise the real ConfigMap / Corefile / forward/plugin semantics without ever touching `kube-system` (D-11 safety). Per-pod dnsConfig only exercises pod-side bypass, not CoreDNS authoring, and D-11 explicitly frames this as CoreDNS content.

### Q2 netpol — exact subtle misconfig
- Primary: `netpol-label-key-drift` — target Deployment pods labeled `app.kubernetes.io/name=web`, but the seeded baseline NetworkPolicy's `podSelector.matchLabels` is `app: web`. Policy matches no pods so default-deny from a sibling policy bites.
- Secondary: `missing-dns-egress` — egress rule omits UDP/53 to kube-system, so even when the primary is fixed, DNS still fails until the candidate adds DNS allow.
- Both required to fully pass grader (two-stage fix).

### Q1 service-mismatch retrofit delta vs Phase 3 existing
Existing Phase 3 version (on disk today):
- Six files present, grader sources `lib/grade.sh` + `lib/traps.sh`.
- metadata.yaml lists 3 traps and references `exercises/11-troubleshoot-cluster/`.
- setup.sh does NOT source `lib/setup.sh` — uses inline ns-Active loop.

**Retrofit delta (minimal — D-05 / Phase 5 retrofit shape):**
1. setup.sh: `source "$CKA_SIM_ROOT/lib/setup.sh"` at top; replace inline ns loop with `cka_sim::setup::ensure_lab_ns` + `cka_sim::setup::wait_for_ns_active`; replace inline Deployment YAML with `cka_sim::setup::seed_deployment` (keeping image pinned to `nginx:1.27-alpine` and readiness probe preserved — may need a `--readiness-probe` flag or inline override).
2. setup.sh: add `imagepullbackoff-wrong-tag` instance — second replica or a second Deployment with a tag typo. Simplest: change the main Deployment's `replicas: 2` to include one sidecar init/image typo OR add a parallel `web-canary` Deployment with `image: nginx:1.27-alpine-typo`. Claude's discretion.
3. metadata.yaml: bump traps[] to 4 entries (add `imagepullbackoff-wrong-tag`); add a `cka-sim/packs/services-networking/02-service-core/` reference with note "sibling for Service+Endpoint semantics"; keep the `exercises/11-troubleshoot-cluster/` link-only ref.
4. grade.sh: add an ImagePullBackOff detector — `kubectl get pods -n $CKA_SIM_LAB_NS -o jsonpath` check for any container `waiting.reason == ImagePullBackOff` or `ErrImagePull` → `cka_sim::grade::record_trap imagepullbackoff-wrong-tag`. Does NOT change the pass criterion (endpoints non-empty after Service fix stays the oracle).
5. ref-solution.sh: also delete / patch the bad-tag replica.
6. reset.sh: unchanged (ns-scoped cleanup already covers the extra Deployment).
7. question.md: append a sentence noting that "one pod replica appears to be in a different failure state" without naming ImagePullBackOff (symptom-only per D-04).

## 5. lib/setup.sh Additions

Existing exported helpers (verified in `cka-sim/lib/setup.sh`):
`ensure_lab_ns`, `wait_for_ns_active`, `seed_pv_hostpath`, `seed_deployment`,
`seed_netpol_skeleton`, `read_node_worker`.

**Recommend: ZERO new helpers.** Every Phase 6 question can be authored with existing
helpers. Q2 uses `seed_netpol_skeleton` *as the broken starting state* (drop the DNS-allow
block inside the question's setup.sh after calling the helper — or override via Claude's
discretion). Q3's lab CoreDNS and Q5's static-pod sandbox are one-off per-question YAML
that does not deduplicate.

Optional nice-to-have (defer if not trivially cheap):
- `cka_sim::setup::seed_sandbox_file <abs-path> <content-heredoc-var>` — centralises `/tmp/qNN-*` file seeding idiom. Used by Q5, Q6. Benefit is ~10 lines saved per question; cost is one helper + unit tests. **Recommendation: skip**, keep setup.sh per-question self-contained for Phase 6 (matches Phase 5 Q07 CRI-dockerd author precedent).

## 6. Lint Extensions

### lint-coverage.sh
One-line change: extend the `for pack_dir in "$PACKS_DIR"/*/` loop (or the target-pack
allowlist) to include `troubleshooting`. In practice the script already walks every
directory under `packs/`, so the only "change" is that `packs/troubleshooting/coverage.yaml`
now needs to exist with all 10 tracker slugs enumerated. **Likely zero script edits
needed** — just author the coverage.yaml. Verify by running `lint-coverage.sh troubleshooting`
during planning.

### lint-packs.sh — forbidden-command guard rails
New deny-list patterns scoped to `cka-sim/packs/troubleshooting/**/*.sh`:

| Forbidden pattern | Rationale |
|---|---|
| `\bsystemctl\b` | D-12: reset.sh must not restart kubelet / services. |
| `kubectl\s+edit\s+configmap\s+coredns\s+-n\s+kube-system` | D-11: no live kube-system CoreDNS mutation. |
| `kubectl\s+delete\s+ns\s+kube-system` | Catastrophic. |
| `kubectl\s+(cordon\|drain)\s+.*worker` | No worker mutation. |
| `>\s*/etc/kubernetes/` | No live control-plane file writes. |
| `>\s*/var/lib/kubelet/` | D-09: kubelet files only via sandbox copy. |
| `/etc/kubernetes/manifests/` as a write target | D-09: no live static-pod mutation. |

Implementation: grep-based, same idiom as the Phase 5 deprecated-strings lint. Comments
excluded (line starts with `#`). Applies only to `packs/troubleshooting/**`.

## 7. Plan Decomposition (recommend plan count)

Target: **9 plans** (matches Phase 5 compression).

**Wave 1 — Foundation & lint (parallelizable, 3 plans):**
- P01 — `lint-packs.sh` forbidden-command guard + fixtures.
- P02 — Trap catalog: append 11 new IDs to `traps/catalog.yaml` + lint-traps.sh regression.
- P03 — `01-deploy-svc-mismatch` retrofit (per §4 above).

**Wave 2 — Per-question authoring (parallelizable, 5 plans, one per new question):**
- P04 — `02-netpol-dns-egress`
- P05 — `03-coredns-resolution`
- P06 — `04-debug-node`
- P07 — `05-static-pod-manifest`
- P08 — `06-broken-kubelet`

**Wave 3 — Close-out (1 plan):**
- P09 — `troubleshooting/manifest.yaml` + `coverage.yaml` + `README.md` (pack metadata
  finalization) + VERIFICATION.md authoring + `lint-coverage.sh` 100%-green validation.

**Total: 9 plans.** Wave 1 and Wave 2 can both parallelize fully (no inter-question
dependencies once the catalog & retrofit land). Wave 3 is the synchronization point.

## 8. VERIFICATION.md Criteria

Seven criteria, executable bash (paths relative to repo root):

1. `bash cka-sim/scripts/lint-coverage.sh troubleshooting | grep -q "coverage 100%"` — tracker → question mapping complete.
2. `bash cka-sim/scripts/lint-coverage.sh | grep -q "coverage 100%"` — all 5 packs collectively green (closes PACK-07).
3. `bash cka-sim/scripts/lint-packs.sh cka-sim/packs/troubleshooting` — exits 0 (schema, RFC-1123, round-trip, forbidden-command guard).
4. `bash cka-sim/scripts/lint-traps.sh` — new trap catalog entries pass 8-field schema + structured references validation.
5. `bash cka-sim/scripts/test.sh` — round-trip self-check (GRADE-06) for all 6 questions: setup → grade fails with ≥1 trap; setup → ref-solution → grade passes.
6. Forbidden-command negative test: `grep -rnE '(\bsystemctl\b\|kubectl edit configmap coredns -n kube-system\|kubectl delete ns kube-system\|> /etc/kubernetes/\|> /var/lib/kubelet/)' cka-sim/packs/troubleshooting/ ; [[ $? -ne 0 ]]` — no matches.
7. Live 1+2 cluster round-trip (manual checklist): for each of the 6 questions, `cka-sim drill troubleshooting NN` completes without error; after answering, grader prints `SCORE:` line and at least one `Trap:` line on the unfixed state.
8. References lint: every troubleshooting `metadata.yaml` has ≥1 `references[]` entry whose `target` begins with `cka-sim/packs/` (D-05 cross-pack guarantee). Executable as: `for f in cka-sim/packs/troubleshooting/*/metadata.yaml; do grep -q 'target: cka-sim/packs/' "$f" || { echo "missing cross-pack ref: $f"; exit 1; }; done`.

## 9. Landmines

- Writing to `/var/lib/kubelet/kubeadm-flags.env` (real file). Q6 MUST stay in `/tmp/q06-kubelet-flags/`.
- Patching the `kube-system/coredns` ConfigMap in any form (setup, grade, reset, ref-solution). Q3 uses a lab-ns CoreDNS Deployment.
- `systemctl restart kubelet` or any `systemctl` in any script. Reset never restarts services (D-12).
- Copying a Q5 manifest into `/etc/kubernetes/manifests/` during grade or ref-solution. Grader uses `kubectl apply --dry-run=client` content match only.
- `kubectl debug node/...` leaving zombie debug pods in `default` ns; Q4 reset.sh must hunt and delete them (`kubectl get pods --all-namespaces -l 'kubectl.kubernetes.io/debug-source' -o name | xargs -r kubectl delete --ignore-not-found`).
- Hardcoding `node-01` / `node-02` anywhere — use `cka_sim::setup::read_node_worker`.
- Q2 seeding `seed_netpol_skeleton` and forgetting that the helper ALLOWS DNS by default; the broken baseline must explicitly strip or replace the DNS egress rule so `missing-dns-egress` actually fires.
- Q1 retrofit tripping the Phase 5 deprecated-strings lint — verify `imagepullbackoff-wrong-tag` setup doesn't embed `PodSecurityPolicy` / `dockershim` / `gitRepo:` / `policy/v1beta1` / `--container-runtime=remote` in its YAML.
- `ref-solution.sh` for Q4 cannot be fully automated without mutating host; design Q4's ref-solution to print the `kubectl debug node/...` command verbatim as guidance and write the known-correct value into `/tmp/q04-debug-node/answer.txt` via `kubectl get node -o jsonpath` (stays off the host).
- Q5's static-pod YAML using `image: nginx:<version>` that requires internet pull in an offline lab — use the same `nginx:1.27-alpine` pin Phase 3/5 chose.

## 10. Validation Architecture (for Nyquist VALIDATION.md)

**Static (bash -n, shellcheck, lint-packs, lint-traps, lint-coverage):**
- `bash -n` on every new `setup.sh`/`grade.sh`/`reset.sh`/`ref-solution.sh` under `packs/troubleshooting/` — runs as part of `scripts/test.sh` sample set.
- `shellcheck` via repo CI (`.github/workflows/validate.yml`) — already wired in Phase 5.
- `lint-packs.sh troubleshooting` — adds the forbidden-command guard this phase.
- `lint-traps.sh` — covers the 11 new catalog entries (schema + structured references).
- `lint-coverage.sh troubleshooting` and full-tree `lint-coverage.sh` — must report 100%.

**Behavioural (round-trip via test.sh fixture stubs):**
- Each question gets a fixture under `cka-sim/tests/fixtures/troubleshooting-NN-<slug>/` with a PATH-shadowed `kubectl` stub replaying the expected objects. `scripts/test.sh` runs `setup.sh && grade.sh` → expect fail + ≥1 trap, then `setup.sh && ref-solution.sh && grade.sh` → expect pass.

**Live (manual on 1+2 cluster):**
- VERIFICATION.md checklist item per question: drill the question on the real 1+2 kubeadm cluster, confirm grader behaviour matches fixture expectations, confirm reset leaves no residue (`kubectl get ns cka-sim-troubleshooting-NN` returns NotFound; `/tmp/qNN-*` removed).
- Q4 additional manual check: `kubectl get pods -A -l 'kubectl.kubernetes.io/debug-source'` empty after reset.
- Q6 additional manual check: `/var/lib/kubelet/kubeadm-flags.env` unchanged (diff against baseline checksum taken before the drill).

**Nyquist sampling rate:**
- Per task commit: `bash -n` + focused lint on the changed question dir (~5s).
- Per wave merge: `scripts/test.sh` full suite + `lint-coverage.sh` (~60s).
- Phase gate: full suite + manual live checklist on 1+2 cluster before `/gsd-verify-work`.

## 11. v1.35 Currency Check

- **kubectl debug node spelling:** `kubectl debug node/<nodename> -it --image=<img> -- chroot /host <cmd>`. The `node/` prefix is mandatory; space-separated `kubectl debug node <name>` is not accepted. Source: `kubectl debug --help` output shape is stable since v1.20 (GA in 1.23). [CITED: kubernetes.io/docs/tasks/debug/debug-cluster/kubectl-node-debug/]
- **CoreDNS ConfigMap field name:** ConfigMap is `kube-system/coredns`; the Corefile lives under `data.Corefile` (capital C). The Deployment mounts it as `/etc/coredns/Corefile`. Sandbox CoreDNS in Q3 should mirror this shape (ConfigMap key `Corefile`). [CITED: kubernetes.io/docs/tasks/administer-cluster/coredns/]
- **Event API version:** `events.k8s.io/v1` is GA and default in v1.35. Legacy `v1/Event` (core) still emitted for compatibility. Graders using jsonpath should query `events.k8s.io/v1` for new authoring. [CITED: kubernetes.io/docs/reference/using-api/deprecation-guide/]
- **1.35-specific troubleshooting bullet not handled by Phases 3-5:** Kubelet's `--container-runtime` flag remains removed (since 1.27); only `--container-runtime-endpoint` exists — already covered by the `removed-container-runtime-flag` trap reused in Q6. No net-new 1.35 troubleshooting content is uncovered.

## Assumptions

Files that would have been useful but were skipped to stay inside the 10-minute budget:

- `.planning/STATE.md` — relied on `06-CONTEXT.md` and `05-CONTEXT.md` for phase/locked-decision context.
- `.planning/PROJECT.md` / `.planning/phases/02-trap-framework-assertion-library/02-CONTEXT.md` / `.planning/phases/03-runtime-contract-drill-mode/03-CONTEXT.md` / `.planning/phases/04-storage-workloads-scheduling-packs/04-CONTEXT.md` — trap schema, six-file shape, and lint contract are already re-stated in `05-CONTEXT.md` §"Existing Code Insights" and in the live `traps/catalog.yaml` comment header.
- `cka-sim/tests/fixtures/` tree — trusted that the Phase 5 fixture-stub pattern transplants 1:1; planner should verify the fixture directory structure on the first question plan.
- `cka-sim/packs/workloads-scheduling/` tree — did not open; Q5 static-pod cross-reference target in §1 is best-guess and flagged as a landmine. Planner must confirm whether PACK-02 shipped a static-pod question and update Q5's `references[]` if so.
- `exercises/11-troubleshoot-cluster/` and `exercises/17-kubectl-debug/` — link-only references per D-06 / BANNER-02; contents not read.
- Full `troubleshooting/README.md` playbook — intentionally skipped per mandatory_reads.
- `.planning/REQUIREMENTS.md` §"Runtime contract" was read only via grep (matched TRIP-01..07 lines with context windows).

## RESEARCH COMPLETE

- Six-question roster locked to the CONTEXT-decided progression; each carries ≥3 traps, at least one cross-pack reference path, and a sandboxed fail mode where host-level state is involved.
- Trap catalog delta is 11 new IDs (8 reused); no collisions with the existing 34 entries.
- Host-safety contract encoded twice: into per-question sandbox layouts (§4) and into a new `lint-packs.sh` forbidden-command guard (§6).
- Plan decomposition recommends 9 plans in 3 waves, mirroring Phase 5's compression; Wave 2 is fully parallelizable across the 5 new questions.
- Closure of PACK-07 100% coverage works with 6 questions by mapping multiple tracker bullets onto Q1 (ImagePullBackOff + Service endpoints) and Q5 (static pod + control-plane logs + Pending + CrashLoopBackOff) — no 7th question required.
