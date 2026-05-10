#!/bin/bash
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?must be set by run.sh}"
source "$CKA_SIM_ROOT/tests/lib/assert.sh"

case_failed=0
fixtures="$CKA_SIM_TEST_FIXTURES_DIR/lint-packs"

_make_pack_tree() {
  local src="$1"
  local root
  root=$(mktemp -d -t lint-packs-test-XXXXXX)
  mkdir -p "$root/storage/01-test"
  for f in metadata.yaml question.md setup.sh grade.sh reset.sh ref-solution.sh; do
    if [[ -e "$fixtures/$src/$f" ]]; then
      cp "$fixtures/$src/$f" "$root/storage/01-test/$f"
    elif [[ -e "$fixtures/good/$f" ]]; then
      cp "$fixtures/good/$f" "$root/storage/01-test/$f"
    else
      : > "$root/storage/01-test/$f"
    fi
  done
  cat > "$root/storage/01-test/reset.sh" <<'EOF'
#!/bin/bash
set -uo pipefail
EOF
  cat > "$root/storage/01-test/ref-solution.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
EOF
  : > "$root/storage/01-test/question.md"
  chmod +x "$root/storage/01-test"/*.sh
  printf '%s' "$root"
}

# POSITIVE: good fixture passes
root=$(_make_pack_tree "good")
if CKA_SIM_LINT_PACKS_DIR="$root" bash "$CKA_SIM_ROOT/scripts/lint-packs.sh" >/dev/null 2>&1; then
  ok "good fixture: lint-packs exits 0" >&2
else
  err "good fixture: lint-packs failed (expected pass)" >&2
  case_failed=1
fi
rm -rf "$root"

# NEGATIVE: bad-grep trips Pass A1
root=$(_make_pack_tree "bad-grep")
if CKA_SIM_LINT_PACKS_DIR="$root" bash "$CKA_SIM_ROOT/scripts/lint-packs.sh" >/dev/null 2>&1; then
  err "bad-grep fixture: lint-packs exited 0 (expected non-zero)" >&2
  case_failed=1
else
  ok "bad-grep fixture: lint-packs exits non-zero" >&2
fi
rm -rf "$root"

# NEGATIVE: bad-getall trips Pass A2
root=$(_make_pack_tree "bad-getall")
if CKA_SIM_LINT_PACKS_DIR="$root" bash "$CKA_SIM_ROOT/scripts/lint-packs.sh" >/dev/null 2>&1; then
  err "bad-getall fixture: lint-packs exited 0 (expected non-zero)" >&2
  case_failed=1
else
  ok "bad-getall fixture: lint-packs exits non-zero" >&2
fi
rm -rf "$root"

exit "$case_failed"
