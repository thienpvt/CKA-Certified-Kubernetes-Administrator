# Inspect simulated apiserver certificate validity

Pack: dump-cooloo9871
Source topic: source-q22 (Certificate validity)

Lab namespace: `${CKA_SIM_LAB_NS}`

Use kubectl against the live lab state seeded by this drill. Create a ConfigMap named `q22-answer` in the lab namespace with these data keys:

- `certName`
- `validUntil`
- `signer`

Use commands to derive the values; do not read or modify files under `/tmp/cka-sim` for the answer.
