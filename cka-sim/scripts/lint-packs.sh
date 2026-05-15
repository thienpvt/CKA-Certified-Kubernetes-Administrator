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
  if grep -nE '^[[:space:]]*[^#]*kubectl[[:space:]]+get[[:space:]][^|]*\|[[:space:]]*grep' "$grade_sh" >/dev/null; then
    err "GRADE-02: $grade_sh contains banned 'kubectl get | grep'"
    errors=$(( errors + 1 ))
  fi
  if grep -nE '^[[:space:]]*[^#]*kubectl[[:space:]]+get[[:space:]]+-A([[:space:]]|$)' "$grade_sh" >/dev/null; then
    err "GRADE-02: $grade_sh contains banned 'kubectl get -A'"
    errors=$(( errors + 1 ))
  fi
done < <(find "$PACKS_DIR" -name 'grade.sh' -type f)

info "pass B: mutating-verb rejection in grade.sh (graders are read-only; apply --dry-run=client allowed)"
while IFS= read -r grade_sh; do
  if grep -nE '^[[:space:]]*[^#]*kubectl[[:space:]]+(delete|create|patch|edit|replace)([[:space:]]|$)' "$grade_sh" >/dev/null; then
    err "MUTATING-VERB: $grade_sh contains forbidden mutating verb (delete|create|patch|edit|replace) — graders must be read-only"
    errors=$(( errors + 1 ))
  fi
  if grep -nE '^[[:space:]]*[^#]*kubectl[[:space:]]+apply[[:space:]]' "$grade_sh" | grep -v -- 'apply --dry-run=client' >/dev/null; then
    err "MUTATING-VERB: $grade_sh contains kubectl apply without --dry-run=client"
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

info "pass F: BUG-3 pre-empt — no hardcoded node-01/node-02 in packs/**/*.sh"
# BUG-3 (Phase 4): storage/04-csi-volumesnapshot hardcoded node-02, which does not
# exist on every 1+2 cluster. Phase 5 promotes dynamic-worker discovery into
# cka_sim::setup::read_node_worker (lib/setup.sh). This pass is the regression
# guard: any literal node-01 / node-02 token in a pack shell script fails lint,
# unless the line is a comment (first non-whitespace char is '#').
#
# File-level opt-out: if the file's first 10 lines contain the sentinel
# '# cka-sim-lint: allow-node-literal', the whole file is skipped. This is
# reserved for legitimate hostname-bound drills (e.g. static-pod on a named
# control-plane host) where dynamic discovery is either infeasible or a
# separately-tracked retrofit. New authors should never reach for the sentinel.
while IFS= read -r sh_file; do
  checked=$(( checked + 1 ))
  if head -n 10 "$sh_file" 2>/dev/null | grep -q '# cka-sim-lint: allow-node-literal'; then
    continue
  fi
  while IFS= read -r hit_line; do
    [[ -z "$hit_line" ]] && continue
    line_num="${hit_line%%:*}"
    rest="${hit_line#*:}"
    # Skip if the line is a comment (first non-whitespace char is '#').
    stripped="${rest#"${rest%%[![:space:]]*}"}"
    [[ "${stripped:0:1}" == "#" ]] && continue
    err "BUG-3 pre-empt: $sh_file:$line_num contains hardcoded node-01/node-02 — use cka_sim::setup::read_node_worker instead"
    errors=$(( errors + 1 ))
  done < <(grep -nE '\bnode-0[12]\b' "$sh_file" 2>/dev/null || true)
done < <(find "$PACKS_DIR" -type f -name '*.sh' -not -path '*/tests/*')

info "pass G: FORBIDDEN-COMMAND guard — troubleshooting pack host-safety (D-09/D-11/D-12)"
if [[ -d "$PACKS_DIR/troubleshooting" ]]; then
  while IFS= read -r sh_file; do
    checked=$(( checked + 1 ))
    forbidden_patterns=(
      "\\bsystemctl\\b|systemctl"
      "kubectl[[:space:]]+edit[[:space:]]+configmap[[:space:]]+coredns[[:space:]]+-n[[:space:]]+kube-system|kubectl edit cm coredns (kube-system)"
      "kubectl[[:space:]]+delete[[:space:]]+(namespace|ns)[[:space:]]+kube-system|kubectl delete ns kube-system"
      "kubectl[[:space:]]+(cordon|drain)[[:space:]]|kubectl cordon/drain"
      ">[[:space:]]*/etc/kubernetes/|write into /etc/kubernetes/ (covers /etc/kubernetes/manifests/ via prefix)"
      ">[[:space:]]*/var/lib/kubelet/|write into /var/lib/kubelet/"
      "cp[[:space:]]+([^#][^[:space:]]*[[:space:]]+)+/etc/kubernetes/manifests/|copy into /etc/kubernetes/manifests/"
      ">>[[:space:]]*[\"']?/etc/kubernetes/|append into /etc/kubernetes/"
      ">>[[:space:]]*[\"']?/var/lib/kubelet/|append into /var/lib/kubelet/"
      "tee([[:space:]]+-a)?[[:space:]]+[\"']?/etc/kubernetes/|tee into /etc/kubernetes/"
      "tee([[:space:]]+-a)?[[:space:]]+[\"']?/var/lib/kubelet/|tee into /var/lib/kubelet/"
      "cp[[:space:]][^#]*[\"'][[:space:]]*/etc/kubernetes/manifests/|quoted cp into /etc/kubernetes/manifests/"
      "install[[:space:]][^#]*[\"']?/etc/kubernetes/manifests/|install into /etc/kubernetes/manifests/"
    )
    for pattern_label in "${forbidden_patterns[@]}"; do
      pattern="${pattern_label%%|*}"
      label="${pattern_label#*|}"
      while IFS= read -r hit_line; do
        [[ -z "$hit_line" ]] && continue
        line_num="${hit_line%%:*}"
        rest="${hit_line#*:}"
        # Skip if the line is a comment (first non-whitespace char is '#').
        stripped="${rest#"${rest%%[![:space:]]*}"}"
        [[ "${stripped:0:1}" == "#" ]] && continue
        err "FORBIDDEN-COMMAND: $sh_file:$line_num forbidden pattern '$label' (D-09/D-11/D-12 host-safety)"
        errors=$(( errors + 1 ))
      done < <(grep -nE "^[[:space:]]*[^#]*${pattern}" "$sh_file" 2>/dev/null || true)
    done
  done < <(find "$PACKS_DIR/troubleshooting" -type f -name '*.sh' -not -path '*/tests/*')
fi

info "pass H: blueprint manifest lint"
EXAMS_DIR="${CKA_SIM_LINT_EXAMS_DIR:-$REPO_ROOT/exams}"
if [[ -d "$EXAMS_DIR" ]]; then
  while IFS= read -r manifest; do
    [[ -z "$manifest" ]] && continue
    checked=$(( checked + 1 ))
    local_bp_dir="$(dirname "$manifest")"
    local_bp_name="$(basename "$local_bp_dir")"

    # Count questions
    q_count=$(grep -c 'slug:' "$manifest" 2>/dev/null || echo 0)
    if (( q_count != 17 )); then
      err "BLUEPRINT: $manifest: expected 17 questions, got $q_count"
      errors=$(( errors + 1 ))
    fi

    # Check weighting fields
    for wt in "storage: 10" "workloads-scheduling: 15" "services-networking: 20" "cluster-architecture: 25" "troubleshooting: 30"; do
      if ! grep -qF "$wt" "$manifest"; then
        err "BLUEPRINT: $manifest: missing or wrong weighting '$wt'"
        errors=$(( errors + 1 ))
      fi
    done

    # Check no duplicate (pack, slug) pairs
    local_dupes=$(grep -E '^\s+(pack|slug):' "$manifest" | paste - - | sort | uniq -d)
    if [[ -n "$local_dupes" ]]; then
      err "BLUEPRINT: $manifest: duplicate (pack, slug) pairs found"
      errors=$(( errors + 1 ))
    fi

    # Check every (pack, slug) resolves to existing question dir
    local_packs=()
    local_slugs=()
    while IFS= read -r line; do
      if [[ "$line" =~ pack:[[:space:]]+(.+) ]]; then
        local_packs+=("${BASH_REMATCH[1]}")
      fi
    done < "$manifest"
    while IFS= read -r line; do
      if [[ "$line" =~ slug:[[:space:]]+(.+) ]]; then
        local_slugs+=("${BASH_REMATCH[1]}")
      fi
    done < "$manifest"

    sum_minutes=0
    for (( bp_i=0; bp_i<${#local_packs[@]}; bp_i++ )); do
      bp_pack="${local_packs[$bp_i]}"
      bp_slug="${local_slugs[$bp_i]:-}"
      bp_qdir="$CKA_SIM_ROOT/packs/$bp_pack/$bp_slug"
      if [[ ! -d "$bp_qdir" ]]; then
        err "BLUEPRINT: $manifest: question dir not found: packs/$bp_pack/$bp_slug"
        errors=$(( errors + 1 ))
      else
        bp_est=$(grep -oE 'estimatedMinutes: [0-9]+' "$bp_qdir/metadata.yaml" 2>/dev/null | grep -oE '[0-9]+' || echo 0)
        sum_minutes=$(( sum_minutes + bp_est ))
      fi
    done

    # Check sum estimatedMinutes against manifest's estimatedMinutesBudget field
    budget_line=$(grep -oE 'estimatedMinutesBudget: \[([0-9]+), ([0-9]+)\]' "$manifest" || true)
    if [[ "$budget_line" =~ \[([0-9]+),\ ([0-9]+)\] ]]; then
      budget_lo="${BASH_REMATCH[1]}"
      budget_hi="${BASH_REMATCH[2]}"
    else
      budget_lo=120
      budget_hi=130
    fi
    if (( sum_minutes < budget_lo || sum_minutes > budget_hi )); then
      err "BLUEPRINT: $manifest: estimatedMinutes sum=$sum_minutes not in [$budget_lo, $budget_hi]"
      errors=$(( errors + 1 ))
    fi

    # Check disclaimer in manifest
    if ! grep -qF "Not real CKA exam content; independently authored" "$manifest"; then
      err "BLUEPRINT: $manifest: missing MOCK-03 disclaimer in manifest"
      errors=$(( errors + 1 ))
    fi

    # Check README disclaimer
    local_readme="$local_bp_dir/README.md"
    if [[ -r "$local_readme" ]]; then
      if ! grep -qF "Not real CKA exam content; independently authored" "$local_readme"; then
        err "BLUEPRINT: $local_readme: missing MOCK-03 disclaimer in README"
        errors=$(( errors + 1 ))
      fi
    else
      err "BLUEPRINT: $local_bp_dir: missing README.md"
      errors=$(( errors + 1 ))
    fi
  done < <(find "$EXAMS_DIR" -mindepth 2 -maxdepth 2 -name manifest.yaml 2>/dev/null)
fi

info "pass I: reset.sh /tmp/cka-sim/ cleanup (Phase 07.1 grading-honesty)"
# Every reset.sh must remove its per-question baseline dir so stale baselines
# don't poison the next drill run. Warn-only until Wave 5 lands cleanup across
# all packs; CI can flip ENFORCE_RESET_TMP_CLEANUP=1 after that.
ENFORCE_RESET_TMP_CLEANUP=${ENFORCE_RESET_TMP_CLEANUP:-0}
while IFS= read -r reset_sh; do
  checked=$(( checked + 1 ))
  if ! grep -qE 'rm[[:space:]]+-rf[[:space:]]+["]?(/tmp/cka-sim/|[^[:space:]]*tmp/cka-sim/)' "$reset_sh" 2>/dev/null; then
    if (( ENFORCE_RESET_TMP_CLEANUP == 1 )); then
      err "RESET-TMP: $reset_sh missing 'rm -rf /tmp/cka-sim/<slug>/' cleanup"
      errors=$(( errors + 1 ))
    else
      warn "RESET-TMP: $reset_sh missing 'rm -rf /tmp/cka-sim/<slug>/' cleanup (warn-only until Wave 5)"
    fi
  fi
done < <(find "$PACKS_DIR" -name 'reset.sh' -type f)

printf '\n' >&2
if (( errors > 0 )); then
  err "$errors pack lint error(s) across $checked check(s). Fix before pushing."
  exit 1
fi
ok "pack lint passed ($checked check(s))."
exit 0
