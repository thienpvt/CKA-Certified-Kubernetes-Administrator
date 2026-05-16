# Troubleshooting Pack

**Domain:** Troubleshooting (30% of CKA blueprint v1.35) — PACK-05.

Progressive difficulty ramp from Service/Deployment label diagnosis to sandboxed kubelet-flag-file repair.

## Questions

| # | Slug | Tracker slug | Time |
|---|------|--------------|------|
| 01 | [deploy-svc-mismatch](01-deploy-svc-mismatch/) | service-endpoints + imagepullbackoff-diagnosis | 7 min |
| 02 | [netpol-dns-egress](02-netpol-dns-egress/) | troubleshoot-netpol | 8 min |
| 03 | [coredns-resolution](03-coredns-resolution/) | troubleshoot-coredns | 8 min |
| 04 | [debug-node](04-debug-node/) | debug-kubectl-node | 9 min |
| 05 | [static-pod-manifest](05-static-pod-manifest/) | control-plane-pod-logs + pending-pods + crashloop-diagnosis | 10 min |
| 06 | [broken-kubelet](06-broken-kubelet/) | kubelet-journalctl | 11 min |

Pack total: 6 questions, ~53 min.

## Host-safety contract

- Per-question sandbox paths live under `/tmp/qNN-*/` for host-file-style drills.
- No script writes into `/var/lib/kubelet/`, `/etc/kubernetes/`, or `/etc/kubernetes/manifests/`.
- No script invokes `systemctl`.
- No script mutates any object in `kube-system`; CoreDNS troubleshooting uses a lab-namespace CoreDNS surface.

## Authoring

See `cka-sim/AUTHORING.md` for the question authoring contract.

## Running

```bash
cka-sim drill troubleshooting          # random question
cka-sim drill troubleshooting 1        # 1-based index into manifest.yaml
```

> Not real CKA exam content; independently authored.
