# workloads-scheduling/05-daemonset

**Domain:** Workloads & Scheduling  |  **Estimated time:** 7 minutes

Create a DaemonSet that runs a lightweight agent pod on **every** Ready node in the cluster — including the control-plane.

## Tasks

1. In `${CKA_SIM_LAB_NS}`, create a DaemonSet named `q05-node-agent`.
2. Use image `busybox:1.36` with command `["sh", "-c", "sleep 3600"]`.
3. Ensure the pod tolerates the taints on the control-plane node so it lands there too.
4. Each container must declare non-zero `resources.requests` for CPU and memory.

## Constraints

- Exactly `status.desiredNumberScheduled` must equal the total number of Ready nodes.
- Use a dedicated ServiceAccount (not `default`).
- Do NOT label or taint any nodes.

## Verify yourself

```
kubectl get ds q05-node-agent -n ${CKA_SIM_LAB_NS}
kubectl get nodes -o name | wc -l      # compare with desiredNumberScheduled
kubectl get ds q05-node-agent -n ${CKA_SIM_LAB_NS} \
  -o jsonpath='{.spec.template.spec.tolerations[?(@.key=="node-role.kubernetes.io/control-plane")].operator}'
```
