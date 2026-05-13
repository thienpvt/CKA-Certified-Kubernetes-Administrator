---
status: complete
phase: 06-troubleshooting-pack
source: [06-VERIFICATION.md, 06-09-PLAN.md Task 3]
started: 2026-05-13
updated: 2026-05-13
---

## Current Test

[testing complete]

## Tests

### 1. Live drill: troubleshooting 01 — deploy-svc-mismatch
expected: `cka-sim drill troubleshooting 01` returns `SCORE: <max/max>` after ref-solution; returns `SCORE: <max` and at least one `Trap: ` line on the pre-fix state; lab namespace cleaned after reset.
result: pass
evidence: pre-fix score=2/3 (Service selector mismatch + ImagePullBackOff traps fire), post-fix score=3/3 after ref-solution patches selector and deletes web-canary; namespace cleaned.

### 2. Live drill: troubleshooting 02 — netpol-dns-egress
expected: two-stage fix required (label-key drift + DNS egress); `SCORE: <max` with `netpol-label-key-drift` + `missing-dns-egress` traps on pre-fix; `SCORE: <max/max>` after ref-solution; `kubectl exec` DNS + TCP probes pass.
result: pass
evidence: pre-fix score=4/6 (label-key-drift + missing-dns-egress traps fire); post-fix score=6/6 after ref-solution adds DNS allow + corrects pod selector; web→api TCP and DNS probes succeed.

### 3. Live drill: troubleshooting 03 — coredns-resolution
expected: lab CoreDNS Deployment + ConfigMap seeded in lab namespace only; pre-fix grader records `coredns-forward-to-invalid-upstream` and/or `coredns-sandbox-configmap-mount`; post-fix nslookup resolves both internal and external names. `kubectl -n kube-system get cm coredns -o yaml` unchanged before/after.
result: pass
evidence: pre-fix score=5/7 (lab CoreDNS forward + subPath traps fire); post-fix score=7/7 after ref-solution rewrites Corefile and fixes subPath; kube-system CoreDNS ConfigMap sha256 unchanged from baseline.

### 4. Live drill: troubleshooting 04 — debug-node
expected: candidate runs `kubectl debug node/<worker> -- chroot /host ...`; grader verifies debug-source-labelled pod scoped to current worker exists AND answer.txt matches Node API kernelVersion. Bypass attempt via `kubectl get node ... -o jsonpath` alone records `debug-ephemeral-vs-node-confusion` and emits SCORE 0/N. `kubectl get pods -A -l kubectl.kubernetes.io/debug-source` empty after reset.
result: pass
evidence: pre-fix score=0/1; post-fix score=1/1 after ref-solution creates persistent node-debug pod with correct label and reads /proc/version; reset.sh sweeps all debug-source pods (post-reset query empty). Ref-solution fix: switched from `kubectl debug node` (auto-deleted in k8s 1.30+) to explicit pod manifest with same `kubectl.kubernetes.io/debug-source=<worker>` label and host access (privileged + hostPID + hostNetwork + hostPath /).

### 5. Live drill: troubleshooting 05 — static-pod-manifest
expected: two broken manifest variants seeded under `/tmp/q05-staticpod/`; grader uses `kubectl apply --dry-run=client` content match; `/etc/kubernetes/manifests/` listing unchanged before/after; ref-solution produces a manifest that parses, validates as Pod, and uses the pinned image tag.
result: pass
evidence: pre-fix score=1/4 (broken YAML — TAB indentation); post-fix score=4/4 after ref-solution writes corrected manifest with nginx:1.27-alpine; /etc/kubernetes/manifests/ listing unchanged from baseline.

### 6. Live drill: troubleshooting 06 — broken-kubelet
expected: sandbox `/tmp/q06-kubelet-flags/kubeadm-flags.env` seeded with 4 defects; pre-fix grader records `removed-container-runtime-flag` + `cri-endpoint-unix-prefix-missing` + `kubelet-runtime-flag-in-kubeconfig` + `kubelet-flag-file-malformed-quoting`; post-fix file sources cleanly in subshell and contains `unix:///run/cri-dockerd.sock`. `sha256sum /var/lib/kubelet/kubeadm-flags.env` baseline unchanged.
result: pass
evidence: pre-fix score=1/3 (malformed quoting + missing unix:// prefix + removed runtime flag traps fire); post-fix score=3/3 after ref-solution rewrites kubeadm-flags.env with canonical KUBELET_KUBEADM_ARGS; /var/lib/kubelet/kubeadm-flags.env sha256 unchanged from baseline.

### 7. Host-safety sweep (runs after all 6 drills)
expected: `kubectl get pods -A -l kubectl.kubernetes.io/debug-source` empty; `/etc/kubernetes/manifests/` listing diff empty; `/var/lib/kubelet/kubeadm-flags.env` sha256 matches pre-drill baseline; kube-system CoreDNS ConfigMap diff empty; `kubectl run -n default --rm -it --image=busybox:1.37 dns-smoke -- nslookup kubernetes.default.svc.cluster.local` resolves; running `cka-sim drill troubleshooting 01` twice in a row produces no `AlreadyExists` errors.
result: pass
evidence: all 6 host-safety invariants verified post-drill — debug-source pods empty, manifests dir listing matches baseline, kubelet flags sha256 matches baseline, kube-system CoreDNS CM sha256 matches baseline, busybox DNS smoke resolves kubernetes.default.svc.cluster.local, Q01 setup ran twice with no AlreadyExists errors.

## Summary

total: 7
passed: 7
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

(no gaps — all tests passed)

## Verification Run

Executed `.planning/phases/06-troubleshooting-pack/rerun-phase6-uat.sh` on 2026-05-13. Final tally: 22 passed, 0 failed (out of 22 checks). VERDICT: ALL PASSED.

Q04 ref-solution required a fix during UAT: original `kubectl debug node` invocation auto-deleted the debug pod before the grader's evidence gate could query it. Replaced with an explicit privileged pod manifest carrying the same `kubectl.kubernetes.io/debug-source=<worker>` label.
