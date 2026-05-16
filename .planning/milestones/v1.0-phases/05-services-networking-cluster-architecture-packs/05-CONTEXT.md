# Phase 5: Services-Networking + Cluster-Architecture Packs - Context

**Gathered:** 2026-05-12
**Status:** Ready for planning
**Mode:** Smart discuss (autonomous mode, batch grey-area tables accepted verbatim)

<domain>
## Phase Boundary

Author the two mid-weight domain packs end-to-end — Services & Networking (20 % weight) and Cluster Architecture (25 %) — using the runtime contract, trap framework, and helper library already shipped in Phases 2–4. Each pack gains enough questions to cover every v1.35 Study Progress Tracker checkbox for that domain, plus the ROADMAP-mandated content-replacement questions: PSS using the correct v1.25+ error wording, CRI-dockerd editing `/var/lib/kubelet/kubeadm-flags.env` with `--container-runtime-endpoint`, kube-proxy mode inspection (CG-15), NetworkPolicy `endPort` (CG-16), audit policy (CG-11), CRD basics (CG-12). Phase exits green when `cka-sim drill services-networking` and `cka-sim drill cluster-architecture` round-trip every question on the live 1+2 cluster, coverage-matrix lint reports 100 % for both domains, every new trap ID is registered in `traps/catalog.yaml` with schema lint green, and the new CI deprecated-strings lint blocks any future content regressions.

</domain>

<decisions>
## Implementation Decisions

### Scope and Coverage Strategy
- **Services & Networking pack total = 6 questions.** Reuses the existing `01-networkpolicy-egress` reference question + 5 new: `02-service-core` (ClusterIP/NodePort/Service selector semantics, endpoints), `03-coredns-resolution` (CoreDNS ConfigMap + upstream forwarding), `04-ingress-path-host` (Ingress path/host routing + IngressClass), `05-kube-proxy-mode` (CG-15 — detect iptables vs ipvs vs nftables mode, Service CIDR debugging), `06-netpol-endport` (CG-16 — NetworkPolicy `endPort` + `ipBlock.except`).
- **Cluster Architecture pack total = 8 questions.** Reuses the existing `01-rbac-viewer` reference question + 7 new: `02-etcd-backup-restore` (snapshot save + restore to alt data-dir), `03-kubeadm-upgrade` (planning + staged `kubeadm upgrade` on a simulated flag file), `04-pss-enforce` (CG-10 — PSS with correct v1.25+ wording `violates PodSecurity "<level>:<version>"`), `05-audit-policy` (CG-11 — Policy file + apiserver flags, sandbox path), `06-crd-basics` (CG-12 — create/install/instantiate CRD with `spec.scope`), `07-cri-dockerd-endpoint` (CG-13 — edit `/var/lib/kubelet/kubeadm-flags.env` sandbox copy with `--container-runtime-endpoint=unix:///run/cri-dockerd.sock`; never `/etc/kubernetes/kubelet.conf`), `08-priorityclass` (PriorityClass + globalDefault semantics, from CONCERNS.md prior-art gap).
- **Cluster-scoped impact policy:** setup.sh seeds broken state in a sandbox location only — etcd snapshot/restore uses `/tmp/q02-etcd-*`; kubeadm-upgrade operates on a simulated flag file under the lab ns; CRI-dockerd question edits a per-question copy of `kubeadm-flags.env` seeded under `/tmp/q07-kubelet-flags/` (never the live `/var/lib/kubelet/kubeadm-flags.env`); audit-policy writes Policy YAML and `AdmissionConfiguration` to per-question sandbox paths (never `/etc/kubernetes/`). reset.sh restores every host-level artifact it touched with sentinel-guarded cleanup. No live cluster state on the CP or workers is mutated outside the lab namespace.
- **Phase 3 retrofit:** retrofit `01-networkpolicy-egress` + `01-rbac-viewer` in place to source `lib/setup.sh` helpers (mirrors Phase 4's retrofit of `01-pvc-binding` + `01-deployment-requests`). Scope is narrow — source helpers only, no grader rewrites, no metadata schema changes, no trap list changes.
- Question directories follow the sequential `NN-slug/` convention. Coverage is asserted by `scripts/lint-coverage.sh`, not by file count.

### Authoring Pattern and Trap Catalog
- Every question ships the identical six-file shape proven in Phases 3–4: `setup.sh`, `grade.sh`, `reset.sh`, `metadata.yaml`, `question.md`, `ref-solution.sh`. No per-question extra files (no `hint.md`, no separate `solution.yaml`) — DF-08 stays deferred to v1.x.
- **Activate the 4 cluster-arch traps seeded in Phase 2 from CONCERNS.md:**
  - `pss-error-string-mismatch` + `psp-fictional-pod-label-exemption` → Q04 (PSS enforce)
  - `kubelet-runtime-flag-in-kubeconfig` + `removed-container-runtime-flag` → Q07 (CRI-dockerd)
  - `as-flag-format-wrong` → optional reinforcement on the `01-rbac-viewer` retrofit (no behaviour change)
- **Add ~10 new trap IDs** to `traps/catalog.yaml` in this phase, matching the Phase 2 seed schema (8 fields each, `references` as structured list):
  - `kube-proxy-mode-mismatch-ipvs-iptables` (Services-Networking)
  - `netpol-endport-missing-protocol` (Services-Networking)
  - `coredns-forward-to-invalid-upstream` (Services-Networking)
  - `ingress-missing-ingressclass` (Services-Networking)
  - `etcd-snapshot-without-env-set` (Cluster-Arch)
  - `etcd-restore-wrong-data-dir` (Cluster-Arch)
  - `kubeadm-upgrade-skip-plan` (Cluster-Arch)
  - `audit-policy-wrong-stage-verbosity` (Cluster-Arch)
  - `crd-missing-scope-field` (Cluster-Arch)
  - `cri-endpoint-unix-prefix-missing` (Cluster-Arch)
  - `priorityclass-globaldefault-conflict` (Cluster-Arch)
- Severity mix: `error` for correctness bugs that break cluster function or misteach; `warn` for footguns and pedagogical reinforcement. Matches Phase 2/3/4 policy.
- **Extend `cka-sim/lib/setup.sh`** with 2 new helpers:
  - `cka_sim::setup::seed_netpol_skeleton <ns> <name> <selector-label>` — emits a baseline NetworkPolicy with an `Egress` rule allowing DNS (deduplicates across `01-networkpolicy-egress` retrofit + `06-netpol-endport`).
  - `cka_sim::setup::read_node_worker` — dynamic worker-discovery idiom (from Phase 4 BUG-3 retrofit) exported as a helper for kube-proxy + any Q needing a non-CP node.
- `ref-solution.sh` stays bash with inline heredoc YAML where a manifest is needed, pure kubectl otherwise — one lint rule for the whole corpus. Audit-policy + PSS ref-solutions write canonical `AdmissionConfiguration`/`Policy` YAML to sandbox paths; never touches `/etc/kubernetes/`. WR-01 (full vendoring under `cka-sim/vendor/`) remains deferred.

### Runtime + Verification Contract
- **`estimatedMinutes` budget per new question**: CRD basics 6, netpol-endport 7, kube-proxy 8, service-core 7, coredns 7, ingress 8, PSS 9, audit-policy 9, etcd-backup-restore 10, kubeadm-upgrade 10, CRI-dockerd 8, priorityclass 7. Pack totals: S&N ~46 min, Cluster-Arch ~68 min. Leaves MOCK-01/02 blueprint composition unconstrained (both well inside the 110–120 min window).
- Round-trip self-check (GRADE-06) runs in two places — identical to Phase 4:
  1. `scripts/test.sh` — unit-level round-trip against the PATH-shadowed `kubectl` stubs.
  2. `scripts/lint-packs.sh` — schema + RFC-1123 + static round-trip lint over every pack directory.
  Live-kubectl round-trip verification against the 1+2 cluster remains a manual VERIFICATION.md checklist item per question.
- **CI extensions**:
  - `scripts/lint-coverage.sh` extended to walk `services-networking` + `cluster-architecture` (already walks storage + workloads).
  - New deprecated-strings grep added to `.github/workflows/validate.yml`: fails the PR if new content under `cka-sim/packs/**` contains `PodSecurityPolicy`, `--container-runtime=remote`, `policy/v1beta1`, `gitRepo:`, or `dockershim` as Kubernetes API strings. Carveout: comment references (lines starting with `#` in YAML or a `<!--` block in markdown) are allowed — the lint scans manifest blocks and runtime content only, per CI-02 scope.
- **Phase 5 VERIFICATION.md must-haves = 8 criteria:**
  1. Services-Networking pack has ≥1 question per Tracker checkbox in the S&N domain (lint-coverage.sh asserts 100 %).
  2. Cluster-Architecture pack has ≥1 question per Tracker checkbox in the Cluster-Arch domain.
  3. Every new question's `metadata.yaml` passes schema lint: `id`, `domain`, `estimatedMinutes ∈ [4,12]`, `verified_against: "1.35"`, `traps: [≥3 IDs]`, `references: [...]`.
  4. Every trap ID referenced by any question exists in `traps/catalog.yaml` (catalog lint).
  5. `cka-sim drill services-networking` and `cka-sim drill cluster-architecture` can drill every question in those packs without error (manual 1+2 cluster verification).
  6. All ~10 new trap entries in `traps/catalog.yaml` pass `scripts/lint-traps.sh` (8-field schema, structured references).
  7. CI deprecated-strings lint fails any content under `cka-sim/packs/**` containing `PodSecurityPolicy`, `--container-runtime=remote`, `policy/v1beta1`, `gitRepo:`, or `dockershim` (comment references allowed).
  8. Phase 3 retrofits (`01-networkpolicy-egress`, `01-rbac-viewer`) still round-trip green after sourcing `lib/setup.sh`.

### Claude's Discretion
- Exact broken-state YAML per question (within the topic and trap-ID constraints above).
- Whether to fold `priorityclass` into `kubeadm-upgrade` or keep as Q08 (based on how the scenario reads — currently Q08 in the plan).
- Per-question success-criteria phrasing inside `grade.sh` (assertion library from Phase 2 is fixed; wording at Claude's discretion).
- Whether the new `lib/setup.sh` helpers (`seed_netpol_skeleton`, `read_node_worker`) keep the `cka_sim::setup::` namespace or get shorter aliases — pick whichever reads cleanest.
- CRI-dockerd question's simulated flag-file path under `/tmp/q07-kubelet-flags/` — exact layout at author's discretion as long as `reset.sh` cleans it.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `cka-sim/lib/traps.sh` + `cka-sim/lib/grade.sh` (Phase 2) — assertion + detector helpers every grader composes from.
- `cka-sim/lib/setup.sh` (Phase 4) — `ensure_lab_ns`, `wait_for_ns_active`, `seed_pv_hostpath`, `seed_deployment`. Phase 5 adds `seed_netpol_skeleton` and `read_node_worker`.
- `cka-sim/traps/catalog.yaml` (Phase 2 seeded + Phase 3/4 extensions) — 25 entries as of commit `03b600f`; schema lint green. Phase 5 adds ~10 new + activates 4 CONCERNS-seeded entries on the new questions.
- `cka-sim/packs/services-networking/01-networkpolicy-egress/` + `cka-sim/packs/cluster-architecture/01-rbac-viewer/` (Phase 3) — reference questions; six-file shape + pack `manifest.yaml` shape are proven. Retrofitted in place in this phase.
- `cka-sim/scripts/test.sh` — bash test harness with PATH-shadowed `kubectl` stub; extend by dropping new fixtures under `cka-sim/tests/fixtures/`.
- `cka-sim/scripts/lint-traps.sh` / `scripts/lint-packs.sh` / `scripts/lint-coverage.sh` — Phase 4 CI contract; extend coverage walker to the two new packs.

### Established Patterns
- Idempotent `setup.sh` / `reset.sh` with `--ignore-not-found`, cka-sim sentinel-guarded mutations, per-question lab namespace `cka-sim-<domain>-NN`.
- Dynamic worker discovery via `kubectl get nodes -l '!node-role.kubernetes.io/control-plane'` (Phase 4 BUG-3 retrofit) — promoted to `lib/setup.sh` in this phase.
- Grader structure: `source lib/grade.sh` + `source lib/traps.sh`, assertions accumulate (`assert_*` never `die`), emit `SCORE:` + `Trap N:` block on stdout, live tick marks on stderr.
- Pack directory layout: `packs/<slug>/manifest.yaml` + `packs/<slug>/NN-slug/` per question + `coverage.yaml` at pack root.
- Sandbox-path convention for host-level mutations: `/tmp/qNN-<topic>/` prefix, sentinel-guarded cleanup in reset.sh.

### Integration Points
- `cka-sim drill <pack>` subcommand (Phase 3) already picks a question by pack and runs the triplet — adding new questions just needs them to match the existing metadata schema.
- CI `bash-tests` GHA job runs `scripts/test.sh`; extending fixtures lands automatically.
- Coverage-matrix lint (Phase 4) will gain the two new packs in this phase.
- New deprecated-strings lint wires into `.github/workflows/validate.yml` alongside the existing yamllint + shellcheck steps.

</code_context>

<specifics>
## Specific Ideas

- The PSS question MUST use the v1.25+ wording `violates PodSecurity "<level>:<version>"` in its ref-solution and `question.md`. CI deprecated-strings lint enforces absence of `PodSecurityPolicy` in new content.
- The CRI-dockerd question MUST edit `/var/lib/kubelet/kubeadm-flags.env` (via a sandbox copy under `/tmp/q07-kubelet-flags/`) with `--container-runtime-endpoint=unix:///run/cri-dockerd.sock`. It MUST NOT touch `/etc/kubernetes/kubelet.conf` (kubeconfig, not runtime flags). Trap `kubelet-runtime-flag-in-kubeconfig` fires if the candidate's ref-solution or submission edits the wrong file; `removed-container-runtime-flag` fires on any `--container-runtime=remote` usage.
- The Phase 3 retrofit touches source-only: `source "$CKA_SIM_ROOT/lib/setup.sh"` at the top of the existing `setup.sh` + replacing any ad-hoc ns-wait loop with the helper call. No metadata, no grader, no trap changes.
- The netpol-endport question seeds a Pod with a listening service on a port range (e.g. 8080-8090), then expects the candidate to write a NetworkPolicy using `endPort` — grader uses `kubectl exec` probe to verify allow/deny behaviour.
- Every new `metadata.yaml` declares `verified_against: "1.35"` literally as a string (not 1.35 numeric) — CI lint from Phase 2 checks for the exact token.

</specifics>

<deferred>
## Deferred Ideas

- Cross-pack question links (Troubleshooting references into S&N / Cluster-Arch) — belongs in Phase 6 per the ROADMAP dependency chain.
- Full vendoring of CSI / audit-policy / PSS manifests under `cka-sim/vendor/` with recorded SHA256 — WR-01 still deferred from Phase 4.
- `cka_sim::grade::assert_custom` helper + grader retrofit — IN-04 still deferred from Phase 4.
- Hint-reveal feature (DF-08) — remains out of scope; no `hint.md` files.
- Auto-generated coverage-matrix rendering in README — optional, can land in Phase 8 docs.
- CI step that runs `cka-sim drill <pack>` live against `kind` (DF-12 fixture CI) — deferred to v1.x.
- Pack-level README.md polish — minimal README per pack in Phase 5; full polish happens in Phase 8's DOC-01..04.
- Q08 priorityclass could merge into kubeadm-upgrade as a post-upgrade validation step — kept as its own Q for now.

</deferred>
