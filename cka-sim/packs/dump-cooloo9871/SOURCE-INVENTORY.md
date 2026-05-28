# dump-cooloo9871 Source Inventory

Source: https://cooloo9871.github.io/cka/

This inventory maps source topics to independently authored simulator drills. It records adaptation intent only; it does not copy source answers.

| Source | Phase | Requirement | Question ID | Runtime Path | Domain | v1.35 Adaptation |
|--------|-------|-------------|-------------|--------------|--------|------------------|
| source-q01 | 25 | CMD-01 | dump-q01-contexts | `01-source-q01-contexts` | cluster-architecture | Command or inspection task stores derived answer in live ConfigMap state, avoiding answer files and stale multi-context assumptions. |
| source-q02 | 27 | OPS-01 | dump-q02-control-plane-scheduling | `02-source-q02-control-plane-scheduling` | workloads-scheduling | Host or control-plane behavior is converted to reversible lab-safe state while preserving the operational skill being practiced. |
| source-q03 | 26 | OBJ-01 | dump-q03-statefulset-scale | `03-source-q03-statefulset-scale` | workloads-scheduling | Object-authoring task grades Kubernetes API state directly and uses baseline-aware authored/change checks. |
| source-q04 | 27 | OPS-02 | dump-q04-readiness-service | `04-source-q04-readiness-service` | services-networking | Host or control-plane behavior is converted to reversible lab-safe state while preserving the operational skill being practiced. |
| source-q05 | 25 | CMD-02 | dump-q05-pod-sorting | `05-source-q05-pod-sorting` | cluster-architecture | Command or inspection task stores derived answer in live ConfigMap state, avoiding answer files and stale multi-context assumptions. |
| source-q06 | 26 | OBJ-02 | dump-q06-pv-pvc-pod-volume | `06-source-q06-pv-pvc-pod-volume` | storage | Object-authoring task grades Kubernetes API state directly and uses baseline-aware authored/change checks. |
| source-q07 | 25 | CMD-03 | dump-q07-resource-usage | `07-source-q07-resource-usage` | cluster-architecture | Command or inspection task stores derived answer in live ConfigMap state, avoiding answer files and stale multi-context assumptions. |
| source-q08 | 25 | CMD-04 | dump-q08-control-plane-info | `08-source-q08-control-plane-info` | cluster-architecture | Command or inspection task stores derived answer in live ConfigMap state, avoiding answer files and stale multi-context assumptions. |
| source-q09 | 27 | OPS-03 | dump-q09-manual-scheduling | `09-source-q09-manual-scheduling` | workloads-scheduling | Host or control-plane behavior is converted to reversible lab-safe state while preserving the operational skill being practiced. |
| source-q10 | 26 | OBJ-03 | dump-q10-rbac-serviceaccount | `10-source-q10-rbac-serviceaccount` | cluster-architecture | Object-authoring task grades Kubernetes API state directly and uses baseline-aware authored/change checks. |
| source-q11 | 26 | OBJ-04 | dump-q11-daemonset-all-nodes | `11-source-q11-daemonset-all-nodes` | workloads-scheduling | Object-authoring task grades Kubernetes API state directly and uses baseline-aware authored/change checks. |
| source-q12 | 26 | OBJ-05 | dump-q12-deployment-topology | `12-source-q12-deployment-topology` | workloads-scheduling | Object-authoring task grades Kubernetes API state directly and uses baseline-aware authored/change checks. |
| source-q13 | 26 | OBJ-06 | dump-q13-multicontainer-volume | `13-source-q13-multicontainer-volume` | workloads-scheduling | Object-authoring task grades Kubernetes API state directly and uses baseline-aware authored/change checks. |
| source-q14 | 25 | CMD-05 | dump-q14-cluster-info | `14-source-q14-cluster-info` | cluster-architecture | Command or inspection task stores derived answer in live ConfigMap state, avoiding answer files and stale multi-context assumptions. |
| source-q15 | 25 | CMD-06 | dump-q15-cluster-events | `15-source-q15-cluster-events` | troubleshooting | Command or inspection task stores derived answer in live ConfigMap state, avoiding answer files and stale multi-context assumptions. |
| source-q16 | 25 | CMD-07 | dump-q16-api-resources | `16-source-q16-api-resources` | cluster-architecture | Command or inspection task stores derived answer in live ConfigMap state, avoiding answer files and stale multi-context assumptions. |
| source-q17 | 27 | OPS-04 | dump-q17-container-inspection | `17-source-q17-container-inspection` | troubleshooting | Host or control-plane behavior is converted to reversible lab-safe state while preserving the operational skill being practiced. |
| source-q18 | 27 | OPS-05 | dump-q18-kubelet-repair | `18-source-q18-kubelet-repair` | cluster-architecture | Host or control-plane behavior is converted to reversible lab-safe state while preserving the operational skill being practiced. |
| source-q19 | 26 | OBJ-07 | dump-q19-secret-mount | `19-source-q19-secret-mount` | workloads-scheduling | Object-authoring task grades Kubernetes API state directly and uses baseline-aware authored/change checks. |
| source-q20 | 27 | OPS-06 | dump-q20-upgrade-join-plan | `20-source-q20-upgrade-join-plan` | cluster-architecture | Host or control-plane behavior is converted to reversible lab-safe state while preserving the operational skill being practiced. |
| source-q21 | 27 | OPS-07 | dump-q21-static-pod-service | `21-source-q21-static-pod-service` | workloads-scheduling | Host or control-plane behavior is converted to reversible lab-safe state while preserving the operational skill being practiced. |
| source-q22 | 25 | CMD-08 | dump-q22-apiserver-cert | `22-source-q22-apiserver-cert` | cluster-architecture | Command or inspection task stores derived answer in live ConfigMap state, avoiding answer files and stale multi-context assumptions. |
| source-q23 | 25 | CMD-09 | dump-q23-kubelet-certs | `23-source-q23-kubelet-certs` | cluster-architecture | Command or inspection task stores derived answer in live ConfigMap state, avoiding answer files and stale multi-context assumptions. |
| source-q24 | 26 | OBJ-08 | dump-q24-networkpolicy | `24-source-q24-networkpolicy` | services-networking | Object-authoring task grades Kubernetes API state directly and uses baseline-aware authored/change checks. |
| source-q25 | 27 | OPS-08 | dump-q25-etcd-snapshot | `25-source-q25-etcd-snapshot` | cluster-architecture | Host or control-plane behavior is converted to reversible lab-safe state while preserving the operational skill being practiced. |
| extra-q01 | 27 | OPS-09 | dump-q26-eviction-priority | `26-extra-q01-eviction-priority` | workloads-scheduling | Host or control-plane behavior is converted to reversible lab-safe state while preserving the operational skill being practiced. |
| extra-q02 | 27 | OPS-10 | dump-q27-manual-api-access | `27-extra-q02-manual-api-access` | cluster-architecture | Host or control-plane behavior is converted to reversible lab-safe state while preserving the operational skill being practiced. |
| preview-q01 | 25 | CMD-10 | dump-q28-etcd-certs | `28-preview-q01-etcd-certs` | cluster-architecture | Command or inspection task stores derived answer in live ConfigMap state, avoiding answer files and stale multi-context assumptions. |
| preview-q02 | 26 | OBJ-09 | dump-q29-kube-proxy-service | `29-preview-q02-kube-proxy-service` | services-networking | Object-authoring task grades Kubernetes API state directly and uses baseline-aware authored/change checks. |
| preview-q03 | 26 | OBJ-10 | dump-q30-service-ip-output | `30-preview-q03-service-ip-output` | services-networking | Object-authoring task grades Kubernetes API state directly and uses baseline-aware authored/change checks. |
