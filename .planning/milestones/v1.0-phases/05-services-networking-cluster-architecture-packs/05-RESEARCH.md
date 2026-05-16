---
phase: 05
phase_name: services-networking-cluster-architecture-packs
research_date: 2026-05-12
research_mode: inline-by-orchestrator
reason: gsd-phase-researcher subagent failed twice with API socket errors; CONTEXT.md is comprehensive and Phase 4 pattern is proven
---

# Phase 5 Research: Services-Networking + Cluster-Architecture Packs

## Scope note

This RESEARCH.md was authored inline by the orchestrator after two `gsd-phase-researcher` spawn attempts returned socket/HTTP errors mid-run. It is deliberately focused and not exhaustive — CONTEXT.md already locks the design, and Phase 5 mirrors the Phase 4 authoring pattern proven in `.planning/phases/04-storage-workloads-scheduling-packs/`. The research below closes the specific knowledge gaps the planner and executor need, with authoritative v1.35 citations for the four highest-leverage traps (PSS wording, kubelet kubeadm-flags, etcd backup/restore, audit policy).

## 1. Per-question technical feasibility on the 1+2 kubeadm v1.35 cluster

The cluster topology is 1 control-plane + 2 worker nodes, Ubuntu 22.04, kubeadm-managed, containerd runtime. Each question's setup.sh must be idempotent and may only mutate resources inside the per-question lab namespace `cka-sim-<pack>-NN` OR under sandbox paths `/tmp/qNN-*/`. Live `/etc/kubernetes/`, `/var/lib/kubelet/`, `/etc/default/kubelet`, `/var/lib/etcd/`, and the apiserver static-pod manifest are OFF LIMITS for mutation.

Feasibility matrix for the 12 new questions:

| Q | Primitives | Sandbox required? | Notes |
|---|---|---|---|
| services/02-service-core | Service, Endpoints, EndpointSlice, Deployment | No | Pure lab-ns. `kubectl get endpoints` oracle. |
| services/03-coredns-resolution | ConfigMap kube-system/coredns read-only, Deployment+dnsutils probe | **Read-only on live** | Grader reads CoreDNS ConfigMap; never edits kube-system. Candidate's fix lives in the lab ns via a dedicated CoreDNS replica OR via a Pod dnsConfig override. Prefer the dnsConfig override pattern. |
| services/04-ingress-path-host | Ingress, IngressClass | Depends on cluster | If no IngressClass exists, setup.sh seeds an IngressClass named `cka-sim-nginx` pointing at a placeholder controller; grader uses structural validation (kubectl get ingress -o jsonpath) not HTTP probe, because the 1+2 cluster may not have a real controller. |
| services/05-kube-proxy-mode | ConfigMap kube-system/kube-proxy read-only | **Read-only** | Grader reads `config.conf` data, asserts `mode:` field value. See §3. |
| services/06-netpol-endport | NetworkPolicy, Pod multi-port listener, kubectl exec probe | No | Lab ns only. CNI dependency — see §4. |
| cluster-arch/02-etcd-backup-restore | etcdctl snapshot save (to /tmp sandbox) | **Sandbox** | Candidate runs etcdctl snapshot save against live etcd (read-only on etcd, writes to /tmp/q02-etcd-backup/snapshot.db); restore step creates a new data-dir in sandbox. Never touches /var/lib/etcd. |
| cluster-arch/03-kubeadm-upgrade | Simulated kubeadm-flags.env + mocked `kubeadm upgrade plan` output | **Sandbox** | Pure file-level drill in /tmp/q03-kubeadm-upgrade/. Real `kubeadm upgrade` would break the user's cluster. |
| cluster-arch/04-pss-enforce | Namespace labels, Pod admission | Lab ns | Enforce=restricted:v1.35 label on lab ns; grader seeds a privileged pod attempt and asserts rejection with correct PSA wording. See §2. |
| cluster-arch/05-audit-policy | Policy YAML authoring under /tmp/q05-audit-policy/ | **Sandbox** | Candidate writes Policy YAML to sandbox path; grader uses `kubectl create --dry-run=client -f <policy> --validate=strict` via the apiserver-side admission path is NOT safe here (apiserver flags), so grader uses YAML structural validation (jsonpath + schema assertions). See §6. |
| cluster-arch/06-crd-basics | CustomResourceDefinition, CR instance | Lab ns (CR) + cluster-scoped (CRD) | CRD is cluster-scoped by necessity; must be prefixed `q06-*` per TRIP-03 and cleaned in reset.sh. |
| cluster-arch/07-cri-dockerd-endpoint | Sandbox copy of kubeadm-flags.env | **Sandbox** | Pure file-level drill in /tmp/q07-kubelet-flags/. Grader greps for correct `--container-runtime-endpoint=unix:///run/cri-dockerd.sock` placement and absence of `--container-runtime=remote`. See §9. |
| cluster-arch/08-priorityclass | PriorityClass (cluster-scoped, prefixed `q08-*`) | Cluster-scoped | Test globalDefault conflict — setup seeds two competing PCs, candidate fixes by unsetting one. |

## 2. CONCERNS.md-seeded trap activation — authoritative v1.35 wording

### `pss-error-string-mismatch` (ref: CONCERNS.md §Content Accuracy)

**v1.35 PodSecurity admission error format** (per https://kubernetes.io/docs/concepts/security/pod-security-admission/):

```
violates PodSecurity "<LEVEL>:<VERSION>": <DETAILS>
```

- `<LEVEL>` is one of `privileged`, `baseline`, `restricted`
- `<VERSION>` is a minor version like `v1.35` or the literal string `latest`
- `<DETAILS>` enumerates specific violations (e.g. `privileged (container "bad" must not set securityContext.privileged=true)`)

Audit / warn variant (logged via annotation `pod-security.kubernetes.io/audit-violations`):

```
would violate PodSecurity "<LEVEL>:<VERSION>": <DETAILS>
```

**Grader assertion** for `04-pss-enforce` — use regex:

```
violates PodSecurity "(privileged|baseline|restricted):(v1\.[0-9]+|latest)":
```

DO NOT accept the substring `PodSecurityPolicy` anywhere in error output — that is the pre-1.25 wording the trap detects.

Namespace label form to activate enforcement:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: cka-sim-cluster-architecture-04
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: v1.35
```

### `psp-fictional-pod-label-exemption`

There is NO pod-level label that exempts a pod from PSS. Candidates sometimes try labels like `pod-security.kubernetes.io/exempt: true` — this is fictional. Real exemptions are cluster-scoped via `--admission-control-config-file` pointing at an `AdmissionConfiguration` resource that lists exempt namespaces / usernames / runtimeClasses.

**Grader trap fires** if candidate's ref-solution contains:
- Any `pod-security.kubernetes.io/exempt` label (on any resource)
- Any pod-level annotation matching `pod-security.kubernetes.io/*exempt*`

### `kubelet-runtime-flag-in-kubeconfig` + `removed-container-runtime-flag`

Per https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/:

- **Runtime flags** (including `--container-runtime-endpoint`) live in `/var/lib/kubelet/kubeadm-flags.env` as:

  ```
  KUBELET_KUBEADM_ARGS="--container-runtime-endpoint=unix:///run/cri-dockerd.sock --pod-infra-container-image=registry.k8s.io/pause:3.10"
  ```

- **kubelet kubeconfig** lives in `/etc/kubernetes/kubelet.conf` — this is ONLY the apiserver auth config. Runtime flags here have no effect.

- **Removed in 1.27**: `--container-runtime=remote` flag. In 1.35 only `--container-runtime-endpoint` remains. Any content referring to `--container-runtime=remote` is exam-wrong and silently no-ops on a real 1.35 kubelet.

**Grader assertions** for `07-cri-dockerd-endpoint`:

```bash
# Trap: edits wrong file
grep -q "container-runtime-endpoint" /tmp/q07-kubelet-flags/kubelet.conf 2>/dev/null && emit_trap kubelet-runtime-flag-in-kubeconfig

# Trap: uses removed flag
grep -q "container-runtime=remote" /tmp/q07-kubelet-flags/kubeadm-flags.env && emit_trap removed-container-runtime-flag

# Correct state
grep -qE 'KUBELET_KUBEADM_ARGS=.*--container-runtime-endpoint=unix:///run/cri-dockerd\.sock' /tmp/q07-kubelet-flags/kubeadm-flags.env
```

## 3. Kube-proxy mode (CG-15) — non-invasive inspection

Per https://kubernetes.io/docs/reference/networking/virtual-ips/:

ConfigMap location: `kube-system/kube-proxy`, key `config.conf` (a nested YAML document).

Exact jsonpath to extract the mode field:

```bash
kubectl -n kube-system get configmap kube-proxy -o jsonpath='{.data.config\.conf}' | awk '/^mode:/{print $2}' | tr -d '"'
```

Valid values on Linux: `iptables` (default on most kubeadm installs), `ipvs`, `nftables`. Empty string means the kube-proxy DaemonSet started with defaults.

**Setup for Q05**: setup.sh DOES NOT mutate the live kube-proxy ConfigMap. Instead, the question frames the candidate as a "cluster auditor" tasked with reporting the mode. The grader asserts the candidate's reported mode matches what `jsonpath` returns from the live ConfigMap.

Trap `kube-proxy-mode-mismatch-ipvs-iptables` fires when the candidate submits a mode string that doesn't match the cluster's actual `mode:` key. Oracle = behavioural (read live ConfigMap), never a shell-history check.

## 4. NetworkPolicy endPort (CG-16)

Per https://kubernetes.io/docs/concepts/services-networking/network-policies/:

Syntax:

```yaml
spec:
  ingress:
  - from:
    - podSelector: { matchLabels: { role: client } }
    ports:
    - protocol: TCP
      port: 8080
      endPort: 8090
```

Constraints:
- `endPort` must be numeric `port` (not a named port)
- `endPort >= port`
- CNI support required. **Calico 3.25+ supports endPort**; Cilium 1.13+ supports it. The user's 1+2 cluster uses `.planning/codebase/INTEGRATIONS.md` to determine the CNI; if Calico, endPort works natively. If the CNI doesn't support endPort, the policy is installed but not enforced — a silent failure mode.

**Setup for Q06 (netpol-endport)**: lab-ns Pod listening on ports 8080-8090 via a multi-port containerPorts spec. Candidate writes the NetworkPolicy. Grader probes via `kubectl exec`:

```bash
# Expected allow
kubectl exec client-pod -- wget -qO- --timeout=3 server-pod:8085 && allowed=1

# Expected deny (outside range)
kubectl exec client-pod -- wget -qO- --timeout=3 server-pod:8095 || denied=1
```

Trap `netpol-endport-missing-protocol` fires when the candidate's NetworkPolicy has `endPort` without `protocol` (v1.35 requires protocol; otherwise default is TCP, but explicit is expected).

## 5. CRD basics (CG-12) — minimum viable

Per https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/:

Minimal CRD:

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: q06widgets.cka-sim.io
spec:
  group: cka-sim.io
  scope: Namespaced   # <-- required; trap fires if missing or wrong
  names:
    plural: q06widgets
    singular: q06widget
    kind: Q06Widget
    shortNames: [q06w]
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              size: { type: integer }
```

No external controller. Grader asserts the CRD is installed, creates a CR in the lab ns, and queries via `kubectl get q06widgets.cka-sim.io -n <lab-ns> -o jsonpath='{.items[0].spec.size}'`.

reset.sh MUST `kubectl delete crd q06widgets.cka-sim.io --ignore-not-found` — this cascades all CR instances.

Trap `crd-missing-scope-field` fires when the CRD has no `spec.scope` or uses `Cluster` when the question intended `Namespaced`.

## 6. Audit policy (CG-11) sandbox authoring

Per https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/:

Canonical minimal Policy:

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
- RequestReceived
rules:
- level: Metadata
  resources:
  - group: ""
    resources: ["secrets"]
- level: Request
  resources:
  - group: ""
    resources: ["configmaps"]
- level: None
  resources:
  - group: ""
    resources: ["events"]
```

Activation flags (apiserver — the candidate does NOT apply these to the live apiserver):

```
--audit-policy-file=/etc/kubernetes/audit-policy.yaml
--audit-log-path=/var/log/kubernetes/audit/audit.log
```

**Setup for Q05 (audit-policy)**: candidate writes their Policy YAML to `/tmp/q05-audit-policy/policy.yaml`. Grader performs structural validation:

```bash
# Must be audit.k8s.io/v1 Policy
grep -q "^apiVersion: audit.k8s.io/v1" /tmp/q05-audit-policy/policy.yaml
grep -q "^kind: Policy" /tmp/q05-audit-policy/policy.yaml

# Must have at least one rule with valid level
python3 -c "import yaml; p=yaml.safe_load(open('/tmp/q05-audit-policy/policy.yaml')); assert p['rules'], 'empty rules'; assert all(r.get('level') in ['None','Metadata','Request','RequestResponse'] for r in p['rules'])"
```

Trap `audit-policy-wrong-stage-verbosity` fires when `level` is missing, invalid, or when `omitStages` uses an unknown stage name.

Note: the candidate's Policy YAML is NOT applied to the live apiserver. The drill ends at structural validity — matching real-exam grading patterns.

## 7. etcd backup/restore drill mechanics

Per https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/ (v1.35):

**snapshot save** (reads from live etcd, writes to candidate-chosen file):

```bash
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /tmp/q02-etcd-backup/snapshot.db
```

**snapshot restore** (uses `etcdutl` in v1.35, not `etcdctl`):

```bash
etcdutl snapshot restore /tmp/q02-etcd-backup/snapshot.db \
  --data-dir=/tmp/q02-etcd-backup/restored-data
```

The live etcd data-dir is `/var/lib/etcd/`. The drill's restore step must use a sandbox path. BOOT-05/06 ensure `ETCDCTL_API=3` is already exported on the candidate's shell.

**Safety:** `snapshot save` is read-only on etcd. The drill is safe. `snapshot restore` against `/var/lib/etcd/` would be catastrophic — grader must assert the candidate's restore command targeted the sandbox data-dir.

Grader assertions for Q02:

```bash
# Save happened and produced a non-empty file with snapshot magic
test -s /tmp/q02-etcd-backup/snapshot.db
head -c 16 /tmp/q02-etcd-backup/snapshot.db | grep -q "etcd"    # etcd snapshot magic bytes

# Integrity check
etcdutl snapshot status /tmp/q02-etcd-backup/snapshot.db --write-out=table

# Restore produced a wal/ dir under the sandbox
test -d /tmp/q02-etcd-backup/restored-data/member/wal
```

Trap `etcd-snapshot-without-env-set` fires when the candidate's shell history / ref-solution omits `ETCDCTL_API=3` (pre-v3 etcdctl defaults to v2 API on some distros).

Trap `etcd-restore-wrong-data-dir` fires when `--data-dir` flag is missing OR points at the live `/var/lib/etcd/`.

## 8. kubeadm-upgrade sandbox mechanics

`kubeadm upgrade plan` and `kubeadm upgrade apply` on a live cluster restart control-plane components. Not safe for a drill.

**Setup for Q03 (kubeadm-upgrade)**: setup.sh seeds a sandbox representation of the current cluster state:

```
/tmp/q03-kubeadm-upgrade/
├── current-version.txt         # "v1.34.2"
├── planned-upgrade.txt         # candidate writes this
├── kubeadm-upgrade-plan.txt    # mocked upgrade plan output provided by setup.sh
└── apply-script.sh             # candidate writes this
```

Grader assertions:

```bash
# Candidate produced a plan document
test -s /tmp/q03-kubeadm-upgrade/planned-upgrade.txt

# Plan specifies target version
grep -qE "target[[:space:]]*version:[[:space:]]*v1\.35" /tmp/q03-kubeadm-upgrade/planned-upgrade.txt

# Apply script uses correct kubeadm command
grep -q "kubeadm upgrade apply v1.35" /tmp/q03-kubeadm-upgrade/apply-script.sh
grep -qv "kubeadm upgrade apply --force" /tmp/q03-kubeadm-upgrade/apply-script.sh  # or whatever discourage

# Plan step not skipped
grep -q "kubeadm upgrade plan" /tmp/q03-kubeadm-upgrade/apply-script.sh
```

Trap `kubeadm-upgrade-skip-plan` fires when the candidate's apply script skips `kubeadm upgrade plan` before `apply`.

## 9. CRI-dockerd endpoint (CG-13)

Covered in §2. Sandbox layout:

```
/tmp/q07-kubelet-flags/
├── kubeadm-flags.env      # copy of live /var/lib/kubelet/kubeadm-flags.env
└── kubelet.conf           # copy of live /etc/kubernetes/kubelet.conf (kubeconfig)
```

setup.sh seeds both files with the WRONG initial state (endpoint in kubelet.conf, and/or `--container-runtime=remote`). Candidate edits `kubeadm-flags.env` to add `--container-runtime-endpoint=unix:///run/cri-dockerd.sock` and removes any reference to `--container-runtime=remote`.

Grader assertions (listed in §2).

Trap `cri-endpoint-unix-prefix-missing` fires when the endpoint value doesn't start with `unix://` (e.g., candidate wrote `--container-runtime-endpoint=/run/cri-dockerd.sock`).

## 10. PriorityClass globalDefault semantics

Per https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/:

`globalDefault: true` applies to Pods with no explicit `priorityClassName`. Only ONE PriorityClass can have `globalDefault: true` at a time. Creating a second one causes a validation error at admission.

Setup for Q08: seed two PriorityClasses, both with `globalDefault: true`. The second creation fails at admission with a specific error. Candidate's task: identify the conflict, pick one as the global default, remove `globalDefault` from the other.

Trap `priorityclass-globaldefault-conflict` fires when both PriorityClasses remain `globalDefault: true`, OR when the candidate deleted one instead of unsetting `globalDefault`.

Grader:

```bash
# Count global-default PCs (must be exactly 1)
count=$(kubectl get priorityclass -o jsonpath='{range .items[?(@.globalDefault==true)]}{.metadata.name}{"\n"}{end}' | wc -l)
test "$count" = "1"

# Both PCs still exist (didn't cheat by deleting)
kubectl get priorityclass q08-critical >/dev/null
kubectl get priorityclass q08-batch >/dev/null
```

## 11. Ingress + IngressClass on the 1+2 cluster

The 1+2 kubeadm cluster may or may not have an installed Ingress controller. Phase 5 must not assume one exists.

**Decision:** Q04 (ingress-path-host) uses structural grading, not HTTP probe. setup.sh seeds an IngressClass named `q04-nginx` with `spec.controller: k8s.io/ingress-placeholder`. Candidate writes an Ingress resource with two rules (host + path routing).

Grader asserts:

```bash
# Ingress exists with correct ingressClassName
kubectl -n "$ns" get ingress q04-web -o jsonpath='{.spec.ingressClassName}' | grep -q q04-nginx

# Host rule present
kubectl -n "$ns" get ingress q04-web -o jsonpath='{.spec.rules[0].host}' | grep -q "api.example.local"

# Two rules (host + path)
rule_count=$(kubectl -n "$ns" get ingress q04-web -o jsonpath='{.spec.rules}' | jq 'length')
test "$rule_count" -ge 1
```

Trap `ingress-missing-ingressclass` fires when the candidate's Ingress has no `spec.ingressClassName` AND no matching `kubernetes.io/ingress.class` annotation. v1.35 strongly prefers `spec.ingressClassName`.

## 12. CoreDNS resolution (Q03 in S&N pack)

Per https://kubernetes.io/docs/tasks/administer-cluster/coredns/:

Corefile structure (ConfigMap kube-system/coredns, key `Corefile`):

```
.:53 {
    errors
    health
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
       pods insecure
       fallthrough in-addr.arpa ip6.arpa
       ttl 30
    }
    prometheus :9153
    forward . /etc/resolv.conf
    cache 30
    loop
    reload
    loadbalance
}
```

**Decision:** Phase 5 Q03 does NOT edit live kube-system/coredns. Instead, the drill uses a Pod-level dnsConfig override:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: q03-dnsclient
  namespace: <lab-ns>
spec:
  dnsPolicy: "None"
  dnsConfig:
    nameservers: ["1.1.1.1"]          # candidate fixes to cluster DNS
    searches: []
    options: []
  containers:
  - name: test
    image: busybox:1.37
    command: ["sleep", "3600"]
```

Candidate corrects dnsConfig to use the cluster's kube-dns service IP. Grader probes:

```bash
kubectl exec -n "$ns" q03-dnsclient -- nslookup kubernetes.default.svc.cluster.local
```

Trap `coredns-forward-to-invalid-upstream` fires when the candidate's dnsConfig references an unreachable upstream OR uses a non-cluster-DNS IP.

## 13. Deprecated-strings CI lint — design

**Scope:** `cka-sim/packs/**` only (not exercises/, not mock-exams/, not .planning/).

**Forbidden strings** (per ROADMAP Phase 5 success criterion 4):
1. `PodSecurityPolicy`
2. `--container-runtime=remote`
3. `policy/v1beta1`
4. `gitRepo:`
5. `dockershim`

**Carveouts** (comment references are allowed):
- YAML comments: lines where the first non-whitespace character is `#` AND the `#` appears before the forbidden string on the same line.
- Markdown comments: content inside `<!-- -->` blocks.
- Markdown prose outside fenced code blocks: e.g., `## CRI-dockerd replacement (the old --container-runtime=remote flag is removed)` is allowed in question.md.

**Implementation** (`scripts/lint-deprecated-strings.sh`):

```bash
#!/bin/bash
# Exit non-zero if any cka-sim/packs/ file contains a forbidden string outside carveouts
set -euo pipefail

patterns=("PodSecurityPolicy" "\\-\\-container-runtime=remote" "policy/v1beta1" "gitRepo:" "dockershim")
files=$(find cka-sim/packs -type f \( -name '*.yaml' -o -name '*.sh' -o -name '*.md' \))

failures=0
for p in "${patterns[@]}"; do
  while IFS= read -r hit; do
    [[ -z "$hit" ]] && continue
    file="${hit%%:*}"
    line_num=$(echo "$hit" | cut -d: -f2)
    line_content=$(echo "$hit" | cut -d: -f3-)
    # Carveout 1: YAML/sh line comment
    if [[ "$line_content" =~ ^[[:space:]]*# ]]; then continue; fi
    # Carveout 2: Markdown prose — ONLY allowed in question.md and README.md, not in YAML blocks
    if [[ "$file" == *.md ]]; then
      # Check if line is inside a fenced code block labeled yaml/bash — use awk to track state
      in_code=$(awk -v target="$line_num" '
        /^```(yaml|bash|sh|shell)/ { code=1; next }
        /^```/ { code=0; next }
        NR==target { print code; exit }
      ' "$file")
      if [[ "$in_code" != "1" ]]; then continue; fi  # prose is OK
    fi
    echo "LINT FAIL: $file:$line_num: $line_content"
    failures=$((failures+1))
  done < <(grep -rn "$p" $files 2>/dev/null || true)
done

exit $failures
```

**Zero-false-positive check against Phase 4 output:**

```bash
# Sanity check — no forbidden string outside carveouts in cka-sim/packs/storage/ or cka-sim/packs/workloads-scheduling/
./scripts/lint-deprecated-strings.sh || echo "Unexpected regressions in Phase 4 content"
```

Expected result on Phase 4 output = 0 failures.

**Wire-up in `.github/workflows/validate.yml`**: add step to existing `validate` job:

```yaml
- name: Lint deprecated strings
  run: bash scripts/lint-deprecated-strings.sh
```

## 14. Phase 4 runtime-bug landmine inventory (pre-empt ex ante)

Phase 4 found 5 bugs only at live drill. Phase 5 must pre-empt the equivalents:

| Phase 4 bug | Phase 5 equivalents | Pre-empt strategy |
|---|---|---|
| BUG-1 setup.sh not executable (Windows git ate exec bit) | All 12 new setup.sh/grade.sh/reset.sh/ref-solution.sh | Add `test -x <path>` to `scripts/lint-packs.sh` for every triplet file. New commit adds `git update-index --chmod=+x` for each. Verify in planning plan P01. |
| BUG-3 hardcoded K8s node name `node-02` | Any question that touches nodes: Q05 kube-proxy (reads all-nodes), Q08 priorityclass (scheduler picks a node), audit-policy (no node touch), etcd (touches CP only) | Promote the worker-discovery idiom to `cka_sim::setup::read_node_worker`. Every setup.sh that needs a worker name uses this helper. Lint rule: grep for literal `node-01`/`node-02` in setup.sh / ref-solution.sh fails. |
| BUG-4 hostpath-csi install URL | No CSI install in Phase 5 | N/A — not applicable. |
| BUG-5 pod pinning to CSI node | Q04 ingress (if probe approach were used); Q06 netpol-endport (client/server pod topology matters) | Use `nodeSelector` only when explicitly required; prefer Service-based indirection. Document in planning. |
| BUG-6 CSI sidecar ClusterRoles missing | Q06 CRD question may need RBAC scaffolding | Q06 CRD question: the CRD itself grants no permissions to CRs; lab-ns default SA can read its own CRs via RBAC on the ClusterRole `system:authenticated` for the CR group. Verify via `kubectl auth can-i` in setup.sh. |

Additional Phase 5-specific landmines to flag:
- **Q02 etcd backup**: `/etc/kubernetes/pki/etcd/ca.crt` path is kubeadm-specific. If the user's cluster was bootstrapped differently (not applicable — confirmed kubeadm), paths differ. Document assumption.
- **Q02 etcd backup**: `etcdutl` command (for restore) was split from `etcdctl` in etcd 3.5+. On older etcd binaries the restore sub-command lives under `etcdctl`. Detect binary existence in setup.sh.
- **Q05 kube-proxy mode**: on some kubeadm distros, the kube-proxy ConfigMap key is `config.conf`; on others it may be sharded. Test jsonpath extraction in setup.sh before asserting in grade.sh.
- **Q04 PSS enforce**: namespace label takes effect at next pod admission; existing pods in the ns are NOT re-evaluated. setup.sh must create the namespace first, THEN apply the enforce label.
- **Q03 coredns dnsConfig**: `dnsPolicy: None` requires `dnsConfig.nameservers` to be non-empty. An empty list fails admission.

## 15. Helper library additions — canonical shapes

### `cka_sim::setup::seed_netpol_skeleton <ns> <name> <selector-label>`

```bash
cka_sim::setup::seed_netpol_skeleton() {
  local ns="$1" name="$2" selector="$3"
  kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ${name}
  namespace: ${ns}
spec:
  podSelector:
    matchLabels:
      ${selector%%=*}: ${selector##*=}
  policyTypes:
    - Ingress
    - Egress
  egress:
    # Allow DNS resolution always (prevents missing-dns-egress trap)
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
EOF
}
```

### `cka_sim::setup::read_node_worker`

```bash
cka_sim::setup::read_node_worker() {
  local node
  node=$(kubectl get nodes \
    -l '!node-role.kubernetes.io/control-plane' \
    --no-headers -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  [[ -n "$node" ]] || die "read_node_worker: no non-control-plane worker node found"
  echo "$node"
}
```

Both helpers land in `cka-sim/lib/setup.sh` in planning plan P01.

## 16. Validation Architecture (Nyquist Dimension 8)

For each Phase 5 VERIFICATION must-have, the validation approach is:

| MH | Must-have | Validation approach |
|---|---|---|
| MH-1 | S&N pack has ≥1 Q per Tracker checkbox | `scripts/lint-coverage.sh` walks `cka-sim/packs/services-networking/coverage.yaml` — deterministic, runs in CI. |
| MH-2 | Cluster-Arch pack has ≥1 Q per Tracker checkbox | Same — `scripts/lint-coverage.sh` walks `cka-sim/packs/cluster-architecture/coverage.yaml`. |
| MH-3 | New `metadata.yaml` passes schema lint | `scripts/lint-packs.sh` extends to the two new packs. Fields validated: id, domain, estimatedMinutes ∈ [4,12], verified_against "1.35", traps ≥3 IDs, references ≥1 item. |
| MH-4 | Every trap ID exists in catalog | `scripts/lint-packs.sh` cross-references metadata.yaml traps[] against catalog.yaml ids[]. |
| MH-5 | `cka-sim drill <pack>` round-trips each Q live | Manual: 14 drill invocations (2 retrofits + 12 new) on the 1+2 cluster. Checklist in VERIFICATION.md with pass/fail per Q. |
| MH-6 | 10 new catalog entries pass lint-traps.sh | `scripts/lint-traps.sh` already validates the 8-field schema. Runs in CI. |
| MH-7 | CI deprecated-strings lint blocks forbidden content | New `scripts/lint-deprecated-strings.sh` (see §13) + GHA step. Runs in CI. |
| MH-8 | Phase 3 retrofits still drill green | Included in MH-5 (the 14 drill count includes the 2 retrofits). |

Unit coverage via PATH-shadowed kubectl stub (`scripts/test.sh`): at minimum, one round-trip fixture per new question demonstrating that the trap fires on a failure state and clears on a success state. Fixtures live under `cka-sim/tests/fixtures/phase-05/`.

CI enforcement order (from `.github/workflows/validate.yml`):
1. yamllint (existing)
2. shellcheck (existing)
3. `scripts/lint-traps.sh` (existing)
4. `scripts/lint-packs.sh` (existing, extended to new packs)
5. `scripts/lint-coverage.sh` (existing, extended to new packs)
6. `scripts/lint-deprecated-strings.sh` (new — Phase 5 adds)
7. `scripts/test.sh` (existing, new fixtures added)

## Research complete

Authoritative citations above cover all four CONCERNS-seeded traps with exact v1.35 wording, and every Q in Phase 5 has a sandbox strategy that avoids live /etc/kubernetes/, /var/lib/kubelet/, /var/lib/etcd/, or static-pod mutations. The helper library additions and CI lint design are spec-complete. Planning can proceed.

## RESEARCH COMPLETE
