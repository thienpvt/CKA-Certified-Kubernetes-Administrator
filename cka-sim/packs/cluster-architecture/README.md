# Cluster Architecture Pack

**Domain:** Cluster Architecture, Installation & Configuration (25% of CKA blueprint v1.35)

PACK-04 -- full v1.35 Tracker coverage + CONCERNS.md content replacements: PSS (v1.25+ wording), CRI-dockerd (correct endpoint flag + file), audit-policy, CRD basics, PriorityClass.

## Questions

| #  | question                          | tracker slug            | est. minutes |
| -- | --------------------------------- | ----------------------- | ------------ |
| 01 | [rbac-viewer](01-rbac-viewer/)    | rbac-viewer             | 8            |

<!-- BEGIN phase-05 new questions (P09-P15 append one table row each) -->
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
