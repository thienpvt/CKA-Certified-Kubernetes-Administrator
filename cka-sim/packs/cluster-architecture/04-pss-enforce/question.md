# Pod Security Standards Enforcement

The namespace is labelled for `restricted` Pod Security enforcement at version `v1.35`.

Inspect `/tmp/q04-pss-enforce/violator-admission.log`, then fix `/tmp/q04-pss-enforce/violator.yaml` so it complies with the restricted profile:

- no privileged container
- `runAsNonRoot: true`
- drop all Linux capabilities
- `seccompProfile.type: RuntimeDefault`

Do not try a pod-level `pod-security.kubernetes.io/exempt` label. Pod Security exemptions are cluster-level admission configuration, not pod labels.
