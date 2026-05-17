# 10-04-SUMMARY.md — BUG-H04 (cluster-architecture/08-priorityclass)

## File modified
- `cka-sim/packs/cluster-architecture/08-priorityclass/grade.sh` — replaced the q08-critical hard-pin (`assert_field_eq priorityclass q08-critical {.globalDefault} true`) with a new "default PC is in {q08-critical, q08-batch}" allowed-set check. Updated file-level header comment to reflect the new shape.

## Scoring shape change
- BEFORE: 2 weight=1 assertions: (1) `q08-critical.globalDefault==true` (hard-pin — broke for candidates who flipped q08-batch); (2) "exactly one PriorityClass is globalDefault" → max 2 points; candidate flipping q08-batch only scored 1/2.
- AFTER: 2 weight=1 assertions: (1) "exactly one PriorityClass is globalDefault" (preserved); (2) "default PC is in {q08-critical, q08-batch}" (new) → max 2 points; both valid candidate paths reach 2/2.

## Reuse of $names/$count
The new assertion reads `$names` and `$count` populated by the preserved "exactly one" assertion — no extra `kubectl get priorityclass` call. `default_pc=$(printf '%s' "$names" | tr -s '[:space:]' ' ' | sed 's/^ //;s/ $//')` trims to a single token; if `count != 1` then `default_pc` is empty or multi-word, both of which fail the in-set check.

## Verification matrix (predicted; live drill required)
- empty submission (both PCs at globalDefault=false): count=0 → "exactly one" fails → "in allowed set" fails (default_pc empty) → 0/2 + 1 trap (priorityclass-globaldefault-conflict, deduplicated across 2 record_trap call sites).
- candidate flips q08-critical only: count=1, names="q08-critical" → both pass → 2/2 + 0 traps.
- candidate flips q08-batch only: count=1, names="q08-batch" → both pass → 2/2 + 0 traps. **Previously-broken path now fixed (ROADMAP success criterion #4).**
- candidate flips both: count=2 → "exactly one" fails → "in allowed set" fails (multi-token) → 0/2 + 1 trap.
- candidate flips a third PC: count=1, names=that PC → "exactly one" passes; "in allowed set" fails → 1/2 + 1 trap (setup.sh:25 also preflights against this case at seed time).

## Acceptance-criteria notes
All substantive checks pass: hard-pin removed (0), 2 TOTAL+1 increments, 2 PASSED+1 increments, 1 `default_pc=` assignment, 3 `record_trap priorityclass-globaldefault-conflict` call sites (preserved-existence + preserved-exactly-one + new-allowed-set), `emit_result` is the last non-blank line, Phase 10 BUG-H04 mentioned 3 times. The "expected exactly one" message appears 2 times (FAILS array push + err log — pre-existing dual-emit idiom, present in the original file too); "one of {q08-critical, q08-batch}" appears 7 times (4 code paths + 3 doc-comment refs) — both flagged criteria were plan-side undercounts.

## bash -n
Passes.
