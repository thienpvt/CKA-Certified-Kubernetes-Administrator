# services-networking/04-ingress-path-host

**Domain:** Services & Networking  |  **Estimated time:** 8 minutes

A Service named `q04-web` backs a healthy Deployment in your lab namespace. An IngressClass named `q04-nginx` exists cluster-wide.

## Tasks

1. Create an Ingress named `q04-web` in `${CKA_SIM_LAB_NS}`.
2. Route host `api.example.local` and path `/` to Service `q04-web` port `80`.
3. Reference the IngressClass with `spec.ingressClassName: q04-nginx`.

## Constraints

- Use `networking.k8s.io/v1` Ingress.
- Use `ingressClassName`; do not rely on the legacy `kubernetes.io/ingress.class` annotation.
- Do not modify the Deployment or Service.

## Verify yourself

Before typing `done`, confirm:

```bash
kubectl get ingress q04-web -n ${CKA_SIM_LAB_NS} -o yaml
kubectl get ingressclass q04-nginx
```
