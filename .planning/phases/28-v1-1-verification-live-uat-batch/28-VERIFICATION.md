---
phase: 28
status: passed
must_haves_passed: 5
must_haves_total: 5
human_verification_count: 4
gaps: []
---

# Phase 28 Verification

## Result

Passed.

## Automated Evidence

- `C:\Program Files\Git\bin\bash.exe -lc 'cd /c/Users/thien/IdeaProjects/CKA-Certified-Kubernetes-Administrator && python3(){ python "$@"; }; export -f python3; bash cka-sim/scripts/test.sh'` passed:
  - trap catalog lint
  - pack lint
  - coverage lint
  - trap coverage lint
  - deprecated-string lint
  - 91 bash unit cases
  - live symptom diff: 61 question(s) passed

## Live UAT Evidence

- Cluster reachable through kubectl:
  - control plane: `https://35.201.154.225:6443`
  - nodes: `master`, `worker-1`, `worker-2`
  - server version observed on nodes: `v1.35.4`
- `cka-sim/current-tests/v11-dump-empty-uat.txt`:
  - empty-submission sweep passed 30/30 dump questions with `SCORE: 0/N`
- `cka-sim/current-tests/v11-dump-uat.txt`:
  - setup -> baseline -> reference solution -> grade -> reset sweep passed 30/30 dump questions with max score

## Fixes Verified During UAT

- Baseline JSON reads now use stdin so Windows `jq` can read `/tmp/cka-sim/...` paths even when `MSYS2_ARG_CONV_EXCL='*'` is set for kubectl literal paths.
- Baseline lookup in generation/authorship helpers now canonicalizes short kinds such as `pv` and `pvc`.
