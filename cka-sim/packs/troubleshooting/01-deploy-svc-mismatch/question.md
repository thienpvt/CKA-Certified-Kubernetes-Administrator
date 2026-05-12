# Troubleshooting: Service has no endpoints

**Domain:** Troubleshooting  |  **Estimated time:** 7 minutes

A `Deployment` named `web` and a `Service` named `web-svc` exist in your lab namespace. Users report they cannot reach the Service. The pods are Running but the Service is not routing traffic.

## Tasks

1. Inspect the `Deployment` `web`, its Pods, and the `Service` `web-svc` in `${CKA_SIM_LAB_NS}`.
2. Diagnose why `Service web-svc` has no endpoints despite the Deployment's Pods being Ready.
3. Modify the `Service` (not the Deployment) so that the Service routes traffic to the Deployment's Pods.
4. One replica of a sibling workload is also failing with a different symptom; identify and resolve that failure as part of the fix.

## Constraints

- Do NOT modify the Deployment or its pod template.
- Do NOT recreate the Service — patch it in place.
- The Pods should remain unchanged (same spec, same image, same replica count).

## Verify yourself

Before typing `done`, confirm:

```
kubectl get endpoints web-svc -n ${CKA_SIM_LAB_NS}
# ENDPOINTS column should list pod IPs, not <none>
```
