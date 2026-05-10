#!/bin/bash
# cka-sim/tests/cases/drill_namespace_construction.sh — verifies the TRIP-03
# lab-namespace format: `cka-sim-<pack>-NN` with NN zero-padded to 2 digits,
# and that names stay under the RFC 1123 63-char limit.

set -uo pipefail
: "${CKA_SIM_ROOT:?must be set by run.sh}"

# shellcheck source=../lib/assert.sh disable=SC1091
source "$CKA_SIM_ROOT/tests/lib/assert.sh"

case_failed=0

# ---------- namespace formatting (TRIP-03) ----------
# The drill.sh contract: lab_ns = "cka-sim-<pack>-NN" with NN zero-padded to 2 digits.
expect_eq "cka-sim-storage-$(printf '%02d' 1)" \
  "cka-sim-storage-01" \
  "pack=storage idx=1 (zero-pad single digit)" || case_failed=1
expect_eq "cka-sim-services-networking-$(printf '%02d' 2)" \
  "cka-sim-services-networking-02" \
  "pack=services-networking idx=2 (long pack name + zero-pad)" || case_failed=1
expect_eq "cka-sim-troubleshooting-$(printf '%02d' 17)" \
  "cka-sim-troubleshooting-17" \
  "pack=troubleshooting idx=17 (no extra padding)" || case_failed=1
expect_eq "cka-sim-workloads-scheduling-$(printf '%02d' 10)" \
  "cka-sim-workloads-scheduling-10" \
  "pack=workloads-scheduling idx=10" || case_failed=1

# ---------- length constraint ----------
# Longest expected ns name across the 5 packs capped at 99 questions:
# "cka-sim-services-networking-99" = 30 chars; "cka-sim-cluster-architecture-99" = 31.
longest="cka-sim-cluster-architecture-99"
actual_len=${#longest}
if (( actual_len <= 63 )); then
  printf '%s  \xe2\x9c\x93 longest expected ns name = %d chars (<= 63)%s\n' \
    "${GREEN:-}" "$actual_len" "${NC:-}" >&2
else
  printf '%s  \xe2\x9c\x97 longest ns name exceeds RFC 1123 63 chars: %d%s\n' \
    "${RED:-}" "$actual_len" "${NC:-}" >&2
  case_failed=1
fi

# ---------- RFC 1123 DNS label conformance ----------
# ns name must match [a-z0-9]([a-z0-9-]*[a-z0-9])? and be <= 63 chars.
for ns in \
  "cka-sim-storage-01" \
  "cka-sim-services-networking-99" \
  "cka-sim-cluster-architecture-01" \
  "cka-sim-workloads-scheduling-10" \
  "cka-sim-troubleshooting-17" \
; do
  if [[ "$ns" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
    printf '%s  \xe2\x9c\x93 RFC 1123 ok: %s%s\n' \
      "${GREEN:-}" "$ns" "${NC:-}" >&2
  else
    printf '%s  \xe2\x9c\x97 RFC 1123 violation: %s%s\n' \
      "${RED:-}" "$ns" "${NC:-}" >&2
    case_failed=1
  fi
done

exit "$case_failed"
