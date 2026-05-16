# Cluster Architecture Pack

**Domain:** Cluster Architecture, Installation & Configuration (25% of CKA blueprint v1.35)

PACK-04 -- full v1.35 Tracker coverage + CONCERNS.md content replacements: PSS (v1.25+ wording), CRI-dockerd (correct endpoint flag + file), audit-policy, CRD basics, PriorityClass.

## Questions

| #  | question                          | tracker slug            | est. minutes |
| -- | --------------------------------- | ----------------------- | ------------ |
| 01 | [rbac-viewer](01-rbac-viewer/)    | rbac-viewer             | 8            |

<!-- BEGIN phase-05 new questions (P09-P15 append one table row each) -->
| 02 | [etcd-backup-restore](02-etcd-backup-restore/) | etcd-backup-restore | 10 |
| 03 | [kubeadm-upgrade](03-kubeadm-upgrade/) | kubeadm-upgrade | 10 |
| 04 | [pss-enforce](04-pss-enforce/) | pss-enforce | 9 |
| 05 | [audit-policy](05-audit-policy/) | audit-policy | 9 |
| 06 | [crd-basics](06-crd-basics/) | crd-basics | 6 |
| 07 | [cri-dockerd-endpoint](07-cri-dockerd-endpoint/) | cri-dockerd-endpoint | 8 |
| 08 | [priorityclass](08-priorityclass/) | priorityclass | 7 |
<!-- END phase-05 new questions -->

Pack total: 8 questions, ~68 min.

Run all questions: `cka-sim drill cluster-architecture`.

## Authoring

See `cka-sim/AUTHORING.md` for the question authoring contract.

## Running

```bash
cka-sim drill cluster-architecture          # random question
cka-sim drill cluster-architecture 1        # 1-based index into manifest.yaml
```

> Not real CKA exam content; independently authored.
