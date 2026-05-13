#!/bin/bash
set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"
: "${CKA_SIM_TEST_FIXTURES_DIR:?must be set by run.sh}"
source "$CKA_SIM_ROOT/tests/lib/assert.sh"
source "$CKA_SIM_ROOT/lib/log.sh"

case_failed=0
fixtures="$CKA_SIM_TEST_FIXTURES_DIR/lint-packs"

run_bad_fixture() {
  local family="$1"
  local root
  root=$(mktemp -d -t lint-packs-forbidden-XXXXXX)
  mkdir -p "$root/troubleshooting/01-test"
  cp "$fixtures/$family/setup.sh" "$root/troubleshooting/01-test/setup.sh"
  cp "$fixtures/$family/grade.sh" "$root/troubleshooting/01-test/grade.sh"
  cp "$fixtures/$family/reset.sh" "$root/troubleshooting/01-test/reset.sh"
  cp "$fixtures/$family/ref-solution.sh" "$root/troubleshooting/01-test/ref-solution.sh"
  cp "$fixtures/$family/metadata.yaml" "$root/troubleshooting/01-test/metadata.yaml"
  cp "$fixtures/$family/question.md" "$root/troubleshooting/01-test/question.md"
  chmod +x "$root/troubleshooting/01-test"/*.sh

  out=$(CKA_SIM_LINT_PACKS_DIR="$root" bash "$CKA_SIM_ROOT/scripts/lint-packs.sh" 2>&1; printf '
RC:%d' $?)
  rc="${out##*RC:}"
  if [[ "$rc" == "0" ]]; then
    err "$family fixture: lint-packs exited 0 unexpectedly" >&2
    case_failed=1
  else
    ok "$family fixture: lint-packs exits non-zero" >&2
  fi
  if grep -q 'FORBIDDEN-COMMAND' <<< "$out"; then
    ok "$family: FORBIDDEN-COMMAND error reported" >&2
  else
    err "$family: expected 'FORBIDDEN-COMMAND' in output" >&2
    case_failed=1
  fi
  rm -rf "$root"
}

run_bad_fixture bad-forbidden-systemctl
run_bad_fixture bad-forbidden-coredns-edit
run_bad_fixture bad-forbidden-varlibkubelet-write
run_bad_fixture bad-forbidden-append-kubelet
run_bad_fixture bad-forbidden-tee-manifest
run_bad_fixture bad-forbidden-cp-manifest

root=$(mktemp -d -t lint-packs-forbidden-XXXXXX)
mkdir -p "$root/troubleshooting/01-test"
cat > "$root/troubleshooting/01-test/setup.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
: "${CKA_SIM_LAB_NS:?}"
kubectl apply -f - <<MANIFEST
apiVersion: v1
kind: Namespace
metadata:
  name: ${CKA_SIM_LAB_NS}
MANIFEST
EOF
cp "$fixtures/good/grade.sh" "$root/troubleshooting/01-test/grade.sh"
cp "$fixtures/good/metadata.yaml" "$root/troubleshooting/01-test/metadata.yaml"
cat > "$root/troubleshooting/01-test/reset.sh" <<'EOF'
#!/bin/bash
exit 0
EOF
cat > "$root/troubleshooting/01-test/ref-solution.sh" <<'EOF'
#!/bin/bash
exit 0
EOF
: > "$root/troubleshooting/01-test/question.md"
chmod +x "$root/troubleshooting/01-test"/*.sh

out=$(CKA_SIM_LINT_PACKS_DIR="$root" bash "$CKA_SIM_ROOT/scripts/lint-packs.sh" 2>&1; printf '
RC:%d' $?)
rc="${out##*RC:}"
if [[ "$rc" == "0" ]]; then
  ok "good fixture: lint-packs exits 0" >&2
else
  err "good fixture: lint-packs exited $rc unexpectedly" >&2
  case_failed=1
fi
if grep -q 'FORBIDDEN-COMMAND:' <<< "$out"; then
  err "good fixture: unexpected FORBIDDEN-COMMAND violation in output" >&2
  case_failed=1
else
  ok "good fixture: no FORBIDDEN-COMMAND violation reported" >&2
fi
rm -rf "$root"

exit "$case_failed"
