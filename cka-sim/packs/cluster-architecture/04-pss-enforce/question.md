# Pod Security Standards Enforcement

The lab namespace is labelled for `restricted` Pod Security admission at version `v1.35`. Both labels are set: `pod-security.kubernetes.io/enforce=restricted` and `pod-security.kubernetes.io/enforce-version=v1.35`. Any Pod admitted here must satisfy the restricted profile.

Inspect `/tmp/q04-pss-enforce/violator-admission.log` first. Setup captured the apiserver's reply when a bare privileged reference Pod was submitted against this namespace. The log is the canonical example of what a restricted-PSS rejection looks like on v1.25+ clusters.

Your task: edit `/tmp/q04-pss-enforce/candidate-violator.yaml` so it describes a Pod that complies with the restricted profile. The file is pre-seeded with a known-wrong template. You can fix it in place or replace the whole body — the grader inspects file contents directly and does not require you to `kubectl apply` anything.

Restricted-profile requirements (all are mandatory in the submission):

- no privileged containers (`securityContext.privileged` must be absent or `false`)
- `runAsNonRoot: true` at pod level
- drop all Linux capabilities: `capabilities.drop: ["ALL"]`
- `seccompProfile.type: RuntimeDefault`
- `allowPrivilegeEscalation: false`

Constraints:

- Do NOT add a `pod-security.kubernetes.io/exempt` label to the Pod. No such label bypasses Pod Security — exemptions live in cluster-wide AdmissionConfiguration, not on individual Pods.
- Do NOT write the legacy pod-security policy wording in your submission. The replacement admission controller uses different error strings; leaving the legacy string in your YAML trips a grader trap.
- The candidate does not need to apply the manifest to the cluster. The grader inspects `/tmp/q04-pss-enforce/candidate-violator.yaml` contents directly via the registered detectors.

## Verify

```bash
cat /tmp/q04-pss-enforce/candidate-violator.yaml
```

```bash
kubectl apply --dry-run=server -f /tmp/q04-pss-enforce/candidate-violator.yaml
```
