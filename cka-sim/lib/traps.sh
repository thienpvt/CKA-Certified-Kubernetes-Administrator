#!/bin/bash
# cka-sim/lib/traps.sh — trap detector library + catalog parser.
# Sourced by: lib/grade.sh, every grade.sh under packs/*/.
# Detector contract (per CONTEXT D-02): positional args; stdout = trap-id on hit, EMPTY on miss.
# Catalog contract (per CONTEXT D-04): pure-bash parser of traps/catalog.yaml's flat shape into associative arrays.

: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set}"

# shellcheck source=colors.sh disable=SC1091
[[ -z "${RED+x}" ]] && source "$CKA_SIM_ROOT/lib/colors.sh"
# shellcheck source=log.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/log.sh"
# shellcheck source=baseline.sh disable=SC1091
source "$CKA_SIM_ROOT/lib/baseline.sh"

# ---------- Catalog state ----------
#
# Six associative arrays, keyed by trap-id, hold the fields of traps/catalog.yaml.
# `declare -gA` ensures they survive sourcing and are shared across every grade.sh
# that sources this library.

declare -gA CKA_SIM_TRAP_NAME=()
declare -gA CKA_SIM_TRAP_DESC=()
declare -gA CKA_SIM_TRAP_REMEDIATION=()
declare -gA CKA_SIM_TRAP_SEVERITY=()
declare -gA CKA_SIM_TRAP_DOMAIN=()
declare -gA CKA_SIM_TRAP_SOURCE=()
declare -g  CKA_SIM_TRAP_CATALOG_LOADED=0

# ---------- Validation ----------

# cka_sim::trap::is_valid_id <id>
#   Returns 0 iff <id> conforms to RFC 1123 DNS label:
#     - matches ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$
#     - length <= 63
#   Single source of truth for TRIP-07 validation — both lint-traps.sh
#   and record_trap call this.
cka_sim::trap::is_valid_id() {
  local id="${1:-}"
  [[ -n "$id" ]] || return 1
  (( ${#id} <= 63 )) || return 1
  [[ "$id" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]
}

# ---------- Catalog parser ----------

# cka_sim::trap::_load_catalog [<catalog-path>]
#   Pure-bash parser for traps/catalog.yaml's flat shape. Default path is
#   ${CKA_SIM_ROOT}/traps/catalog.yaml. Populates the six associative
#   arrays above. Idempotent — calling twice overwrites the same slots.
#   On parse failure (bad id, missing required field, unreadable file)
#   invokes `die` from log.sh.
cka_sim::trap::_load_catalog() {
  local path="${1:-$CKA_SIM_ROOT/traps/catalog.yaml}"
  [[ -r "$path" ]] || die "catalog parse failed: cannot read '$path'"

  local line trimmed value
  local current_id=""

  # Walk each line of the flat YAML. Required-field completeness is verified
  # in a second pass below; this pass only populates the maps.
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip blank lines and whole-line comments.
    [[ -z "${line//[[:space:]]/}" ]] && continue
    trimmed="${line#"${line%%[![:space:]]*}"}"
    [[ "${trimmed:0:1}" == "#" ]] && continue

    # New entry marker: `^  - id: <id>` (two-space indent is a fixed part of
    # the flat catalog shape — enforced by lint-traps.sh).
    if [[ "$line" =~ ^\ \ -\ id:\ (.+)$ ]]; then
      value="${BASH_REMATCH[1]}"
      value="${value%\"}"
      value="${value#\"}"
      cka_sim::trap::is_valid_id "$value" \
        || die "catalog parse failed: invalid id '$value' (must match RFC 1123)"
      current_id="$value"
      # Claim the slot for this id with empty placeholders. The second-pass
      # completeness check flags any field left empty.
      CKA_SIM_TRAP_NAME[$current_id]=""
      CKA_SIM_TRAP_DESC[$current_id]=""
      CKA_SIM_TRAP_REMEDIATION[$current_id]=""
      CKA_SIM_TRAP_SEVERITY[$current_id]=""
      CKA_SIM_TRAP_DOMAIN[$current_id]=""
      CKA_SIM_TRAP_SOURCE[$current_id]=""
      continue
    fi

    # Field line: `^    (name|description|remediation_hint|severity|domain|source): <value>`.
    # Four-space indent distinguishes top-level entry fields from the `references:`
    # sub-list items (six-space dash) which we intentionally skip.
    if [[ "$line" =~ ^\ \ \ \ (name|description|remediation_hint|severity|domain|source):\ (.+)$ ]]; then
      local field="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
      # Strip one layer of surrounding double-quotes if present.
      if [[ "${value:0:1}" == '"' && "${value: -1}" == '"' ]]; then
        value="${value#\"}"
        value="${value%\"}"
      fi
      [[ -n "$current_id" ]] \
        || die "catalog parse failed: field '$field' appeared before any entry id"
      case "$field" in
        name)             CKA_SIM_TRAP_NAME[$current_id]="$value" ;;
        description)      CKA_SIM_TRAP_DESC[$current_id]="$value" ;;
        remediation_hint) CKA_SIM_TRAP_REMEDIATION[$current_id]="$value" ;;
        severity)         CKA_SIM_TRAP_SEVERITY[$current_id]="$value" ;;
        domain)           CKA_SIM_TRAP_DOMAIN[$current_id]="$value" ;;
        source)           CKA_SIM_TRAP_SOURCE[$current_id]="$value" ;;
      esac
      continue
    fi

    # Anything else (top-level `traps:`, the `references:` sub-list header,
    # its `- kind/target/note` items, stray blank-indent lines) is skipped.
    # Schema enforcement is lint-traps.sh's job; the runtime parser only
    # cares about the six runtime-consumed fields.
  done < "$path"

  # Second pass: verify every claimed entry has all six required fields filled.
  local id
  for id in "${!CKA_SIM_TRAP_NAME[@]}"; do
    [[ -n "${CKA_SIM_TRAP_NAME[$id]}"        ]] || die "catalog parse failed: '$id' missing field 'name'"
    [[ -n "${CKA_SIM_TRAP_DESC[$id]}"        ]] || die "catalog parse failed: '$id' missing field 'description'"
    [[ -n "${CKA_SIM_TRAP_REMEDIATION[$id]}" ]] || die "catalog parse failed: '$id' missing field 'remediation_hint'"
    [[ -n "${CKA_SIM_TRAP_SEVERITY[$id]}"    ]] || die "catalog parse failed: '$id' missing field 'severity'"
    [[ -n "${CKA_SIM_TRAP_DOMAIN[$id]}"      ]] || die "catalog parse failed: '$id' missing field 'domain'"
    [[ -n "${CKA_SIM_TRAP_SOURCE[$id]}"      ]] || die "catalog parse failed: '$id' missing field 'source'"
  done

  CKA_SIM_TRAP_CATALOG_LOADED=1
}

# ---------- Runtime lookup helpers ----------

# cka_sim::trap::id_exists <id>
#   Returns 0 if <id> is present in the loaded catalog, 1 otherwise.
#   Lazy-loads the catalog on first call so graders never have to.
cka_sim::trap::id_exists() {
  local id="${1:-}"
  [[ -n "$id" ]] || return 1
  (( CKA_SIM_TRAP_CATALOG_LOADED == 1 )) || cka_sim::trap::_load_catalog
  [[ -n "${CKA_SIM_TRAP_NAME[$id]+x}" ]]
}

# cka_sim::trap::format_line <ordinal> <id>
#   Prints one catalog-line to stdout:
#     Trap <ordinal>: <name>: <description>
#   Fails via `die` if <id> is not in the catalog.
cka_sim::trap::format_line() {
  local ord="${1:-}" id="${2:-}"
  [[ -n "$ord" && -n "$id" ]] || die "format_line: usage: format_line <ordinal> <id>"
  cka_sim::trap::id_exists "$id" \
    || die "format_line: unknown trap-id '$id' (not in catalog)"
  printf 'Trap %d: %s: %s\n' "$ord" "${CKA_SIM_TRAP_NAME[$id]}" "${CKA_SIM_TRAP_DESC[$id]}"
}

# ---------- Detectors ----------
# Contract (per CONTEXT D-02): positional args; stdout = trap-id on hit, EMPTY on miss.
# No global state, no side effects, idempotent.
#
# 8 seeded detectors — one per id in traps/catalog.yaml.
# kubectl-based detectors: kubectl stderr is suppressed (2>/dev/null) so a
# missing resource looks like a miss, not an error — the PATH-shadowed kubectl
# stub in cka-sim/tests/bin/ exits 1 when no fixture matches, and we treat
# that as "resource not present -> no hit".
# Text-based detectors take a single <text> arg (typically a candidate's
# submitted solution snippet or a captured kubectl error message) and use
# grep/regex to spot the wrong wording. They MUST NOT require kubectl.

# cka_sim::trap::detect_default_sa_used <namespace> <pod-name>
#   Echoes "default-sa-used" if the pod's .spec.serviceAccountName is unset
#   or equals "default" (pod inherits the default SA with auto-mounted token).
cka_sim::trap::detect_default_sa_used() {
  local ns="${1:?detect_default_sa_used: namespace required}"
  local pod="${2:?detect_default_sa_used: pod name required}"
  # Ownership gate (Phase 07.1): skip setup-owned unchanged resources.
  cka_sim::baseline::is_candidate_modified pod "$pod" -n "$ns" || return 0
  local sa
  sa=$(kubectl get pod "$pod" -n "$ns" -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null)
  if [[ -z "$sa" || "$sa" == "default" ]]; then
    echo "default-sa-used"
  fi
}

# cka_sim::trap::detect_missing_dns_egress <namespace> <netpol-name>
#   Echoes "missing-dns-egress" if the NetworkPolicy restricts egress
#   (policyTypes includes "Egress" AND egress rules are present) but none of
#   those rules permit UDP/53. An egress-deny-all policy (policyTypes has
#   "Egress" but .spec.egress is empty/missing) is NOT a hit — the author
#   may intend to block everything.
cka_sim::trap::detect_missing_dns_egress() {
  local ns="${1:?detect_missing_dns_egress: namespace required}"
  local np="${2:?detect_missing_dns_egress: netpol name required}"
  # Ownership gate (Phase 07.1): skip setup-owned unchanged resources.
  cka_sim::baseline::is_candidate_modified networkpolicy "$np" -n "$ns" || return 0
  local json
  json=$(kubectl get networkpolicy "$np" -n "$ns" -o json 2>/dev/null) || return 0
  [[ -n "$json" ]] || return 0
  local has_egress
  has_egress=$(echo "$json" | jq -r '.spec.policyTypes // [] | index("Egress") != null' 2>/dev/null)
  [[ "$has_egress" == "true" ]] || return 0
  local egress_rules
  egress_rules=$(echo "$json" | jq -r '(.spec.egress // []) | length' 2>/dev/null)
  [[ "$egress_rules" =~ ^[0-9]+$ ]] || return 0
  (( egress_rules > 0 )) || return 0
  local has_dns
  has_dns=$(echo "$json" | jq -r '
    [.spec.egress[]?.ports[]?
     | select((.protocol // "TCP") == "UDP")
     | select((.port // 0) == 53 or (.port // "") == "53")
    ] | length > 0' 2>/dev/null)
  if [[ "$has_dns" != "true" ]]; then
    echo "missing-dns-egress"
  fi
}

# cka_sim::trap::detect_hostpath_pv_without_nodeaffinity <pv-name>
#   Echoes "hostpath-pv-without-nodeaffinity" if the PV has .spec.hostPath
#   set AND .spec.nodeAffinity is missing/null. Single-node clusters mask
#   the problem; multi-node clusters hit it the first time the pod reschedules.
cka_sim::trap::detect_hostpath_pv_without_nodeaffinity() {
  local pv="${1:?detect_hostpath_pv_without_nodeaffinity: pv name required}"
  # Ownership gate (Phase 07.1): skip setup-owned unchanged resources (cluster-scoped).
  cka_sim::baseline::is_candidate_modified pv "$pv" || return 0
  local json
  json=$(kubectl get pv "$pv" -o json 2>/dev/null) || return 0
  [[ -n "$json" ]] || return 0
  local has_hostpath has_nodeaffinity
  has_hostpath=$(echo "$json" | jq -r '.spec.hostPath != null' 2>/dev/null)
  has_nodeaffinity=$(echo "$json" | jq -r '.spec.nodeAffinity != null' 2>/dev/null)
  if [[ "$has_hostpath" == "true" && "$has_nodeaffinity" != "true" ]]; then
    echo "hostpath-pv-without-nodeaffinity"
  fi
}

# cka_sim::trap::detect_pss_error_string_mismatch <text>
#   Echoes "pss-error-string-mismatch" if <text> contains the legacy
#   "PodSecurityPolicy" wording AND does NOT contain the v1.25+ wording
#   `violates PodSecurity "`. Operates on the candidate's submitted text
#   (no kubectl call) — Phase 3 graders pipe in the candidate's answer.
cka_sim::trap::detect_pss_error_string_mismatch() {
  local text="${1:-}"
  [[ -n "$text" ]] || return 0
  if grep -qF 'PodSecurityPolicy' <<<"$text" \
     && ! grep -qE 'violates PodSecurity "' <<<"$text"; then
    echo "pss-error-string-mismatch"
  fi
}

# cka_sim::trap::detect_psp_fictional_pod_label_exemption <text>
#   Echoes "psp-fictional-pod-label-exemption" if <text> uses the fictional
#   pod-level label key pod-security.kubernetes.io/exempt: (no such label
#   bypasses PSS — exemptions are AdmissionConfiguration-level).
cka_sim::trap::detect_psp_fictional_pod_label_exemption() {
  local text="${1:-}"
  [[ -n "$text" ]] || return 0
  if grep -qE 'pod-security\.kubernetes\.io/exempt[: ]' <<<"$text"; then
    echo "psp-fictional-pod-label-exemption"
  fi
}

# cka_sim::trap::detect_kubelet_runtime_flag_in_kubeconfig <text>
#   Echoes "kubelet-runtime-flag-in-kubeconfig" if <text> edits
#   /etc/kubernetes/kubelet.conf (the kubeconfig) AND adds a --container-runtime
#   flag. Kubelet runtime flags belong in /var/lib/kubelet/kubeadm-flags.env,
#   not the kubeconfig file.
cka_sim::trap::detect_kubelet_runtime_flag_in_kubeconfig() {
  local text="${1:-}"
  [[ -n "$text" ]] || return 0
  if grep -qE '/etc/kubernetes/kubelet\.conf' <<<"$text" \
     && grep -qE -- '--container-runtime' <<<"$text"; then
    echo "kubelet-runtime-flag-in-kubeconfig"
  fi
}

# cka_sim::trap::detect_removed_container_runtime_flag <text>
#   Echoes "removed-container-runtime-flag" if <text> contains the removed
#   --container-runtime=<value> flag (any value). Only --container-runtime-endpoint=
#   remains in 1.27+; the bare --container-runtime= flag was removed.
cka_sim::trap::detect_removed_container_runtime_flag() {
  local text="${1:-}"
  [[ -n "$text" ]] || return 0
  # Match --container-runtime=<word-char> but NOT --container-runtime-endpoint=
  # (the leading-char class excludes the hyphen that starts "-endpoint").
  if grep -qE -- '--container-runtime=[a-z]' <<<"$text"; then
    echo "removed-container-runtime-flag"
  fi
}

# cka_sim::trap::detect_as_flag_format_wrong <text>
#   Echoes "as-flag-format-wrong" if <text> contains a kubectl --as=VALUE
#   or --as VALUE where VALUE contains a colon AND does NOT start with
#   "system:serviceaccount:". Plain usernames (no colon) are allowed;
#   system:serviceaccount:<ns>:<name> is allowed; "my-sa" bare name is
#   allowed at the regex level (no colon) because it doesn't fit the
#   "wrong subject" fingerprint — the trap specifically catches the
#   half-remembered "system:serviceaccount:foo" or "sa:foo" typos.
cka_sim::trap::detect_as_flag_format_wrong() {
  local text="${1:-}"
  [[ -n "$text" ]] || return 0
  local v
  while IFS= read -r v; do
    [[ -n "$v" ]] || continue
    # Allowed: bare username (no colon) OR system:serviceaccount:NS:NAME.
    # Hit: any other colon-containing shape (e.g. "foo:bar", "sa:foo").
    if [[ "$v" == *:* ]] && [[ "$v" != system:serviceaccount:*:* ]]; then
      echo "as-flag-format-wrong"
      return 0
    fi
  done < <(grep -oE -- '--as[ =][^[:space:]]+' <<<"$text" \
            | sed -E 's/^--as[ =]//')
}

# cka_sim::trap::detect_rbac_viewer_role_mismatch <namespace> <role-name>
#   Echoes "rbac-viewer-role-mismatch" if the Role has at least one rule
#   that targets pods (apiGroups includes "" and resources includes "pods")
#   BUT that rule's verbs do NOT include both "get" AND "list". Intended
#   for questions where a candidate Role is supposed to grant viewer-level
#   pod access; this detector fires when the verbs are wrong (e.g., only
#   "watch", or missing altogether).
cka_sim::trap::detect_rbac_viewer_role_mismatch() {
  local ns="${1:?detect_rbac_viewer_role_mismatch: namespace required}"
  local role="${2:?detect_rbac_viewer_role_mismatch: role name required}"
  # Ownership gate (Phase 07.1): skip setup-owned unchanged resources.
  cka_sim::baseline::is_candidate_modified role "$role" -n "$ns" || return 0
  local json
  json=$(kubectl get role "$role" -n "$ns" -o json 2>/dev/null) || return 0
  [[ -n "$json" ]] || return 0

  # Stage 1 — count pod-targeting rules. Zero rules = trap.
  local pod_rule_count
  pod_rule_count=$(echo "$json" | jq -r '
    [.rules[]?
     | select(((.apiGroups // []) | index("")) != null)
     | select(((.resources // []) | index("pods")) != null)
    ] | length' 2>/dev/null)
  if [[ ! "$pod_rule_count" =~ ^[0-9]+$ ]] || (( pod_rule_count == 0 )); then
    echo "rbac-viewer-role-mismatch"
    return 0
  fi

  # Stage 2 — pod rule(s) exist; collect their verbs and require get AND list.
  local verbs_csv
  verbs_csv=$(echo "$json" | jq -r '
    [.rules[]?
     | select(((.apiGroups // []) | index("")) != null)
     | select(((.resources // []) | index("pods")) != null)
     | .verbs[]?
    ] | unique | @csv' 2>/dev/null)
  local has_get=0 has_list=0
  grep -qE '"(get|\*)"'  <<<"$verbs_csv" && has_get=1
  grep -qE '"(list|\*)"' <<<"$verbs_csv" && has_list=1
  if (( has_get == 0 )) || (( has_list == 0 )); then
    echo "rbac-viewer-role-mismatch"
  fi
}

# cka_sim::trap::detect_service_label_mismatch <namespace> <service-name>
#   Echoes "service-selector-empty-endpoints" if the Service exists but no
#   EndpointSlice has any ready addresses for it. Queries EndpointSlice (the
#   authoritative resource on k8s 1.21+; pack target is 1.35) via the
#   `kubernetes.io/service-name=<svc>` label selector — NOT the legacy
#   Endpoints object, which can be suppressed on managed clusters.
#   Cannot-determine paths (Service missing, kubectl/jq parse failure) return
#   without echoing — they are NOT misclassified as hits. The echoed id MUST
#   match the catalog entry (see cka-sim/traps/catalog.yaml); lint-traps.sh
#   + lint-packs.sh both enforce that every id emitted is registered.
cka_sim::trap::detect_service_label_mismatch() {
  local ns="${1:?detect_service_label_mismatch: namespace required}"
  local svc="${2:?detect_service_label_mismatch: service name required}"
  # Ownership gate (Phase 07.1): skip setup-owned unchanged resources.
  cka_sim::baseline::is_candidate_modified service "$svc" -n "$ns" || return 0
  # Service must exist for the detector to fire (otherwise different problem)
  kubectl get service "$svc" -n "$ns" -o name >/dev/null 2>&1 || return 0
  local addr_count
  addr_count=$(kubectl get endpointslice -n "$ns" \
                 -l "kubernetes.io/service-name=$svc" -o json 2>/dev/null \
               | jq -r '[.items[]?.endpoints[]?.addresses[]?] | length' 2>/dev/null)
  # Cannot-determine -> miss (do NOT misreport as hit). EndpointSlice fetch
  # failures (RBAC deny, transient API error) and jq parse failures both
  # leave $addr_count non-numeric, which we silently treat as "no signal".
  [[ "$addr_count" =~ ^[0-9]+$ ]] || return 0
  if (( addr_count == 0 )); then
    echo "service-selector-empty-endpoints"
  fi
}
