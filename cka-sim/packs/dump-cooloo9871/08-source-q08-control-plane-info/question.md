# Inspect control-plane component information

Pack: dump-cooloo9871
Source topic: source-q08 (Control-plane information)

Lab namespace: `${CKA_SIM_LAB_NS}`

Use kubectl against the live lab state seeded by this drill. Create a ConfigMap named `q08-answer` in the lab namespace with these data keys:

- `component`
- `namespace`
- `securePort`

Use commands to derive the values; do not read or modify files under `/tmp/cka-sim` for the answer.
