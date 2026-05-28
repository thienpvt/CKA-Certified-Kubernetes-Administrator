#!/bin/bash
# Shared runtime for dump-cooloo9871 questions.
set -uo pipefail
export MSYS2_ARG_CONV_EXCL='*'

cka_sim::dump::ensure_ns() {
  cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" "dump-cooloo9871" "$CKA_SIM_QUESTION_ID"
  cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" "dump-cooloo9871" "$CKA_SIM_QUESTION_ID" 60
}

cka_sim::dump::setup() {
  local q="$1"
  cka_sim::dump::ensure_ns
  case "$q" in
    03)
      kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: queue
  namespace: ${CKA_SIM_LAB_NS}
spec:
  serviceName: queue
  replicas: 3
  selector:
    matchLabels:
      app: queue
  template:
    metadata:
      labels:
        app: queue
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command: ["sh", "-c", "sleep 3600"]
EOF
      ;;
    04)
      kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: q04-api
  namespace: ${CKA_SIM_LAB_NS}
spec:
  selector:
    app: q04-api
  ports:
    - port: 80
      targetPort: 8080
EOF
      ;;
    05)
      for item in "api:10" "batch:20" "worker:30"; do
        name="${item%%:*}"
        rank="${item##*:}"
        kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: q05-${name}
  namespace: ${CKA_SIM_LAB_NS}
  labels:
    app: q05
    sort-rank: "${rank}"
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
EOF
      done
      ;;
    07)
      kubectl create configmap q07-metrics -n "$CKA_SIM_LAB_NS" \
        --from-literal=largestPodCpu=q07-heavy \
        --from-literal=largestNodeCpu=worker-a \
        --dry-run=client -o yaml | kubectl apply -f -
      ;;
    08)
      kubectl create configmap q08-control-plane -n "$CKA_SIM_LAB_NS" \
        --from-literal=component=kube-apiserver \
        --from-literal=securePort=6443 \
        --dry-run=client -o yaml | kubectl apply -f -
      ;;
    09)
      node="$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
      node="${node:-manual-worker}"
      kubectl create configmap q09-scheduler-sim -n "$CKA_SIM_LAB_NS" \
        --from-literal=targetNode="$node" \
        --dry-run=client -o yaml | kubectl apply -f -
      ;;
    14)
      kubectl create configmap q14-cluster-facts -n "$CKA_SIM_LAB_NS" \
        --from-literal=nodeCount=3 \
        --from-literal=controlPlaneVersion=v1.35.0 \
        --dry-run=client -o yaml | kubectl apply -f -
      ;;
    15)
      kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: q15-pending
  namespace: ${CKA_SIM_LAB_NS}
spec:
  nodeSelector:
    cka-sim/nonexistent: "true"
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
EOF
      ;;
    16)
      kubectl create configmap q16-api-inventory -n "$CKA_SIM_LAB_NS" \
        --from-literal=namespace=metadata \
        --from-literal=namespacedKind=configmaps \
        --dry-run=client -o yaml | kubectl apply -f -
      ;;
    17)
      kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: q17-inspect
  namespace: ${CKA_SIM_LAB_NS}
spec:
  containers:
    - name: app
      image: nginx:1.27-alpine
    - name: sidecar
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
EOF
      ;;
    18)
      kubectl create configmap kubelet-flags -n "$CKA_SIM_LAB_NS" \
        --from-literal=runtimeEndpoint=broken \
        --from-literal=status=broken \
        --dry-run=client -o yaml | kubectl apply -f -
      ;;
    20)
      kubectl create configmap q20-upgrade-constraints -n "$CKA_SIM_LAB_NS" \
        --from-literal=targetVersion=v1.35.x \
        --from-literal=extraCluster=false \
        --dry-run=client -o yaml | kubectl apply -f -
      ;;
    22)
      kubectl create configmap q22-apiserver-cert -n "$CKA_SIM_LAB_NS" \
        --from-literal=certName=kube-apiserver \
        --from-literal=validUntil=2030-05-28 \
        --from-literal=signer=kubernetes \
        --dry-run=client -o yaml | kubectl apply -f -
      ;;
    23)
      kubectl create configmap q23-kubelet-certs -n "$CKA_SIM_LAB_NS" \
        --from-literal=clientIssuer=kubernetes-ca \
        --from-literal=servingEku=server-auth \
        --dry-run=client -o yaml | kubectl apply -f -
      ;;
    24)
      kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  namespace: ${CKA_SIM_LAB_NS}
  labels:
    app: frontend
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
EOF
      ;;
    26)
      kubectl create configmap q26-eviction-data -n "$CKA_SIM_LAB_NS" \
        --from-literal=bestEffort=besteffort-low \
        --from-literal=guaranteed=guaranteed-critical \
        --dry-run=client -o yaml | kubectl apply -f -
      ;;
    28)
      kubectl create configmap q28-etcd-certs -n "$CKA_SIM_LAB_NS" \
        --from-literal=serverKey=/etc/kubernetes/pki/etcd/server.key \
        --from-literal=clientAuth=true \
        --from-literal=snapshotPath=/tmp/cka-sim-etcd-snapshot.db \
        --dry-run=client -o yaml | kubectl apply -f -
      ;;
  esac
}

cka_sim::dump::record_on_fail() {
  local rc="$1" trap_id="$2"
  if (( rc != 0 )); then
    cka_sim::grade::record_trap "$trap_id"
  fi
}

cka_sim::dump::assert_field() {
  local kind="$1" name="$2" jsonpath="$3" expected="$4" trap_id="$5"
  shift 5
  cka_sim::grade::assert_field_eq "$kind" "$name" "$jsonpath" "$expected" "$@" || cka_sim::grade::record_trap "$trap_id"
}

cka_sim::dump::assert_authored() {
  local kind="$1" name="$2" trap_id="$3"
  shift 3
  cka_sim::grade::assert_resource_candidate_authored "$kind" "$name" "$@" || cka_sim::grade::record_trap "$trap_id"
}

cka_sim::dump::assert_changed() {
  local kind="$1" name="$2" trap_id="$3"
  shift 3
  cka_sim::grade::assert_changed_since_setup "$kind" "$name" "$@" || cka_sim::grade::record_trap "$trap_id"
}

cka_sim::dump::grade_answer() {
  local cm="$1" trap_id="$2"
  shift 2
  cka_sim::dump::assert_authored configmap "$cm" "$trap_id" -n "$CKA_SIM_LAB_NS"
  local pair key expected
  for pair in "$@"; do
    key="${pair%%=*}"
    expected="${pair#*=}"
    cka_sim::dump::assert_field configmap "$cm" "{.data.$key}" "$expected" "$trap_id" -n "$CKA_SIM_LAB_NS"
  done
}

cka_sim::dump::grade() {
  local q="$1" trap_id="$2"
  case "$q" in
    01) cka_sim::dump::grade_answer "q01-answer" "$trap_id" contexts=current-lab currentContext=current-lab noKubectlSource=kubeconfig-current-context ;;
    05) cka_sim::dump::grade_answer "q05-answer" "$trap_id" sortedPods=api,batch,worker ;;
    07) cka_sim::dump::grade_answer "q07-answer" "$trap_id" largestPodCpu=q07-heavy largestNodeCpu=worker-a ;;
    08) cka_sim::dump::grade_answer "q08-answer" "$trap_id" component=kube-apiserver namespace=kube-system securePort=6443 ;;
    14) cka_sim::dump::grade_answer "q14-answer" "$trap_id" nodeCount=3 controlPlaneVersion=v1.35.0 ;;
    15) cka_sim::dump::grade_answer "q15-answer" "$trap_id" warningReason=FailedScheduling involvedObject=q15-pending ;;
    16) cka_sim::dump::grade_answer "q16-answer" "$trap_id" namespace=metadata namespacedKind=configmaps ;;
    17) cka_sim::dump::grade_answer "q17-answer" "$trap_id" container=sidecar image=busybox:1.36 command=sleep ;;
    20) cka_sim::dump::grade_answer "q20-answer" "$trap_id" firstStep=kubeadm-upgrade-plan joinMode=dry-run-token-review ;;
    22) cka_sim::dump::grade_answer "q22-answer" "$trap_id" certName=kube-apiserver validUntil=2030-05-28 signer=kubernetes ;;
    23) cka_sim::dump::grade_answer "q23-answer" "$trap_id" clientIssuer=kubernetes-ca servingEku=server-auth ;;
    26) cka_sim::dump::grade_answer "q26-answer" "$trap_id" firstEvicted=besteffort-low lastEvicted=guaranteed-critical ;;
    28) cka_sim::dump::grade_answer "q28-answer" "$trap_id" serverKey=/etc/kubernetes/pki/etcd/server.key clientAuth=true snapshotPath=/tmp/cka-sim-etcd-snapshot.db ;;
    02)
      cka_sim::dump::assert_authored pod cp-toolbox "$trap_id" -n "$CKA_SIM_LAB_NS"
      CKA_SIM_GRADE_TOTAL=$(( CKA_SIM_GRADE_TOTAL + 1 ))
      selector_present=$(kubectl get pod cp-toolbox -n "$CKA_SIM_LAB_NS" -o jsonpath='{.spec.nodeSelector.node-role\.kubernetes\.io/control-plane}' 2>/dev/null; printf x)
      if [[ "$selector_present" == "x" ]] && kubectl get pod cp-toolbox -n "$CKA_SIM_LAB_NS" -o name >/dev/null 2>&1; then
        CKA_SIM_GRADE_PASSED=$(( CKA_SIM_GRADE_PASSED + 1 ))
        CKA_SIM_GRADE_PASSES+=("pod/cp-toolbox targets control-plane node label")
        ok "pod/cp-toolbox targets control-plane node label"
      else
        CKA_SIM_GRADE_FAILS+=("pod/cp-toolbox missing control-plane node selector")
        err "pod/cp-toolbox missing control-plane node selector"
        cka_sim::grade::record_trap "$trap_id"
      fi
      cka_sim::dump::assert_field pod cp-toolbox '{.spec.tolerations[0].key}' 'node-role.kubernetes.io/control-plane' "$trap_id" -n "$CKA_SIM_LAB_NS"
      ;;
    03)
      cka_sim::dump::assert_changed statefulset queue "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_field statefulset queue '{.spec.replicas}' '1' "$trap_id" -n "$CKA_SIM_LAB_NS"
      ;;
    04)
      cka_sim::dump::assert_authored pod q04-client "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_field pod q04-client '{.spec.containers[0].readinessProbe.tcpSocket.port}' '80' "$trap_id" -n "$CKA_SIM_LAB_NS"
      ;;
    06)
      cka_sim::dump::assert_authored pv q06-data-pv "$trap_id"
      cka_sim::dump::assert_authored pvc q06-data "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_authored pod q06-reader "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_field pod q06-reader '{.spec.volumes[0].persistentVolumeClaim.claimName}' 'q06-data' "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_field pod q06-reader '{.spec.containers[0].volumeMounts[0].mountPath}' '/data' "$trap_id" -n "$CKA_SIM_LAB_NS"
      ;;
    09)
      cka_sim::dump::assert_authored pod manual-nginx "$trap_id" -n "$CKA_SIM_LAB_NS"
      expected_node="$(kubectl get configmap q09-scheduler-sim -n "$CKA_SIM_LAB_NS" -o jsonpath='{.data.targetNode}' 2>/dev/null)"
      cka_sim::dump::assert_field pod manual-nginx '{.spec.nodeName}' "$expected_node" "$trap_id" -n "$CKA_SIM_LAB_NS"
      ;;
    10)
      cka_sim::dump::assert_authored serviceaccount audit-reader "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_authored role audit-reader "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_authored rolebinding audit-reader "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::grade::assert_can_i list pods -n "$CKA_SIM_LAB_NS" --as "system:serviceaccount:$CKA_SIM_LAB_NS:audit-reader" || cka_sim::grade::record_trap "$trap_id"
      ;;
    11)
      cka_sim::dump::assert_authored daemonset node-log-agent "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_field daemonset node-log-agent '{.spec.template.spec.tolerations[0].key}' 'node-role.kubernetes.io/control-plane' "$trap_id" -n "$CKA_SIM_LAB_NS"
      ;;
    12)
      cka_sim::dump::assert_authored deployment spread-web "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_field deployment spread-web '{.spec.replicas}' '3' "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_field deployment spread-web '{.spec.template.spec.containers[0].resources.requests.cpu}' '25m' "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_field deployment spread-web '{.spec.template.spec.topologySpreadConstraints[0].topologyKey}' 'kubernetes.io/hostname' "$trap_id" -n "$CKA_SIM_LAB_NS"
      ;;
    13)
      cka_sim::dump::assert_authored pod shared-tools "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_field pod shared-tools '{.spec.containers[0].name}' 'writer' "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_field pod shared-tools '{.spec.containers[1].name}' 'reader' "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_field pod shared-tools '{.spec.volumes[0].name}' 'shared' "$trap_id" -n "$CKA_SIM_LAB_NS"
      ;;
    18)
      cka_sim::dump::assert_changed configmap kubelet-flags "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_field configmap kubelet-flags '{.data.runtimeEndpoint}' 'unix:///run/containerd/containerd.sock' "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_field configmap kubelet-flags '{.data.status}' 'repaired' "$trap_id" -n "$CKA_SIM_LAB_NS"
      ;;
    19)
      cka_sim::dump::assert_authored secret app-credentials "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_authored pod secret-reader "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_field pod secret-reader '{.spec.volumes[0].secret.secretName}' 'app-credentials' "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_field pod secret-reader '{.spec.containers[0].volumeMounts[0].mountPath}' '/etc/secret-data' "$trap_id" -n "$CKA_SIM_LAB_NS"
      ;;
    21)
      cka_sim::dump::assert_authored configmap q21-static-manifest "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_authored service static-web "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_field configmap q21-static-manifest '{.data.source}' 'file' "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_field service static-web '{.spec.selector.app}' 'static-web' "$trap_id" -n "$CKA_SIM_LAB_NS"
      ;;
    24)
      cka_sim::dump::assert_authored networkpolicy frontend-egress "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_field networkpolicy frontend-egress '{.spec.podSelector.matchLabels.app}' 'frontend' "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_field networkpolicy frontend-egress '{.spec.policyTypes[0]}' 'Egress' "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_field networkpolicy frontend-egress '{.spec.egress[0].ports[0].port}' '443' "$trap_id" -n "$CKA_SIM_LAB_NS"
      ;;
    25)
      cka_sim::dump::assert_authored secret q25-etcd-snapshot "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_authored configmap q25-restore-plan "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_field configmap q25-restore-plan '{.data.dataDir}' '/tmp/q25-etcd-restore' "$trap_id" -n "$CKA_SIM_LAB_NS"
      ;;
    27)
      cka_sim::dump::assert_authored serviceaccount api-caller "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_authored pod api-curl "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_authored configmap q27-answer "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_field pod api-curl '{.spec.serviceAccountName}' 'api-caller' "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_field configmap q27-answer '{.data.apiPath}' '/api' "$trap_id" -n "$CKA_SIM_LAB_NS"
      ;;
    29)
      cka_sim::dump::assert_authored pod p2-pod "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_authored service p2-service "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_authored configmap q29-answer "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_field service p2-service '{.spec.ports[0].port}' '3000' "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_field configmap q29-answer '{.data.proxyMode}' 'iptables' "$trap_id" -n "$CKA_SIM_LAB_NS"
      ;;
    30)
      cka_sim::dump::assert_authored pod check-ip "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_authored service check-ip-service "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_authored configmap q30-answer "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_field service check-ip-service '{.spec.selector.app}' 'check-ip' "$trap_id" -n "$CKA_SIM_LAB_NS"
      cka_sim::dump::assert_field configmap q30-answer '{.data.serviceName}' 'check-ip-service' "$trap_id" -n "$CKA_SIM_LAB_NS"
      ;;
    *) cka_sim::grade::record_trap "$trap_id" ;;
  esac
  cka_sim::grade::emit_result
}

cka_sim::dump::ref_solution() {
  local q="$1"
  case "$q" in
    01) kubectl create configmap q01-answer -n "$CKA_SIM_LAB_NS" \
    --from-literal=contexts="current-lab" \
    --from-literal=currentContext="current-lab" \
    --from-literal=noKubectlSource="kubeconfig-current-context" \
    --dry-run=client -o yaml | kubectl apply -f - ;;
    02) kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: cp-toolbox
  namespace: ${CKA_SIM_LAB_NS}
spec:
  nodeSelector:
    node-role.kubernetes.io/control-plane: ""
  tolerations:
    - key: node-role.kubernetes.io/control-plane
      operator: Exists
      effect: NoSchedule
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
EOF
      ;;
    03) kubectl scale statefulset queue -n "$CKA_SIM_LAB_NS" --replicas=1 ;;
    04) kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: q04-client
  namespace: ${CKA_SIM_LAB_NS}
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      readinessProbe:
        tcpSocket:
          port: 80
        initialDelaySeconds: 1
        periodSeconds: 5
EOF
      ;;
    05) kubectl create configmap q05-answer -n "$CKA_SIM_LAB_NS" \
    --from-literal=sortedPods="api,batch,worker" \
    --dry-run=client -o yaml | kubectl apply -f - ;;
    06) kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: q06-data-pv
spec:
  capacity:
    storage: 1Gi
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /tmp/cka-sim/q06-data
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: q06-data
  namespace: ${CKA_SIM_LAB_NS}
spec:
  storageClassName: manual
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: q06-reader
  namespace: ${CKA_SIM_LAB_NS}
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: q06-data
EOF
      ;;
    07) kubectl create configmap q07-answer -n "$CKA_SIM_LAB_NS" \
    --from-literal=largestPodCpu="q07-heavy" \
    --from-literal=largestNodeCpu="worker-a" \
    --dry-run=client -o yaml | kubectl apply -f - ;;
    08) kubectl create configmap q08-answer -n "$CKA_SIM_LAB_NS" \
    --from-literal=component="kube-apiserver" \
    --from-literal=namespace="kube-system" \
    --from-literal=securePort="6443" \
    --dry-run=client -o yaml | kubectl apply -f - ;;
    09) node="$(kubectl get configmap q09-scheduler-sim -n "$CKA_SIM_LAB_NS" -o jsonpath='{.data.targetNode}')"; kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: manual-nginx
  namespace: ${CKA_SIM_LAB_NS}
spec:
  nodeName: ${node}
  containers:
    - name: app
      image: nginx:1.27-alpine
EOF
      ;;
    10) kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: audit-reader
  namespace: ${CKA_SIM_LAB_NS}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: audit-reader
  namespace: ${CKA_SIM_LAB_NS}
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: audit-reader
  namespace: ${CKA_SIM_LAB_NS}
subjects:
  - kind: ServiceAccount
    name: audit-reader
    namespace: ${CKA_SIM_LAB_NS}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: audit-reader
EOF
      ;;
    11) kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-log-agent
  namespace: ${CKA_SIM_LAB_NS}
spec:
  selector:
    matchLabels:
      app: node-log-agent
  template:
    metadata:
      labels:
        app: node-log-agent
    spec:
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
      containers:
        - name: app
          image: busybox:1.36
          command: ["sh", "-c", "sleep 3600"]
EOF
      ;;
    12) kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spread-web
  namespace: ${CKA_SIM_LAB_NS}
spec:
  replicas: 3
  selector:
    matchLabels:
      app: spread-web
  template:
    metadata:
      labels:
        app: spread-web
    spec:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app: spread-web
      containers:
        - name: web
          image: nginx:1.27-alpine
          resources:
            requests:
              cpu: 25m
              memory: 32Mi
EOF
      ;;
    13) kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: shared-tools
  namespace: ${CKA_SIM_LAB_NS}
spec:
  containers:
    - name: writer
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      volumeMounts:
        - name: shared
          mountPath: /shared
    - name: reader
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      volumeMounts:
        - name: shared
          mountPath: /shared
  volumes:
    - name: shared
      emptyDir: {}
EOF
      ;;
    14) kubectl create configmap q14-answer -n "$CKA_SIM_LAB_NS" \
    --from-literal=nodeCount="3" \
    --from-literal=controlPlaneVersion="v1.35.0" \
    --dry-run=client -o yaml | kubectl apply -f - ;;
    15) kubectl create configmap q15-answer -n "$CKA_SIM_LAB_NS" \
    --from-literal=warningReason="FailedScheduling" \
    --from-literal=involvedObject="q15-pending" \
    --dry-run=client -o yaml | kubectl apply -f - ;;
    16) kubectl create configmap q16-answer -n "$CKA_SIM_LAB_NS" \
    --from-literal=namespace="metadata" \
    --from-literal=namespacedKind="configmaps" \
    --dry-run=client -o yaml | kubectl apply -f - ;;
    17) kubectl create configmap q17-answer -n "$CKA_SIM_LAB_NS" \
    --from-literal=container="sidecar" \
    --from-literal=image="busybox:1.36" \
    --from-literal=command="sleep" \
    --dry-run=client -o yaml | kubectl apply -f - ;;
    18) kubectl create configmap kubelet-flags -n "$CKA_SIM_LAB_NS" --from-literal=runtimeEndpoint='unix:///run/containerd/containerd.sock' --from-literal=status=repaired --dry-run=client -o yaml | kubectl apply -f - ;;
    19) kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: app-credentials
  namespace: ${CKA_SIM_LAB_NS}
stringData:
  password: correct-horse
---
apiVersion: v1
kind: Pod
metadata:
  name: secret-reader
  namespace: ${CKA_SIM_LAB_NS}
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      volumeMounts:
        - name: secret-data
          mountPath: /etc/secret-data
  volumes:
    - name: secret-data
      secret:
        secretName: app-credentials
EOF
      ;;
    20) kubectl create configmap q20-answer -n "$CKA_SIM_LAB_NS" \
    --from-literal=firstStep="kubeadm-upgrade-plan" \
    --from-literal=joinMode="dry-run-token-review" \
    --dry-run=client -o yaml | kubectl apply -f - ;;
    21) kubectl create configmap q21-static-manifest -n "$CKA_SIM_LAB_NS" --from-literal=source=file --dry-run=client -o yaml | kubectl apply -f -; kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: static-web
  namespace: ${CKA_SIM_LAB_NS}
spec:
  selector:
    app: static-web
  ports:
    - port: 80
      targetPort: 80
EOF
      ;;
    22) kubectl create configmap q22-answer -n "$CKA_SIM_LAB_NS" \
    --from-literal=certName="kube-apiserver" \
    --from-literal=validUntil="2030-05-28" \
    --from-literal=signer="kubernetes" \
    --dry-run=client -o yaml | kubectl apply -f - ;;
    23) kubectl create configmap q23-answer -n "$CKA_SIM_LAB_NS" \
    --from-literal=clientIssuer="kubernetes-ca" \
    --from-literal=servingEku="server-auth" \
    --dry-run=client -o yaml | kubectl apply -f - ;;
    24) kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-egress
  namespace: ${CKA_SIM_LAB_NS}
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
    - Egress
  egress:
    - ports:
        - protocol: TCP
          port: 443
EOF
      ;;
    25) kubectl create secret generic q25-etcd-snapshot -n "$CKA_SIM_LAB_NS" --from-literal=snapshot=saved --dry-run=client -o yaml | kubectl apply -f -; kubectl create configmap q25-restore-plan -n "$CKA_SIM_LAB_NS" --from-literal=dataDir=/tmp/q25-etcd-restore --dry-run=client -o yaml | kubectl apply -f - ;;
    26) kubectl create configmap q26-answer -n "$CKA_SIM_LAB_NS" \
    --from-literal=firstEvicted="besteffort-low" \
    --from-literal=lastEvicted="guaranteed-critical" \
    --dry-run=client -o yaml | kubectl apply -f - ;;
    27) kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: api-caller
  namespace: ${CKA_SIM_LAB_NS}
---
apiVersion: v1
kind: Pod
metadata:
  name: api-curl
  namespace: ${CKA_SIM_LAB_NS}
spec:
  serviceAccountName: api-caller
  containers:
    - name: curl
      image: curlimages/curl:8.8.0
      command: ["sh", "-c", "sleep 3600"]
EOF
      kubectl create configmap q27-answer -n "$CKA_SIM_LAB_NS" --from-literal=apiPath=/api --dry-run=client -o yaml | kubectl apply -f -
      ;;
    28) kubectl create configmap q28-answer -n "$CKA_SIM_LAB_NS" \
    --from-literal=serverKey="/etc/kubernetes/pki/etcd/server.key" \
    --from-literal=clientAuth="true" \
    --from-literal=snapshotPath="/tmp/cka-sim-etcd-snapshot.db" \
    --dry-run=client -o yaml | kubectl apply -f - ;;
    29) kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: p2-pod
  namespace: ${CKA_SIM_LAB_NS}
  labels:
    app: p2-pod
spec:
  containers:
    - name: web
      image: nginx:1.27-alpine
---
apiVersion: v1
kind: Service
metadata:
  name: p2-service
  namespace: ${CKA_SIM_LAB_NS}
spec:
  selector:
    app: p2-pod
  ports:
    - port: 3000
      targetPort: 80
EOF
      kubectl create configmap q29-answer -n "$CKA_SIM_LAB_NS" --from-literal=proxyMode=iptables --dry-run=client -o yaml | kubectl apply -f -
      ;;
    30) kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: check-ip
  namespace: ${CKA_SIM_LAB_NS}
  labels:
    app: check-ip
spec:
  containers:
    - name: web
      image: httpd:2.4.62-alpine
---
apiVersion: v1
kind: Service
metadata:
  name: check-ip-service
  namespace: ${CKA_SIM_LAB_NS}
spec:
  selector:
    app: check-ip
  ports:
    - port: 80
      targetPort: 80
EOF
      kubectl create configmap q30-answer -n "$CKA_SIM_LAB_NS" --from-literal=serviceName=check-ip-service --dry-run=client -o yaml | kubectl apply -f -
      ;;
  esac
}
