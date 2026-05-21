#!/bin/bash
# cka-sim/tests/cases/symptom-diff-regression.sh — Phase 15 plan 07.
# Synthetic regression: mutate storage/01 expected-symptom.yaml so the
# PVC claim is "Pending" instead of the real "Bound"; run the lint;
# assert exit 1 + the expected citation pattern; restore the file.
#
# Note (v1.0.3): mutation direction flipped from Bound→Pending to Pending→Bound
# after Phase 10 BUG-H01 reshape made the actual post-setup state Bound. Mutating
# the YAML to claim Pending forces lint to detect actual=Bound vs expected=Pending.
#
# This case is source'd by cka-sim/tests/run.sh in a subshell.
# Cluster-info gated: skips with rc=0 when no live cluster is reachable.
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"

target="$CKA_SIM_ROOT/packs/storage/01-pvc-binding/expected-symptom.yaml"
backup="$(mktemp -t symptom-diff-regression.XXXXXX.yaml 2>/dev/null || mktemp)"
cp "$target" "$backup"

cleanup() {
  cp "$backup" "$target" 2>/dev/null || true
  rm -f "$backup"
}
trap cleanup EXIT

if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "[symptom-diff regression] no live cluster — SKIP"
  exit 0
fi

# Mutate: change "status.phase: Bound" -> "status.phase: Pending" for the PVC.
# Only the FIRST occurrence (the PVC entry) — leave the PV entry alone so the
# citation focuses on the PVC line.
if command -v gsed >/dev/null 2>&1; then
  gsed -i '0,/status\.phase: Bound/s//status.phase: Pending/' "$target"
else
  sed -i'.bak' '0,/status\.phase: Bound/s//status.phase: Pending/' "$target" && rm -f "${target}.bak"
fi
if ! grep -q 'status.phase: Pending' "$target"; then
  echo "[symptom-diff regression] FAIL: mutation not applied to $target" >&2
  exit 1
fi

# Run the lint with output capture.
out="$(bash "$CKA_SIM_ROOT/scripts/lint-question-symptom.sh" storage/01-pvc-binding 2>&1 || true)"

# Run again for exit-code capture (lint is idempotent: setup + reset per question).
set +e
bash "$CKA_SIM_ROOT/scripts/lint-question-symptom.sh" storage/01-pvc-binding >/dev/null 2>&1
rc=$?
set -e

if [[ "$rc" -eq 0 ]]; then
  echo "[symptom-diff regression] FAIL: lint exited 0 with mutated YAML; expected 1" >&2
  echo "$out" >&2
  exit 1
fi

if ! echo "$out" | grep -q "expected 'Pending', got 'Bound'"; then
  echo "[symptom-diff regression] FAIL: expected citation \"expected 'Pending', got 'Bound'\" not found" >&2
  echo "$out" >&2
  exit 1
fi

echo "[symptom-diff regression] PASS — lint detected drift"
exit 0
