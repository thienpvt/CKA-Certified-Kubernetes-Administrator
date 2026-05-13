#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

source "$CKA_SIM_ROOT/lib/setup.sh"

CKA_SIM_PACK="cluster-architecture"
CKA_SIM_QUESTION_ID="cluster-architecture-pss-enforce"
sandbox="/tmp/q04-pss-enforce"

cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" "$CKA_SIM_PACK" "$CKA_SIM_QUESTION_ID"
kubectl label namespace "$CKA_SIM_LAB_NS" \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=v1.35 \
  --overwrite
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" "$CKA_SIM_PACK" "$CKA_SIM_QUESTION_ID"

mkdir -p "$sandbox"
touch "$sandbox/.cka-sim-sentinel"

# Step A — Reference violator Pod (setup-owned). Captures apiserver's PSS
# rejection wording for a bare privileged Pod. Writing a Pod (not a Deployment)
# guarantees the documented `pods "<name>" is forbidden: violates PodSecurity
# "restricted:v1.35":` wording that grade.sh's regex consumes. Deployments
# produce `Warning: would violate PodSecurity` wording instead — grade.sh now
# accepts both, but the canonical capture remains a bare Pod.
cat > "$sandbox/ref-violator-pod.yaml" <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: q04-ref-violator
  namespace: ${CKA_SIM_LAB_NS}
spec:
  containers:
    - name: app
      image: nginx:1.27-alpine
      securityContext:
        privileged: true
EOF

# `|| true` is mandatory: apiserver rejects a bare privileged Pod under
# restricted PSS with non-zero exit; the evidence is in the log, and
# `set -euo pipefail` would otherwise abort setup here.
kubectl apply --dry-run=server -f "$sandbox/ref-violator-pod.yaml" 2>&1 \
  | tee "$sandbox/violator-admission.log" >/dev/null || true

# Step B — q04-compliant Deployment (unchanged shape) + Available wait so the
# grader's readyReplicas assertion is no longer racy.
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: q04-compliant
  namespace: ${CKA_SIM_LAB_NS}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: q04-compliant
  template:
    metadata:
      labels:
        app: q04-compliant
    spec:
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: app
          image: nginxinc/nginx-unprivileged:1.27-alpine
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
EOF

# Trailing `|| true` keeps a slow cluster from failing setup — grade.sh does
# the final readyReplicas check and is the authority on pass/fail.
kubectl wait --for=condition=Available deployment/q04-compliant \
  -n "$CKA_SIM_LAB_NS" --timeout=120s >/dev/null 2>&1 || true

# Step C — Candidate submission stub. Candidate edits this file; grade.sh runs
# the registered detectors (detect_pss_error_string_mismatch +
# detect_psp_fictional_pod_label_exemption) against its raw text. The stub
# embeds both trap triggers in broken state:
#   1) legacy PodSecurityPolicy wording (in a # comment — the deprecated-string
#      lint comment carveout permits this; the detector fires on raw text regardless
#      of YAML comment semantics because it operates on grep -F over the file).
#   2) pod-security.kubernetes.io/exempt: "true" at metadata.labels level — the
#      documented fictional exemption; detect_psp_fictional_pod_label_exemption
#      matches /pod-security\.kubernetes\.io\/exempt[: ]/.
# Ref-solution overwrites this file with a compliant Pod (no triggers). Traps
# go silent and grade reaches 5/5.
cat > "$sandbox/candidate-violator.yaml" <<EOF
# Legacy wording reference — remove before submitting. Replacing PodSecurityPolicy
# with the v1.25+ PodSecurity admission is the goal of this question.
# Do NOT attempt a pod-level pod-security.kubernetes.io/exempt label: no such
# label bypasses PSS — exemptions are cluster-wide AdmissionConfiguration.
apiVersion: v1
kind: Pod
metadata:
  name: q04-candidate
  namespace: ${CKA_SIM_LAB_NS}
  labels:
    app: q04-candidate
    pod-security.kubernetes.io/exempt: "true"
spec:
  containers:
    - name: app
      image: nginx:1.27-alpine
      securityContext:
        privileged: true
EOF

# Informational check — not fatal. An empty log indicates PSS may not be
# enforcing as expected, which is a cluster-level issue, not a setup bug.
[[ -s "$sandbox/violator-admission.log" ]] \
  || warn "setup: violator-admission.log is empty — PSS admission may not be enforcing as expected"
