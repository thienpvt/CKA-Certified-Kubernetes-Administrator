#!/bin/bash
# cka-sim/tests/cases/drill_namespace_render.sh — locks DRILL-NS-01 (Phase 22-01).
#
# Validates the pure-bash parameter-expansion shape that drill.sh:321 uses to
# substitute `${CKA_SIM_LAB_NS}` placeholders in question.md prompts, mirroring
# exam.sh:191-196.
#
# Test 1: behaviour — the expansion replaces the literal `${CKA_SIM_LAB_NS}`
#         token with the resolved namespace.
# Test 2: selectivity — `$OTHER_VAR` and `${UNRELATED}` survive verbatim;
#         only the one token we own is substituted.
# Test 3: source-shape lock — `cka-sim/lib/cmd/drill.sh` carries the
#         parameter-expansion idiom (regression guard against reverting to
#         a plain `cat`).

set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"

# shellcheck source=../lib/assert.sh disable=SC1091
source "$CKA_SIM_ROOT/tests/lib/assert.sh"

case_failed=0

tmp=$(mktemp -d -t cka-sim-drill-ns-render-XXXXXX)
trap 'rm -rf "$tmp"' EXIT

# ---------- Test 1: substitution behaviour ----------
# Quoted heredoc keeps the literal `${CKA_SIM_LAB_NS}` four-byte token intact.
cat >"$tmp/q1.md" <<'EOF'
Create resources in the ${CKA_SIM_LAB_NS} namespace.
EOF

CKA_SIM_LAB_NS="cka-sim-test-01"
qc=$(<"$tmp/q1.md")
out="${qc//\$\{CKA_SIM_LAB_NS\}/$CKA_SIM_LAB_NS}"

if [[ "$out" == *"cka-sim-test-01"* ]]; then
  printf '%s  \xe2\x9c\x93 Test 1a: resolved ns appears in rendered output%s\n' \
    "${GREEN:-}" "${NC:-}" >&2
else
  printf '%s  \xe2\x9c\x97 Test 1a: resolved ns missing from rendered output: %q%s\n' \
    "${RED:-}" "$out" "${NC:-}" >&2
  case_failed=1
fi

if [[ "$out" != *'${CKA_SIM_LAB_NS}'* ]]; then
  printf '%s  \xe2\x9c\x93 Test 1b: literal placeholder absent from rendered output%s\n' \
    "${GREEN:-}" "${NC:-}" >&2
else
  printf '%s  \xe2\x9c\x97 Test 1b: literal placeholder still present in: %q%s\n' \
    "${RED:-}" "$out" "${NC:-}" >&2
  case_failed=1
fi

# ---------- Test 2: selectivity ----------
# Other dollar-sign shapes must survive untouched — no shell expansion,
# no envsubst, no broad `$VAR` walk.
cat >"$tmp/q2.md" <<'EOF'
intro ${CKA_SIM_LAB_NS} middle $OTHER_VAR end ${UNRELATED}
EOF

qc=$(<"$tmp/q2.md")
out="${qc//\$\{CKA_SIM_LAB_NS\}/$CKA_SIM_LAB_NS}"

if [[ "$out" == *"cka-sim-test-01"* ]]; then
  printf '%s  \xe2\x9c\x93 Test 2a: target token substituted%s\n' \
    "${GREEN:-}" "${NC:-}" >&2
else
  printf '%s  \xe2\x9c\x97 Test 2a: target token NOT substituted: %q%s\n' \
    "${RED:-}" "$out" "${NC:-}" >&2
  case_failed=1
fi

if [[ "$out" == *'$OTHER_VAR'* ]]; then
  printf '%s  \xe2\x9c\x93 Test 2b: $OTHER_VAR survived verbatim%s\n' \
    "${GREEN:-}" "${NC:-}" >&2
else
  printf '%s  \xe2\x9c\x97 Test 2b: $OTHER_VAR was unexpectedly expanded in: %q%s\n' \
    "${RED:-}" "$out" "${NC:-}" >&2
  case_failed=1
fi

if [[ "$out" == *'${UNRELATED}'* ]]; then
  printf '%s  \xe2\x9c\x93 Test 2c: ${UNRELATED} survived verbatim%s\n' \
    "${GREEN:-}" "${NC:-}" >&2
else
  printf '%s  \xe2\x9c\x97 Test 2c: ${UNRELATED} was unexpectedly expanded in: %q%s\n' \
    "${RED:-}" "$out" "${NC:-}" >&2
  case_failed=1
fi

# ---------- Test 3: drill.sh source carries the idiom ----------
# Source-shape lock: catches regression to plain `cat "$CKA_SIM_QUESTION_DIR/question.md"`.
# The literal source bytes use backslash-escaped braces (`\$\{...\}`) — that is
# the bash parameter-expansion syntax for matching the literal `${VAR}` token.
# Same shape exam.sh:196 ships.
if grep -qF 'question_content//\$\{CKA_SIM_LAB_NS\}/' "$CKA_SIM_ROOT/lib/cmd/drill.sh"; then
  printf '%s  \xe2\x9c\x93 Test 3: drill.sh carries the parameter-expansion idiom%s\n' \
    "${GREEN:-}" "${NC:-}" >&2
else
  printf '%s  \xe2\x9c\x97 Test 3: drill.sh missing parameter-expansion idiom (DRILL-NS-01 not applied)%s\n' \
    "${RED:-}" "${NC:-}" >&2
  case_failed=1
fi

exit "$case_failed"
