# Troubleshooting: Repair the static-pod manifest

**Domain:** Troubleshooting  |  **Estimated time:** 10 minutes

A candidate static-pod manifest lives in the sandbox at `/tmp/q05-staticpod/manifest.yaml`. The file has intentional defects (tab-indented YAML and an image-tag typo) so it cannot be parsed as YAML and would never produce a valid Pod if the kubelet were to pick it up.

Repair the manifest in place so it is (a) valid YAML, (b) defines a single `Pod` named `q05-cache` in the `kube-system` namespace, and (c) passes `kubectl apply --dry-run=client`. The grader scores the file directly — it does NOT install the manifest into `/etc/kubernetes/manifests/` or wait for a Running Pod.

## Sandbox

- Working directory: `/tmp/q05-staticpod/`
- Candidate manifest: `/tmp/q05-staticpod/manifest.yaml`
- Reference variants, read-only: `/tmp/q05-staticpod/manifest-broken.yaml` and `/tmp/q05-staticpod/manifest-tagtypo.yaml`

## Tasks

- Inspect `/tmp/q05-staticpod/manifest.yaml` and identify why it cannot produce a Running Pod.
- Edit `/tmp/q05-staticpod/manifest.yaml` in place so it is valid YAML, defines a single `Pod`, and references an existing image.
- Confirm acceptability via client-side dry-run.

## Constraints

- Do NOT place manifest into '/etc/kubernetes/manifests/'.
- Do NOT restart node services.
- Do NOT run live-service restart commands.
- 'metadata.name' must remain 'q05-cache'.

## Verify yourself

```bash
python3 -c 'import yaml; yaml.safe_load(open("/tmp/q05-staticpod/manifest.yaml"))'
kubectl apply --dry-run=client -f /tmp/q05-staticpod/manifest.yaml
```

Both commands must exit 0.
