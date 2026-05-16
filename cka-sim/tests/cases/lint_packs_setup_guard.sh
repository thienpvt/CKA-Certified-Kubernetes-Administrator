#!/bin/bash
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?must be set by run.sh}"
source "$CKA_SIM_ROOT/tests/lib/assert.sh"

case_failed=0
fixtures="$CKA_SIM_TEST_FIXTURES_DIR/lint-packs"

root=$(mktemp -d -t lint-packs-setup-XXXXXX)
mkdir -p "$root/storage/01-test"
cp "$fixtures/bad-deletens/setup.sh" "$root/storage/01-test/setup.sh"
cp "$fixtures/good/grade.sh" "$root/storage/01-test/grade.sh"
cp "$fixtures/good/metadata.yaml" "$root/storage/01-test/metadata.yaml"
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
  err "bad-deletens fixture: lint-packs exited 0" >&2
  case_failed=1
else
  ok "bad-deletens fixture: lint-packs exits non-zero" >&2
fi
if grep -q 'D-09' <<< "$out"; then
  ok "bad-deletens: D-09 error reported" >&2
else
  err "bad-deletens: expected 'D-09' in output" >&2
  case_failed=1
fi
rm -rf "$root"

exit "$case_failed"
