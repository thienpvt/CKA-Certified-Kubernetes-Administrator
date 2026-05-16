#!/bin/bash
# cka-sim/tests/cases/drill_orchestration_order.sh — verifies the TRIP-05
# orchestration sequence: reset.sh -> setup.sh -> grade.sh -> reset.sh (EXIT trap).
# Uses stub scripts in a tempdir that log their name on run; we assert the
# log contents match the expected sequence.

set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"

# shellcheck source=../lib/assert.sh disable=SC1091
source "$CKA_SIM_ROOT/tests/lib/assert.sh"

case_failed=0

# ---------- create stub question dir ----------
qdir=$(mktemp -d -t drill-fake-question-XXXXXX)
log="$qdir/order.log"
: > "$log"

# Unquoted EOF so $log expands to the current test's tempdir path.
cat > "$qdir/setup.sh" <<EOF
#!/bin/bash
echo setup >> "$log"
EOF

cat > "$qdir/reset.sh" <<EOF
#!/bin/bash
echo reset >> "$log"
EOF

cat > "$qdir/grade.sh" <<EOF
#!/bin/bash
echo grade >> "$log"
echo "SCORE: 0/1"
EOF

cat > "$qdir/ref-solution.sh" <<'EOF'
#!/bin/bash
exit 0
EOF

: > "$qdir/question.md"
: > "$qdir/metadata.yaml"
chmod +x "$qdir"/*.sh

# ---------- simulate the drill.sh main() orchestration order ----------
# reset (pre-setup clean slate) -> setup -> grade -> reset (EXIT-trap cleanup)
bash "$qdir/reset.sh"
bash "$qdir/setup.sh"
bash "$qdir/grade.sh" >/dev/null
bash "$qdir/reset.sh"   # EXIT-trap simulation

# ---------- assert order ----------
expected="reset
setup
grade
reset"
actual=$(cat "$log")
expect_eq "$actual" "$expected" \
  "orchestration: reset -> setup -> grade -> reset (EXIT-trap)" || case_failed=1

# ---------- verify the 6 question files are present (drill.sh load_pack contract) ----------
for f in metadata.yaml question.md setup.sh grade.sh reset.sh ref-solution.sh; do
  if [[ -e "$qdir/$f" ]]; then
    printf '%s  \xe2\x9c\x93 question file present: %s%s\n' \
      "${GREEN:-}" "$f" "${NC:-}" >&2
  else
    printf '%s  \xe2\x9c\x97 missing question file: %s%s\n' \
      "${RED:-}" "$f" "${NC:-}" >&2
    case_failed=1
  fi
done
for f in setup.sh grade.sh reset.sh ref-solution.sh; do
  if [[ -x "$qdir/$f" ]]; then
    printf '%s  \xe2\x9c\x93 question script executable: %s%s\n' \
      "${GREEN:-}" "$f" "${NC:-}" >&2
  else
    printf '%s  \xe2\x9c\x97 question script not executable: %s%s\n' \
      "${RED:-}" "$f" "${NC:-}" >&2
    case_failed=1
  fi
done

# ---------- cleanup ----------
rm -rf "$qdir"

exit "$case_failed"
