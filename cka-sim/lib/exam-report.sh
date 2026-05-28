#!/bin/bash
# cka-sim/lib/exam-report.sh — Markdown score report renderer.
# Sourced by lib/cmd/exam.sh (end-of-exam) and lib/cmd/score.sh (re-render).

set -euo pipefail
: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=colors.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/colors.sh"
# shellcheck source=log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"

cka_sim::report::render() {
  local session_json="${1:?render: session_json required}"
  local output_md="${2:?render: output_md required}"

  [[ -r "$session_json" ]] || die "session not readable: $session_json"

  local tmp
  tmp=$(mktemp -t "cka-sim-report.XXXXXX")

  {
    cka_sim::report::header "$session_json"
    printf '\n'
    cka_sim::report::domain_table "$session_json"
    printf '\n'
    cka_sim::report::trap_table "$session_json"
    printf '\n'
    cka_sim::report::next_drills "$session_json"
    printf '\n'
    cka_sim::report::question_detail "$session_json"
  } > "$tmp"

  mv -f "$tmp" "$output_md"
}

cka_sim::report::header() {
  local session_json="$1"

  local blueprint_id started_at ts
  blueprint_id=$(jq -r '.blueprint.id' "$session_json")
  started_at=$(jq -r '.started_at' "$session_json")
  ts=$(basename "$session_json" .json)

  local completed_at
  completed_at=$(jq -r '
    [.questions[] | select(.completed_at != null) | .completed_at] | sort | last // "N/A"
  ' "$session_json")

  local duration="N/A"
  if [[ "$completed_at" != "N/A" && "$started_at" != "null" ]]; then
    local start_epoch end_epoch
    start_epoch=$(date -d "$started_at" +%s 2>/dev/null || echo 0)
    end_epoch=$(date -d "$completed_at" +%s 2>/dev/null || echo 0)
    if (( start_epoch > 0 && end_epoch > 0 )); then
      local diff=$(( end_epoch - start_epoch ))
      local hh=$(( diff / 3600 ))
      local mm=$(( (diff % 3600) / 60 ))
      local ss=$(( diff % 60 ))
      duration=$(printf '%02d:%02d:%02d' "$hh" "$mm" "$ss")
    fi
  fi

  local total
  total=$(cka_sim::report::compute_total "$session_json")
  local verdict="FAIL"
  (( total >= 66 )) && verdict="PASS"

  cat <<EOF
# CKA Exam Report — $ts

**Blueprint:** $blueprint_id
**Started:** $started_at  **Completed:** $completed_at  **Duration:** $duration
**Total Score: ${total}/100  (${verdict} vs 66% pass mark)**
EOF
}

cka_sim::report::compute_total() {
  local session_json="$1"

  jq -r '
    def weight_for(d):
      if d == "storage" then 10
      elif d == "workloads-scheduling" then 15
      elif d == "services-networking" then 20
      elif d == "cluster-architecture" then 25
      elif d == "troubleshooting" then 30
      else 0 end;

    [.questions[] | {domain, score: (.score // 0), max_score: (.max_score // 1)}]
    | group_by(.domain)
    | map({
        domain: .[0].domain,
        score: (map(.score) | add),
        max: (map(.max_score) | add)
      })
    | map(. + {pct: (if .max > 0 then (.score / .max * 100) else 0 end)})
    | map(.pct * weight_for(.domain) / 100)
    | add
    | . + 0.5 | floor
  ' "$session_json" | tr -d '\r'
}

cka_sim::report::domain_table() {
  local session_json="$1"

  cat <<'EOF'
## Per-Domain Breakdown (weakest first)

| Domain | Score | Percentage | Blueprint Weight |
|--------|-------|------------|------------------|
EOF

  jq -r '
    def weight_for(d):
      if d == "storage" then 10
      elif d == "workloads-scheduling" then 15
      elif d == "services-networking" then 20
      elif d == "cluster-architecture" then 25
      elif d == "troubleshooting" then 30
      else 0 end;

    [.questions[] | {domain, score: (.score // 0), max_score: (.max_score // 1)}]
    | group_by(.domain)
    | map({
        domain: .[0].domain,
        score: (map(.score) | add),
        max: (map(.max_score) | add)
      })
    | map(. + {
        pct: (if .max > 0 then (.score / .max * 100) else 0 end),
        weight: weight_for(.domain)
      })
    | sort_by(.pct)
    | .[]
    | "| \(.domain) | \(.score)/\(.max) | \(.pct | . + 0.5 | floor)% | \(.weight)% |"
  ' "$session_json" | tr -d '\r'
}

cka_sim::report::trap_table() {
  local session_json="$1"

  cat <<'EOF'
## Top 5 Traps Hit

| # | Trap ID | Count | Description |
|---|---------|-------|-------------|
EOF

  local trap_counts
  trap_counts=$(jq -r '
    [.questions[].traps // [] | .[]]
    | group_by(.)
    | map({id: .[0], count: length})
    | sort_by(-.count)
    | .[0:5]
    | to_entries[]
    | "\(.key + 1)|\(.value.id)|\(.value.count)"
  ' "$session_json" | tr -d '\r')

  local catalog="$CKA_SIM_ROOT/traps/catalog.yaml"

  while IFS='|' read -r num trap_id count; do
    [[ -z "$num" ]] && continue
    local desc=""
    if [[ -r "$catalog" ]]; then
      desc=$(grep -A3 "^  - id: ${trap_id}$" "$catalog" 2>/dev/null \
        | grep 'description:' \
        | sed 's/.*description: *//' \
        | sed 's/^"//' | sed 's/"$//' \
        | head -1 || true)
    fi
    [[ -z "$desc" ]] && desc="$trap_id"
    printf '| %s | %s | %s | %s |\n' "$num" "$trap_id" "$count" "$desc"
  done <<< "$trap_counts"
}

cka_sim::report::next_drills() {
  local session_json="$1"

  local weak_domains
  weak_domains=$(jq -r '
    [.questions[] | {domain, score: (.score // 0), max_score: (.max_score // 1)}]
    | group_by(.domain)
    | map({
        domain: .[0].domain,
        score: (map(.score) | add),
        max: (map(.max_score) | add)
      })
    | map(. + {pct: (if .max > 0 then (.score / .max * 100) else 0 end)})
    | map(select(.pct < 80))
    | sort_by(.pct)
    | .[0:3]
    | .[].domain
  ' "$session_json" | tr -d '\r')

  if [[ -z "$weak_domains" ]]; then
    cat <<'EOF'
## Suggested Next Drills

All domains scored 80% or above. Great work!
EOF
    return
  fi

  local domain_list=""
  while IFS= read -r d; do
    [[ -z "$d" ]] && continue
    domain_list="${domain_list}${domain_list:+, }$d"
  done <<< "$weak_domains"

  printf '## Suggested Next Drills\n\n'
  printf 'Your weakest domains: %s. Drill these next:\n\n' "$domain_list"

  while IFS= read -r d; do
    [[ -z "$d" ]] && continue
    printf -- '- `cka-sim drill %s`\n' "$d"
  done <<< "$weak_domains"
}

cka_sim::report::question_detail() {
  local session_json="$1"

  cat <<'EOF'
## Question-by-Question Detail

| # | Domain | Question | Score | Status | Traps |
|---|--------|----------|-------|--------|-------|
EOF

  jq -r '
    .questions | to_entries[] |
    "| \(.key + 1) | \(.value.domain // "—") | \(.value.id // "—") | \(.value.score // 0)/\(.value.max_score // 0) | \(.value.status // "—") | \((.value.traps // []) | if length == 0 then "—" else join(", ") end) |"
  ' "$session_json" | tr -d '\r'
}
