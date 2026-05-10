# workloads-scheduling/01-deployment-requests

**Domain:** Workloads & Scheduling  |  **Estimated time:** 7 minutes

A `Deployment` named `load-app` exists in your lab namespace. The platform team has decided that:
- Every workload MUST run under its own dedicated `ServiceAccount` (no shared `default` SA).
- Every container MUST declare CPU and memory `resources.requests` so the scheduler can place it correctly.

## Tasks

1. Inspect the Deployment `load-app` in `${CKA_SIM_LAB_NS}` and the pods it manages.
2. Create a `ServiceAccount` named `load-app-sa` in `${CKA_SIM_LAB_NS}`.
3. Update the Deployment so its pods use `load-app-sa` (not the default).
4. Add `resources.requests.cpu: 50m` and `resources.requests.memory: 64Mi` to the container spec.
5. Wait for the Deployment to be Available with the new pod template.

## Constraints

- Do NOT delete the Deployment — modify it in place (`kubectl edit` / `kubectl patch` / re-`apply`).
- The image must remain `nginx:1.27`.

## Verify yourself

Before typing `done`, confirm:

```
kubectl get sa load-app-sa -n ${CKA_SIM_LAB_NS}
kubectl get deployment load-app -n ${CKA_SIM_LAB_NS} -o jsonpath='{.spec.template.spec.serviceAccountName}'
kubectl get deployment load-app -n ${CKA_SIM_LAB_NS} -o jsonpath='{.spec.template.spec.containers[0].resources.requests}'
```
