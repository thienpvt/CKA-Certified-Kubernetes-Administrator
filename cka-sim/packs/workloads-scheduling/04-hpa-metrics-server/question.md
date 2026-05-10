# workloads-scheduling/04-hpa-metrics-server

**Domain:** Workloads & Scheduling  |  **Estimated time:** 9 minutes

A Deployment `q04-load` exists in `${CKA_SIM_LAB_NS}` with CPU and memory requests already set. Platform ops wants it autoscaled. `kubectl top pod` currently fails on this cluster.

## Tasks

1. Make `kubectl top pod -n ${CKA_SIM_LAB_NS} -l app=q04-load` return readings.
2. Create a HorizontalPodAutoscaler `q04-load` targeting Deployment `q04-load`:
   - `minReplicas: 1`
   - `maxReplicas: 5`
   - CPU target: `averageUtilization: 50`
   - `apiVersion: autoscaling/v2`

## Constraints

- Do NOT modify `q04-load` Deployment's resources.requests.
- Installing metrics-server on a kubeadm cluster with self-signed kubelet certs requires extra flags — consult its upstream README.

## Verify yourself

```
kubectl top pod -n ${CKA_SIM_LAB_NS} -l app=q04-load
kubectl get hpa q04-load -n ${CKA_SIM_LAB_NS}
```
