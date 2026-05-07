#!/bin/bash
# cka-sim/lib/colors.sh — ANSI color variables with TTY detection
# Sourced by: lib/log.sh and any subcommand that prints colored output
# Style: matches scripts/validate-local.sh (RED, GREEN, YELLOW + NC)

# Only emit colors when stdout is a terminal. Pipes and redirects get plain text.
if [[ -t 1 ]] && [[ -n "${TERM:-}" ]] && [[ "${TERM}" != "dumb" ]]; then
  readonly RED=$'\033[31m'
  readonly GREEN=$'\033[32m'
  readonly YELLOW=$'\033[33m'
  readonly BLUE=$'\033[34m'
  readonly BOLD=$'\033[1m'
  readonly NC=$'\033[0m'
else
  readonly RED=''
  readonly GREEN=''
  readonly YELLOW=''
  readonly BLUE=''
  readonly BOLD=''
  readonly NC=''
fi
