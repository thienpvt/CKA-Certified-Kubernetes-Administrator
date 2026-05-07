---
title: Concerns
focus: concerns
last_mapped: 2026-05-07
---

# Concerns — CKA Study Repository

This is a CKA study/exercise repo (Markdown + YAML + Bash). Traditional "tech debt" doesn't apply; concerns are scoped to **content accuracy, exam-curriculum alignment, learner safety, and script portability**.

## Content Accuracy & Version Drift

### Pod Security Standards error string says "PodSecurityPolicy" (removed in 1.25)
- `exercises/20-pod-security-standards/README.md:110` — solution shows `# Error: pods "restricted-test" is forbidden: violates PodSecurityPolicy: ...`
- `mock-exams/MOCK-EXAM-01-SOLUTIONS.md:636` — `violates PodSecurityPolicy: privileged: true`
- **Problem:** PSP was removed in 1.25. PSS errors now read `violates PodSecurity "<level>:<version>"`.
- **Fix:** Replace with the actual PSS wording.

### Pod-level PSS exemption label is fictional
- `mock-exams/MOCK-EXAM-02-SOLUTIONS.md:603-647` (Solution 13: "Pod Security Policy Bypass") tells learners to label a Pod with `pod-security.kubernetes.io/exempt: 'true'` to bypass PSS.
- **Problem:** No such label exists. PSS exemptions are configured cluster-wide via `AdmissionConfiguration.exemptions` (usernames, namespaces, runtimeClasses) in `--admission-control-config-file`. There is no per-pod opt-out. A learner would copy this and have a privileged pod silently rejected.
- **Fix:** Rewrite to either raise the namespace label to `privileged` or show the correct cluster-level `AdmissionConfiguration` YAML.

### Mock Exam 02 still uses the heading "Pod Security Policy"
- `mock-exams/MOCK-EXAM-02-SOLUTIONS.md:603` — `Solution 13: Pod Security Policy Bypass`.
- **Fix:** Rename to "Pod Security Standards (PSS) Exemption."

### CRI-dockerd kubelet flag `--container-runtime=remote` was removed in 1.27
- `exercises/26-cri-dockerd-setup/README.md:41,114-115` and `exercises/18-cri-dockerd-setup/README.md`
- **Problem:** Solution does `sed -i 's|--container-runtime=containerd|--container-runtime=remote|' /etc/kubernetes/kubelet.conf`. The `--container-runtime` flag was removed in 1.27; in 1.35 only `--container-runtime-endpoint` remains. Worse, `/etc/kubernetes/kubelet.conf` is the kubeconfig — kubelet runtime flags live in `/var/lib/kubelet/kubeadm-flags.env` (or `/etc/default/kubelet`). The `sed` will silently no-op.
- **Fix:** Drop `--container-runtime=remote`; edit the correct flags file with `--container-runtime-endpoint=unix:///run/cri-dockerd.sock`. Same fix in ex-18.

### Dockershim removal version misstated
- `exercises/26-cri-dockerd-setup/README.md:26` — claims "Kubernetes v1.35 dropped built-in dockershim — must use cri-dockerd."
- **Problem:** Dockershim was removed in 1.24 (March 2022). The 1.35 phrasing implies a recent change.
- **Fix:** Correct the version. Consider whether two near-duplicate cri-dockerd exercises belong in a CKA-targeted study guide (cri-dockerd is not in the published v1.35 competencies).

### Inconsistent image versions across the repo (nginx 1.27 vs 1.28, busybox 1.36 vs 1.37)
- `exercises/01-pod-basics/README.md:12` task says `nginx:1.27`; solution at line 64 uses `nginx:1.28`; YAML at line 81 uses `nginx:1.27` — three values in one file.
- `exercises/05-networkpolicy/README.md:11-12` `nginx:1.27`
- `exercises/19-ingress-classic/README.md:21-22` `nginx:1.28`
- `exercises/20-pod-security-standards/README.md:59` `nginx:1.28`
- `cheatsheet/cka-cheatsheet.md:44-48` `nginx:1.27`, `busybox:1.36`
- `mock-exams/MOCK-EXAM-01-SOLUTIONS.md:654-659` `nginx:1.28`, `busybox:1.37`
- `skeletons/securitycontext.yaml:12`, `skeletons/daemonset.yaml:22` `busybox:1.36`/`fluentd:v1.17`
- **Fix:** Pick canonical versions and `find/replace`. Add a one-line policy in `CONTRIBUTING.md`.

### Domain-numbering scheme is internally inconsistent (and many cross-links 404)
- `README.md:111-117` defines 5 domains (matches v1.35 CNCF curriculum).
- `exercises/README.md:3` says "all seven CKA exam domains" — contradicts.
- `exercises/19-ingress-classic/README.md:3` links `#domain-3--services--networking-20` (Services & Networking is Domain 5).
- `exercises/26-cri-dockerd-setup/README.md:3`, `exercises/27-cni-tigera-install/README.md:3`, `exercises/29-troubleshoot-etcd-endpoint/README.md:3` link `#domain-7--cluster-maintenance-11` (no such domain).
- `exercises/30-tls-configuration-update/README.md:3` links `#domain-4--security-12` (no separate Security domain in v1.35 CKA).
- `exercises/31-argocd-gitops-setup/README.md:3` links `#domain-3--workloads--scheduling-15`, but `exercises/README.md:41` categorises it under Cluster Architecture.
- **Fix:** Run a link checker; consolidate to the v1.35 5-domain syllabus.

### `kubeadm` apt pin uses unstable Debian revision suffix
- `README.md:1522,1533,1548-1549,2178-2179,2190,2559-2567`, `cheatsheet/cka-cheatsheet.md:125,130`
- **Pattern:** `apt-get install -y kubeadm=1.35.0-1.1`
- **Problem:** `-1.1` is a Debian package revision and gets rebuilt; by the time a learner runs this it may not be available in `pkgs.k8s.io` and apt will fail.
- **Fix:** Pin only the upstream version (`kubeadm=1.35.*`), or document `apt-cache madison kubeadm`.

## Coverage Gaps

### v1.35 syllabus topics likely under-represented
- **CRDs** — no standalone exercise. Only mentioned via Argo CD (ex-31) and `skeletons/validatingadmissionpolicy.yaml`.
- **CNI / kube-proxy modes** — ex-27 covers Calico install but no lab on iptables vs ipvs vs nftables, Service CIDR debugging, or kube-proxy metrics.
- **kube-scheduler customisation** — `KubeSchedulerConfiguration` profiles and extenders not covered (ex-22/24 only cover PriorityClass).
- **Logging / monitoring** — no metrics-server install lab; ex-16 (HPA) implicitly assumes metrics-server is present.
- **CSI snapshots / VolumeSnapshot** — `skeletons/` has no `volumesnapshot.yaml`. `CONTRIBUTING.md:24` even cites a hypothetical "exercise 18 — CSI snapshots" but ex-18 is now CRI-dockerd.
- **Native sidecar containers (GA in 1.33)** — only `skeletons/sidecar-init-container.yaml` and a passing troubleshooting reference; no exercise drills `restartPolicy: Always` on initContainers.
- **NetworkPolicy `endPort` / `ipBlock.except`** — not exercised.
- **Audit policy** — no exercise on `--audit-policy-file` / `kubectl auth whoami`.

**Suggested adds:** `exercises/3X-crd-basics/`, `exercises/3X-volume-snapshot/`, `exercises/3X-metrics-server-bootstrap/`, `exercises/3X-native-sidecar/`.

### Only 2 mock exams; weighting skewed
- `mock-exams/MOCK-EXAM-01.md`, `mock-exams/MOCK-EXAM-02.md`
- Both heavy on troubleshooting and scheduling; Storage and Services & Networking under-represented relative to the 10% / 20% domain weights. A learner who memorises both has only ~30 unique questions of practice.

## Maintenance Debt

### Duplicate exercise: 18 and 26 both cover CRI-dockerd
- `exercises/18-cri-dockerd-setup/README.md` and `exercises/26-cri-dockerd-setup/README.md`
- Same slug, same topic. Diff: ex-18 is more thorough; ex-26 contains the broken `--container-runtime=remote` flag. Inflates badge count and confuses navigation.
- **Fix:** Delete ex-26, fold unique tips into ex-18.

### Overlapping exercise: 22 (PriorityClass) and 24 (PriorityClass Patch)
- ex-24 is essentially "do ex-22 again with `kubectl patch`." Useful drill but presented as a peer exercise; ~30 minutes of redundant content.
- **Fix:** Fold ex-24 into ex-22 as a "Bonus: do it with patch" appendix.

### `priorityclass.yaml` skeleton referenced but does not exist
- `exercises/24-priorityclass-patch/README.md:3` links `../../skeletons/priorityclass.yaml`
- `skeletons/` directory has no `priorityclass.yaml`. Broken link.
- **Fix:** Add the skeleton or remove the link.

### Badges and counts disagree with reality
- `README.md:6-8` claims 31 exercises, 23 skeletons. `exercises/` has 31 directories (but 30 unique topics due to the cri-dockerd duplicate). `skeletons/` count of 23 is correct.
- `CHANGELOG.md` `[1.1.0]` says "Exercises index updated to cover **17 exercises**" but the index now covers 31. The jump 17→31 is undocumented; `exercises/README.md:7` mentions a "v2.0" that has no CHANGELOG entry and no git tag.
- **Fix:** Add a `[2.0.0]` CHANGELOG entry.

### `CONTRIBUTING.md` example references nonexistent topic for ex-18
- `CONTRIBUTING.md:24` example: `feat: add exercise 18 — CSI snapshots`. Exercise 18 is now CRI-dockerd Setup. Stale.

### Fact-wrong "What tripped me up" anecdote
- `exercises/20-pod-security-standards/README.md:43-49`
- Quote: `It failed immediately with "Pod rejected by Pod Security Policy" error. But my pod was already created! ... The pod appears in 'k get pods' as "Pending" with a reason "Pod Security Policy violation"`.
- **Problem:** PSS rejects at admission — there is no cache artifact, no Pending pod, no "Pod Security Policy violation" reason. The pod simply isn't created. This anecdote teaches a wrong mental model.

### Skeleton placeholder uppercase `NAME`
- `skeletons/serviceaccount.yaml:4` uses `name: NAME`.
- **Problem:** Will fail RFC 1123 validation. Inconsistent with other skeletons that use `my-pv`, `my-config` etc.
- **Fix:** `name: my-sa`.

### CI only validates `skeletons/`, not `exercises/` and not fenced YAML
- `.github/workflows/validate.yml:29-44` lints `skeletons/` only.
- Inline YAML inside `exercises/*/README.md` and `mock-exams/*.md` is never validated. `scripts/validate-local.sh:21` walks both directories but only finds standalone `.yaml` files, never the fenced blocks where exercise solutions actually live.
- **Fix:** Add a step that extracts fenced YAML blocks (e.g. small Python script with `mistune` + `yaml.safe_load_all`) and runs `kubectl --dry-run=client -f -` on each. This would have caught the CRI-dockerd flag bug, the PSS error string, and the missing skeleton.

### `TEMPLATES.md` (752 lines) duplicates `skeletons/*.yaml` with no drift guard
- `TEMPLATES.md` and `skeletons/*.yaml`
- `skeletons/README.md:1-7` says TEMPLATES.md is the canonical browse-friendly version. No automation enforces equivalence.
- **Fix:** Generate `TEMPLATES.md` from `skeletons/*.yaml` at CI time, or delete it and link to `skeletons/`.

### CI workflow doesn't pin yamllint
- `.github/workflows/validate.yml:27` — `pip install yamllint` (no version). A new yamllint release that tightens rules will break CI on a green PR.
- **Fix:** Pin to a specific version.

### CI workflow `paths:` filter excludes markdown
- `.github/workflows/validate.yml:5-17` — Markdown changes (the bulk of this repo) skip CI. Broken anchors and bad fenced YAML are invisible.
- **Fix:** Add `'**.md'` (or remove the filter) and add a markdown-link checker.

## Security Example Hygiene

> The repo teaches CKA, not CKS — some "insecure" patterns (hostPath PVs, default SA, secrets in env) are unavoidable. The concern is whether they are clearly labelled as exam scaffolding.

### `Secret` skeleton uses literal credentials with no callout
- `skeletons/configmap-secret.yaml:14-20` — `stringData: DB_PASS: changeme`. No "do not commit real credentials this way; use ExternalSecrets / SealedSecrets / CSI Secret Store in production" comment.
- **Fix:** Add a one-line comment.

### Privileged pods used as counter-examples without a "for learning only" banner
- `mock-exams/MOCK-EXAM-02-SOLUTIONS.md:621` — Solution 13 builds a pod with `securityContext: privileged: true`.
- `mock-exams/MOCK-EXAM-01.md:166` — explicitly says "Test by deploying a pod with `privileged: true`."
- `exercises/20-pod-security-standards/README.md:24,71` — uses `--privileged` to demonstrate rejection.
- **Problem:** Pedagogically fine but no banner. A learner copy-pasting may not register that this is a counter-example.
- **Fix:** Add a uniform banner: `# Educational counter-example. NEVER deploy a privileged pod to production without a documented threat model and PSS exemption.`

### `daemonset.yaml` skeleton mounts `/var/log` with no warning
- `skeletons/daemonset.yaml:31-36` — `hostPath: /var/log` is the standard fluentd pattern, but a learner might generalise to `hostPath: /`.
- **Fix:** Add a comment about narrowing host paths.

### Default ServiceAccount usage everywhere
- Most exercises (01, 02, 03, 05, 06, 19, 21 etc.) create pods/Deployments without `serviceAccountName`, defaulting to the `default` SA with auto-mounted token. RBAC ex-04 is the only one that creates a dedicated SA.
- **Fix:** Add a "Production note: in real workloads, set `automountServiceAccountToken: false` and use a dedicated SA" line at the top of `exercises/README.md`.

### `hostPath` PVs everywhere, no node-pinning
- `skeletons/pv.yaml:13-14`, `exercises/12-storage-pv-pvc/README.md:14,89`, `mock-exams/MOCK-EXAM-01-SOLUTIONS.md:325`, `README.md:909,1316,2300,2600,3447`
- **Problem:** hostPath PVs without `nodeAffinity` are correct on single-node minikube/kind but break silently on multi-node clusters. No exercise calls this out — a footgun on the actual exam.
- **Fix:** Update `skeletons/pv.yaml` with a commented-out `nodeAffinity:` block and a note about multi-node behaviour.

## Script Fragility

### `scripts/exam-setup.sh` — bash-only, Linux-assumed, non-idempotent
- `scripts/exam-setup.sh:1-46`
- **Problems:**
  1. Must be `source`d to make aliases stick. Most learners run `bash scripts/exam-setup.sh`, which sets aliases in a subshell that immediately exits. No "source me" warning.
  2. `cat <<'EOF' >> ~/.vimrc` (lines 29-35) is non-idempotent — running the script N times appends N copies. Practising for 4 weeks → many duplicates in `.vimrc`.
  3. `source <(kubectl completion bash)` (line 25) errors out and dumps source code if `kubectl` is missing.
  4. `alias d='docker'`, `alias de='docker exec'` (lines 19-20) — Docker isn't on the CKA exam (use `crictl` against containerd). Misleading.
  5. macOS bash 3.2 + missing bash-completion will silently no-op the `complete` line.
- **Fix:** Wrap vimrc append in a `grep -q` sentinel guard; print "source me, don't run me" detection; replace `d`/`de` with `crictl` aliases.

### `scripts/validate-local.sh` — assumes Python 3 and GNU find
- `scripts/validate-local.sh:6,29`
- **Problems:**
  1. `python3` hard requirement; on default Windows it's `python` or `py`.
  2. `find -print0` + `read -d ''` works on GNU find / macOS BSD; can choke on Windows MSYS / Git-bash.
  3. Embedded shell-quoted Python `python3 -c "import yaml, sys; list(yaml.safe_load_all(open('$f')))"` will fail opaquely if `$f` ever contains a single quote.
- **Fix:** Pass `$f` as `argv` instead of interpolating into the Python source.

### Install snippets assume Debian/Ubuntu apt
- `exercises/26-cri-dockerd-setup/README.md:87-90`, `cheatsheet/cka-cheatsheet.md:125,130`, `README.md:1522,1533,1548-1549`
- All install snippets use `apt-get` / `dpkg`. Defensible (CKA exam is Ubuntu 22.04) but the repo doesn't say so. Local Fedora/Rocky learners will hit confusing errors.
- **Fix:** One-line note in `exercises/README.md`: "Practice on Ubuntu 22.04 to match the exam VM."

### `kubeadm-flags.env` / `/etc/default/kubelet` not mentioned anywhere
- The cri-dockerd exercises and any kubelet-config troubleshooting reference `/etc/kubernetes/kubelet.conf` (kubeconfig) when the actual file for kubelet runtime args is `/var/lib/kubelet/kubeadm-flags.env`. Recurring confusion across `exercises/26-cri-dockerd-setup/README.md:114` and `exercises/05-networkpolicy/README.md:72`.
- **Fix:** Add a small reference table in `cheatsheet/cka-cheatsheet.md` mapping every kubeadm config file to its purpose.

## Other

### "v2.0" referenced but no release/tag exists
- `exercises/README.md:7` mentions "New in v2.0." `CHANGELOG.md` only goes up to `[1.1.0]`. No `v2.0.0` tag.
- **Fix:** Tag a v2.0.0 release or remove the v2.0 reference.

### "Not real exam questions" disclaimer not present in mock-exam files
- `README.md:11`, `SECURITY.md:7`, `CONTRIBUTING.md:35` all carry the disclaimer. `mock-exams/MOCK-EXAM-01.md`, `mock-exams/MOCK-EXAM-02.md` and the solution files do not.
- **Fix:** Add a 3-line "These are independently designed practice questions, not actual CKA exam content. Sharing real exam content violates CNCF policy" block at the top of every mock-exam markdown file.

### `troubleshooting/README.md` jump-link block has 16 anchors — needs a link audit
- `troubleshooting/README.md:5`. Anchors are sensitive to heading punctuation; manual or `markdown-link-check` audit recommended.

### `README.md` is 3889 lines
- A single very large entry point file is intimidating to update and merge-conflict-prone. Sections like `kubectl Cheat Sheet` (already mirrored in `cheatsheet/cka-cheatsheet.md`) and `Troubleshooting Decision Flowchart` (already in `troubleshooting/`) duplicate content.
- **Fix:** Slim root README to a curriculum overview + entrypoint.

## Summary of Highest-Priority Fixes

1. Wrong PSS error string in ex-20 + mock-exam-01.
2. Fictional pod-level PSS exemption label in mock-exam-02 Solution 13.
3. Removed `--container-runtime=remote` flag in ex-26 / ex-18 (and wrong file path `/etc/kubernetes/kubelet.conf`).
4. Duplicate ex-18 / ex-26.
5. Missing `skeletons/priorityclass.yaml` referenced by ex-24.
6. Domain cross-link 404s across ex-19, ex-26, ex-27, ex-29, ex-30, ex-31.
7. CI doesn't validate exercise-embedded YAML.
8. `exam-setup.sh` non-idempotent vimrc append + missing "source me" guard.
9. Image-version inconsistency across the repo (nginx 1.27/1.28, busybox 1.36/1.37).
10. `kubeadm` apt pins use unstable `-1.1` Debian revision.
