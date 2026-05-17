---
phase: 13-grader-strengthening
plan: 01
status: complete
requirements: [BUG-M04]
files_modified:
  - cka-sim/packs/services-networking/06-netpol-endport/setup.sh
  - cka-sim/packs/services-networking/06-netpol-endport/grade.sh
---

# Plan 13-01 Summary — BUG-M04 services-networking/06-netpol-endport

## What changed

- **setup.sh** — Appended a CNI-enforcement probe block after the existing
  `kubectl wait .../q06-client` line:
  - `mkdir -p /tmp/q06-netpol-endport` for sentinel scratch
  - Apply temp deny-all-ingress NP `q06-cni-probe-deny` scoped to `app=q06-server`
  - `sleep 3` then `q06-client` wget probe to `q06-server:8085` (timeout=3)
  - Wget success → sentinel `false`; wget failure → sentinel `true`
  - Delete `q06-cni-probe-deny` NP (`--ignore-not-found --wait=false`)
  - All pre-existing setup blocks (pods/svc/baseline NP/client-egress NP) preserved
    verbatim; `set -euo pipefail` retained.

- **grade.sh** — Full rewrite preserving header/source statements:
  - 4 unconditional weight=1 structural assertions (existence + port=8080 +
    endPort=8090 + protocol=TCP) — act as over-permissive guard
  - `np_authored` gate preserved verbatim via `is_candidate_modified`
  - Reads `/tmp/q06-netpol-endport/.cni-enforces` sentinel and branches:
    - `true` → 4-port reachability matrix (8080/8085/8090 reachable, 8095 NOT
      reachable), each gated on `np_authored`
    - `false` → emit non-scoring info line (no TOTAL/PASSED mutation)
    - missing → emit non-scoring err line (no TOTAL/PASSED mutation)
  - `netpol-endport-missing-protocol` trap detector preserved
  - `cka_sim::grade::emit_result` finalizer preserved

## Scoring shape

| Branch         | Max points | Notes                                                        |
| -------------- | ---------- | ------------------------------------------------------------ |
| Enforcing CNI  | 8/8        | 4 structural + 4 reachability                                |
| Non-enforcing  | 4/4        | 4 structural only; honest info line for reachability         |
| Sentinel miss  | 4/4        | 4 structural only; honest err line "re-run setup"            |

## Verification status

- `bash -n setup.sh` and `bash -n grade.sh` both exit 0.
- Acceptance greps all positive (5 minor numeric discrepancies vs plan literal
  expectations are author-intent equivalent — e.g. `for port in ...` is one
  source line iterating 3 ports, plan expected 5 grep hits but file has 3
  source lines that increment TOTAL — runtime arithmetic matches plan).
- Live GRADE round-trip (ref-solution 4/4 non-enforcing or 8/8 enforcing;
  empty 0/N; over-permissive endPort=8095 fails structurally) requires a
  live cluster — out of scope of this autonomous execution; deferred to UAT.

## Sibling files surveyed (no edits)

- `ref-solution.sh` — applies `q06-allow-range` with port=8080, endPort=8090,
  protocol=TCP. Already canonical for the strengthened grader.
- `reset.sh` — namespace delete sweeps any leftover `q06-cni-probe-deny` if
  setup interrupted; no change needed.
- `metadata.yaml` — trap list (`netpol-endport-missing-protocol`,
  `missing-dns-egress`, `default-sa-used`) unchanged by this fix.
- `question.md` — text already prescribes port=8080 + endPort=8090 + protocol=TCP.

## Open follow-up

- The sentinel at `/tmp/q06-netpol-endport/.cni-enforces` is NOT purged by
  `reset.sh` (existing reset only sweeps `/tmp/cka-sim/06-netpol-endport/`).
  Each setup overwrites the sentinel, so this is acceptable for v1.0.1.
  Cross-question `/tmp` hygiene is its own concern.
