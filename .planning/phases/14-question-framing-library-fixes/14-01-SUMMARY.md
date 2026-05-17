---
phase: 14-question-framing-library-fixes
plan: 01
status: passed
requirements: [BUG-M07]
files_modified:
  - cka-sim/packs/troubleshooting/02-netpol-dns-egress/question.md
---

# Summary: Plan 14-01 — BUG-M07 Conventions block

## What

Added a `## Conventions` section to `troubleshooting/02-netpol-dns-egress/question.md` between Constraints and Verify-yourself. The new block surfaces the two well-known label selectors the `ref-solution.sh` DNS-allow egress rule depends on but which the candidate-facing question previously withheld.

## Conventions surfaced

- `kube-system` namespace carries `kubernetes.io/metadata.name=kube-system` (auto-applied by the `NamespaceDefaultLabelName` admission plugin).
- CoreDNS pods carry `k8s-app=kube-dns`.

## Acceptance check (all greens)

- `grep -c '^## Conventions$'` returns 1.
- `grep -c 'kubernetes.io/metadata.name=kube-system'` returns 1.
- `grep -c 'k8s-app=kube-dns'` returns 1.
- `grep -c 'NamespaceDefaultLabelName'` returns 1.
- Section order: Tasks → Constraints → Conventions → Verify yourself.
- Total `## ` headings: 4.
- Git diff scope: only `question.md` in the pack changed.

## What was preserved verbatim

- Title (`# Troubleshooting: Pod cannot resolve or reach a backend`).
- Domain/time line.
- Opening paragraph.
- `## Tasks` (3 bullets).
- `## Constraints` (3 bullets — no new constraint added).
- `## Verify yourself` (heading + 2 code fences + "Both commands must exit 0.").

## Files NOT modified

- `setup.sh`, `grade.sh`, `ref-solution.sh`, `reset.sh`, `metadata.yaml` — untouched.

## BUG-M07 status

Resolved by adding pedagogically honest label disclosure. Candidate can now author the kube-system DNS-allow rule equivalent to the ref-solution from the question text alone.
