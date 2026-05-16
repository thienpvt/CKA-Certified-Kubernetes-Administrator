# workloads-scheduling/03-configmap-secret-env-volume

**Domain:** Workloads & Scheduling  |  **Estimated time:** 8 minutes

The platform team wires application configuration via a `ConfigMap` and an `API_KEY` secret via a `Secret`. A `ConfigMap` named `q03-app-config` and a `Secret` named `q03-app-secret` already exist in `${CKA_SIM_LAB_NS}`. You must create a Pod that consumes both correctly.

## Tasks

1. Create a Pod named `q03-app` in `${CKA_SIM_LAB_NS}` running image `busybox:1.36` with a long-lived command (e.g. `sleep 3600`).
2. Expose the ConfigMap key `APP_MODE` as an environment variable named `APP_MODE` using `valueFrom.configMapKeyRef` (do **not** hardcode the literal value into the Pod spec).
3. Mount the Secret `q03-app-secret` as a **read-only** volume at `/etc/app-secrets`; the key `API_KEY` must be readable at the path `/etc/app-secrets/api-key`.

## Constraints

- Use `valueFrom.configMapKeyRef` for the env var; do NOT copy the literal value into the Pod spec.
- The Secret volume mount must be read-only (`readOnly: true`).
- Use the Secret `items` projection to rename key `API_KEY` -> file path `api-key` so the file is reachable at `/etc/app-secrets/api-key`.

## Verify yourself

```
kubectl exec -n ${CKA_SIM_LAB_NS} q03-app -- printenv APP_MODE             # production
kubectl exec -n ${CKA_SIM_LAB_NS} q03-app -- cat /etc/app-secrets/api-key  # q03-api-key-value
```
