---
phase: 06
reviewed: 2026-05-13
depth: standard
status: resolved
files_reviewed: 41
severity_counts:
  critical: 2
  warning: 3
  info: 0
  total: 5
resolved_commits:
  - e9dc95c  # CR-01
  - 8b2d108  # CR-02
  - 260925c  # WR-01
  - ea8a09b  # WR-02
  - 880c84b  # WR-03
---

# Phase 6 — Code Review

Reviewed Phase 6 Troubleshooting Pack implementation at `standard` depth. Scope: 41 files under `cka-sim/packs/troubleshooting/`, `cka-sim/scripts/lint-packs.sh`, `cka-sim/tests/cases/lint_packs_forbidden_command.sh`, and `cka-sim/traps/catalog.yaml`.

Diff base: `15056ef` (phase-06 ancestor).

## Critical Issues

### CR-01: Q03 grader does not score required external DNS lookup

**File:** `cka-sim/packs/troubleshooting/03-coredns-resolution/grade.sh:33-37`

**Issue:** Required task says both `kubernetes.default.svc.cluster.local` and `www.example.com` must resolve, but external lookup only logs `err`; no `CKA_SIM_GRADE_TOTAL` increment, no fail append, no trap. Candidate can leave external DNS broken and still get full score if internal lookup passes.

**Fix:** Make external lookup a real scored assertion that increments totals, appends pass/fail, and records `coredns-forward-to-invalid-upstream` on failure.

### CR-02: Q04 debug evidence gate can be bypassed with unrelated debug pod

**File:** `cka-sim/packs/troubleshooting/04-debug-node/grade.sh:26-33`

**Issue:** D-10 gate checks for any pod in any namespace with label key `kubectl.kubernetes.io/debug-source`. It does not verify the debug pod targets the current `worker`. Candidate can run `kubectl debug node/<other-node>` or rely on stale unrelated evidence, then write the correct answer via `kubectl get node "$worker"` jsonpath; grade passes without the candidate actually inspecting the required worker host.

**Fix:** Require debug-source label value matching current worker. Use `-l "kubectl.kubernetes.io/debug-source=$worker"` and `--field-selector=status.phase!=Pending` so only pods actually scheduled against the target worker satisfy the gate.

## Warnings

### WR-01: D-04 symptom-only invariant violated by candidate prose

**File:** `cka-sim/packs/troubleshooting/05-static-pod-manifest/question.md:5,7,24,25`

**Issue:** Prompt exposes forbidden/root-cause terms: `kubelet` and `systemctl`. D-04 forbids bare `kubelet`/`kubeadm`/`systemctl`/`CoreDNS`/`NetworkPolicy` tokens in candidate prose. This weakens the troubleshooting diagnosis step.

**Fix:** Replace with symptom-only language:
- `kubelet's static-pod directory` → `node-agent static workload directory`
- `when kubelet picks it up` → `when the node agent picks it up`
- `Do NOT restart kubelet.` → `Do NOT restart node services.`
- `Do NOT run systemctl.` → `Do NOT run live-service restart commands.`

### WR-02: Q05 trap detector swallows Python error, can miss image-tag-typo trap

**File:** `cka-sim/packs/troubleshooting/05-static-pod-manifest/grade.sh:62-69`

**Issue:** `img=$(python3 - "$manifest" <<'PY'`… runs Python via heredoc. If the script fails (parse error, missing module, exit ≠ 0), `$img` ends up empty and the `"$img" == *"doesnotexistXYZ"*` comparison silently misses. The trap `static-pod-image-tag-typo` never fires even when the image is typo'd, and there is no fallback to `static-pod-manifest-bad-yaml` on parse failure.

**Fix:** Wrap the heredoc in an `if …; then; else` so parse failures explicitly record `static-pod-manifest-bad-yaml` and successful runs keep the tag check.

### WR-03: lint pass G misses common forbidden host writes

**File:** `cka-sim/scripts/lint-packs.sh:189-197`

**Issue:** Guard catches `> /etc/kubernetes/` and `> /var/lib/kubelet/`, but misses `>>`, `tee`, quoted destinations, and most `cp`/`install` forms. Host-safety lint can pass scripts that still write forbidden paths.

**Fix:** Expand the deny-list to include `>>` redirection, `tee` (with optional `-a`), and `cp` / `install` targeting `/etc/kubernetes/` or `/var/lib/kubelet/`. Add negative fixtures under `cka-sim/tests/fixtures/lint-packs/` that exercise each new pattern and wire them into `cka-sim/tests/cases/lint_packs_forbidden_command.sh`.

## Coverage

- D-10 debug-evidence gate: present but too permissive (see CR-02).
- D-04 symptom-only invariant: violated in Q05 (see WR-01); every other question.md scrubs the forbidden tokens.
- D-09/D-11/D-12 host-safety: enforced by pass G at lint time but guard coverage is incomplete (see WR-03).
- Trap catalog schema + RFC 1123: 47 entries, zero collisions, `lint-traps.sh` clean.
- YAML metadata schema: every Phase 6 question has `verified_against: "1.35"`, ≥3 traps, ≥1 `references[]` with `cka-sim/packs/…` target.

## Next Steps

Run `/gsd-code-review 06 --fix` to apply the concrete fixes above, then re-run `bash cka-sim/scripts/test.sh`.
