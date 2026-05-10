# workloads-scheduling/08-nodeselector-affinity-taints

**Domain:** Workloads & Scheduling  |  **Estimated time:** 9 minutes

Deployment `q08-gpu-sim` in `${CKA_SIM_LAB_NS}` must run exclusively on `node-02`. `node-02` has a taint `gpu=true:NoSchedule` seeded by the lab. `node-02` does NOT yet carry the label `gpu=true`.

## Tasks

1. Label `node-02` with `gpu=true`.
2. Modify Deployment `q08-gpu-sim` so every replica:
   - tolerates the `gpu=true:NoSchedule` taint on `node-02`.
   - has a required `nodeAffinity` matching the `gpu=true` label (operator `In`).
3. Confirm all replicas land on `node-02`.

## Constraints

- Do NOT remove the taint from `node-02`.
- Do NOT use `nodeSelector` — use `nodeAffinity` with `requiredDuringSchedulingIgnoredDuringExecution`.
- Keep the image (`busybox:1.36`) and existing `resources.requests`.

## Verify yourself

```
kubectl get node node-02 -o jsonpath='{.metadata.labels.gpu}'                                    # true
kubectl get deploy q08-gpu-sim -n ${CKA_SIM_LAB_NS} \
  -o jsonpath='{.spec.template.spec.tolerations[?(@.key=="gpu")].effect}'                        # NoSchedule
kubectl get pod -n ${CKA_SIM_LAB_NS} -l app=q08-gpu-sim \
  -o jsonpath='{.items[*].spec.nodeName}'                                                        # all node-02
```
