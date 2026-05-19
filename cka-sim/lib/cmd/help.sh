#!/bin/bash
# cka-sim help — print usage

set -euo pipefail

cat <<'EOF'
cka-sim — CKA Exam Simulator

Usage: cka-sim <command> [args]

Commands:
  bootstrap   Prepare cluster for exam practice (SSH, env, state dirs)
  doctor      Check cluster readiness; exits 0 if healthy
  list        Show available packs, blueprints, history
  drill       Practice a single question (not yet implemented — phase 3)
  exam        Take a timed mock exam (not yet implemented — phase 7)
  score       View a past session report (not yet implemented — phase 7)
  audit       Question-intent baseline diff (forensic; live-cluster required)
  version     Print version + repo checksum
  help        Show this message

See cka-sim/README.md for details.
EOF
