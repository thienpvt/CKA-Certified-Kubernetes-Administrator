---
plan: 17-02
phase: 17-v1-0-2-backlog-cleanup
requirements: [BLG-02]
status: complete
date: 2026-05-19
---

# Plan 17-02 Summary — BLG-02 unsupported-on-kind flag

## Outcome

Three questions whose `setup.sh` cannot complete on a kind+Calico cluster now ship `unsupported-on-kind: true` in their `metadata.yaml`. The lint and audit drivers honor the flag via a tiny shared helper in `cka-sim/lib/symptom-diff.sh`, skip those questions cleanly, and (for audit) report the skip count in the summary line.

The 3 questions remain VALID for live-cluster drill UAT against the lab cluster (Phase 21 batch); they are excluded only from the kind-based lint/audit harness.

## Files Modified (4) + Created (1)

| File | Change |
|------|--------|
| `cka-sim/packs/cluster-architecture/02-etcd-backup-restore/metadata.yaml` | +2 lines: BLG-02 comment + `unsupported-on-kind: true` (etcd snapshot CLI on CP node). |
| `cka-sim/packs/storage/04-csi-volumesnapshot/metadata.yaml` | +2 lines: BLG-02 comment + `unsupported-on-kind: true` (CSI VolumeSnapshots). |
| `cka-sim/packs/workloads-scheduling/06-static-pod/metadata.yaml` | +2 lines: BLG-02 comment + `unsupported-on-kind: true` (`/etc/kubernetes/manifests/`). |
| `cka-sim/lib/symptom-diff.sh` | New `cka_sim::symptom_diff::is_unsupported_on_kind` helper (pure bash + grep). |
| `cka-sim/scripts/lint-question-symptom.sh` | Skip-with-warn branch using the helper before `checked++`. |
| `cka-sim/lib/cmd/audit.sh` | `_AUDIT_SKIPPED` counter + skip branch + summary segment. |
| `cka-sim/tests/cases/symptom-diff-unsupported-on-kind.sh` | NEW. 5 sub-tests (true / missing / false / no-meta / real-pack count >=3). |

## Helper Signature

```bash
cka_sim::symptom_diff::is_unsupported_on_kind() {
  local q_dir="$1"
  local meta="$q_dir/metadata.yaml"
  [[ -f "$meta" ]] || return 1
  grep -qE '^unsupported-on-kind:[[:space:]]*true[[:space:]]*(#.*)?$' "$meta"
}
```

Pure bash + grep — no python or jq. The `(#.*)?$` tolerates trailing inline comments.

## Audit Summary Line

Before:
```
─── audit summary ───
N/M PASS, K FAIL, L errors
```

After:
```
─── audit summary ───
N/M PASS, K FAIL, L errors, S skipped
```

`$total = _AUDIT_PASS + _AUDIT_FAIL + _AUDIT_ERROR` (skipped questions do not count toward audited total — the skip is structural, not a result).

## Test Suite Delta

| Metric | Before | After |
|--------|--------|-------|
| Total cases | 86 | **87** |
| Passing | 86 | **87** |
| Failing | 0 | **0** |
| `bash cka-sim/scripts/test.sh` exit code | 0 | **0** |

Phase 16 + Plans 17-01 + 17-04 cases all still pass; new BLG-02 case PASSes.

## Acceptance Criteria

| Check | Result |
|-------|--------|
| 3 metadata.yaml files declare `unsupported-on-kind: true` | ✓ All 3 grep-confirmed; rationale comment cites BLG-02 |
| Helper exists in lib + invoked by both drivers | ✓ `is_unsupported_on_kind` referenced in lib + lint script + audit cmd |
| `_AUDIT_SKIPPED` counter wired into summary | ✓ Init + increment + summary line all reference it |
| Lint stays rc=0 on no-cluster Windows host | ✓ Confirmed: warn-skip preflight unchanged |
| Test suite green | ✓ 87/87 pass, exit 0 |

## BLG-02 Closed

Pattern B questions (etcd-backup-restore / csi-volumesnapshot / static-pod) will be skipped cleanly when the GHA `symptom-diff` job re-runs; their absence from the audit total reflects the kind environment limitation, not a question bug.
