---
phase: 14-question-framing-library-fixes
plan: 02
status: passed
requirements: [BUG-M08]
files_modified:
  - cka-sim/packs/troubleshooting/03-coredns-resolution/question.md
files_verified_only:
  - cka-sim/packs/troubleshooting/03-coredns-resolution/metadata.yaml
---

# Summary: Plan 14-02 — BUG-M08 two-trap framing

## What

Two surgical edits to `troubleshooting/03-coredns-resolution/question.md`:

1. **Lead paragraph rewrite** — the stale "Other lab namespace infrastructure is running" sentence (which lied about the q03-coredns Deployment being healthy) replaced with concrete acknowledgement: the lab CoreDNS Deployment `q03-coredns` is failing to start AND the upstream forwarder must be fixed.

2. **Tasks list reshape** — three numbered items now map to the two traps that `setup.sh` actually plants:
   1. Stabilise the `q03-coredns` Deployment so its Pod reaches Ready.
   2. Fix the lab CoreDNS upstream forwarder so cluster-internal and external names resolve.
   3. Verify both internal and external names from inside `q03-dnsclient`.

## metadata.yaml verification (no edit applied)

Re-read confirms:
- `grep -cE '^(description|summary):' metadata.yaml` returns 0 (no narrative field exists).
- `grep -c 'Other lab namespace' metadata.yaml` returns 0.
- `grep -c 'infrastructure is running' metadata.yaml` returns 0.

No edit applied. Plan 14-02 leaves `metadata.yaml` untouched.

## Acceptance check (all greens)

- Stale framing removed: `grep -c 'Other lab namespace infrastructure is running'` returns 0.
- New framing present: `grep -c 'failing to start'` returns 1.
- `q03-coredns` named in lead AND Tasks: `grep -c 'q03-coredns'` returns 2.
- `upstream forwarder` named in lead AND Tasks: `grep -c 'upstream forwarder'` returns 2.
- Three Tasks lines match the exact two-trap shape (verified per-line).
- Section order: Tasks → Constraints → Verify yourself (3 H2 headings total).
- Constraints + Verify-yourself + closing line preserved verbatim.
- Git diff scope: only `question.md` in the pack changed.

## Files NOT modified

- `setup.sh`, `grade.sh`, `ref-solution.sh`, `reset.sh` — untouched.
- `metadata.yaml` — verified clean, no edit needed.

## BUG-M08 status

Resolved. Question framing now matches what `setup.sh` actually produces: candidate is clued to both traps (Pod-not-Running AND DNS-fails) instead of just one.
