# 11-02-SUMMARY.md — BUG-H06 (troubleshooting/05-static-pod-manifest)

## Files modified
- `cka-sim/packs/troubleshooting/05-static-pod-manifest/question.md` — title and lead paragraph rewritten to match what the grader actually scores (YAML parse + kind=Pod + client dry-run). Tasks, Constraints (with single-quoted path tokens per plan acceptance criteria), and Verify-yourself sections preserved.

## Files NOT modified (verified in Task 3)
- `cka-sim/packs/troubleshooting/05-static-pod-manifest/grade.sh` — already correctly scores YAML repair (3 weight=1 assertions: parseable + kind=Pod + dry-run); no `kubectl wait`, no `/etc/kubernetes/manifests/`, no `condition=Ready` references.
- `cka-sim/packs/troubleshooting/05-static-pod-manifest/setup.sh` — correctly seeds `manifest-broken.yaml` (tab indent at line 35) + `manifest-tagtypo.yaml` (image `nginx:1.27-alpine-doesnotexistXYZ`) and copies the broken variant into the live `manifest.yaml`.
- `cka-sim/packs/troubleshooting/05-static-pod-manifest/ref-solution.sh` — overwrites `manifest.yaml` with a valid Pod (correct indent, `nginx:1.27-alpine`); no Running-wait, no `/etc/kubernetes/manifests/` side effect.
- `cka-sim/packs/troubleshooting/05-static-pod-manifest/reset.sh` — namespace + per-question tmp cleanup intact.
- `cka-sim/packs/troubleshooting/05-static-pod-manifest/metadata.yaml` — verification-first task confirmed there is no `description:` or `summary:` field with stale framing; identity fields, trap list (3 entries), and references unchanged. No edit needed.

## Reframing
Pre-fix:
- Title: "Static pod never becomes Running" (claims kubelet pickup behavior).
- Lead paragraph: "When manifest is placed in node-agent static workload directory, intended Pod q05-cache never appears in `kubectl get pods -A` or never reaches Running. Repair sandbox manifest so that when the node agent picks it up, Pod reaches Running."

Post-fix:
- Title: "Repair the static-pod manifest".
- Lead paragraph (1): describes intentional defects (tab-indented YAML + image-tag typo).
- Lead paragraph (2): repair the file in place so it is (a) valid YAML, (b) defines a single Pod named `q05-cache` in `kube-system`, and (c) passes client dry-run. Explicitly states "The grader scores the file directly — it does NOT install the manifest into `/etc/kubernetes/manifests/` or wait for a Running Pod."

Skill named now matches skill graded.

## Pedagogy preservation
- Manifest's `metadata.namespace: kube-system` (in setup.sh seeded variants) preserves the static-pod context.
- Constraint "Do NOT place manifest into '/etc/kubernetes/manifests/'" still hints at where a real static pod would live.
- Tasks list bullet 1 ("identify why it cannot produce a Running Pod") is preserved verbatim — it remains a valid hint about WHY the file is broken without claiming the grader checks Running.

## Verification (predicted; live drill required)
- ref-solution: SCORE 3/3 (parse + kind=Pod + dry-run all pass), 0 traps.
- empty submission (untouched broken tab-indent variant): SCORE 0/3, 1 trap (`static-pod-manifest-bad-yaml` fires from both the YAML-parse fail at line 43 and the image-extract fail at line 83 — `record_trap` dedups, so only 1 trap is reported).
- All scripts pass `bash -n` (none modified by this plan).
- metadata.yaml YAML parse OK.

## Static acceptance-criteria summary
All Task 1-3 acceptance greps pass. False positives noted:

1. **Plan Task 1 single-quote vs backtick mismatch on Constraints**: the plan's `<action>` block specified that constraints (Do NOT place manifest into '/etc/kubernetes/manifests/' / 'metadata.name' must remain 'q05-cache') would be "kept verbatim" but the acceptance criteria require single quotes around path/identifier tokens. The pre-edit file used backticks; the new constraint lines use single quotes to satisfy the authoritative greps. Other backtick-quoted text inside Sandbox/Tasks/Verify sections kept verbatim.

2. **Plan Task 3 setup.sh greps**: the plan's literal grep `grep -P '\\\\t' "\$sandbox/manifest-broken.yaml"` and `cp "\$sandbox/manifest-broken.yaml" "\$sandbox/manifest.yaml"` returned 0 due to bash quote-escape ambiguity. Direct line-numbered inspection confirms both lines exist verbatim (line 40 tab assertion, line 63 cp). Re-verified with `grep -cF` (fixed-string), each returned 1.

## Out-of-scope finding
The trap entry `default-sa-used` declared in metadata.yaml has no matching `cka_sim::grade::record_trap` call site in grade.sh. CONTEXT.md explicitly defers this to Phase 12 (LINT-01 trap-coverage lint + BUG-M03 orphan cleanup); not addressed by this phase.

`git diff --name-only -- cka-sim/packs/troubleshooting/05-static-pod-manifest/ | sort` lists exactly `question.md` (the only file in this plan's `files_modified`).
