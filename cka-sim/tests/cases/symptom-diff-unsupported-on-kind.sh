#!/bin/bash
# tests/cases/symptom-diff-unsupported-on-kind.sh — Phase 17 BLG-02
# Locks: cka_sim::symptom_diff::is_unsupported_on_kind returns 0/1 correctly
# for metadata.yaml flag values: true / missing / false / no-meta.
set -euo pipefail

: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set by run.sh}"

# shellcheck disable=SC1091
source "$CKA_SIM_ROOT/lib/symptom-diff.sh"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

# Case 1: flag=true → helper returns 0.
mkdir -p "$tmp_dir/case-true"
cat >"$tmp_dir/case-true/metadata.yaml" <<'YAML'
id: test-true
unsupported-on-kind: true
YAML
if ! cka_sim::symptom_diff::is_unsupported_on_kind "$tmp_dir/case-true"; then
  printf 'FAIL: helper returned non-zero on flag=true case\n' >&2
  exit 1
fi

# Case 2: flag missing → helper returns 1.
mkdir -p "$tmp_dir/case-missing"
cat >"$tmp_dir/case-missing/metadata.yaml" <<'YAML'
id: test-missing
domain: testing
YAML
if cka_sim::symptom_diff::is_unsupported_on_kind "$tmp_dir/case-missing"; then
  printf 'FAIL: helper returned 0 on flag-missing case\n' >&2
  exit 1
fi

# Case 3: flag=false → helper returns 1.
mkdir -p "$tmp_dir/case-false"
cat >"$tmp_dir/case-false/metadata.yaml" <<'YAML'
id: test-false
unsupported-on-kind: false
YAML
if cka_sim::symptom_diff::is_unsupported_on_kind "$tmp_dir/case-false"; then
  printf 'FAIL: helper returned 0 on flag=false case\n' >&2
  exit 1
fi

# Case 4: metadata.yaml absent → helper returns 1.
mkdir -p "$tmp_dir/case-no-meta"
if cka_sim::symptom_diff::is_unsupported_on_kind "$tmp_dir/case-no-meta"; then
  printf 'FAIL: helper returned 0 when metadata.yaml is absent\n' >&2
  exit 1
fi

# Case 5: real packs sanity check — at least 3 packs are flagged true.
flagged=0
while IFS= read -r q; do
  if cka_sim::symptom_diff::is_unsupported_on_kind "$q"; then
    flagged=$(( flagged + 1 ))
  fi
done < <(find "$CKA_SIM_ROOT/packs" -mindepth 2 -maxdepth 2 -type d | sort)

if (( flagged < 3 )); then
  printf 'FAIL: expected >=3 packs flagged unsupported-on-kind, got %d\n' "$flagged" >&2
  exit 1
fi

exit 0
