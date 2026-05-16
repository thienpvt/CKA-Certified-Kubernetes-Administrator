# workloads-scheduling/08-nodeselector-affinity-taints

**Domain:** Workloads & Scheduling  |  **Estimated time:** 9 minutes

Deployment `q08-gpu-sim` in `${CKA_SIM_LAB_NS}` must run exclusively on the cluster's GPU worker node. The lab has tainted the first non-control-plane worker with `gpu=true:NoSchedule`. That worker does NOT yet carry the label `gpu=true`.

## Find your target node

```
kubectl get nodes -l '!node-role.kubernetes.io/control-plane' \
  --no-headers -o jsonpath='{.items[0].metadata.name}'
```

The node printed is the one the lab tainted and the one your replicas must land on. Use this node name wherever `<target-node>` appears below.

## Tasks

1. Label `<target-node>` with `gpu=true`.
2. Modify Deployment `q08-gpu-sim` so every replica:
   - tolerates the `gpu=true:NoSchedule` taint on `<target-node>`.
   - has a required `nodeAffinity` matching the `gpu=true` label (operator `In`).
3. Confirm all replicas land on `<target-node>`.

## Constraints

- Do NOT remove the taint from `<target-node>`.
- Do NOT use `nodeSelector` — use `nodeAffinity` with `requiredDuringSchedulingIgnoredDuringExecution`.
- Keep the image (`busybox:1.36`) and existing `resources.requests`.

## Verify yourself

```
TARGET=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' \
  --no-headers -o jsonpath='{.items[0].metadata.name}')

kubectl get node "$TARGET" -o jsonpath='{.metadata.labels.gpu}'                                # true
kubectl get deploy q08-gpu-sim -n ${CKA_SIM_LAB_NS} \
  -o jsonpath='{.spec.template.spec.tolerations[?(@.key=="gpu")].effect}'                      # NoSchedule
kubectl get pod -n ${CKA_SIM_LAB_NS} -l app=q08-gpu-sim \
  -o jsonpath='{.items[*].spec.nodeName}'                                                      # all $TARGET
```
