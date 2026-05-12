# Troubleshooting: Static pod never becomes Running

**Domain:** Troubleshooting  |  **Estimated time:** 10 minutes

Candidate static-pod manifest lives in sandbox. When manifest is placed in kubelet's static-pod directory, intended Pod `q05-cache` never appears in `kubectl get pods -A` or never reaches `Running`.

Repair sandbox manifest so that when kubelet picks it up, Pod reaches `Running`.

## Sandbox

- Working directory: `/tmp/q05-staticpod/`
- Candidate manifest: `/tmp/q05-staticpod/manifest.yaml`
- Reference variants, read-only: `/tmp/q05-staticpod/manifest-broken.yaml` and `/tmp/q05-staticpod/manifest-tagtypo.yaml`

## Tasks

- Inspect `/tmp/q05-staticpod/manifest.yaml` and identify why it cannot produce a Running Pod.
- Edit `/tmp/q05-staticpod/manifest.yaml` in place so it is valid YAML, defines a single `Pod`, and references an existing image.
- Confirm acceptability via client-side dry-run.

## Constraints

- Do NOT place manifest into `/etc/kubernetes/manifests/`.
- Do NOT restart kubelet.
- Do NOT run `systemctl`.
- `metadata.name` must remain `q05-cache`.

## Verify yourself

```bash
python3 -c 'import yaml; yaml.safe_load(open("/tmp/q05-staticpod/manifest.yaml"))'
kubectl apply --dry-run=client -f /tmp/q05-staticpod/manifest.yaml
```

Both commands must exit 0.
