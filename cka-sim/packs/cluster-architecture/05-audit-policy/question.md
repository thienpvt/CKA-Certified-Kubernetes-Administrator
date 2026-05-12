# Audit Policy Authoring

Edit `/tmp/q05-audit-policy/policy.yaml` so it is a valid `audit.k8s.io/v1` `Policy`.

The policy should include:

- Metadata-level logging for Secrets.
- Request-level logging for ConfigMaps.
- None-level logging for Events.
- `omitStages: [RequestReceived]`.

Do not apply the policy to the live apiserver and do not edit `/etc/kubernetes/`.
