#!/bin/bash
# tests/cases/symptom-diff-deploy-wait.sh — Phase 17 BLG-04
# Locks: the wait gate's regex matches kind=deploy claiming Available=True
# and does NOT match Available=False or non-deploy kinds. No kubectl invocation.
set -euo pipefail

: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set by run.sh}"

# Reproduce the gate logic in isolation: same predicate stack as run_one's
# wait pre-step. No subshell needed; pure bash regex tests.
gate_matches() {
  local tag="$1" kind="$2" jp="$3" expected="$4"
  [[ "$tag" == "E" ]] || return 1
  [[ "$kind" == "deploy" ]] || return 1
  [[ "$jp" =~ ^(status|spec)\.conditions\[\?\(@\.type==\"Available\"\)\]\.status$ ]] || return 1
  [[ "$expected" == "True" ]] || return 1
  return 0
}

# Case 1: deploy + Available=True → match.
if ! gate_matches E deploy 'status.conditions[?(@.type=="Available")].status' True; then
  printf 'FAIL: gate did not match deploy/Available/True\n' >&2
  exit 1
fi

# Case 2: deploy + Available=False → no match (the troubleshooting/03 case).
if gate_matches E deploy 'status.conditions[?(@.type=="Available")].status' False; then
  printf 'FAIL: gate matched Available=False — would waste 90s on coredns/etc\n' >&2
  exit 1
fi

# Case 3: non-deploy (pod) + Available=True → no match.
if gate_matches E pod 'status.conditions[?(@.type=="Available")].status' True; then
  printf 'FAIL: gate matched non-deploy kind\n' >&2
  exit 1
fi

# Case 4: deploy with a different jp (e.g. status.phase) → no match.
if gate_matches E deploy 'status.phase' True; then
  printf 'FAIL: gate matched non-Available jsonpath\n' >&2
  exit 1
fi

# Case 5: deploy + Available=Unknown → no match (only True triggers wait).
if gate_matches E deploy 'status.conditions[?(@.type=="Available")].status' Unknown; then
  printf 'FAIL: gate matched Available=Unknown\n' >&2
  exit 1
fi

# Case 6: R event with deploy + Available-shaped jp → no match (only E events trigger wait).
if gate_matches R deploy 'status.conditions[?(@.type=="Available")].status' True; then
  printf 'FAIL: gate matched R event (only E events should trigger wait)\n' >&2
  exit 1
fi

exit 0
