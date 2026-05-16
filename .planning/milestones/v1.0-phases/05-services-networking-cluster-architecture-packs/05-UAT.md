---
status: resolved
phase: 05-services-networking-cluster-architecture-packs
source: [05-01-SUMMARY.md, 05-02-SUMMARY.md, 05-03-SUMMARY.md, 05-04-SUMMARY.md, 05-05-SUMMARY.md, 05-06-SUMMARY.md, 05-07-SUMMARY.md, 05-08-SUMMARY.md, 05-09-SUMMARY.md, 05-10-SUMMARY.md, 05-11-SUMMARY.md, 05-12-SUMMARY.md, 05-13-SUMMARY.md, 05-14-SUMMARY.md, 05-15-SUMMARY.md, 05-16-SUMMARY.md]
started: 2026-05-12T15:38:21Z
updated: 2026-05-13T01:55:00Z
resolved_by: [05-17, 05-18, 05-19, 05-20]
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
  root_cause: "grade.sh:17 counts globalDefault=true PriorityClasses via `kubectl get ... | grep -v '^$' | wc -l`. The GRADE-02 pass-A regex (lint-packs.sh:43 `kubectl[[:space:]]+get[[:space:]].*\\|[[:space:]]*grep`) is intentionally literal — it bans any `kubectl get | grep` regardless of flags, matching the project-wide convention of jsonpath + `wc -w` (see storage/03-access-modes-reclaim/grade.sh:39-40, workloads-scheduling/07-native-sidecar/grade.sh:29). Grader is non-idiomatic; lint is correct."
  artifacts:
    - path: "cka-sim/packs/cluster-architecture/08-priorityclass/grade.sh"
      issue: "line 17 uses `{range}...{end}` jsonpath with trailing newlines counted via `grep -v '^$' | wc -l` instead of the canonical `{items[?(...)].metadata.name}` space-separated stream + `wc -w`"
  missing:
    - "Rewrite grade.sh:17 to match the storage/03 pattern: `names=$(kubectl get priorityclass -o jsonpath='{.items[?(@.globalDefault==true)].metadata.name}' 2>/dev/null || echo \"\"); count=$(printf '%s' \"$names\" | wc -w | tr -d ' ')`"
    - "Do NOT widen lint-packs.sh pass A to allow grep -v/grep -c — that defeats GRADE-02 and diverges from the rest of the corpus"
    - "Re-run bash cka-sim/scripts/test.sh end-to-end after the fix; confirm pass A passes and unit cases (32) run green"
  debug_session: ""

- truth: "S&N Q06 netpol-endport ref-solution grades 6/6 after applying the endPort NetworkPolicy"
  status: failed
  reason: "User reported: Broken 1/6 rc=1 with netpol-endport-missing-protocol trap fires correctly. But ref-solution grade only reaches 5/6 rc=1 — one assertion still failing after ref-solution applied. Expected 6/6 rc=0."
  severity: major
  test: 7
  root_cause: "Grade assertion 5 (kubectl exec q06-client → wget q06-server:8085) fails because setup.sh's baseline NetworkPolicy seeded via cka_sim::setup::seed_netpol_skeleton (selector app=q06-client, policyTypes: [Ingress, Egress]) allows only UDP/53 + TCP/53 egress to kube-system. All other client egress — including TCP to q06-server:8085 — is denied. The ref-solution's q06-allow-range is an Ingress-only policy on the server side and does NOT relax client egress, so the 8085 probe times out. Assertion 6 (8095 must fail) passes coincidentally via the baseline block, not the endPort range."
  artifacts:
    - path: "cka-sim/packs/services-networking/06-netpol-endport/setup.sh"
      issue: "After seed_netpol_skeleton(app=q06-client) call, baseline restricts q06-client egress to DNS only. Setup never adds a TCP 8080-8090 egress allowance to q06-server, which the grader's in-range probe requires."
    - path: "cka-sim/lib/setup.sh"
      issue: "seed_netpol_skeleton helper hard-codes policyTypes: [Ingress, Egress] and emits only the DNS egress rule. No parameter for extra app-egress allowance; caller must augment, and q06's setup.sh does not."
  missing:
    - "In setup.sh, after seed_netpol_skeleton, apply an additional NetworkPolicy (or extend baseline) selecting app=q06-client with an egress rule: to podSelector app=q06-server, TCP ports 8080-8090 via endPort. Keeps student's ingress task untouched; unblocks grader's 8085 probe."
    - "Verify after fix: BROKEN still 1/6 with netpol-endport-missing-protocol trap (8095 probe still fails — new client egress rule covers 8080-8090, not 8095). Then PASS reaches 6/6 rc=0."
  debug_session: ""

- truth: "CA Q02 etcd-backup-restore ref-solution grades 3/3 after snapshot save + restore"
  status: failed
  reason: "User reported: Broken 0/3 rc=1 with both etcd-snapshot-without-env-set and etcd-restore-wrong-data-dir traps firing correctly. But ref-solution grade only reaches 1/3 rc=1 — two assertions still failing after ref-solution applied. Expected 3/3 rc=0."
  severity: major
  test: 9
  root_cause: "setup.sh lines 15-16 pre-create $sandbox/restored-data/ (with a .pre-existing sentinel file) BEFORE ref-solution runs; `etcdutl snapshot restore` refuses to write into an existing data-dir and `set -euo pipefail` aborts ref-solution.sh, leaving restored-data/member/wal absent — assertion 3 fails. Secondary: setup.sh line 23 only `warn`s on missing etcdutl instead of dying; on kubeadm v1.35 nodes where etcd-client (etcdctl) is installed but etcdutl is not, both the grader's `etcdutl snapshot status` assertion and ref-solution's `etcdutl snapshot restore` silently fail — yielding the observed 1/3."
  artifacts:
    - path: "cka-sim/packs/cluster-architecture/02-etcd-backup-restore/setup.sh"
      issue: "Lines 15-16 pre-create $sandbox/restored-data/ and $sandbox/restored-data/.pre-existing — this directory MUST be absent when etcdutl snapshot restore runs. Line 23 only warns on missing etcdutl instead of failing; grader and ref both depend on etcdutl being on PATH."
    - path: "cka-sim/packs/cluster-architecture/02-etcd-backup-restore/ref-solution.sh"
      issue: "Line 26 runs `etcdutl snapshot restore --data-dir=$sandbox/restored-data` without removing any pre-existing directory. Under set -euo pipefail + setup's pre-created dir, restore aborts before member/wal is written."
    - path: "cka-sim/packs/cluster-architecture/02-etcd-backup-restore/grade.sh"
      issue: "Line 20 depends on etcdutl being installed; on a kubeadm v1.35 node with only etcd-client, the assertion always fails. Either setup must verify etcdutl presence fatally, or the status check should prefer `etcdctl snapshot status` with fallback."
  missing:
    - "In setup.sh, drop `mkdir -p \"$sandbox/restored-data\"` and `touch \"$sandbox/restored-data/.pre-existing\"` — leave restored-data/ absent so etcdutl snapshot restore can create it cleanly. Keep $sandbox/.cka-sim-sentinel."
    - "In setup.sh, promote the etcdutl check from warn to die (or install the etcd-utl binary) so UAT fails fast with a clear message instead of producing 1/3 grades."
    - "Optional hardening in ref-solution.sh: `rm -rf \"$sandbox/restored-data\"` immediately before the etcdutl snapshot restore call — robust against stale dirs from prior failed runs."
  debug_session: ".planning/debug/ca-q02-etcd-backup-restore.md"

- truth: "CA Q04 pss-enforce broken state fires a PSS trap and ref-solution grades 5/5"
  status: failed
  reason: "User reported: Broken 3/5 rc=1 but NO trap line logged. Ref-solution grade stays at 3/5 rc=1 — ref-solution does not improve score and no PSS-specific trap fires on broken state. Expected broken to fire pss-error-string-mismatch or psp-fictional-pod-label-exemption, and pass grade to reach 5/5 rc=0."
  severity: major
  test: 11
  root_cause: "Two assertions unsatisfiable by ref-solution, stuck at 3/5. (3) admission-log regex requires literal 'violates PodSecurity \"...\":' but setup captures Deployment dry-run output whose wording is 'would violate PodSecurity \"...\"' — different wording, regex never matches; ref-solution then overwrites the log with a compliant dry-run emitting no PSS text at all. (5) q04-compliant Deployment has no kubectl wait in setup OR ref-solution, so readyReplicas is raced. Trap gap: grade.sh inlines grep logic against wrong data sources — greps admission log for legacy 'PodSecurityPolicy' (v1.25+ apiserver never emits that string) and greps $sandbox/*.yaml for an exempt label that neither setup's privileged violator.yaml nor ref-solution's compliant variant ever contains. No candidate-submission YAML path is modeled. Inline grep duplicates lib/traps.sh detector logic rather than calling the registered detectors."
  artifacts:
    - path: "cka-sim/packs/cluster-architecture/04-pss-enforce/grade.sh"
      issue: "Line 15 regex 'violates PodSecurity \"...\":' never matches Deployment dry-run output ('would violate PodSecurity'). Lines 23-26 grep admission log for 'PodSecurityPolicy' — apiserver never emits that. Lines 28-30 grep $sandbox/*.yaml for an exempt label never present. Assertion 5 reads readyReplicas with no prior kubectl wait. Inline grep duplicates detectors in lib/traps.sh."
    - path: "cka-sim/packs/cluster-architecture/04-pss-enforce/setup.sh"
      issue: "Captures admission output from a Deployment (apps/v1 kind: Deployment at $sandbox/violator.yaml:51-72) via 'kubectl apply --dry-run=server' — yields 'Warning: would violate PodSecurity' warning, not the 'violates PodSecurity' rejection. q04-compliant Deployment created with no wait-for-Available; readyReplicas racy at grade time."
    - path: "cka-sim/packs/cluster-architecture/04-pss-enforce/ref-solution.sh"
      issue: "Overwrites $sandbox/violator.yaml with compliant pod template and overwrites violator-admission.log with compliant dry-run emitting no PSS violation text — makes assertion 3 strictly worse. Does not touch q04-compliant Deployment or wait for readiness, so cannot recover assertion 5. Writes admission-config.yaml that isn't applied to the apiserver — satisfies nothing."
    - path: "cka-sim/packs/cluster-architecture/04-pss-enforce/metadata.yaml"
      issue: "Declares traps pss-error-string-mismatch and psp-fictional-pod-label-exemption, but question flow produces no trigger input for either — pss-error-string-mismatch needs candidate text containing legacy 'PodSecurityPolicy' wording; psp-fictional-pod-label-exemption needs a candidate YAML with 'pod-security.kubernetes.io/exempt'. Neither input path exists."
    - path: "cka-sim/packs/cluster-architecture/04-pss-enforce/question.md"
      issue: "Tells candidate to 'fix /tmp/q04-pss-enforce/violator.yaml' but grade.sh + trap detectors don't read that file as a candidate submission — only setup- and ref-solution-generated content is inspected. Candidate has no place to put an answer that is scored."
  missing:
    - "Change setup.sh to capture PSS admission output from a bare Pod (apiVersion: v1, kind: Pod) so 'kubectl apply --dry-run=server' emits 'pods \"...\" is forbidden: violates PodSecurity \"restricted:v1.35\"' matching grade.sh regex — OR broaden grade.sh regex to accept both wordings: `grep -qE '(would violate|violates) PodSecurity \"(privileged|baseline|restricted):v1\\.[0-9]+'`."
    - "Add `kubectl wait --for=condition=Available deployment/q04-compliant -n \"$CKA_SIM_LAB_NS\" --timeout=120s` in setup.sh after the apply; assertion 5 gets a stable readyReplicas."
    - "Define a candidate-submission artifact path (e.g. $sandbox/candidate-violator.yaml); question.md prompts candidate to write it; grade.sh calls `cka_sim::trap::detect_psp_fictional_pod_label_exemption \"$(cat $sandbox/candidate-violator.yaml)\"` so the fictional-label trap fires when warranted."
    - "For pss-error-string-mismatch: either (a) accept a candidate notes/rationale text file and run detect_pss_error_string_mismatch against it, or (b) replace this trap in metadata.yaml with one whose trigger input is actually produced by the setup/ref-solution flow (e.g. enforce-version=latest mistake, missing pod-level securityContext)."
    - "Replace inline grep blocks in grade.sh with calls to cka_sim::trap::detect_pss_error_string_mismatch and cka_sim::trap::detect_psp_fictional_pod_label_exemption from lib/traps.sh — keep trap semantics in one place."
    - "Stop overwriting $sandbox/violator-admission.log in ref-solution.sh (it invalidates assertion 3 evidence), or have grade.sh re-capture admission output against a pristine reference Pod template it owns, independent of sandbox state."
  debug_session: ""

- truth: "CA Q08 priorityclass broken grade FAILs with priorityclass-globaldefault-conflict trap firing"
  status: failed
  reason: "User reported: Broken grade PASSES at 2/2 rc=0 — grader accepts the broken state as correct and priorityclass-globaldefault-conflict trap never fires. Ref-solution grade also 2/2 rc=0. Grader is too permissive. The api server likely rejected the 2nd q08-batch globalDefault=true create during setup (Forbidden: only one globalDefault PriorityClass can exist), so the seeded state already satisfies 'exactly one globalDefault'. Setup needs a fallback that forces the conflict to persist, or grader should detect the seeded pre-state and require ref-solution evidence."
  severity: major
  test: 15
  root_cause: "setup.sh tries to create both q08-critical and q08-batch with globalDefault:true. The K8s PriorityClass admission plugin rejects the second create with Forbidden (only one globalDefault cluster-wide). `|| true` at setup.sh:30 swallows the error; fallback at lines 43-54 creates q08-batch with globalDefault:false. Final state satisfies grade.sh's assertions (both exist + exactly one globalDefault=true), so 2/2 PASSes. The intended 2×globalDefault broken state is unreachable on a real cluster — admission blocks both create and update. ref-solution is effectively a no-op. Also affects test 1 via banned `kubectl get | grep` on line 17."
  artifacts:
    - path: "cka-sim/packs/cluster-architecture/08-priorityclass/setup.sh"
      issue: "Lines 30-41 attempt globalDefault:true on q08-batch; admission rejects. Lines 43-54 fallback creates it with globalDefault:false, landing cluster in the grader's pass state. No post-setup assertion that intended broken state was produced."
    - path: "cka-sim/packs/cluster-architecture/08-priorityclass/grade.sh"
      issue: "Assertions are (a) both PCs exist (b) exactly one globalDefault=true. Both satisfied by post-fallback state. No setup-time witness (annotation/label/saved event) to distinguish broken from repaired."
    - path: "cka-sim/packs/cluster-architecture/08-priorityclass/grade.sh"
      issue: "Line 17 uses banned `kubectl get ... | grep -v '^$' | wc -l` idiom — also causes lint-packs pass A failure (test 1)."
    - path: "cka-sim/packs/cluster-architecture/08-priorityclass/ref-solution.sh"
      issue: "Patches q08-batch to globalDefault:false — already the actual state after setup. Reference fix is a no-op."
    - path: "cka-sim/packs/cluster-architecture/08-priorityclass/question.md"
      issue: "Prompt wording aligns with unreachable 2×globalDefault broken state; needs redirecting to the 0×globalDefault variant."
  missing:
    - "Redesign the broken state to 0×globalDefault (or duplicate `value` conflict). API server blocks 2×globalDefault at both create and update."
    - "Rewrite setup.sh: create both q08-critical and q08-batch with globalDefault:false. Remove the Forbidden-create + fallback trick. Assert post-setup count-of-globalDefault == 0 and die loudly if a pre-existing cluster globalDefault PC is present."
    - "Keep grade.sh assertion 2 (exactly one globalDefault) — it now correctly fires for the 0-globalDefault broken state. Record trap priorityclass-globaldefault-conflict when count != 1."
    - "Replace grade.sh:17 with jq-based construction: `count=$(kubectl get priorityclass -o json | jq '[.items[] | select(.globalDefault==true)] | length')` — fixes the banned-idiom lint."
    - "Update ref-solution.sh to patch one PC to globalDefault:true: `kubectl patch priorityclass q08-critical --type=merge -p '{\"globalDefault\":true}'` — matches the new broken state."
    - "Rewrite question.md prompt to describe the reachable broken state (no globalDefault set, pods fall through to system defaults). Retain 'do not delete' constraint."
    - "Add setup.sh preflight: if any existing PriorityClass with globalDefault:true is owned outside this pack (e.g. system-cluster-critical), fail with a clear diagnostic before seeding."
  debug_session: ""
