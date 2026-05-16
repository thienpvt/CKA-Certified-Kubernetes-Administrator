# Plan 05-04 Summary — Services-Networking Q03 CoreDNS resolution

## Completed

- Added `services-networking/03-coredns-resolution` six-file question shape.
- Seeded `q03-dnsclient` with `dnsPolicy: None` and intentionally wrong nameserver `1.1.1.1`.
- Kept setup read-only for `kube-system/coredns`.
- Added grader checks for Pod existence, `dnsPolicy: None`, nslookup success, and `coredns-forward-to-invalid-upstream` trap.
- Added ref solution that discovers `kube-system/kube-dns` ClusterIP and recreates the Pod with correct `dnsConfig.nameservers`.
- Added Phase 5 fixture score files for fail/pass expectations.

## Verification

Pending final suite after inline Wave 2 merge batch.
