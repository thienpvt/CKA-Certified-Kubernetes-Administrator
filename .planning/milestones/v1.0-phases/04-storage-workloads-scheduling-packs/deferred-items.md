# Deferred Items — Phase 04

Items discovered during execution that are out of scope for the current plan.


## 04-16: validate-local.sh python3 interpreter fallback on Windows

**Discovered during:** 04-16 Task 2 verification.

**Symptom:** `bash scripts/validate-local.sh` exits 1 on Windows dev hosts because
`/c/Users/.../WindowsApps/python3` is a Microsoft Store shim that prints
"Python was not found" instead of executing the real Python 3.12 (which is
available as `python`). All YAML files (skeletons + cka-sim) then FAIL the
`python3 -c 'yaml.safe_load'` probe.

**Pre-existing?** Yes — reproduced with `git stash` before Plan 04-16 changes
(23 skeleton files failed). Plan 04-16 only extended the for-dir loop to walk
`cka-sim/` too, bringing the total to 61.

**CI behavior:** Works fine on Ubuntu runners (GitHub Actions). `python3` is
a real interpreter there.

**Deferred fix:** Replace `python3` invocation with a detected interpreter:
```bash
PY=$(command -v python3 || command -v python)
"$PY" -c "import yaml, sys; list(yaml.safe_load_all(open('$f')))"
```
Out of scope for Plan 04-16 (pre-existing, environmental, CI passes).
Track in a future chore plan or Phase 5 polish wave.
