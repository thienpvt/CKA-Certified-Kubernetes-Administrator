# expected-symptom.yaml schema

Per-question `expected-symptom.yaml` describes the post-`setup.sh` cluster state
that `question.md` claims. `cka-sim/scripts/lint-question-symptom.sh` diffs the
live cluster against this file; any divergence is a question-vs-setup contract
bug that must be fixed before the question ships.

## Shape

```yaml
question: <pack-id>-<question-slug>     # RFC 1123; matches metadata.yaml id
namespace: ${CKA_SIM_LAB_NS}            # or null/omitted for cluster-scoped resources
resources:                              # list of expected resources
  - kind: <one of the allow-list>
    name: <resource-name>
    namespace: ${CKA_SIM_LAB_NS}        # optional; defaults to the top-level namespace
    expect:                             # jsonpath -> expected-string map
      <jsonpath>: <expected-value>
absent_resources:                       # optional; resources that MUST NOT exist
  - kind: <one of the allow-list>
    name: <resource-name>
    namespace: <ns>                     # optional; defaults to top-level namespace
```

- Top-level `question:` is a free-form string but should match the
  `metadata.yaml` `id:` field for the question dir.
- Top-level `namespace:` provides the default namespace for any `resources` /
  `absent_resources` entry that omits its own `namespace:`. Cluster-scoped
  resources (`pv`, `storageclass`, `clusterrole`, `clusterrolebinding`,
  `priorityclass`, `volumesnapshotclass`, `namespace`) ignore namespace.
- Per-resource `expect:` is a flat map. Keys are jsonpath-style dot-paths
  (e.g. `status.phase`, `spec.storageClassName`). Values are stringified
  literals. An empty `expect: {}` is a presence check: the resource must exist,
  but no field is asserted.

## Resource-kind allow-list

The lint script only diffs the following kinds. Unknown kinds emit a warn and
are skipped (rather than fail the lint):

`pvc, pv, pod, svc, deploy, networkpolicy, configmap, secret, namespace, role,
rolebinding, clusterrole, clusterrolebinding, serviceaccount, hpa, daemonset,
replicaset, priorityclass, storageclass, volumesnapshot, volumesnapshotclass,
ingress`

Each short alias maps to the canonical kubectl kind in
`cka-sim/scripts/lint-question-symptom.sh` (`pvc` -> `persistentvolumeclaim`,
`deploy` -> `deployment`, etc.).

## Substitution rules

`${CKA_SIM_LAB_NS}` is the only allowed placeholder; it is replaced at lint
time with the per-question lab namespace that the lint script generates
(typically `cka-sim-lint-<pack>-<question>`). No other env-var expansion is
performed; literal `$VAR` strings are passed through as-is.

## Open-world semantics

Only fields listed under `expect:` are diffed. Extra fields on the live
resource do NOT fail. A missing live resource DOES fail (with a
`<file>:<line>: <kind>/<name> not found` citation).

An unexpected resource present in the cluster does NOT fail — that is what
`absent_resources:` is for. Use `absent_resources:` for negative claims
(resources the question text says must not exist at setup time, such as a
candidate-authored deployment that the candidate creates as part of the task).

## jsonpath translator

The lint script translates user-friendly jsonpath dot-form into jq queries:

| Author writes                                                | jq query                                               |
|--------------------------------------------------------------|--------------------------------------------------------|
| `status.phase`                                               | `.status.phase`                                        |
| `spec.template.spec.containers[0].image`                     | `.spec.template.spec.containers[0].image`              |
| `status.conditions[?(@.type=="Available")].status`           | `.status.conditions[] | select(.type=="Available") | .status` |
| `metadata.labels.pod-security\.kubernetes\.io/enforce`       | `.metadata.labels."pod-security.kubernetes.io/enforce"`|

The conditions selector and dotted-key label forms are special-cased; all
other paths are passed through as `.<dot-path>`.

## Authoring guidance

Derive `expected-symptom.yaml` from `question.md`'s claimed symptom (NOT from running setup.sh).
The point of the symptom-diff is to catch question-vs-setup drift. If you
generate the YAML from setup output, you encode the drift instead of catching
it.

For example, if `question.md` says "the PVC is stuck Pending" and the candidate
runs `setup.sh` and finds the PVC actually Bound, the lint must fail — because
the post-setup reality contradicts the question text. Encoding the question's
claim makes that drift visible.

## Worked example: storage/01-pvc-binding

```yaml
# storage/01-pvc-binding — post-setup.sh symptom expected by question.md.
question: storage-pvc-binding
namespace: ${CKA_SIM_LAB_NS}
resources:
  - kind: pvc
    name: app-data
    namespace: ${CKA_SIM_LAB_NS}
    expect:
      status.phase: Pending
      spec.storageClassName: manual
  - kind: pv
    name: q01-app-pv
    expect:
      status.phase: Available
      spec.storageClassName: manual
      spec.persistentVolumeReclaimPolicy: Retain
```

The PV's `spec.nodeAffinity` is intentionally NOT enumerated under `expect:`
— the post-setup state INTENTIONALLY omits it (that's the trap the candidate
must fix). Open-world semantics handle missing fields silently; adding a
negative claim for a missing-but-expected field is unsupported.
