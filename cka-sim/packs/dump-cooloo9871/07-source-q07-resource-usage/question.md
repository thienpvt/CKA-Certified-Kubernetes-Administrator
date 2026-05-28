# Report node and pod resource requests

Pack: dump-cooloo9871
Source topic: source-q07 (Node and pod resource usage)

Lab namespace: `${CKA_SIM_LAB_NS}`

Use kubectl against the live lab state seeded by this drill. Create a ConfigMap named `q07-answer` in the lab namespace with these data keys:

- `largestPodCpu`
- `largestNodeCpu`

Use commands to derive the values; do not read or modify files under `/tmp/cka-sim` for the answer.
