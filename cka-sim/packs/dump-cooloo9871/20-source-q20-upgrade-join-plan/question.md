# Write a safe upgrade and join runbook

Pack: dump-cooloo9871
Source topic: source-q20 (Update Kubernetes version and join cluster)

Lab namespace: `${CKA_SIM_LAB_NS}`

Use kubectl against the live lab state seeded by this drill. Create a ConfigMap named `q20-answer` in the lab namespace with these data keys:

- `firstStep`
- `joinMode`

Use commands to derive the values; do not read or modify files under `/tmp/cka-sim` for the answer.
