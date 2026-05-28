# Report cluster node and version information

Pack: dump-cooloo9871
Source topic: source-q14 (Cluster information)

Lab namespace: `${CKA_SIM_LAB_NS}`

Use kubectl against the live lab state seeded by this drill. Create a ConfigMap named `q14-answer` in the lab namespace with these data keys:

- `nodeCount`
- `controlPlaneVersion`

Use commands to derive the values; do not read or modify files under `/tmp/cka-sim` for the answer.
