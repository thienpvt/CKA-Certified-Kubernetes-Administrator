# storage/06-pvc-mount-pod

**Domain:** Storage  |  **Estimated time:** 7 minutes

A `PersistentVolumeClaim` named `q06-data` is already Bound in `${CKA_SIM_LAB_NS}`. Its backing volume contains a pre-written file at `/data/marker`.

## Tasks

1. Create a `Deployment` named `q06-reader` in `${CKA_SIM_LAB_NS}`.
2. Each pod in the Deployment must mount `q06-data` **read-only** under `/data`.
3. Use image `nginx:1.27`, `replicas: 1`, and `resources.requests` set to a non-zero cpu + memory.
4. Do NOT let pods run under the default ServiceAccount.

## Constraints

- Do NOT modify `q06-data` or its PV.
- Do NOT set `readOnly: false` or omit it on the volumeMount.
- The Deployment must survive a rollout — the PVC mount must be correct.

## Verify yourself

```
kubectl get deploy q06-reader -n ${CKA_SIM_LAB_NS}
kubectl exec -n ${CKA_SIM_LAB_NS} deploy/q06-reader -- cat /data/marker
```

The `cat` command should print `q06-marker`.
