# External Integrations

**Analysis Date:** 2026-05-07

This is a study/practice repository — it does not run as a service and does not call external APIs at runtime. "Integrations" here are the third-party container images, Helm charts, operator manifests, documentation links, and CI services referenced by exercises and tooling. They define what an exam-taker downloads or installs while practising.

## APIs & External Services

**Kubernetes API surface (in-cluster, not external):**
- All `skeletons/*.yaml` target the Kubernetes API server directly via `kubectl apply`. Skeleton apiVersions: `v1`, `apps/v1`, `batch/v1`, `autoscaling/v2`, `networking.k8s.io/v1`, `rbac.authorization.k8s.io/v1`, `storage.k8s.io/v1`, `admissionregistration.k8s.io/v1`, `gateway.networking.k8s.io/v1`.
- `https://kubernetes.default.svc` is referenced as the in-cluster API target in `exercises/31-argocd-gitops-setup/README.md:105` (Argo CD `Application.spec.destination.server`).

**Container registries (Docker Hub, implicit):**
- `nginx:1.27`, `nginx:1.28` — used in `skeletons/pod.yaml:10`, `skeletons/deployment.yaml:24`, `skeletons/statefulset.yaml`, `skeletons/daemonset.yaml`, multiple exercise solutions.
- `busybox:1.36`, `busybox:1.37` — used in `skeletons/job.yaml`, `skeletons/cronjob.yaml`, `skeletons/sidecar-init-container.yaml`, and many exercise pods.
- `fluentd:v1.17` — used in `skeletons/sidecar-init-container.yaml` (logging sidecar example).
- No private registry, no `imagePullSecrets`, no SDK clients — these are pulled directly by the cluster's container runtime.

**GitHub releases API:**
- `https://api.github.com/repos/Mirantis/cri-dockerd/releases/latest` — queried in `exercises/18-cri-dockerd-setup/README.md:112` and `exercises/26-cri-dockerd-setup/README.md` to discover the latest CRI-dockerd version. No auth token required (anonymous public API).

**Argo CD example app source:**
- `https://github.com/argoproj/argocd-example-apps.git` — used as the upstream Git source for the GitOps Application demo in `exercises/31-argocd-gitops-setup/README.md:101` (path `guestbook`).

## Data Storage

**Databases:**
- None used by the repo itself.
- Exercises exercise Kubernetes-native storage abstractions (no managed DB):
  - PV / PVC / StorageClass — `skeletons/pv.yaml`, `skeletons/pvc.yaml`, `skeletons/storageclass.yaml`, `exercises/12-storage-pv-pvc/`, `exercises/25-storage-waitforfirstconsumer/`.
  - `hostPath` is the only volume backend in skeletons (`skeletons/pv.yaml:13-14`, path `/data/my-pv`).

**File Storage:**
- Local filesystem only. No S3/GCS/Azure Blob. `hostPath` PVs reference the node-local filesystem.

**Caching:**
- None.

**etcd (referenced as a cluster component, not as application storage):**
- `https://127.0.0.1:2379` and `https://10.0.0.5:2379` referenced in `exercises/29-troubleshoot-etcd-endpoint/README.md` for `etcdctl` snapshot/restore against the cluster's own etcd.
- `scripts/exam-setup.sh:38` exports `ETCDCTL_API=3`.

## Authentication & Identity

**Auth Provider:**
- None at the repo level.
- Kubernetes-native auth concepts are exercised:
  - ServiceAccounts (`skeletons/serviceaccount.yaml`).
  - RBAC: Role/RoleBinding (`skeletons/rbac.yaml`), ClusterRole (`skeletons/clusterrole.yaml`), used by `exercises/04-rbac/`.
  - TLS / certificate rotation in `exercises/30-tls-configuration-update/`.
  - Argo CD initial admin secret retrieved via `kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d` in `exercises/31-argocd-gitops-setup/README.md:131`.

## Monitoring & Observability

**Error Tracking:**
- None.

**Logs:**
- Reviewed via `kubectl logs`, `journalctl -u kubelet`, `journalctl -u cri-docker.service` — see `troubleshooting/README.md` and `exercises/11-troubleshoot-cluster/`.
- Sample logging sidecar: `skeletons/sidecar-init-container.yaml` uses `fluentd:v1.17`.
- Metrics-server / HPA referenced in `exercises/16-hpa/` and `skeletons/hpa.yaml` (no external monitoring backend).

## CI/CD & Deployment

**Hosting:**
- Source hosted on GitHub: `https://github.com/theplatformlab/CKA-Certified-Kubernetes-Administrator` (badges in `README.md:1-9`).
- No deployment target — this is a documentation repo.

**CI Pipeline:**
- **GitHub Actions** — single workflow at `.github/workflows/validate.yml`.
  - Trigger: `push` and `pull_request` on `main`, only when `skeletons/**`, `exercises/**`, or any `*.yaml`/`*.yml` file changes.
  - Runner: `ubuntu-latest`.
  - Steps:
    1. `actions/checkout@v4` (only third-party action).
    2. `pip install yamllint`.
    3. `yamllint` against `skeletons/` with the inline rule overrides from `validate.yml:31`.
    4. Python `yaml.safe_load_all` parse loop over `skeletons/*.yaml` (`validate.yml:36-49`).
- Status badge: `https://github.com/theplatformlab/CKA-Certified-Kubernetes-Administrator/actions/workflows/validate.yml/badge.svg` (linked from `README.md:3`).

**Local CI mirror:**
- `scripts/validate-local.sh` reproduces the workflow logic over `skeletons/` and `exercises/`. Optional `yamllint` if available locally.

## Environment Configuration

**Required env vars:** None for the repo. Practice scripts export:
- `do=--dry-run=client -o yaml` (`scripts/exam-setup.sh:21`).
- `now=--force --grace-period=0` (`scripts/exam-setup.sh:22`).
- `ETCDCTL_API=3` (`scripts/exam-setup.sh:38`).

**Secrets location:**
- None. No `.env*` file is present, and no credential is committed. `.gitignore` does not list `.env*` explicitly; this is acceptable because nothing in the repo writes one.

## Webhooks & Callbacks

**Incoming:** None (no service runs from this repo).

**Outgoing:** None at runtime. Exercises do issue outgoing fetches when followed:
- `curl https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml` (`exercises/27-cni-tigera-install/README.md:85`).
- `kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.10.3/manifests/install.yaml` (`exercises/31-argocd-gitops-setup/README.md:84`).
- `wget https://github.com/Mirantis/cri-dockerd/releases/download/v${VER}/cri-dockerd-${VER}.amd64.tgz` (`exercises/18-cri-dockerd-setup/README.md:115`).

## Helm Repositories

- **Bitnami** — added by `exercises/13-helm-install-upgrade/README.md:66`:
  ```bash
  helm repo add bitnami https://charts.bitnami.com/bitnami
  helm install web bitnami/nginx -n exercise-13 --create-namespace --set replicaCount=2
  ```
  Only chart used: `bitnami/nginx`.

## Cluster Add-ons Installed by Exercises

| Add-on | Source | Exercise |
|--------|--------|----------|
| Tigera Operator (Calico CNI) | `https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml` | `exercises/27-cni-tigera-install/README.md:85` |
| Calico Installation CR | inline `apiVersion: operator.tigera.io/v1` manifest | `exercises/27-cni-tigera-install/README.md:94-109` |
| Argo CD v2.10.3 | `https://raw.githubusercontent.com/argoproj/argo-cd/v2.10.3/manifests/install.yaml` | `exercises/31-argocd-gitops-setup/README.md:84` |
| CRI-dockerd | `https://github.com/Mirantis/cri-dockerd/releases` | `exercises/18-cri-dockerd-setup/README.md`, `exercises/26-cri-dockerd-setup/README.md` |
| Bitnami NGINX (Helm) | `https://charts.bitnami.com/bitnami` | `exercises/13-helm-install-upgrade/README.md:66` |
| Cluster Autoscaler (referenced) | `https://github.com/kubernetes/autoscaler.git` | `README.md` study links |
| (Legacy reference) Calico manifest | `https://docs.projectcalico.org/manifests/calico.yaml` | mentioned in study materials |

## Cloud-Provider Hooks

- None. The repo is cloud-agnostic. No AWS / GCP / Azure SDK or provider-specific manifest is committed.
- Storage examples use `kubernetes.io/no-provisioner` (`skeletons/storageclass.yaml:5`) and `hostPath` PVs — no cloud volume plugin.

## Cloud Native / Documentation References

**Upstream Kubernetes docs (linked from exercises and `README.md`):**
- `https://kubernetes.io/` and `https://kubernetes.io/docs/`
- `https://kubernetes.io/docs/concepts/services-networking/network-policies/`
- `https://kubernetes.io/docs/concepts/services-networking/ingress/`
- `https://kubernetes.io/docs/concepts/services-networking/gateway/`
- `https://kubernetes.io/docs/concepts/storage/persistent-volumes/`
- `https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/`
- `https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/`
- `https://kubernetes.io/docs/concepts/workloads/controllers/job/`
- `https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/`
- `https://kubernetes.io/docs/reference/access-authn-authz/rbac/`
- `https://kubernetes.io/docs/reference/kubectl/cheatsheet/`
- `https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/priority-class-v1/`
- `https://kubernetes.io/docs/setup/production-environment/container-runtimes/`
- `https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/`
- `https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/`
- `https://kubernetes.io/docs/tasks/administer-cluster/coredns/`
- `https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/`
- `https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/`
- `https://kubernetes.io/docs/tasks/configure-pod-container/static-pod/`
- `https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/`
- `https://kubernetes.io/docs/tasks/manage-kubernetes-objects/update-api-object-kubectl-patch/`

**CNCF / vendor:**
- `https://www.cncf.io/certification/cka/` (CKA program page).
- `https://github.com/cncf/curriculum` (CKA curriculum repo).
- `https://docs.linuxfoundation.org/tc-docs/certification/tips-cka-and-ckad`.
- `https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises`.
- `https://argo-cd.readthedocs.io/`, `https://argo-cd.readthedocs.io/en/stable/getting_started/`, `https://argo-cd.readthedocs.io/en/stable/declarative-setup/`.
- `https://github.com/Mirantis/cri-dockerd`, `https://github.com/Mirantis/cri-dockerd/releases`.

**Practice platforms (links only, not integrated):**
- `https://killer.sh` (CKA simulator bundled with the exam).
- `https://killercoda.com/cka`.
- `https://kodekloud.com`.
- `https://www.udemy.com/course/certified-kubernetes-administrator-with-practice-tests/`.
- `https://minikube.sigs.k8s.io/`, `https://kind.sigs.k8s.io/` (local cluster options).

**Author / community:**
- Blog companion: `https://techwithmohamed.com/blog/cka-exam-study-guide/` (`README.md:25`).
- GitHub Discussions: `https://github.com/theplatformlab/CKA-Certified-Kubernetes-Administrator/discussions` (linked from `.github/ISSUE_TEMPLATE/config.yml:4`).
- Shields.io badges (`https://img.shields.io/...`) — `README.md:1-9`.

---

*Integration audit: 2026-05-07*
