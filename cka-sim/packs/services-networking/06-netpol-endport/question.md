# services-networking/06-netpol-endport

**Domain:** Services & Networking  |  **Estimated time:** 7 minutes

A server Pod named `q06-server` listens on TCP ports 8080-8090 in your lab namespace. A client Pod named `q06-client` must be allowed to reach only that inclusive port range.

## Tasks

1. Create a NetworkPolicy named `q06-allow-range` in `${CKA_SIM_LAB_NS}`.
2. Select server Pods with label `app=q06-server`.
3. Allow ingress only from Pods with label `app=q06-client`.
4. Use a single port-range rule with `protocol: TCP`, `port: 8080`, and `endPort: 8090`.

## Constraints

- Use `endPort`; do not write eleven separate port rules.
- Do not modify the Pods or Service.
- Keep traffic outside the 8080-8090 range blocked.

## Verify yourself

Before typing `done`, confirm:

```bash
kubectl get networkpolicy q06-allow-range -n ${CKA_SIM_LAB_NS} -o yaml
kubectl exec -n ${CKA_SIM_LAB_NS} q06-client -- wget -qO- --timeout=3 q06-server:8085
kubectl exec -n ${CKA_SIM_LAB_NS} q06-client -- wget -qO- --timeout=3 q06-server:8095
```

The 8085 probe should work and the 8095 probe should fail. Your CNI must support NetworkPolicy port ranges (`endPort`).
