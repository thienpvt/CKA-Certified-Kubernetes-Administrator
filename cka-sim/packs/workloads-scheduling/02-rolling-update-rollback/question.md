# workloads-scheduling/02-rolling-update-rollback

**Domain:** Workloads & Scheduling  |  **Estimated time:** 7 minutes

A Deployment `web` in `${CKA_SIM_LAB_NS}` currently runs `nginx:1.25`. Ops asks you to try `nginx:1.27`, verify it works, and — if anything looks wrong — roll back.

## Tasks

1. Update Deployment `web` so its pods run `nginx:1.27`.
2. Wait until the rollout finishes successfully.
3. After verification, roll back one revision so `web` returns to `nginx:1.25`.

## Constraints

- Do NOT delete and recreate the Deployment.
- Rollout must complete without replicas dropping to zero (RollingUpdate strategy is pre-configured).

## Verify yourself

```
kubectl rollout status deployment/web -n ${CKA_SIM_LAB_NS}
kubectl get deploy web -n ${CKA_SIM_LAB_NS} -o jsonpath='{.spec.template.spec.containers[0].image}'   # nginx:1.25
kubectl rollout history deployment/web -n ${CKA_SIM_LAB_NS}
```
