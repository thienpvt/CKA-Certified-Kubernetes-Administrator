# Services & Networking Pack

**Domain:** Services & Networking (20% of CKA blueprint v1.35) — PACK-03.

Full Services & Networking domain pack with v1.35 Tracker coverage. Slot 01
is the Phase 3 reference question retrofitted in Phase 5 Plan 02 to source
`cka-sim/lib/setup.sh`; slots 02-06 are filled by Phase 5 Plans 03-07.

## Questions

| #  | Slug                     | Tracker slug          | Time   |
| -- | ------------------------ | --------------------- | ------ |
| 01 | [networkpolicy-egress](01-networkpolicy-egress/) | netpol-egress | 9 min  |
<!-- BEGIN phase-05 new questions (P03-P07 append one table row each below this line; idempotent via grep guard) -->
| 06 | [netpol-endport](06-netpol-endport/) | netpol-endport | 7 min |
<!-- END phase-05 new questions -->

Pack total (planned): 6 questions, ~46 min.

## Authoring

See `cka-sim/AUTHORING.md` for the question authoring contract.

## Running

```bash
cka-sim drill services-networking          # random question
cka-sim drill services-networking 1        # 1-based index into manifest.yaml
```

> Not real CKA exam content; independently authored.
