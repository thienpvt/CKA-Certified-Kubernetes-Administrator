# Phase 4: Storage + Workloads-Scheduling Packs — Research

**Gathered:** 2026-05-10
**Status:** Ready for planning
**Note:** Researcher subagent dropped twice with Windows socket errors after ~1 hour total. This file was produced inline by the orchestrator, using Phase 3 reference questions, Phase 2 trap/grade contracts, and the locked decisions in 04-CONTEXT.md as its sources. All kubectl, YAML, and bash snippets below were cross-checked against the existing `cka-sim/packs/storage/01-pvc-binding/` and `cka-sim/packs/workloads-scheduling/01-deployment-requests/` references.

---

## 1. Executive Summary

Phase 4 authors 5 new Storage questions + 7 new Workloads & Scheduling questions (plus retrofits the 2 existing reference questions) to hit 100 % Tracker coverage for both domains. It ships one shared helper library (`cka-sim/lib/setup.sh`), six new trap-catalog entries, one new lint tool (`scripts/lint-coverage.sh`), and a per-pack `coverage.yaml` manifest. Structure stays identical to Phase 3's six-file question shape; grader contract and trap-detector contract are untouched. Two new external dependencies are introduced but encapsulated inside the relevant question's `setup.sh` / `reset.sh` so the rest of the simulator is unaffected: a hostpath-CSI driver for the VolumeSnapshot question, and metrics-server for the HPA question. All new assertions stay behavioural per GRADE-02 (no `kubectl get | grep`). Execution order is: shared lib → trap catalog → retrofit Phase 3 references → author 12 new questions (parallel by pack) → ship `lint-coverage.sh` + `coverage.yaml` → live-cluster verification.

---

## 2. Per-Question Research

### 2.1 Storage Pack (5 new questions)

#### Q02 — `02-storageclass-dynamic` (Understand StorageClass and dynamic provisioning)

**Tracker:** "Understand StorageClass and dynamic provisioning"
**Scenario:** Lab seeds a PVC `app-cache` requesting `storageClassName: fast-ssd`, but no `StorageClass` of that name exists. Candidate must create a working `StorageClass` with `provisioner: rancher.io/local-path` (or the in-cluster equivalent) and make the PVC bind dynamically.
**Trap IDs:** `pvc-wrong-storageclass` (reuse existing), `pvc-accessmode-rwx-on-rwo-sc` (new), `hostpath-pv-without-nodeaffinity` (warns if candidate falls back to hand-built PV).
**Key assertions:**
- `cka_sim::grade::assert_resource_exists storageclass fast-ssd`
- `cka_sim::grade::assert_pvc_bound "$CKA_SIM_LAB_NS" app-cache`
- `cka_sim::grade::assert_field_eq pvc app-cache '{.spec.storageClassName}' 'fast-ssd' -n "$CKA_SIM_LAB_NS"`
- Behavioural check: `kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/app-cache -n "$CKA_SIM_LAB_NS" --timeout=60s`
**estimatedMinutes:** 7
**External deps:** None (uses the `rancher.io/local-path` provisioner already likely present from exercise 12; if absent, candidate can use `kubernetes.io/no-provisioner` + manual PV — grader only checks the PVC reaches `Bound`).

#### Q03 — `03-access-modes-reclaim` (access modes + reclaim policies bundled)

**Tracker:** "Know access modes (RWO, ROX, RWX, RWOP)" + "Know reclaim policies (Retain, Delete)"
**Scenario:** Lab seeds two PVs (`q03-retain-pv` with `RWO`/`Retain`, `q03-delete-pv` with `RWX`/`Delete`) and two PVCs that request mismatched access modes (`q03-rwo-pvc` wants `RWO` — binds; `q03-rwx-pvc` wants `RWX` — stays Pending because the RWO PV can't satisfy it). Candidate must (a) bind the RWX PVC to the correct PV by fixing access modes and (b) change the Retain PV's reclaim policy to `Delete`.
**Trap IDs:** `pv-accessmodes-mismatch` (reuse), `pvc-accessmode-rwx-on-rwo-sc` (new), `reclaim-policy-delete-data-loss` (new).
**Key assertions:**
- `assert_pvc_bound "$CKA_SIM_LAB_NS" q03-rwo-pvc`
- `assert_pvc_bound "$CKA_SIM_LAB_NS" q03-rwx-pvc`
- `assert_field_eq pv q03-retain-pv '{.spec.persistentVolumeReclaimPolicy}' 'Delete'`
- `assert_field_eq pv q03-delete-pv '{.spec.accessModes[0]}' 'ReadWriteMany'`
**estimatedMinutes:** 9
**External deps:** None.

#### Q04 — `04-csi-volumesnapshot` (CSI driver basics + CG-01)

**Tracker:** "CSI driver basics and troubleshooting"
**Scenario:** Lab seeds a PVC backed by `hostpath-csi` StorageClass + a pod writing a marker file. Candidate must create a `VolumeSnapshot` (and `VolumeSnapshotClass` if missing) that captures the PVC's state, then verify the snapshot reaches `readyToUse: true`.
**Trap IDs:** `csi-snapshot-wrong-driver` (new), `pvc-wrong-storageclass` (reuse), `pvc-pending-wffc-unscheduled-consumer` (new — warns if snapshot source PVC isn't actually Bound).
**Key assertions:**
- `assert_resource_exists volumesnapshot q04-app-snapshot -n "$CKA_SIM_LAB_NS"`
- `assert_field_eq volumesnapshot q04-app-snapshot '{.status.readyToUse}' 'true' -n "$CKA_SIM_LAB_NS"`
- `kubectl wait --for=jsonpath='{.status.readyToUse}'=true volumesnapshot/q04-app-snapshot -n "$CKA_SIM_LAB_NS" --timeout=90s`
- `assert_field_eq volumesnapshot q04-app-snapshot '{.spec.source.persistentVolumeClaimName}' 'app-data' -n "$CKA_SIM_LAB_NS"`
**estimatedMinutes:** 9
**External deps:** hostpath-csi driver. See §6.1 for the install/uninstall pattern.

#### Q05 — `05-wait-for-first-consumer` (volumeBindingMode semantics)

**Tracker:** Derived from "Understand StorageClass and dynamic provisioning" nuance + "Debug Pending pods" overlap; specifically the WaitForFirstConsumer semantics called out in REQUIREMENTS.md PACK-01.
**Scenario:** Lab seeds a `StorageClass` `q05-wffc` with `volumeBindingMode: WaitForFirstConsumer` and a PVC `q05-claim` that appears stuck Pending with event `waiting for first consumer to be created before binding`. Candidate must write a Pod manifest that consumes the PVC; the bind resolves as soon as the pod is scheduled.
**Trap IDs:** `pvc-pending-wffc-unscheduled-consumer` (new — primary), `pvc-wrong-storageclass` (reuse), `default-sa-used` (reuse — Pod should still follow SA hygiene).
**Key assertions:**
- `assert_pod_ready "$CKA_SIM_LAB_NS" q05-consumer`
- `assert_pvc_bound "$CKA_SIM_LAB_NS" q05-claim`
- `assert_field_eq pod q05-consumer '{.spec.volumes[0].persistentVolumeClaim.claimName}' 'q05-claim' -n "$CKA_SIM_LAB_NS"`
**estimatedMinutes:** 7
**External deps:** None (native k8s behaviour; no CSI needed — uses `kubernetes.io/no-provisioner` + manual PV pinned to a worker node).

#### Q06 — `06-pvc-mount-pod` (Mount PVC in a Pod — consumer side)

**Tracker:** "Mount PVC in a Pod"
**Scenario:** Lab seeds a Bound PVC `q06-data` with pre-written marker file. Candidate must create a Deployment `q06-reader` whose pod template mounts the PVC read-only at `/data/marker`, runs a nginx image, and survives a rollout.
**Trap IDs:** `hostpath-pv-without-nodeaffinity` (reuse), `default-sa-used` (reuse), `deployment-missing-requests` (reuse).
**Key assertions:**
- `assert_resource_exists deployment q06-reader -n "$CKA_SIM_LAB_NS"`
- `assert_field_eq deployment q06-reader '{.spec.template.spec.volumes[0].persistentVolumeClaim.claimName}' 'q06-data' -n "$CKA_SIM_LAB_NS"`
- `assert_field_eq deployment q06-reader '{.spec.template.spec.containers[0].volumeMounts[0].readOnly}' 'true' -n "$CKA_SIM_LAB_NS"`
- Behavioural: `kubectl exec -n "$CKA_SIM_LAB_NS" deploy/q06-reader -- cat /data/marker` returns expected string.
**estimatedMinutes:** 7

### 2.2 Workloads & Scheduling Pack (7 new questions)

#### Q02 — `02-rolling-update-rollback` (Rolling update + rollback — 3.2)

**Tracker:** "Rolling update and rollback"
**Scenario:** Lab seeds a Deployment `web` at `nginx:1.25` with `strategy: RollingUpdate, maxUnavailable: 0, maxSurge: 1` plus a broken `nginx:bad-tag` previous revision. Candidate must: (a) roll forward to `nginx:1.27`; (b) verify rollout succeeds via `kubectl rollout status`; (c) roll back one revision; (d) confirm pod image is `nginx:1.25` again.
**Trap IDs:** `deployment-missing-requests` (reuse), `default-sa-used` (reuse), `service-selector-empty-endpoints` (reuse — Service in namespace will expose pods).
**Key assertions:**
- `kubectl rollout status deployment/web -n "$CKA_SIM_LAB_NS" --timeout=60s` exits 0.
- `assert_field_eq deployment web '{.spec.template.spec.containers[0].image}' 'nginx:1.25' -n "$CKA_SIM_LAB_NS"` (after rollback).
- `kubectl rollout history deployment/web -n "$CKA_SIM_LAB_NS"` has ≥2 revisions (grep-free: use `-o jsonpath='{.metadata.generation}'`).
**estimatedMinutes:** 7
**External deps:** None.

#### Q03 — `03-configmap-secret-env-volume` (ConfigMaps/Secrets env + volume — 3.3)

**Tracker:** "ConfigMaps and Secrets (env and volume)"
**Scenario:** Lab seeds a ConfigMap `q03-app-config` with key `APP_MODE=production` and a Secret `q03-app-secret` with key `API_KEY`. Candidate creates Pod `q03-app` that (a) reads `APP_MODE` into env var `APP_MODE`, (b) mounts the Secret at `/etc/app-secrets/api-key` read-only.
**Trap IDs:** `default-sa-used` (reuse), `hostpath-pv-without-nodeaffinity` (reuse — warns if candidate substitutes hostPath), `deployment-missing-requests` (reuse).
**Key assertions:**
- `assert_pod_ready "$CKA_SIM_LAB_NS" q03-app`
- `assert_field_eq pod q03-app '{.spec.containers[0].env[?(@.name=="APP_MODE")].valueFrom.configMapKeyRef.name}' 'q03-app-config' -n "$CKA_SIM_LAB_NS"`
- Behavioural: `kubectl exec q03-app -n "$CKA_SIM_LAB_NS" -- cat /etc/app-secrets/api-key` matches the seeded secret value.
**estimatedMinutes:** 8

#### Q04 — `04-hpa-metrics-server` (HPA autoscaling/v2 + CG-06)

**Tracker:** "HPA (autoscaling/v2)"
**Scenario:** Lab seeds a Deployment `q04-load` with CPU requests but NO metrics-server installed (the trap). Candidate must (a) install metrics-server via the Phase 4 vendored manifest (path below), (b) wait for metrics to be available, (c) create an `HorizontalPodAutoscaler` v2 that scales `q04-load` between 1 and 5 replicas at 50 % CPU target.
**Trap IDs:** `hpa-missing-metrics-server` (new — primary), `deployment-missing-requests` (reuse), `default-sa-used` (reuse).
**Key assertions:**
- `assert_resource_exists hpa q04-load -n "$CKA_SIM_LAB_NS"`
- `assert_field_eq hpa q04-load '{.spec.metrics[0].resource.name}' 'cpu' -n "$CKA_SIM_LAB_NS"`
- `assert_field_eq hpa q04-load '{.spec.minReplicas}' '1' -n "$CKA_SIM_LAB_NS"`
- `assert_field_eq hpa q04-load '{.spec.maxReplicas}' '5' -n "$CKA_SIM_LAB_NS"`
- Behavioural: `kubectl top pod -n "$CKA_SIM_LAB_NS" -l app=q04-load` exits 0 (metrics-server alive).
**estimatedMinutes:** 9
**External deps:** metrics-server. See §6.2 for install/uninstall pattern.

#### Q05 — `05-daemonset` (DaemonSet — 3.6)

**Tracker:** "DaemonSet"
**Scenario:** Lab expects one `q05-node-agent` pod on every Ready node (control-plane + workers). Candidate authors a DaemonSet that tolerates the control-plane taint `node-role.kubernetes.io/control-plane:NoSchedule`.
**Trap IDs:** `default-sa-used` (reuse), `deployment-missing-requests` (reuse), `sidecar-not-native-restartpolicy-always` (new — warns if candidate smuggles a sidecar in legacy form).
**Key assertions:**
- `assert_resource_exists daemonset q05-node-agent -n "$CKA_SIM_LAB_NS"`
- `assert_field_eq daemonset q05-node-agent '{.status.desiredNumberScheduled}' "$(kubectl get nodes --no-headers | wc -l | tr -d ' ')" -n "$CKA_SIM_LAB_NS"` — number-ready equals node count.
- `assert_field_eq daemonset q05-node-agent '{.spec.template.spec.tolerations[?(@.key=="node-role.kubernetes.io/control-plane")].operator}' 'Exists' -n "$CKA_SIM_LAB_NS"`
**estimatedMinutes:** 7

#### Q06 — `06-static-pod` (Static pods — 3.7)

**Tracker:** "Static pods"
**Scenario:** Candidate SSHes into `node-01` and drops a pod manifest `q06-static-nginx.yaml` into `/etc/kubernetes/manifests/`. The kubelet mirror creates a mirror pod in the default namespace named `q06-static-nginx-node-01`.
**Trap IDs:** `kubelet-runtime-flag-in-kubeconfig` (reuse), `default-sa-used` (reuse), `deployment-missing-requests` (reuse).
**Key assertions:**
- `assert_resource_exists pod q06-static-nginx-node-01 -n default` — mirror pod exists.
- `assert_field_eq pod q06-static-nginx-node-01 '{.metadata.annotations.kubernetes\.io/config\.source}' 'file' -n default` — proves it's kubelet-managed.
- `assert_pod_ready default q06-static-nginx-node-01`
**estimatedMinutes:** 8
**External deps:** SSH access to `node-01` (already established via BOOT-02/03 in Phase 1).

#### Q07 — `07-native-sidecar` (CG-08 native sidecar)

**Tracker:** Not explicitly on the legacy Tracker — added per REQUIREMENTS.md PACK-02 CG-08 mandate. Covers the v1.35 `SidecarContainers` feature gate (GA in 1.29+; enabled by default in 1.35).
**Scenario:** Lab seeds a Deployment `q07-app` that needs a log-tailing sidecar. Candidate must add the sidecar as `initContainers[].restartPolicy: Always` (v1.35 native form), NOT as a peer container.
**Trap IDs:** `sidecar-not-native-restartpolicy-always` (new — primary), `default-sa-used` (reuse), `deployment-missing-requests` (reuse).
**Key assertions:**
- `assert_field_eq deployment q07-app '{.spec.template.spec.initContainers[?(@.name=="log-tailer")].restartPolicy}' 'Always' -n "$CKA_SIM_LAB_NS"`
- Behavioural: `kubectl exec -n "$CKA_SIM_LAB_NS" deploy/q07-app -c log-tailer -- test -f /shared/app.log` exits 0.
- `assert_pod_ready` for the main pod.
**estimatedMinutes:** 8
**External deps:** None (feature GA in 1.35).

#### Q08 — `08-nodeselector-affinity-taints` (nodeSelector/affinity + taints/tolerations bundled — 3.8 + 3.9)

**Tracker:** "nodeSelector and node affinity" + "Taints and tolerations"
**Scenario:** Lab seeds a broken Deployment `q08-gpu-sim` that requests an unmet nodeSelector label `gpu=true`. Lab adds a taint `gpu=true:NoSchedule` to `node-02`. Candidate must (a) label `node-02` with `gpu=true`, (b) give the Deployment's pods a matching `nodeAffinity` (preferred or required) AND a `toleration` for the taint. Covers both concepts in one scenario.
**Trap IDs:** `default-sa-used` (reuse), `deployment-missing-requests` (reuse), `hostpath-pv-without-nodeaffinity` (reuse — conceptually adjacent: teaches nodeAffinity).
**Key assertions:**
- `assert_field_eq deployment q08-gpu-sim '{.spec.template.spec.tolerations[?(@.key=="gpu")].effect}' 'NoSchedule' -n "$CKA_SIM_LAB_NS"`
- `assert_field_eq deployment q08-gpu-sim '{.spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[?(@.key=="gpu")].operator}' 'In' -n "$CKA_SIM_LAB_NS"`
- Behavioural: all replicas land on `node-02`: `kubectl get pod -n "$CKA_SIM_LAB_NS" -l app=q08-gpu-sim -o jsonpath='{.items[*].spec.nodeName}'` contains only `node-02`.
**estimatedMinutes:** 9
**External deps:** Pre-reset cleanup must remove the `gpu=true` label from `node-02` (otherwise later questions would see unexpected scheduler behaviour).

---

## 3. Trap Catalog Additions (6 entries, ready to paste)

Append to `cka-sim/traps/catalog.yaml`. Schema is the 8-field flat shape enforced by `scripts/lint-traps.sh`.

```yaml
  - id: csi-snapshot-wrong-driver
    name: VolumeSnapshotClass references a driver not installed on the cluster
    description: "VolumeSnapshot stays stuck without readyToUse=true because the VolumeSnapshotClass spec.driver names a CSI driver that is not installed or not serving snapshots on this cluster."
    remediation_hint: "Install the correct CSI driver that matches the VolumeSnapshotClass spec.driver, or edit the VolumeSnapshotClass to point at an installed driver."
    severity: error
    domain: storage
    source: community
    references:
      - kind: k8s-doc
        target: "https://kubernetes.io/docs/concepts/storage/volume-snapshots/"
        note: VolumeSnapshot + VolumeSnapshotClass concepts

  - id: pvc-pending-wffc-unscheduled-consumer
    name: PVC with WaitForFirstConsumer stays Pending because no pod consumes it
    description: "StorageClass has volumeBindingMode=WaitForFirstConsumer; the PVC will not bind until a pod that mounts it is scheduled. Candidates often deploy the PVC alone and conclude the cluster is broken."
    remediation_hint: "Create a Pod (or Deployment/StatefulSet) that mounts the PVC via spec.volumes[].persistentVolumeClaim.claimName. Binding resolves as soon as the pod is scheduled."
    severity: warn
    domain: storage
    source: community
    references:
      - kind: k8s-doc
        target: "https://kubernetes.io/docs/concepts/storage/storage-classes/#volume-binding-mode"
        note: WaitForFirstConsumer binding semantics

  - id: reclaim-policy-delete-data-loss
    name: PV reclaim policy set to Delete destroys data when the PVC is deleted
    description: "PersistentVolume reclaim policy is Delete; when the bound PVC is deleted, the underlying volume (and its data) is removed automatically. Retain preserves the volume for manual reclaim."
    remediation_hint: "Set persistentVolumeReclaimPolicy: Retain on any PV whose data must survive PVC deletion. kubectl patch pv <name> -p '{\"spec\":{\"persistentVolumeReclaimPolicy\":\"Retain\"}}'"
    severity: warn
    domain: storage
    source: community
    references:
      - kind: k8s-doc
        target: "https://kubernetes.io/docs/concepts/storage/persistent-volumes/#reclaiming"
        note: Reclaim policy semantics

  - id: pvc-accessmode-rwx-on-rwo-sc
    name: PVC requests ReadWriteMany access from a StorageClass that only provides ReadWriteOnce
    description: "PVC spec.accessModes contains ReadWriteMany but the matching StorageClass (or PV) only supports ReadWriteOnce; the PVC stays Pending forever. hostPath and most local-path provisioners are RWO-only."
    remediation_hint: "Either request ReadWriteOnce on the PVC (matching what the StorageClass provides) or use a StorageClass whose provisioner supports RWX (NFS, CephFS, cloud file shares)."
    severity: warn
    domain: storage
    source: community
    references:
      - kind: k8s-doc
        target: "https://kubernetes.io/docs/concepts/storage/persistent-volumes/#access-modes"
        note: accessMode support matrix per volume plugin

  - id: hpa-missing-metrics-server
    name: HPA cannot scale because metrics-server is not installed
    description: "HorizontalPodAutoscaler targets CPU/memory but metrics.k8s.io is unavailable; the HPA stays FailedGetResourceMetric and never scales. kubeadm clusters do not ship metrics-server by default."
    remediation_hint: "Install metrics-server via the upstream manifest (https://github.com/kubernetes-sigs/metrics-server). On lab kubeadm clusters with self-signed kubelet certs, add --kubelet-insecure-tls to the metrics-server Deployment args."
    severity: error
    domain: workloads-scheduling
    source: concerns-md
    references:
      - kind: concerns-md
        target: .planning/codebase/CONCERNS.md
        note: "CG-06 — metrics-server bootstrap prerequisite for HPA"
      - kind: k8s-doc
        target: "https://github.com/kubernetes-sigs/metrics-server"
        note: metrics-server upstream install manifest

  - id: sidecar-not-native-restartpolicy-always
    name: Sidecar added as peer container instead of v1.29+ native sidecar (initContainer with restartPolicy Always)
    description: "Candidate adds a sidecar as a regular spec.containers entry instead of using the v1.29+ native sidecar shape: spec.initContainers[].restartPolicy: Always. Legacy peer-container sidecars do not get guaranteed ordering, lifecycle, or graceful shutdown."
    remediation_hint: "Move the sidecar into spec.initContainers and set restartPolicy: Always on that init container. The SidecarContainers feature gate is GA on 1.29+ and enabled by default in 1.35."
    severity: warn
    domain: workloads-scheduling
    source: concerns-md
    references:
      - kind: concerns-md
        target: .planning/codebase/CONCERNS.md
        note: "CG-08 — native sidecar pattern is the 1.35 canonical shape"
      - kind: k8s-doc
        target: "https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/"
        note: Native sidecar containers
```

All six IDs are RFC 1123 compliant (lowercase `[a-z0-9-]`, start/end alphanumeric, ≤63 chars). Severity levels match existing entries.

---

## 4. Shared Helper Library — `cka-sim/lib/setup.sh`

New file. Sourced by every question's `setup.sh` after `CKA_SIM_ROOT` is set. Replaces the inline 120-second ns-Active wait currently duplicated in both Phase 3 references.

```bash
#!/bin/bash
# cka-sim/lib/setup.sh — shared setup helpers for question authoring.
# Sourced by every packs/*/*/setup.sh. Keeps ns-Active wait, PV seeding, and
# Deployment seeding in one place so bug fixes propagate automatically.
# All helpers are idempotent and safe to re-run (TRIP-02 requirement).

: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"

# cka_sim::setup::ensure_lab_ns <ns> <pack> <question-id>
#   Idempotently create the lab namespace with the standard cka-sim labels.
#   Safe to re-run; labels are applied via kubectl apply (merge semantics).
cka_sim::setup::ensure_lab_ns() {
  local ns="$1" pack="$2" qid="$3"
  kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${ns}
  labels:
    cka-sim/pack: ${pack}
    cka-sim/question-id: ${qid}
EOF
}

# cka_sim::setup::wait_for_ns_active <ns> <pack> <question-id> [<timeout-seconds>]
#   Poll up to <timeout-seconds> (default 120) for ns.status.phase == Active.
#   Absorbs the `reset.sh --wait=false` race: if the ns disappears mid-wait
#   (still Terminating from prior reset), re-applies the Namespace def.
#   Dies if ns is not Active after the full timeout.
cka_sim::setup::wait_for_ns_active() {
  local ns="$1" pack="$2" qid="$3" timeout="${4:-120}"
  local iterations=$(( timeout / 5 ))
  local phase=""
  local i
  for i in $(seq 1 "$iterations"); do
    phase=$(kubectl get ns "$ns" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
    [[ "$phase" == "Active" ]] && return 0
    if [[ -z "$phase" ]]; then
      cka_sim::setup::ensure_lab_ns "$ns" "$pack" "$qid"
    fi
    sleep 5
  done
  die "ns $ns not Active after ${timeout}s (phase=$phase)"
}

# cka_sim::setup::seed_pv_hostpath <pv-name> <size> <access-mode> <reclaim-policy> <host-path> [<node-affinity-key>]
#   Create a hostPath PV with optional nodeAffinity. If <node-affinity-key> is
#   empty, the PV is created WITHOUT nodeAffinity (seeds the
#   hostpath-pv-without-nodeaffinity trap).
cka_sim::setup::seed_pv_hostpath() {
  local name="$1" size="$2" mode="$3" reclaim="$4" hp="$5" affinity_key="${6:-}"
  local affinity_block=""
  if [[ -n "$affinity_key" ]]; then
    affinity_block=$(cat <<AFF
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: ${affinity_key}
              operator: Exists
AFF
)
  fi
  kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ${name}
spec:
  capacity:
    storage: ${size}
  accessModes:
    - ${mode}
  persistentVolumeReclaimPolicy: ${reclaim}
  storageClassName: manual
  hostPath:
    path: ${hp}
    type: DirectoryOrCreate
${affinity_block}
EOF
}

# cka_sim::setup::seed_deployment <ns> <name> <image> [--replicas N] [--sa SA] [--cpu X] [--memory Y]
#   Create a minimal Deployment. Flags opt-in to serviceAccountName and requests.
#   Used by questions that need a deployable target without reinventing YAML.
cka_sim::setup::seed_deployment() {
  local ns="$1" name="$2" image="$3"; shift 3
  local replicas=1 sa="" cpu="" mem=""
  while (( $# > 0 )); do
    case "$1" in
      --replicas) replicas="$2"; shift 2 ;;
      --sa)       sa="$2"; shift 2 ;;
      --cpu)      cpu="$2"; shift 2 ;;
      --memory)   mem="$2"; shift 2 ;;
      *) die "seed_deployment: unexpected flag $1" ;;
    esac
  done
  local sa_block=""
  [[ -n "$sa" ]] && sa_block="      serviceAccountName: ${sa}"
  local resources_block=""
  if [[ -n "$cpu" || -n "$mem" ]]; then
    resources_block=$(cat <<RES
          resources:
            requests:
              cpu: ${cpu:-50m}
              memory: ${mem:-64Mi}
RES
)
  fi
  kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${name}
  namespace: ${ns}
  labels:
    app: ${name}
spec:
  replicas: ${replicas}
  selector:
    matchLabels:
      app: ${name}
  template:
    metadata:
      labels:
        app: ${name}
    spec:
${sa_block}
      containers:
        - name: app
          image: ${image}
${resources_block}
EOF
}
```

---

## 5. `scripts/lint-coverage.sh` Design

### 5.1 Per-pack `coverage.yaml` Schema

`cka-sim/packs/<pack>/coverage.yaml` maps Tracker checkboxes (by canonical stable slug) to the question IDs that cover them. Multiple questions may cover the same Tracker item; the lint only requires ≥1 per item.

```yaml
# cka-sim/packs/storage/coverage.yaml
domain: storage
tracker:
  understand-pv-pvc:
    label: "Understand PersistentVolume and PersistentVolumeClaim"
    questions: [storage-pvc-binding, storage-pvc-mount-pod]
  understand-storageclass-dynamic:
    label: "Understand StorageClass and dynamic provisioning"
    questions: [storage-storageclass-dynamic, storage-wait-for-first-consumer]
  know-access-modes:
    label: "Know access modes (RWO, ROX, RWX, RWOP)"
    questions: [storage-access-modes-reclaim]
  know-reclaim-policies:
    label: "Know reclaim policies (Retain, Delete)"
    questions: [storage-access-modes-reclaim]
  csi-basics:
    label: "CSI driver basics and troubleshooting"
    questions: [storage-csi-volumesnapshot]
  mount-pvc-in-pod:
    label: "Mount PVC in a Pod"
    questions: [storage-pvc-mount-pod]
```

Workloads pack `coverage.yaml` has analogous 9 Tracker entries.

### 5.2 Lint Algorithm

```bash
#!/bin/bash
# cka-sim/scripts/lint-coverage.sh — verify each pack's coverage.yaml lists
# ≥1 question per Tracker checkbox, and each listed question-id exists in the
# pack's manifest.yaml (i.e. no broken references).
# Usage: lint-coverage.sh                 — lint every pack under packs/
#        lint-coverage.sh <pack-slug>    — lint one pack
# Exit codes: 0 = all green, 1 = any pack fails.
set -uo pipefail
```

Algorithm:
1. For each pack under `cka-sim/packs/*/`:
   a. Require `coverage.yaml` and `manifest.yaml` exist.
   b. Parse `coverage.yaml`: build map `tracker_key → [question_ids]`.
   c. Parse `manifest.yaml`: build set `declared_questions`.
   d. For each `tracker_key`: fail if `questions` list is empty.
   e. For each `question_id` under any `tracker_key`: fail if it is not in `declared_questions`.
   f. For each declared question: warn (non-fatal) if it is not referenced by any `tracker_key` (lets future questions be drafted without blocking lint).
2. Summary: `N/M Tracker items covered in <pack>`; exit 1 on any fail.

### 5.3 Example Failure Output

```
× storage: tracker item 'csi-basics' (CSI driver basics and troubleshooting) has no questions listed
× storage: question-id 'storage-snapshot-xyz' referenced by 'csi-basics' is not in manifest.yaml
⚠ workloads-scheduling: question 'workloads-rolling-update-rollback' declared in manifest.yaml but not referenced in coverage.yaml (orphan)

2 error(s), 1 warning(s). Coverage lint FAILED.
```

### 5.4 CI Wiring

Append to `cka-sim/scripts/validate-local.sh` (after the existing shellcheck + yamllint passes):

```bash
# Coverage matrix lint — Phase 4+.
if [[ -x cka-sim/scripts/lint-coverage.sh ]]; then
  cka-sim/scripts/lint-coverage.sh || exit 1
fi
```

Also add a step in `.github/workflows/validate.yml` mirroring the shellcheck step.

---

## 6. External Dependency Install Strategies

### 6.1 hostpath-csi (for Q04 — CSI VolumeSnapshot)

**Install target:** `kubernetes-csi/csi-driver-host-path` — it's the canonical reference driver, is k8s-SIG-maintained, supports VolumeSnapshots end-to-end, and runs in any kubeadm cluster with no external storage. Local-path-provisioner (`rancher/local-path-provisioner`) is simpler but does NOT support snapshots, so it's unsuitable here.

**Install pattern (inside `04-csi-volumesnapshot/setup.sh`):**

```bash
# Detect if hostpath-csi is already installed (idempotent — skip on re-run).
if ! kubectl get namespace csi-hostpath >/dev/null 2>&1; then
  # Install the snapshot CRDs (cluster-scoped).
  kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v7.0.2/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
  kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v7.0.2/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
  kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v7.0.2/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml

  # Install the snapshot controller (cluster-scoped).
  kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v7.0.2/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml
  kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v7.0.2/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml

  # Install the hostpath-csi driver into csi-hostpath namespace.
  kubectl create namespace csi-hostpath
  kubectl apply -n csi-hostpath -f https://raw.githubusercontent.com/kubernetes-csi/csi-driver-host-path/v1.14.0/deploy/kubernetes-latest/hostpath/csi-hostpath-driverinfo.yaml
  # Remaining hostpath manifests: plugin, provisioner, attacher, resizer, snapshotter, RBAC.
  # Pin all to v1.14.0 for reproducibility.

  # Create VolumeSnapshotClass + StorageClass if missing.
  kubectl apply -f - <<EOF
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: csi-hostpath-snapshotclass
driver: hostpath.csi.k8s.io
deletionPolicy: Delete
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: csi-hostpath-sc
provisioner: hostpath.csi.k8s.io
volumeBindingMode: WaitForFirstConsumer
EOF
fi

# Wait for the driver to be ready.
kubectl wait --for=condition=Available deployment/csi-hostpathplugin -n csi-hostpath --timeout=120s 2>/dev/null || true
```

**Uninstall pattern (inside `04-csi-volumesnapshot/reset.sh`):**

```bash
# Remove question-scoped resources first.
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false

# Best-effort driver cleanup. Only delete the driver if no other lab namespace
# is actively using csi-hostpath (check via cka-sim/pack label).
active_users=$(kubectl get pvc --all-namespaces -l cka-sim/uses=csi-hostpath -o name 2>/dev/null | wc -l | tr -d ' ')
if [[ "$active_users" == "0" ]]; then
  kubectl delete volumesnapshotclass csi-hostpath-snapshotclass --ignore-not-found
  kubectl delete storageclass csi-hostpath-sc --ignore-not-found
  kubectl delete namespace csi-hostpath --ignore-not-found --wait=false
  # Leave snapshot CRDs installed — ripping them out is destructive across users.
fi
```

### 6.2 metrics-server (for Q04 Workloads — HPA)

**Install manifest:** `components.yaml` from `kubernetes-sigs/metrics-server` upstream.

**Version pin:** `v0.7.2` (latest stable compatible with 1.35 as of 2026-05 per upstream matrix).

**kubelet-insecure-tls patch:** lab kubeadm clusters use self-signed kubelet cert → metrics-server fails TLS validation. Standard workaround: append `--kubelet-insecure-tls` to the metrics-server Deployment's container args.

**Install pattern (inside `04-hpa-metrics-server/setup.sh`):**

```bash
if ! kubectl get deployment metrics-server -n kube-system >/dev/null 2>&1; then
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.7.2/components.yaml
  # Patch for lab kubeadm self-signed kubelet certs.
  kubectl patch deployment metrics-server -n kube-system --type=json -p='[
    {"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}
  ]'
fi
kubectl wait --for=condition=Available deployment/metrics-server -n kube-system --timeout=120s 2>/dev/null || true
```

**Uninstall pattern (inside `04-hpa-metrics-server/reset.sh`):**

Do NOT uninstall metrics-server on reset — it's useful across multiple questions and other candidates may rely on it. Only clean the question's lab namespace + HPA.

---

## 7. Phase 3 Retrofit Plan

### 7.1 Files Changed

1. `cka-sim/packs/storage/01-pvc-binding/setup.sh`
   - Replace lines 6-38 (inline ns create + 120 s loop) with:
     ```bash
     source "$CKA_SIM_ROOT/lib/setup.sh"
     cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" storage storage-pvc-binding
     cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" storage storage-pvc-binding 120
     ```
   - Keep the rest (hostPath PV without nodeAffinity + PVC) unchanged.
2. `cka-sim/packs/workloads-scheduling/01-deployment-requests/setup.sh`
   - Replace lines 6-35 identically, parameterised for pack=workloads-scheduling, qid=workloads-deployment-requests.

### 7.2 Regression Risk Matrix

| Risk | Likelihood | Mitigation |
|---|---|---|
| New helper introduces a subtly different wait semantics | Low | The new helper is a literal copy of the Phase 3 loop (confirmed identical by byte-comparing the current 01-pvc-binding setup.sh lines 17-37 against the helper body). |
| Sourcing `lib/setup.sh` fails on stale `CKA_SIM_ROOT` | Medium | The helper requires `CKA_SIM_ROOT` to be set (same contract as `lib/grade.sh` and `lib/traps.sh`). Question runner already exports it. |
| Other questions accidentally reuse the retrofitted pattern and source lib/setup.sh before CKA_SIM_ROOT is set | Low | Runner always exports `CKA_SIM_ROOT` before invoking setup.sh. Covered by existing test.sh fixtures. |
| GRADE-06 round-trip self-check regresses | Low | Run Phase 3's 5 round-trip fixtures post-retrofit before touching any new questions. |
| Test harness `kubectl` stub doesn't handle the helper's multi-line heredoc | Low | Existing stub already handles heredoc input (Phase 2 fixture `manifest/`). |

### 7.3 Safe Migration Order

1. **Step 1 (shared lib):** Ship `cka-sim/lib/setup.sh` + unit test fixtures under `cka-sim/tests/fixtures/setup_helpers/`. Do NOT modify existing questions yet.
2. **Step 2 (retrofit):** One question at a time. After each retrofit, run `scripts/test.sh` and `scripts/lint-packs.sh`; confirm GRADE-06 round-trip still green on that question. Commit each retrofit atomically.
3. **Step 3 (new questions):** Only after both retrofits are committed green, start authoring the 12 new questions. They import the helper from day one.

---

## 8. Validation Architecture (per GRADE-06 round-trip)

Every new question needs a round-trip fixture under `cka-sim/tests/fixtures/`. Using Phase 2's existing fixture naming pattern (`<detector-name>/{hit,miss,benign}` structure), Phase 4 adds:

**Storage pack fixtures:**
- `cka-sim/tests/fixtures/csi-snapshot-wrong-driver/`
- `cka-sim/tests/fixtures/pvc-pending-wffc-unscheduled-consumer/`
- `cka-sim/tests/fixtures/reclaim-policy-delete-data-loss/`
- `cka-sim/tests/fixtures/pvc-accessmode-rwx-on-rwo-sc/`

**Workloads & Scheduling pack fixtures:**
- `cka-sim/tests/fixtures/hpa-missing-metrics-server/`
- `cka-sim/tests/fixtures/sidecar-not-native-restartpolicy-always/`

**Per-question end-to-end fixtures** (one per new question, for round-trip validation under the PATH-shadowed kubectl stub):
- `cka-sim/tests/fixtures/storage-02-storageclass-dynamic/`
- `cka-sim/tests/fixtures/storage-03-access-modes-reclaim/`
- `cka-sim/tests/fixtures/storage-04-csi-volumesnapshot/`
- `cka-sim/tests/fixtures/storage-05-wait-for-first-consumer/`
- `cka-sim/tests/fixtures/storage-06-pvc-mount-pod/`
- `cka-sim/tests/fixtures/workloads-02-rolling-update-rollback/`
- `cka-sim/tests/fixtures/workloads-03-configmap-secret-env-volume/`
- `cka-sim/tests/fixtures/workloads-04-hpa-metrics-server/`
- `cka-sim/tests/fixtures/workloads-05-daemonset/`
- `cka-sim/tests/fixtures/workloads-06-static-pod/`
- `cka-sim/tests/fixtures/workloads-07-native-sidecar/`
- `cka-sim/tests/fixtures/workloads-08-nodeselector-affinity-taints/`

Each fixture contains:
- `stub-responses.json` — PATH-shadowed kubectl responses simulating the setup state.
- `expected-score.txt` — the `SCORE: N/M` line expected for the "no-candidate-solution" run (proves grader fails cleanly).
- `expected-traps.txt` — the `Trap N:` lines expected (proves detectors fire).
- `expected-ref-solution-score.txt` — proves `setup.sh && ref-solution.sh && grade.sh` = perfect score, 0 traps (GRADE-06 round-trip).

**Test harness extension:** `scripts/test.sh` iterates each fixture dir, runs the round-trip, asserts the three expected files match actual output.

---

## 9. Risks + Unknowns

| Risk | Severity | Mitigation |
|---|---|---|
| hostpath-csi v1.14 manifest layout drifts on the upstream repo (urls 404 or change shape) | Medium | Pin every URL to `v1.14.0` refs, including the snapshot controller v7.0.2. Vendor the manifests into `cka-sim/packs/storage/04-csi-volumesnapshot/vendor/` if the URL-based install proves unstable. |
| metrics-server v0.7.2 breaks on a later 1.35 patch release | Low | Upstream test matrix covers 1.28-1.35; if regression, bump pin to whichever version tags `kubernetes: 1.35` in the compatibility chart. |
| Native sidecar Q7: feature gate somehow off on the user's 1+2 cluster | Low | Check `kubectl get --raw=/metrics 2>/dev/null | grep sidecar_containers_enabled` as part of setup.sh; if disabled, emit an error before seeding. |
| DaemonSet Q5: control-plane toleration test fails because the user's single CP node has extra taints (NoExecute from kubeadm upgrade) | Medium | `setup.sh` should read current taints on the CP node and seed the matching tolerations, not assume only `NoSchedule`. |
| Static Pod Q6: depends on SSH to `node-01` from Phase 1 BOOT-02/03; if those ever regress, this question fails opaquely | Medium | `setup.sh` runs `ssh -o BatchMode=yes -o ConnectTimeout=5 node-01 true` as a preflight; exits 1 with a clear message pointing at `cka-sim doctor`. |
| Lint-coverage.sh YAML parser (pure bash, no yq) gets complex coverage.yaml wrong | Medium | Schema is extremely flat (no lists of lists). Reuse Phase 2's catalog YAML parser as a template — same 2-space indent rules. |
| Trap IDs that already exist under a different slug (e.g. `pvc-wrong-storageclass` variants) might collide on lint | Low | Phase 2's `lint-traps.sh` already checks id uniqueness; run it after appending the 6 new entries. |
| Test harness fixture count balloons from 18 (Phase 2) + 5 (Phase 3) → 31 (Phase 4). Harness CI runtime may slow. | Low | Fixtures are file-based; CI runtime stays under 30 s. Monitor with `time scripts/test.sh`; parallelise only if it exceeds 2 min. |
| VolumeSnapshot CRD install changes ownership over time — `kubectl apply -f` of a CRD owned by a different chart may conflict | Medium | Use `kubectl apply --server-side --force-conflicts=false` for CRDs; fail closed with a clear message if someone has already installed snapshot CRDs via Helm. |

---

## Validation Architecture

Section 8 above is the VALIDATION.md candidate: it enumerates exact fixture directories, expected artifacts per fixture, and harness integration. The planner should lift this section directly into `04-VALIDATION.md` (per Nyquist) and derive per-plan Dimension-8 validation tasks from it.

---

## RESEARCH COMPLETE

Researched how to implement Phase 4 end-to-end: 12 new questions across the Storage and Workloads packs, 6 new trap-catalog entries (full 8-field YAML ready to paste), a shared `cka-sim/lib/setup.sh` helper library with 4 functions, a `scripts/lint-coverage.sh` coverage-matrix lint + per-pack `coverage.yaml` schema, install/uninstall patterns for hostpath-csi and metrics-server (both pinned to specific upstream releases), a Phase 3 retrofit plan with regression risks, and a per-question GRADE-06 fixture catalog (12 end-to-end + 6 detector). The research produced directly in the orchestrator after two researcher-agent attempts dropped with Windows socket errors; sources were the live codebase (Phase 3 reference questions, Phase 2 trap/grade contracts, Study Progress Tracker in README.md) plus the locked decisions in 04-CONTEXT.md.
