# Inspect a pod container detail

Pack: dump-cooloo9871
Source topic: source-q17 (Find container of pod and check info)

Lab namespace: `${CKA_SIM_LAB_NS}`

Use kubectl against the live lab state seeded by this drill. Create a ConfigMap named `q17-answer` in the lab namespace with these data keys:

- `container`
- `image`
- `command`

Use commands to derive the values; do not read or modify files under `/tmp/cka-sim` for the answer.
