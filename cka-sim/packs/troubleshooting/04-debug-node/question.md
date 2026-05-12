# Troubleshooting: Inspect a worker node read-only

**Domain:** Troubleshooting  |  **Estimated time:** 9 minutes

A scheduling decision depends on a kernel property of one specific worker node. Discover the exact kernel version string from that worker's host and record it in the sandbox answer file, without modifying anything on the worker host.

## Sandbox

Work in `/tmp/q04-debug-node/`.

- Worker hostname: `/tmp/q04-debug-node/worker.txt` (one line)
- Answer file: `/tmp/q04-debug-node/answer.txt` (single line, exact match)

## Constraints

- Do not modify any file on the worker host.
- Do not SSH to the worker; use a Kubernetes-native mechanism.
- Do not add or modify cluster objects outside `/tmp/q04-debug-node/` and transient inspection tooling you use.

## Verify yourself

`cat /tmp/q04-debug-node/answer.txt` should match:

```bash
worker=$(cat /tmp/q04-debug-node/worker.txt)
kubectl get node "$worker" -o jsonpath='{.status.nodeInfo.kernelVersion}'
```
