# Inspect simulated kubelet client and serving certs

Pack: dump-cooloo9871
Source topic: source-q23 (Kubelet certificate info)

Lab namespace: `${CKA_SIM_LAB_NS}`

Use kubectl against the live lab state seeded by this drill. Create a ConfigMap named `q23-answer` in the lab namespace with these data keys:

- `clientIssuer`
- `servingEku`

Use commands to derive the values; do not read or modify files under `/tmp/cka-sim` for the answer.
