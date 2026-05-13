#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

source "$CKA_SIM_ROOT/lib/setup.sh"

CKA_SIM_PACK="cluster-architecture"
CKA_SIM_QUESTION_ID="cluster-architecture-priorityclass"
sandbox="/tmp/q08-priorityclass"

cka_sim::setup::ensure_lab_ns "$CKA_SIM_LAB_NS" "$CKA_SIM_PACK" "$CKA_SIM_QUESTION_ID"
cka_sim::setup::wait_for_ns_active "$CKA_SIM_LAB_NS" "$CKA_SIM_PACK" "$CKA_SIM_QUESTION_ID"
mkdir -p "$sandbox"
touch "$sandbox/.cka-sim-sentinel"

# Preflight: refuse to seed if the cluster already carries a globalDefault
# PriorityClass that is not part of this pack. Without this guard, the scoring
# oracle ("exactly one globalDefault") would silently resolve to a non-q08 PC
# (e.g. a customised system-cluster-critical) and the drill would pass before
# the candidate ever touches it. Stock kubeadm v1.35 ships no globalDefault by
# default, so this is a fast no-op on a clean cluster.
existing=$(kubectl get priorityclass \
  -o jsonpath='{range .items[?(@.globalDefault==true)]}{.metadata.name}{" "}{end}' 2>/dev/null || echo "")
for token in $existing; do
  [[ -z "$token" ]] && continue
  if [[ "$token" != q08-* ]]; then
    die "setup: cluster already owns a globalDefault PriorityClass '$token' outside this pack; refusing to seed the q08 drill because the scoring oracle requires exactly one globalDefault to come from q08-critical or q08-batch"
  fi
done

# Seed both q08 PriorityClasses with globalDefault=false. This is the
# reachable broken state: grade.sh requires count==1, so count==0 fails and
# records the priorityclass-globaldefault-conflict trap. The candidate flips
# exactly one PC to globalDefault=true to reach the pass state.
kubectl apply -f - <<'EOF'
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: q08-critical
  labels:
    cka-sim/pack: cluster-architecture
    cka-sim/question-id: cluster-architecture-priorityclass
value: 2000000
globalDefault: false
description: "High-priority for critical workloads"
EOF

kubectl apply -f - <<'EOF'
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: q08-batch
  labels:
    cka-sim/pack: cluster-architecture
    cka-sim/question-id: cluster-architecture-priorityclass
value: 100
globalDefault: false
description: "Batch workloads"
EOF

# Post-seed assertion: broken state must have zero globalDefault PCs, otherwise
# grade-on-broken would not fire the trap and the drill would be unscorable.
# Uses the storage/03 canonical idiom (jsonpath space-stream + wc -w) for
# consistency with the grader. setup.sh is not under the GRADE-02 `kubectl get
# | grep` ban, but keeping the same idiom across the corpus is intentional.
after=$(kubectl get priorityclass \
  -o jsonpath='{range .items[?(@.globalDefault==true)]}{.metadata.name}{" "}{end}' 2>/dev/null || echo "")
after_count=$(printf '%s' "$after" | wc -w | tr -d ' ')
if [[ "$after_count" != "0" ]]; then
  die "setup: expected 0 q08 PriorityClasses with globalDefault=true after seed; got $after_count ('$after'). Broken state not reachable; aborting."
fi
