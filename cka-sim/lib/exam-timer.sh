#!/bin/bash
# cka-sim/lib/exam-timer.sh — Background countdown timer subshell.
# Sourced by lib/cmd/exam.sh.

set -euo pipefail
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

declare -g CKA_SIM_TIMER_PID=""
declare -g CKA_SIM_TIMER_GATE="${CKA_SIM_TIMER_GATE:-${TMPDIR:-/tmp}/cka-sim-timer-gate.$$}"
export CKA_SIM_TIMER_GATE

cka_sim::timer::_now() {
  printf '%d' "${CKA_SIM_NOW_OVERRIDE:-$(date +%s)}"
}

cka_sim::timer::redraw_loop() {
  local deadline="$1"
  local sleep_interval="${CKA_SIM_TIMER_FAST:+0.1}"
  sleep_interval="${sleep_interval:-1}"

  while :; do
    local now remaining
    now=$(cka_sim::timer::_now)
    remaining=$(( deadline - now ))
    (( remaining < 0 )) && remaining=0

    # Skip drawing while gated (read owns terminal or exam is paused)
    if [[ ! -e "${CKA_SIM_TIMER_GATE:-}" ]]; then
      local hh=$(( remaining / 3600 ))
      local mm=$(( (remaining % 3600) / 60 ))
      local ss=$(( remaining % 60 ))

      local rows cols
      rows=$(tput lines 2>/dev/null || echo 24)
      cols=$(tput cols 2>/dev/null || echo 80)
      local status_row=$(( rows - 1 ))

      tput sc 2>/dev/null || true
      tput cup "$status_row" 0 2>/dev/null || true
      tput el 2>/dev/null || true

      if (( remaining == 0 )); then
        printf "⏱  TIME'S UP"
        tput rc 2>/dev/null || true
        exit 0
      elif (( cols < 30 )); then
        printf '⏱  %02d:%02d:%02d' "$hh" "$mm" "$ss"
      else
        printf '⏱  %02d:%02d:%02d remaining' "$hh" "$mm" "$ss"
      fi

      tput rc 2>/dev/null || true
    else
      # Gated — still check for time's up even while silent
      if (( remaining == 0 )); then
        exit 0
      fi
    fi

    sleep "$sleep_interval"
  done
}

cka_sim::timer::spawn() {
  local deadline="${1:?spawn: deadline_ts required}"

  cka_sim::timer::stop

  cka_sim::timer::redraw_loop "$deadline" &
  CKA_SIM_TIMER_PID=$!
}

cka_sim::timer::stop() {
  if [[ -n "${CKA_SIM_TIMER_PID:-}" ]]; then
    kill "$CKA_SIM_TIMER_PID" 2>/dev/null || true
    wait "$CKA_SIM_TIMER_PID" 2>/dev/null || true
    CKA_SIM_TIMER_PID=""
  fi
  rm -f "${CKA_SIM_TIMER_GATE:-}" 2>/dev/null || true
}

# Gate the background timer so tput does not collide with foreground read.
# Create gate file → redraw_loop skips drawing that iteration.
cka_sim::timer::gate_on() {
  : > "${CKA_SIM_TIMER_GATE:-/tmp/cka-sim-timer-gate.$$}"
}

# Remove gate file → redraw_loop resumes drawing.
cka_sim::timer::gate_off() {
  rm -f "${CKA_SIM_TIMER_GATE:-/tmp/cka-sim-timer-gate.$$}" 2>/dev/null || true
}
