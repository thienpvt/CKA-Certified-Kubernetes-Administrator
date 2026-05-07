# Technology Stack

**Analysis Date:** 2026-05-07

This repository is a CKA (Certified Kubernetes Administrator) study and practice resource. It is **not a traditional application** — there is no compiled code, no package manifest (`package.json`/`go.mod`/`Cargo.toml`/`pyproject.toml`), and no production runtime. The "stack" is the set of formats, CLIs, and Kubernetes APIs that the exercises, skeletons, mock exams, and helper scripts target.

## Languages

**Primary:**
- **YAML** — Kubernetes manifests in `skeletons/*.yaml` (23 files) and embedded in fenced code blocks across `exercises/`, `mock-exams/`, `troubleshooting/`, and `TEMPLATES.md`. Standard `apiVersion` set in skeletons:
  - `v1` (core), `apps/v1`, `batch/v1`, `autoscaling/v2`
  - `networking.k8s.io/v1`, `rbac.authorization.k8s.io/v1`, `storage.k8s.io/v1`
  - `admissionregistration.k8s.io/v1`, `gateway.networking.k8s.io/v1`
- **Bash** — helper scripts under `scripts/` (`exam-setup.sh`, `validate-local.sh`) and command snippets throughout exercise/cheatsheet/troubleshooting documentation. Line-ending policy enforced via `.gitattributes` (`*.sh text eol=lf`).
- **Markdown** — primary content format. Major docs: `README.md` (3889 lines), `TEMPLATES.md` (752 lines), `troubleshooting/README.md` (392 lines), `cheatsheet/cka-cheatsheet.md` (316 lines), 31 exercise READMEs, 4 mock-exam files, contributing/security/code-of-conduct/changelog.

**Secondary:**
- **Python** — invoked only for YAML syntax validation (`python3 -c "import yaml; yaml.safe_load_all(...)"`) in `scripts/validate-local.sh:29` and `.github/workflows/validate.yml:38`. No Python source in repo.
- **Kubernetes CEL** — appears in `skeletons/validatingadmissionpolicy.yaml:13` (`expression: "object.spec.replicas <= 10"`).
- **Go template / JSONPath** — used inline in `kubectl ... -o jsonpath='...'` snippets across exercise solutions.

## Runtime

**Environment:**
- **Target cluster Kubernetes version:** v1.35 (declared in `README.md:5,162` and `assets/cka.png` badge).
- **Exam OS:** Ubuntu Linux terminal (per `README.md:170`); scripts assume a POSIX shell with bash.
- **Local dev shell:** bash (Linux/macOS) or Git Bash on Windows. `.gitattributes` normalises shell scripts to LF.

**Package Manager:**
- **None for application code.** No lockfile.
- `pip install yamllint` is used ad hoc in CI (`.github/workflows/validate.yml:27`) and as an optional local dev tool (`scripts/validate-local.sh:42`).

## Frameworks

There is no application framework. The "frameworks" here are the Kubernetes APIs and operational tools the curriculum exercises.

**Kubernetes APIs exercised (skeleton coverage in `skeletons/`):**
- Core workloads: Pod (`pod.yaml`), Deployment (`deployment.yaml`), StatefulSet (`statefulset.yaml`), DaemonSet (`daemonset.yaml`), Job (`job.yaml`), CronJob (`cronjob.yaml`), sidecar/init containers (`sidecar-init-container.yaml`).
- Config & identity: ConfigMap + Secret (`configmap-secret.yaml`), ServiceAccount (`serviceaccount.yaml`), Role/RoleBinding (`rbac.yaml`), ClusterRole (`clusterrole.yaml`).
- Networking: Service (`service.yaml`), Ingress (`ingress.yaml`), NetworkPolicy (`networkpolicy.yaml`), Gateway + HTTPRoute (`gateway-api.yaml`).
- Storage: PV (`pv.yaml`), PVC (`pvc.yaml`), StorageClass (`storageclass.yaml`).
- Scheduling/limits: HPA (`hpa.yaml`), ResourceQuota (`resourcequota.yaml`), LimitRange (`limitrange.yaml`), SecurityContext (`securitycontext.yaml`).
- Policy: ValidatingAdmissionPolicy + Binding (`validatingadmissionpolicy.yaml`).

**Testing:**
- No application test framework. "Testing" = YAML lint + parse:
  - `yamllint` (extends `default` with overrides; see `.github/workflows/validate.yml:31`).
  - `python3 yaml.safe_load_all` (`scripts/validate-local.sh:29`, `.github/workflows/validate.yml:38`).
- Mock exams (`mock-exams/MOCK-EXAM-01.md`, `mock-exams/MOCK-EXAM-02.md`) act as integration "tests" the user runs against a live cluster.

**Build/Dev:**
- No build system. Content is consumed as-is.
- Local pre-push validator: `scripts/validate-local.sh`.
- CI lint job: `.github/workflows/validate.yml` (`yamllint` + Python parse on every push/PR touching YAML).

## Key Dependencies

There are no language-level dependencies. The runtime dependencies are CLIs that an exam-taker is expected to have installed on the target node/cluster.

**CLIs the exercises drive (counted via `grep` across `exercises/`, `scripts/`, `cheatsheet/`, `troubleshooting/`, `mock-exams/`):**

| Tool | Approx. references | Purpose | Where it appears |
|------|---------------------|---------|------------------|
| `kubectl` (also aliased `k`) | 60+ | Primary cluster CLI | All exercises, `cheatsheet/cka-cheatsheet.md`, `scripts/exam-setup.sh:7` |
| `kubelet` | 60+ | Node agent — troubleshooting | `troubleshooting/README.md`, `exercises/11-troubleshoot-cluster/`, `exercises/29-troubleshoot-etcd-endpoint/` |
| `systemctl` | 48 | Service management on nodes | `exercises/18-cri-dockerd-setup/`, `exercises/26-cri-dockerd-setup/`, `exercises/30-tls-configuration-update/` |
| `kubeadm` | 38 | Cluster bootstrap/upgrade | `exercises/09-kubeadm-upgrade/`, `exercises/27-cni-tigera-install/` |
| `helm` | 31 | Package manager | `exercises/13-helm-install-upgrade/` |
| `journalctl` | 18 | Reading systemd logs | troubleshooting exercises |
| `cri-dockerd` | 13 | Docker CRI shim | `exercises/18-cri-dockerd-setup/`, `exercises/26-cri-dockerd-setup/` |
| `kube-proxy` | 11 | Service networking | troubleshooting exercises |
| `crictl` | 7 | CRI debugging | `exercises/18-cri-dockerd-setup/README.md:64`, troubleshooting docs |
| `argocd` | 7 | GitOps | `exercises/31-argocd-gitops-setup/` |
| `etcdctl` | 6 | etcd backup/restore | `exercises/29-troubleshoot-etcd-endpoint/`, `scripts/exam-setup.sh:38` (`ETCDCTL_API=3`) |
| `docker` | 5 | Container runtime | `exercises/18-cri-dockerd-setup/`, `scripts/exam-setup.sh:18` |
| `kustomize` (via `kubectl -k`) | 4 | Overlay config | `exercises/14-kustomize-overlays/` |
| `containerd` | 1 | Default CRI | `exercises/18-cri-dockerd-setup/` |

**Container images referenced in YAML (`grep "image:"` across `skeletons/` and `exercises/`):**
- `nginx:1.27`, `nginx:1.28`
- `busybox:1.36`, `busybox:1.37`
- `fluentd:v1.17`

**Critical infra components installed by exercises (not bundled in repo):**
- **Calico via Tigera Operator** (`exercises/27-cni-tigera-install/README.md:85`) — `https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml`.
- **Argo CD v2.10.3** (`exercises/31-argocd-gitops-setup/README.md:84`) — `https://raw.githubusercontent.com/argoproj/argo-cd/v2.10.3/manifests/install.yaml`.
- **Bitnami NGINX Helm chart** (`exercises/13-helm-install-upgrade/README.md:66`) — `https://charts.bitnami.com/bitnami`.
- **CRI-dockerd from Mirantis GitHub releases** (`exercises/18-cri-dockerd-setup/README.md:115`).

## Configuration

**Environment:**
- No `.env` files. No secrets stored in repo.
- Shell-level config exported by `scripts/exam-setup.sh`:
  - `do=--dry-run=client -o yaml` (line 21)
  - `now=--force --grace-period=0` (line 22)
  - `ETCDCTL_API=3` (line 38)
- Aliases set up by `scripts/exam-setup.sh:7-19`: `k`, `kg`, `kn`, `kgp`, `kgs`, `kgn`, `kd`, `kaf`, `kdel`, `ll`, `d`, `de`.
- vim config appended to `~/.vimrc` by `scripts/exam-setup.sh:29-35` (`expandtab`, `tabstop=2`, `shiftwidth=2`, `number`, `autoindent`).

**Build / Lint config:**
- `.github/workflows/validate.yml` — inline `yamllint` config (`extends: default`, `line-length.max: 200`, `truthy: disable`, `document-start: disable`, `comments-indentation: disable`, `indentation.indent-sequences: whatever`, `new-lines.type: platform`).
- `scripts/validate-local.sh:46` — same yamllint config minus `new-lines`.
- `.gitattributes` — `* text=auto eol=lf`, `*.sh text eol=lf`, `*.bat/*.cmd text eol=crlf`, image files marked `binary`.
- `.gitignore` — covers OS files, editor state (`.vscode/`, `.idea/`, `*.iml`), Node (`node_modules/`), Python (`__pycache__/`, `.venv/`), and Terraform state. There is no source for any of those — they are precautionary.

**Issue / PR templates:**
- `.github/ISSUE_TEMPLATE/bug-report.md`, `content-request.md`, `exam-feedback.md`, `config.yml` (links to GitHub Discussions; `blank_issues_enabled: false`).
- `.github/PULL_REQUEST_TEMPLATE.md`.

## Platform Requirements

**Development (for contributors editing the repo):**
- `git` and a Markdown/YAML-aware editor.
- Optional: `python3` with PyYAML, `yamllint` (`pip install yamllint`) — required to run `scripts/validate-local.sh` cleanly.
- Bash (Git Bash on Windows is fine; LF line endings are enforced).

**Practice / Exam runtime (for users working through exercises):**
- A working Kubernetes v1.35 cluster — minikube, kind, or kubeadm-built (`README.md:5`, exercise 09 and 27 assume kubeadm).
- `kubectl` matching cluster minor version, plus `helm`, `kustomize` (built into kubectl), `etcdctl`, `crictl`, `kubeadm`, `argocd` per exercise.
- `curl`, `wget`, `tar`, `systemctl`, `journalctl`, `modprobe`, `sysctl`, `apt-get` for node-prep exercises (18, 26, 30).
- Internet access to pull container images, Helm charts, and operator manifests listed in `INTEGRATIONS.md`.

**Production:**
- Not applicable — repo is study material, not deployable software.

---

*Stack analysis: 2026-05-07*
