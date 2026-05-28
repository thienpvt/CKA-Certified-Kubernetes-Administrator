# Inspect simulated etcd certificate and key metadata

Pack: dump-cooloo9871
Source topic: preview-q01 (Etcd certificate and key inspection)

Lab namespace: `${CKA_SIM_LAB_NS}`

Use kubectl against the live lab state seeded by this drill. Create a ConfigMap named `q28-answer` in the lab namespace with these data keys:

- `serverKey`
- `clientAuth`
- `snapshotPath`

Use commands to derive the values; do not read or modify files under `/tmp/cka-sim` for the answer.
