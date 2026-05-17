# Phase 13 Discussion Log

**Discussed:** 2026-05-17
**Mode:** Autonomous --interactive

## Areas Discussed

### BUG-M04 CNI enforcement gating
- Options: detect at setup-time / skip gating / refactor setup with non-NP listener on 8095
- **User selection:** Detect CNI enforcement at setup-time
- Notes: most honest path; lets the grader gate reachability assertions when CNI doesn't enforce NetworkPolicy.

### BUG-M05 audit-policy precise mappings — claude's discretion
- No options surfaced (forensic report is unambiguous: validate per-resource level mapping + omitStages).
- Implementation: replace the existing single "structure valid" assertion with one assertion per requirement: Secrets→Metadata, ConfigMaps→Request, Events→None, omitStages contains RequestReceived. 4 weight=1 scoring assertions.

### BUG-M06 HPA averageUtilization=50 — claude's discretion
- No options surfaced (forensic report names the exact fields needed).
- Implementation: add 2 weight=1 assertions: `target.type == Utilization` and `target.averageUtilization == 50` on the CPU Resource metric. Keep existing 5 assertions.

## Deferred Ideas

- Exhaustive over-permissive NP probe matrix (e.g., test every port outside 8080-8090 individually) — out of scope; criterion 1 only requires that an over-permissive NP fail.
- Audit policy validation against the full kube-apiserver schema (omitting unsupported keys, etc.) — Phase 13 only requires the 3 mappings + omitStages; full schema check could be future enhancement.

## Claude's Discretion

- BUG-M04 setup-time CNI probe specifics (probe pod image, probe duration, sentinel file location) deferred to executor.
- BUG-M05 jsonpath/python-yaml choice for parsing per-rule level — both acceptable; existing grader uses python yaml so continuity favors python.
- BUG-M06 jsonpath query syntax for nested filter selectors deferred to executor.
- Plan splitting (3 plans for 3 bugs vs 1 combined plan) deferred to planner.
