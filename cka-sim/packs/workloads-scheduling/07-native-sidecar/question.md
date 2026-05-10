# workloads-scheduling/07-native-sidecar

**Domain:** Workloads & Scheduling  |  **Estimated time:** 8 minutes

A Deployment `q07-app` in `${CKA_SIM_LAB_NS}` has a sidecar that tails a log file. The sidecar is currently declared in the wrong place for v1.35. Fix it.

## Tasks

1. Inspect `q07-app` pod spec and note how the `log-tailer` container is declared.
2. Convert the sidecar to the v1.35 canonical form (native sidecar via `initContainers` with a specific `restartPolicy`).
3. Keep the app container in `spec.containers` with image `nginx:1.27`. Keep the sidecar with image `busybox:1.36` running `tail -f /shared/app.log` (or the equivalent echo loop used at setup).

## Constraints

- After your change, `spec.containers` has exactly 1 entry (the app).
- `spec.initContainers[log-tailer].restartPolicy` must be `Always` (native sidecar shape).

## Verify yourself

```
kubectl get deploy q07-app -n ${CKA_SIM_LAB_NS} \
  -o jsonpath='{.spec.template.spec.initContainers[?(@.name=="log-tailer")].restartPolicy}'   # Always
kubectl get deploy q07-app -n ${CKA_SIM_LAB_NS} \
  -o jsonpath='{.spec.template.spec.containers[*].name}'   # app  (exactly one name)
```
