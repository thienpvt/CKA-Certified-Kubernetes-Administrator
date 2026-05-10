#!/bin/bash
# cka-sim/scripts/lint-packs.sh — GRADE-02 + PACK-06 + D-09 setup-guard + mutating-verb lint for cka-sim/packs/.
# Pure bash. Wired into cka-sim/scripts/test.sh between lint-traps.sh and tests/run.sh.
# Mirror of cka-sim/scripts/lint-traps.sh shape.

set -euo pipefail

CKA_SIM_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$CKA_SIM_ROOT/.." && pwd)"

# shellcheck source=../lib/colors.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/colors.sh"
# shellcheck source=../lib/log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"

header "pack lint"

# Test-mode override: unit tests point this at a fixture tree.
PACKS_DIR="${CKA_SIM_LINT_PACKS_DIR:-$CKA_SIM_ROOT/packs}"

if [[ ! -d "$PACKS_DIR" ]]; then
  warn "no packs dir at $PACKS_DIR — skipping lint (expected during scaffold before plans 03-04..03-08 land)"
  exit 0
fi

# Source traps.sh for is_valid_id + id_exists (single source of truth).
# shellcheck source=../lib/traps.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/traps.sh"

# Closed enums
valid_domain=("storage" "workloads-scheduling" "services-networking" "cluster-architecture" "troubleshooting")
valid_ref_kind=("concerns-md" "k8s-doc" "prior-art-exercise" "exam-objective" "blog-post")

_strip_quotes() { local v="$1"; v="${v#\"}"; v="${v%\"}"; v="${v#\'}"; v="${v%\'}"; printf '%s' "$v"; }
_in_array() { local needle="$1"; shift; local item; for item in "$@"; do [[ "$item" == "$needle" ]] && return 0; done; return 1; }

errors=0
checked=0

info "pass A: GRADE-02 grade.sh idioms"
while IFS= read -r grade_sh; do
  checked=$(( checked + 1 ))
  if grep -nE '^[[:space:]]*[^#]*kubectl[[:space:]]+get[[:space:]].*\|[[:space:]]*grep' "$grade_sh" >/dev/null; then
    err "GRADE-02: $grade_sh contains banned 'kubectl get | grep'"
    errors=$(( errors + 1 ))
  fi
  if grep -nE '^[[:space:]]*[^#]*kubectl[[:space:]]+get[[:space:]]+-A([[:space:]]|$)' "$grade_sh" >/dev/null; then
    err "GRADE-02: $grade_sh contains banned 'kubectl get -A'"
    errors=$(( errors + 1 ))
  fi
done < <(find "$PACKS_DIR" -name 'grade.sh' -type f)

info "pass B: mutating-verb rejection in grade.sh (graders are read-only)"
while IFS= read -r grade_sh; do
  if grep -nE '^[[:space:]]*[^#]*kubectl[[:space:]]+(delete|create|apply|patch|edit|replace)([[:space:]]|$)' "$grade_sh" >/dev/null; then
    err "MUTATING-VERB: $grade_sh contains forbidden mutating verb (delete|create|apply|patch|edit|replace) — graders must be read-only"
    errors=$(( errors + 1 ))
  fi
done < <(find "$PACKS_DIR" -name 'grade.sh' -type f)

info "pass C: D-09 runner-owns-cleanup guard (no 'kubectl delete ns' in setup.sh)"
while IFS= read -r setup_sh; do
  if grep -nE '^[[:space:]]*[^#]*kubectl[[:space:]]+delete[[:space:]]+(namespace|ns)([[:space:]]|$)' "$setup_sh" >/dev/null; then
    err "D-09: $setup_sh contains 'kubectl delete ns' — runner owns cleanup"
    errors=$(( errors + 1 ))
  fi
done < <(find "$PACKS_DIR" -name 'setup.sh' -type f)

info "pass D: D-12(d/e) 6-files-per-question + executable bits"
while IFS= read -r q_dir; do
  checked=$(( checked + 1 ))
  for f in metadata.yaml question.md setup.sh grade.sh reset.sh ref-solution.sh; do
    [[ -e "$q_dir/$f" ]] || { err "$q_dir: missing $f"; errors=$(( errors + 1 )); }
  done
  for f in setup.sh grade.sh reset.sh ref-solution.sh; do
    if [[ -e "$q_dir/$f" ]] && [[ ! -x "$q_dir/$f" ]]; then
      err "$q_dir/$f: not executable (chmod +x)"; errors=$(( errors + 1 ))
    fi
  done
done < <(find "$PACKS_DIR" -mindepth 2 -maxdepth 2 -type d)

info "pass E: D-12(b/c) metadata.yaml schema + trap-id registration"
while IFS= read -r meta_yaml; do
  checked=$(( checked + 1 ))
  m_id=""; m_domain=""; m_estmin=""; m_verified=""
  m_traps=()
  m_refs=0
  in_traps=0
  in_refs=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "${line//[[:space:]]/}" ]] && continue
    [[ "${line#"${line%%[![:space:]]*}"}" == "#"* ]] && continue

    if [[ ! "$line" =~ ^[[:space:]] ]] && [[ "$line" =~ ^([a-z_A-Z]+):[[:space:]]*(.*)$ ]]; then
      k="${BASH_REMATCH[1]}"
      v="$(_strip_quotes "${BASH_REMATCH[2]}")"
      in_traps=0
      in_refs=0
      case "$k" in
        id)               m_id="$v" ;;
        domain)           m_domain="$v" ;;
        estimatedMinutes) m_estmin="$v" ;;
        verified_against) m_verified="$v" ;;
        traps)            in_traps=1 ;;
        references)       in_refs=1 ;;
      esac
      continue
    fi

    if (( in_traps == 1 )) && [[ "$line" =~ ^[[:space:]]{2}-[[:space:]]+(.+)$ ]]; then
      m_traps+=("$(_strip_quotes "${BASH_REMATCH[1]}")")
      continue
    fi

    if (( in_refs == 1 )) && [[ "$line" =~ ^[[:space:]]{2}-[[:space:]]+kind:[[:space:]]+ ]]; then
      m_refs=$(( m_refs + 1 ))
      continue
    fi
  done < "$meta_yaml"

  [[ -n "$m_id" ]] || { err "$meta_yaml: missing 'id'"; errors=$(( errors + 1 )); }
  if [[ -n "$m_id" ]] && ! cka_sim::trap::is_valid_id "$m_id"; then
    err "$meta_yaml: id '$m_id' not RFC 1123"
    errors=$(( errors + 1 ))
  fi
  [[ -n "$m_domain" ]] || { err "$meta_yaml: missing 'domain'"; errors=$(( errors + 1 )); }
  if [[ -n "$m_domain" ]] && ! _in_array "$m_domain" "${valid_domain[@]}"; then
    err "$meta_yaml: domain '$m_domain' not in enum {${valid_domain[*]}}"
    errors=$(( errors + 1 ))
  fi
  if [[ ! "$m_estmin" =~ ^[0-9]+$ ]] || (( m_estmin < 4 )) || (( m_estmin > 12 )); then
    err "$meta_yaml: estimatedMinutes '$m_estmin' must be integer in [4,12]"
    errors=$(( errors + 1 ))
  fi
  if [[ "$m_verified" != "1.35" ]]; then
    err "$meta_yaml: verified_against must be \"1.35\" (got '$m_verified')"
    errors=$(( errors + 1 ))
  fi
  if (( ${#m_traps[@]} < 3 )); then
    err "$meta_yaml: traps[] has ${#m_traps[@]} entries, need >=3 (GRADE-04)"
    errors=$(( errors + 1 ))
  fi
  for tid in "${m_traps[@]}"; do
    if ! cka_sim::trap::id_exists "$tid"; then
      err "$meta_yaml: trap-id '$tid' not registered in cka-sim/traps/catalog.yaml"
      errors=$(( errors + 1 ))
    fi
  done
done < <(find "$PACKS_DIR" -name 'metadata.yaml' -type f)

printf '\n' >&2
if (( errors > 0 )); then
  err "$errors pack lint error(s) across $checked check(s). Fix before pushing."
  exit 1
fi
ok "pack lint passed ($checked check(s))."
exit 0
