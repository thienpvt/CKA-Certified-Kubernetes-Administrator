#!/bin/bash
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?must be set by run.sh}"
source "$CKA_SIM_ROOT/tests/lib/assert.sh"

case_failed=0
fixtures="$CKA_SIM_TEST_FIXTURES_DIR/lint-packs"

root=$(mktemp -d -t lint-packs-meta-XXXXXX)
mkdir -p "$root/storage/01-test"
cp "$fixtures/bad-metadata/metadata.yaml" "$root/storage/01-test/metadata.yaml"
cp "$fixtures/good/grade.sh" "$root/storage/01-test/grade.sh"
cp "$fixtures/good/setup.sh" "$root/storage/01-test/setup.sh"
cat > "$root/storage/01-test/reset.sh" <<'EOF'
#!/bin/bash
EOF
cat > "$root/storage/01-test/ref-solution.sh" <<'EOF'
#!/bin/bash
EOF
: > "$root/storage/01-test/question.md"
chmod +x "$root/storage/01-test"/*.sh

out=$(CKA_SIM_LINT_PACKS_DIR="$root" bash "$CKA_SIM_ROOT/scripts/lint-packs.sh" 2>&1; printf '\nRC:%d' $?)
rc="${out##*RC:}"
if [[ "$rc" == "0" ]]; then
  err "bad-metadata fixture: lint-packs exited 0 (expected non-zero)" >&2
  case_failed=1
else
  ok "bad-metadata fixture: lint-packs exits non-zero" >&2
fi
if grep -q 'estimatedMinutes' <<< "$out"; then
  ok "bad-metadata: estimatedMinutes error reported" >&2
else
  err "bad-metadata: expected estimatedMinutes error in output" >&2
  case_failed=1
fi
if grep -q 'verified_against' <<< "$out"; then
  ok "bad-metadata: verified_against error reported" >&2
else
  err "bad-metadata: expected verified_against error in output" >&2
  case_failed=1
fi
if grep -q 'not registered' <<< "$out"; then
  ok "bad-metadata: unknown trap-id error reported" >&2
else
  err "bad-metadata: expected 'not registered' error for unknown trap-id" >&2
  case_failed=1
fi
rm -rf "$root"

exit "$case_failed"
