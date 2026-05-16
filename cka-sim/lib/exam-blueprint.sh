#!/bin/bash
# cka-sim/lib/exam-blueprint.sh — Blueprint manifest parser and validator.
# Sourced by lib/cmd/exam.sh and lint-packs.sh (pass H).

set -euo pipefail
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=colors.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/colors.sh"
# shellcheck source=log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"

declare -ag CKA_SIM_BLUEPRINT_PACKS=()
declare -ag CKA_SIM_BLUEPRINT_SLUGS=()
declare -ag CKA_SIM_BLUEPRINT_MINUTES=()
declare -gA CKA_SIM_BLUEPRINT_META=()

cka_sim::blueprint::load() {
  local manifest_path="${1:?load: manifest path required}"
  [[ -r "$manifest_path" ]] || die "blueprint manifest not readable: $manifest_path"

  CKA_SIM_BLUEPRINT_PACKS=()
  CKA_SIM_BLUEPRINT_SLUGS=()
  CKA_SIM_BLUEPRINT_MINUTES=()
  CKA_SIM_BLUEPRINT_META=()

  local line value
  local in_exam=0 in_questions=0 in_weighting=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "${line//[[:space:]]/}" ]] && continue
    [[ "${line#"${line%%[![:space:]]*}"}" == "#"* ]] && continue

    if [[ "$line" =~ ^exam:[[:space:]]*$ ]]; then
      in_exam=1; in_questions=0; in_weighting=0; continue
    fi
    if [[ "$line" =~ ^questions:[[:space:]]*$ ]]; then
      in_questions=1; in_exam=0; in_weighting=0; continue
    fi

    if (( in_exam )); then
      if [[ "$line" =~ ^[[:space:]]+weighting:[[:space:]]*$ ]]; then
        in_weighting=1; continue
      fi
      if (( in_weighting )); then
        if [[ "$line" =~ ^[[:space:]]{4,}([a-z-]+):[[:space:]]+([0-9]+) ]]; then
          CKA_SIM_BLUEPRINT_META["weight_${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
          continue
        else
          in_weighting=0
        fi
      fi
      if [[ "$line" =~ ^[[:space:]]+([a-zA-Z_]+):[[:space:]]+(.+)$ ]]; then
        local key="${BASH_REMATCH[1]}" val="${BASH_REMATCH[2]}"
        if [[ "${val:0:1}" == '"' && "${val: -1}" == '"' ]]; then
          val="${val#\"}"; val="${val%\"}"
        fi
        CKA_SIM_BLUEPRINT_META["$key"]="$val"
      fi
    fi

    if (( in_questions )); then
      if [[ "$line" =~ ^[[:space:]]+-[[:space:]]+pack:[[:space:]]+(.+)$ ]]; then
        value="${BASH_REMATCH[1]}"
        if [[ "${value:0:1}" == '"' && "${value: -1}" == '"' ]]; then
          value="${value#\"}"; value="${value%\"}"
        fi
        CKA_SIM_BLUEPRINT_PACKS+=("$value")
        CKA_SIM_BLUEPRINT_SLUGS+=("")
      elif [[ "$line" =~ ^[[:space:]]+slug:[[:space:]]+(.+)$ ]]; then
        value="${BASH_REMATCH[1]}"
        if [[ "${value:0:1}" == '"' && "${value: -1}" == '"' ]]; then
          value="${value#\"}"; value="${value%\"}"
        fi
        local last_s=$(( ${#CKA_SIM_BLUEPRINT_SLUGS[@]} - 1 ))
        (( last_s >= 0 )) && CKA_SIM_BLUEPRINT_SLUGS[$last_s]="$value"
      fi
    fi
  done < "$manifest_path"

  local i qdir
  for (( i=0; i<${#CKA_SIM_BLUEPRINT_PACKS[@]}; i++ )); do
    qdir="$CKA_SIM_ROOT/packs/${CKA_SIM_BLUEPRINT_PACKS[$i]}/${CKA_SIM_BLUEPRINT_SLUGS[$i]}"
    if [[ -r "$qdir/metadata.yaml" ]]; then
      local min_line
      min_line=$(grep -E '^estimatedMinutes:' "$qdir/metadata.yaml" | head -1 || true)
      if [[ "$min_line" =~ estimatedMinutes:[[:space:]]+([0-9]+) ]]; then
        CKA_SIM_BLUEPRINT_MINUTES+=("${BASH_REMATCH[1]}")
      else
        CKA_SIM_BLUEPRINT_MINUTES+=(0)
      fi
    else
      CKA_SIM_BLUEPRINT_MINUTES+=(0)
    fi
  done
}

cka_sim::blueprint::resolve_question() {
  local pack="${1:?resolve_question: pack required}"
  local slug="${2:?resolve_question: slug required}"
  local qdir="$CKA_SIM_ROOT/packs/$pack/$slug"

  [[ -d "$qdir" ]] || die "question dir not found: $qdir"

  local f
  for f in metadata.yaml question.md setup.sh grade.sh reset.sh ref-solution.sh; do
    [[ -e "$qdir/$f" ]] || die "missing $f in $qdir"
  done
  for f in setup.sh grade.sh reset.sh ref-solution.sh; do
    [[ -x "$qdir/$f" ]] || die "$qdir/$f not executable"
  done

  printf '%s' "$qdir"
}

cka_sim::blueprint::validate() {
  local manifest_path="${1:?validate: manifest path required}"
  local errors=0

  cka_sim::blueprint::load "$manifest_path"

  local count=${#CKA_SIM_BLUEPRINT_PACKS[@]}
  if (( count != 17 )); then
    err "blueprint: expected 17 questions, got $count"
    errors=$(( errors + 1 ))
  fi

  local expected_weights=("storage:10" "workloads-scheduling:15" "services-networking:20" "cluster-architecture:25" "troubleshooting:30")
  local w
  for w in "${expected_weights[@]}"; do
    local domain="${w%%:*}" weight="${w##*:}"
    local actual="${CKA_SIM_BLUEPRINT_META["weight_$domain"]:-}"
    if [[ "$actual" != "$weight" ]]; then
      err "blueprint: weight for $domain expected $weight, got '${actual:-missing}'"
      errors=$(( errors + 1 ))
    fi
  done

  local i j
  for (( i=0; i<count; i++ )); do
    for (( j=i+1; j<count; j++ )); do
      if [[ "${CKA_SIM_BLUEPRINT_PACKS[$i]}" == "${CKA_SIM_BLUEPRINT_PACKS[$j]}" ]] \
         && [[ "${CKA_SIM_BLUEPRINT_SLUGS[$i]}" == "${CKA_SIM_BLUEPRINT_SLUGS[$j]}" ]]; then
        err "blueprint: duplicate (${CKA_SIM_BLUEPRINT_PACKS[$i]}, ${CKA_SIM_BLUEPRINT_SLUGS[$i]}) at positions $i and $j"
        errors=$(( errors + 1 ))
      fi
    done
  done

  local sum
  sum=$(cka_sim::blueprint::estimated_minutes_sum)
  if (( sum < 120 || sum > 130 )); then
    err "blueprint: estimatedMinutes sum $sum not in [120, 130]"
    errors=$(( errors + 1 ))
  fi

  local disclaimer="${CKA_SIM_BLUEPRINT_META[disclaimer]:-}"
  if [[ "$disclaimer" != *"Not real CKA exam content"* ]]; then
    err "blueprint: missing or incorrect disclaimer"
    errors=$(( errors + 1 ))
  fi

  (( errors == 0 )) && return 0 || return 1
}

cka_sim::blueprint::estimated_minutes_sum() {
  local sum=0 m
  for m in "${CKA_SIM_BLUEPRINT_MINUTES[@]}"; do
    sum=$(( sum + m ))
  done
  printf '%d' "$sum"
}
