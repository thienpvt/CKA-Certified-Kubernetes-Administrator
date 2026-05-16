# Plan 05-05 Summary — Services-Networking Q04 Ingress path/host

## Completed

- Added `services-networking/04-ingress-path-host` six-file question shape.
- Seeded cluster-scoped `IngressClass/q04-nginx`, backend Deployment, and Service.
- Kept Ingress absent in setup so candidate creates it.
- Added structural grader checks for `ingressClassName`, host, path, and backend service without HTTP probe dependency.
- Added reset cleanup for cluster-scoped `IngressClass/q04-nginx`.
- Added Phase 5 fixture score files for fail/pass expectations.

## Verification

Pending final suite after inline Wave 2 merge batch.
