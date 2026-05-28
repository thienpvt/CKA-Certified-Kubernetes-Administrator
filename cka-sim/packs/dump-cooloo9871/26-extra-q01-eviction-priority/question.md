# Identify pods first to be evicted

Pack: dump-cooloo9871
Source topic: extra-q01 (Eviction priority analysis)

Lab namespace: `${CKA_SIM_LAB_NS}`

Use kubectl against the live lab state seeded by this drill. Create a ConfigMap named `q26-answer` in the lab namespace with these data keys:

- `firstEvicted`
- `lastEvicted`

Use commands to derive the values; do not read or modify files under `/tmp/cka-sim` for the answer.
