---
status: complete
phase: 05-services-networking-cluster-architecture-packs
source: [05-01-SUMMARY.md, 05-02-SUMMARY.md, 05-03-SUMMARY.md, 05-04-SUMMARY.md, 05-05-SUMMARY.md, 05-06-SUMMARY.md, 05-07-SUMMARY.md, 05-08-SUMMARY.md, 05-09-SUMMARY.md, 05-10-SUMMARY.md, 05-11-SUMMARY.md, 05-12-SUMMARY.md, 05-13-SUMMARY.md, 05-14-SUMMARY.md, 05-15-SUMMARY.md, 05-16-SUMMARY.md]
started: 2026-05-12T15:38:21Z
updated: 2026-05-12T16:30:31Z
---

## Current Test

[testing complete]

## Tests

### 1. Full bash lint + test suite on Linux host
expected: On a bash-capable host, `bash cka-sim/scripts/test.sh` + the four lint scripts (lint-packs, lint-traps, lint-coverage, lint-deprecated-strings) all exit 0. test.sh reports 32 unit cases green. lint-traps reports "catalog lint passed (36 entries schema OK)." lint-coverage walks 4 packs with 0 warnings. lint-deprecated-strings finds no forbidden-string hits under cka-sim/packs/**.
result: issue
reported: "lint-packs pass A (GRADE-02) failed on cluster-architecture/08-priorityclass/grade.sh line 17 — contains banned 'kubectl get | grep' idiom. test.sh aborted at step 2 before reaching unit cases. lint-traps (36 entries), lint-coverage (4 packs, 0 warnings), lint-deprecated-strings (940 checks) all passed."
severity: major

### 2. S&N Q01 NetworkPolicy egress (Phase 3 retrofit round-trip)
expected: `cka-sim drill services-networking --question 01 --grade-broken` FAILs with the missing-dns-egress trap. `--ref-solution` applies the fix. `--grade` PASSes. `--reset` cleans up `cka-sim-services-networking-01` namespace. No live kubelet or /etc/kubernetes mutations. Retrofitted setup.sh sources lib/setup.sh and behaves identically to pre-retrofit.
result: pass

### 3. S&N Q02 Service core (ClusterIP selector)
expected: `cka-sim drill services-networking --question 02 --grade-broken` FAILs — q02-web Service has broken selector `app=q02-web-typo`, Endpoints empty, `service-selector-empty-endpoints` trap fires. `--ref-solution` patches Service selector to `app=q02-web`. `--grade` PASSes. `--reset` cleans namespace.
result: pass

### 4. S&N Q03 CoreDNS resolution
expected: `cka-sim drill services-networking --question 03 --grade-broken` FAILs — q03-dnsclient Pod has `dnsPolicy: None` with wrong nameserver 1.1.1.1, nslookup fails, `coredns-forward-to-invalid-upstream` trap fires. `--ref-solution` recreates Pod with kube-system/kube-dns ClusterIP in dnsConfig.nameservers. `--grade` PASSes (nslookup succeeds). `--reset` cleans namespace. kube-system/coredns is not mutated.
result: pass

### 5. S&N Q04 Ingress path/host
expected: `cka-sim drill services-networking --question 04 --grade-broken` FAILs — Ingress absent by design, `ingress-missing-ingressclass` trap fires. `--ref-solution` creates Ingress with `ingressClassName: q04-nginx`, correct host and path, backend Service. `--grade` PASSes via structural checks (no HTTP probe dependency). `--reset` removes cluster-scoped IngressClass/q04-nginx.
result: pass

### 6. S&N Q05 kube-proxy mode
expected: `cka-sim drill services-networking --question 05 --grade-broken` is a read-only live ConfigMap inspection drill. Grader checks the candidate correctly identifies the active kube-proxy mode (iptables/ipvs/nftables). `--ref-solution` shows the inspection commands. `--grade` PASSes when mode is correctly reported. `--reset` is a no-op for live ConfigMap. No mutation of kube-system/kube-proxy.
result: pass

### 7. S&N Q06 NetworkPolicy endPort
expected: `cka-sim drill services-networking --question 06 --grade-broken` FAILs — q06-server Pod listens on 8080-8090, no endPort policy yet. `--ref-solution` creates NetworkPolicy with `port: 8080`, `endPort: 8090`, `protocol: TCP`. `--grade` PASSes — in-range 8085 probe from q06-client succeeds, out-of-range 8095 probe is denied. Baseline DNS-allow NetworkPolicy from `seed_netpol_skeleton` not disturbed. `--reset` cleans namespace.
result: issue
reported: "Broken 1/6 rc=1 with netpol-endport-missing-protocol trap fires correctly. But ref-solution grade only reaches 5/6 rc=1 — one assertion still failing after ref-solution applied. Expected 6/6 rc=0."
severity: major

### 8. Cluster-Arch Q01 RBAC viewer (Phase 3 retrofit round-trip)
expected: `cka-sim drill cluster-architecture --question 01 --grade-broken` FAILs — Role pod-viewer has verbs `[watch]` trap, ServiceAccount `viewer` can't `get`/`list` Pods, `rbac-viewer-role-mismatch` + `default-sa-used` traps fire. `--ref-solution` patches Role verbs to `[get, list, watch]`. `--grade` PASSes. `--reset` cleans namespace. Retrofitted setup.sh sources lib/setup.sh; identical behaviour to pre-retrofit.
result: pass

### 9. Cluster-Arch Q02 etcd backup/restore
expected: `cka-sim drill cluster-architecture --question 02 --grade-broken` FAILs — no snapshot yet or snapshot at wrong data-dir. `--ref-solution` runs `etcdutl snapshot save` to /tmp/q02-etcd-backup/snapshot.db, verifies via `etcdutl snapshot status`, restores ONLY into /tmp/q02-etcd-backup/restored-data (never touches live /var/lib/etcd). `etcd-snapshot-without-env-set` and `etcd-restore-wrong-data-dir` traps fire on common mistakes. `--grade` PASSes. `--reset` wipes /tmp/q02-etcd-*. Live etcd not impacted.
result: issue
reported: "Broken 0/3 rc=1 with both etcd-snapshot-without-env-set and etcd-restore-wrong-data-dir traps firing correctly. But ref-solution grade only reaches 1/3 rc=1 — two assertions still failing after ref-solution applied. Expected 3/3 rc=0."
severity: major

### 10. Cluster-Arch Q03 kubeadm upgrade (sandbox)
expected: `cka-sim drill cluster-architecture --question 03 --grade-broken` FAILs — seeded version file + mocked upgrade-plan file present, no written plan or apply script yet. `--ref-solution` writes plan targeting v1.35 and apply script in plan-before-apply order. `--grade` checks written plan, target version v1.35, apply script content, and plan-before-apply ordering. `kubeadm-upgrade-skip-plan` trap fires on wrong order. NO real `kubeadm upgrade` is invoked on the live cluster. `--reset` wipes sandbox files.
result: pass

### 11. Cluster-Arch Q04 PSS enforce (v1.25+ wording)
expected: `cka-sim drill cluster-architecture --question 04 --grade-broken` FAILs — namespace not PSS-labelled, offending Pod admission captured. `--ref-solution` labels namespace with `pod-security.kubernetes.io/enforce=<level>` and deploys compliant workload. `--grade` checks: enforce label present, admission error contains v1.25+ wording `violates PodSecurity "<level>:<version>"`, no legacy `PodSecurityPolicy` string (lint would fail if leaked), no fictional-pod-label exemption. Compliant Deployment reaches Ready. `--reset` cleans namespace.
result: issue
reported: "Broken 3/5 rc=1 but NO trap line logged. Ref-solution grade stays at 3/5 rc=1 — ref-solution does not improve score and no PSS-specific trap fires on broken state. Expected broken to fire pss-error-string-mismatch or psp-fictional-pod-label-exemption, and pass grade to reach 5/5 rc=0."
severity: major

### 12. Cluster-Arch Q05 audit policy
expected: `cka-sim drill cluster-architecture --question 05 --grade-broken` FAILs — seeded invalid Policy missing a rule `level`. `--ref-solution` writes valid `audit.k8s.io/v1` Policy + `AdmissionConfiguration` YAML to /tmp/q05-audit/ sandbox only (NEVER /etc/kubernetes/). `--grade` validates Policy structure via python3 + PyYAML, records `audit-policy-wrong-stage-verbosity` trap on wrong stage/verbosity. `--grade` PASSes on valid Policy. Requires python3 + PyYAML on CP node. `--reset` wipes sandbox.
result: pass

### 13. Cluster-Arch Q06 CRD basics
expected: `cka-sim drill cluster-architecture --question 06 --grade-broken` FAILs — only a ConfigMap hint seeded; no CRD installed. `--ref-solution` installs `q06widgets.cka-sim.io` CRD with `spec.scope: Namespaced`, waits for Established, creates a sample CR. `crd-missing-scope-field` trap fires if scope omitted. `--grade` PASSes once CRD Established + CR instantiated. `--reset` deletes cluster-scoped CRD (CRs cascade).
result: pass

### 14. Cluster-Arch Q07 CRI-dockerd endpoint
expected: `cka-sim drill cluster-architecture --question 07 --grade-broken` FAILs — sandbox copy of kubeadm-flags.env at /tmp/q07-kubelet-flags/ has obsolete `--container-runtime=remote` (assembled in shell to dodge lint). `--ref-solution` edits ONLY the sandbox copy, setting `--container-runtime-endpoint=unix:///run/cri-dockerd.sock` on kubeadm-flags.env. `--grade` checks correct unix:// endpoint present, no edit to /etc/kubernetes/kubelet.conf (`kubelet-runtime-flag-in-kubeconfig` trap), no `--container-runtime=remote` in result (`removed-container-runtime-flag` trap), `cri-endpoint-unix-prefix-missing` if scheme absent. Live /var/lib/kubelet/kubeadm-flags.env untouched. `--reset` wipes /tmp/q07-kubelet-flags/.
result: pass

### 15. Cluster-Arch Q08 PriorityClass
expected: `cka-sim drill cluster-architecture --question 08 --grade-broken` FAILs — setup creates `q08-critical` (globalDefault) then attempts conflicting `q08-batch` (also globalDefault), fallback ensures both exist. `priorityclass-globaldefault-conflict` trap fires. `--ref-solution` flips exactly one to `globalDefault: false` without deleting either. `--grade` verifies both PriorityClasses still exist and exactly one is globalDefault. `--reset` deletes both cluster-scoped `q08-*` PriorityClasses.
result: issue
reported: "Broken grade PASSES at 2/2 rc=0 — grader accepts the broken state as correct and priorityclass-globaldefault-conflict trap never fires. Ref-solution grade also 2/2 rc=0. Grader is too permissive. The api server likely rejected the 2nd q08-batch globalDefault=true create during setup (Forbidden: only one globalDefault PriorityClass can exist), so the seeded state already satisfies 'exactly one globalDefault'. Setup needs a fallback that forces the conflict to persist, or grader should detect the seeded pre-state and require ref-solution evidence."
severity: major

### 16. Pack-level random drill: services-networking
expected: Running `cka-sim drill services-networking` (no --question flag) twice picks a random question each time from the 6 available. Each run shows broken state, accepts candidate work or ref-solution, grades, and cleans up. No run crashes or leaves stray namespaces/resources. Both runs complete within the ~46 min pack budget if attempting each.
result: pass

### 17. Pack-level random drill: cluster-architecture
expected: Running `cka-sim drill cluster-architecture` (no --question flag) twice picks a random question each time from the 8 available. Each run shows broken state, accepts candidate work or ref-solution, grades, and cleans up. No run mutates live cluster state outside per-question lab namespaces and /tmp/qNN-*/ sandboxes. Both runs complete within the ~68 min pack budget if attempting each.
result: pass

## Summary

total: 17
passed: 12
issues: 5
pending: 0
skipped: 0
blocked: 0

## Gaps

- truth: "cka-sim full bash lint + test suite exits 0 on a Linux host"
  status: failed
  reason: "User reported: lint-packs pass A (GRADE-02) failed on cluster-architecture/08-priorityclass/grade.sh line 17 — contains banned 'kubectl get | grep' idiom. test.sh aborted at step 2 before reaching unit cases. lint-traps (36 entries), lint-coverage (4 packs, 0 warnings), lint-deprecated-strings (940 checks) all passed."
  severity: major
  test: 1
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

- truth: "S&N Q06 netpol-endport ref-solution grades 6/6 after applying the endPort NetworkPolicy"
  status: failed
  reason: "User reported: Broken 1/6 rc=1 with netpol-endport-missing-protocol trap fires correctly. But ref-solution grade only reaches 5/6 rc=1 — one assertion still failing after ref-solution applied. Expected 6/6 rc=0."
  severity: major
  test: 7
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

- truth: "Cluster-Arch Q02 etcd-backup-restore ref-solution grades 3/3 after snapshot save + restore"
  status: failed
  reason: "User reported: Broken 0/3 rc=1 with both etcd-snapshot-without-env-set and etcd-restore-wrong-data-dir traps firing correctly. But ref-solution grade only reaches 1/3 rc=1 — two assertions still failing after ref-solution applied. Expected 3/3 rc=0."
  severity: major
  test: 9
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

- truth: "Cluster-Arch Q04 pss-enforce broken state fires a PSS trap and ref-solution grades 5/5"
  status: failed
  reason: "User reported: Broken 3/5 rc=1 but NO trap line logged. Ref-solution grade stays at 3/5 rc=1 — ref-solution does not improve score and no PSS-specific trap fires on broken state. Expected broken to fire pss-error-string-mismatch or psp-fictional-pod-label-exemption, and pass grade to reach 5/5 rc=0."
  severity: major
  test: 11
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

- truth: "Cluster-Arch Q08 priorityclass broken grade FAILs with priorityclass-globaldefault-conflict trap firing"
  status: failed
  reason: "User reported: Broken grade PASSES at 2/2 rc=0 — grader accepts the broken state as correct and priorityclass-globaldefault-conflict trap never fires. Ref-solution grade also 2/2 rc=0. Grader is too permissive. The api server likely rejected the 2nd q08-batch globalDefault=true create during setup (Forbidden: only one globalDefault PriorityClass can exist), so the seeded state already satisfies 'exactly one globalDefault'. Setup needs a fallback that forces the conflict to persist, or grader should detect the seeded pre-state and require ref-solution evidence."
  severity: major
  test: 15
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""
