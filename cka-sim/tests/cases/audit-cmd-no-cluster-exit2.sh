#!/bin/bash
# tests/cases/audit-cmd-no-cluster-exit2.sh — Phase 16 BASELINE-01
# Locks: cka-sim audit exits 2 (NOT 0) when no live cluster is reachable.
# The lint-mode counterpart (lint-question-symptom.sh) exits 0 by design;
# audit's contract is exit 2 because it's a forensic tool, not a CI gate.
set -euo pipefail

: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set by run.sh}"

# Build a minimal sandbox PATH so kubectl resolves to a stub that fails
# cluster-info. mktemp instead of relying on the suite stub at
# cka-sim/tests/bin/kubectl: that stub has rich behaviour for grade.sh
# tests; here we only need cluster-info to fail.
sandbox=$(mktemp -d)
cat >"$sandbox/kubectl" <<'STUB'
#!/bin/bash
if [[ "${1:-}" == "cluster-info" ]]; then
  exit 1
fi
# Default: pretend everything else also fails — audit should never reach here.
exit 1
STUB
chmod +x "$sandbox/kubectl"

# Prepend the sandbox so our stub wins over the suite-wide stub.
PATH="$sandbox:$PATH"
export PATH

# Capture: stdout+stderr, rc.
rc=0
out=$(bash "$CKA_SIM_ROOT/bin/cka-sim" audit 2>&1) || rc=$?

# Cleanup before assertions so a failed assertion still cleans the sandbox.
rm -rf "$sandbox"

# Assert rc=2.
if (( rc != 2 )); then
  printf 'FAIL: expected rc=2 for no-cluster audit, got rc=%s\n' "$rc" >&2
  printf 'output was:\n%s\n' "$out" >&2
  exit 1
fi

# Assert stderr message present.
if ! grep -qE 'no live cluster reachable' <<<"$out"; then
  printf 'FAIL: expected "no live cluster reachable" in stderr\n' >&2
  printf 'output was:\n%s\n' "$out" >&2
  exit 1
fi

exit 0
