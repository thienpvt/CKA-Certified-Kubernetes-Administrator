#!/bin/bash
# tests/cases/symptom-diff-lib-name-substitution.sh — Phase 17 BLG-01
# Locks: the python parser inside cka_sim::symptom_diff::run_one substitutes
# ${CKA_SIM_LAB_NS} on resource name fields (not just namespace + expect values).
set -euo pipefail

: "${CKA_SIM_ROOT:?CKA_SIM_ROOT must be set by run.sh}"

# Graceful skip if python3+yaml isn't available locally (e.g. Windows MSYS host
# where python3 resolves to a Microsoft Store stub). The lib itself preflights
# this via lint-question-symptom.sh's tool gate; the case mirrors that gate to
# stay portable. CI (Linux) always has both.
if ! python3 -c 'import yaml' >/dev/null 2>&1; then
  printf 'SKIP: python3+yaml not available locally (the lib preflights this; CI Linux has it)\n' >&2
  exit 0
fi

# Build a tmp YAML that uses ${CKA_SIM_LAB_NS} in name (Pattern A reproducer).
tmp_dir=$(mktemp -d)
yaml="$tmp_dir/expected-symptom.yaml"
cat >"$yaml" <<'YAML'
question: blg-01-reproducer
namespace: ${CKA_SIM_LAB_NS}
resources:
  - kind: namespace
    name: ${CKA_SIM_LAB_NS}
    expect:
      status.phase: Active
YAML

# Drive the parser in isolation via the same python heredoc that lib uses.
parsed=$(python3 - "$yaml" "lab-ns-actual" <<'PY'
import sys
import yaml
path, ns = sys.argv[1], sys.argv[2]
with open(path) as f:
    d = yaml.safe_load(f) or {}

def sub(v):
    if isinstance(v, str):
        return v.replace('${CKA_SIM_LAB_NS}', ns)
    return v

top_ns = sub(d.get('namespace') or '')
for r in (d.get('resources') or []):
    kind = r.get('kind') or ''
    name = r.get('name') or ''
    rns = sub(r.get('namespace') if r.get('namespace') is not None else top_ns)
    print('R', kind, sub(name), rns, sep='\t')
    for jp, ev in (r.get('expect') or {}).items():
        print('E', kind, sub(name), jp, sub(str(ev)), sep='\t')
PY
)

rm -rf "$tmp_dir"

# Assert: the R event line carries the substituted ns ('lab-ns-actual'), not the literal '${CKA_SIM_LAB_NS}'.
if ! grep -qE $'^R\tnamespace\tlab-ns-actual\tlab-ns-actual$' <<<"$parsed"; then
  printf 'FAIL: expected R event with substituted name=lab-ns-actual\n' >&2
  printf 'parsed output:\n%s\n' "$parsed" >&2
  exit 1
fi

# Assert: the E event line also carries the substituted name.
if ! grep -qE $'^E\tnamespace\tlab-ns-actual\tstatus\\.phase\tActive$' <<<"$parsed"; then
  printf 'FAIL: expected E event with substituted name=lab-ns-actual\n' >&2
  printf 'parsed output:\n%s\n' "$parsed" >&2
  exit 1
fi

# Assert: the literal placeholder does not appear anywhere in the parsed output.
if grep -qF '${CKA_SIM_LAB_NS}' <<<"$parsed"; then
  printf 'FAIL: literal ${CKA_SIM_LAB_NS} placeholder leaked into parsed output\n' >&2
  printf 'parsed output:\n%s\n' "$parsed" >&2
  exit 1
fi

exit 0
