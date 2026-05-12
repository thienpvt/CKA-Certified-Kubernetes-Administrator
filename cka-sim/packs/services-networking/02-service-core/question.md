# services-networking/02-service-core

**Domain:** Services & Networking  |  **Estimated time:** 7 minutes

A Deployment named `q02-web` is healthy in your lab namespace. A Service named `q02-web` exists, but it has no endpoints and traffic cannot reach the Pods.

## Tasks

1. Inspect the Deployment labels and the Service selector in `${CKA_SIM_LAB_NS}`.
2. Fix the Service so it routes to the existing `q02-web` Pods.
3. Confirm the Service has at least one endpoint address.

## Constraints

- Do NOT modify Deployment labels.
- Fix the Service selector.
- Keep the Service name `q02-web`.

## Verify yourself

Before typing `done`, confirm:

```bash
kubectl get deploy q02-web -n ${CKA_SIM_LAB_NS} --show-labels
kubectl get service q02-web -n ${CKA_SIM_LAB_NS} -o yaml
kubectl get endpoints q02-web -n ${CKA_SIM_LAB_NS}
```
