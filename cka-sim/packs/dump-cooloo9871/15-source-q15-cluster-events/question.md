# Find recent cluster events

Pack: dump-cooloo9871
Source topic: source-q15 (Cluster event logging)

Lab namespace: `${CKA_SIM_LAB_NS}`

Use kubectl against the live lab state seeded by this drill. Create a ConfigMap named `q15-answer` in the lab namespace with these data keys:

- `warningReason`
- `involvedObject`

Use commands to derive the values; do not read or modify files under `/tmp/cka-sim` for the answer.
