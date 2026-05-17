# 10-02-SUMMARY.md — BUG-H02 (services-networking/05-kube-proxy-mode)

## File modified
- `cka-sim/packs/services-networking/05-kube-proxy-mode/setup.sh` — line 17: `SEED_MODE='ipvs'` → `SEED_MODE='placeholder'` plus a 5-line BUG-H02 comment block above the assignment.

## Why 'placeholder' over 'unknown'
'placeholder' is unambiguously not a kube-proxy mode token. 'unknown' could be misread as a real enum value. The candidate-wrote check (grade.sh:23) is `reported != seeded && both non-empty`. With seeded='placeholder', this holds for every valid candidate write on every cluster (iptables, ipvs, nftables).

## Task 2 sanity scan results
- `SEED_MODE` referenced ONLY in `setup.sh` (3 lines: assignment + sandbox write + sentinel write).
- `ipvs` hits in peer files are all expected: grade.sh enum regex + trap-id literal (lines 48, 53, 58, 60), grade.sh stale header comment (lines 3-5 — pre-existing, refers to old seed value), metadata.yaml trap-id (line 6), question.md valid-enum hint (line 10).
- `.setup-seeded-mode` referenced ONLY in setup.sh (write x2) and grade.sh:18 (read).
- ref-solution.sh writes `$live_mode`, not a literal — unaffected.
- reset.sh has no seed-value references.

## Stale comment caveat
grade.sh lines 3-5 still reference the pre-fix 'ipvs' seed value in a documentation comment. The plan scopes the fix to setup.sh only; the grade.sh header is descriptive and not load-bearing for behaviour. Future cleanup phase can refresh it.

## Verification (predicted; live drill required)
- iptables cluster + ref-solution: candidate writes 'iptables' → reported != seeded ('placeholder') → 3/3
- ipvs cluster + ref-solution: candidate writes 'ipvs' → reported != seeded → 3/3 (the previously-broken case)
- nftables cluster + ref-solution: 3/3
- empty submission on any cluster: reported == seeded ('placeholder') → 0/3
- `bash -n` passes
