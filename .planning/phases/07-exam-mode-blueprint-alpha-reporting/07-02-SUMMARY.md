---
phase: 07-exam-mode-blueprint-alpha-reporting
plan: "02"
backfilled: 2026-05-17
source_commit: d54e569
---

# 07-02: Report Renderer

## One-Liner
Markdown score report renderer with per-domain breakdown + trap frequencies; golden test for stable output.

## What Was Built
- `cka-sim/lib/exam-report.sh` — renders 5 sections (header, score, domain breakdown, trap freq, per-question)
- Golden test fixture + diff-based test for output stability

## Verification
Golden test passes. Covered by 07-VERIFICATION.md (REPORT-01 satisfied).

## Self-Check: PASSED
