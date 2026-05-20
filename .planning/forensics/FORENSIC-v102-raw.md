# cka-sim audit report

Generated: 2026-05-20T00:32:17Z
Scope: all

---

✓ cluster-architecture/01-rbac-viewer: PASS (0/0 expectations met)
---
ⓘ cluster-architecture/02-etcd-backup-restore: SKIPPED (unsupported-on-kind)
---
✓ cluster-architecture/03-kubeadm-upgrade: PASS (1/1 expectations met)
---
✗ cluster-architecture/04-pss-enforce: FAIL (2 expectation(s) failed of 7)
kind      | name                                              | jsonpath                                                     | claimed    | actual | verdict       
----------+---------------------------------------------------+--------------------------------------------------------------+------------+--------+---------------
namespace | cka-sim-audit-cluster-architecture-04-pss-enforce | status.phase                                                 | Active     | Active | ✓           
namespace | cka-sim-audit-cluster-architecture-04-pss-enforce | metadata.labels.pod-security\.kubernetes\.io/enforce         | restricted | [      | ✗           
          |                                                   |                                                              |            |        |   "restricted"
11        |                                                   |                                                              |            |        | ]             
namespace | cka-sim-audit-cluster-architecture-04-pss-enforce | metadata.labels.pod-security\.kubernetes\.io/enforce-version | v1.35      | [      | ✗           
          |                                                   |                                                              |            |        |   "v1.35"     
12        |                                                   |                                                              |            |        | ]             
Claim source:
  question.md: <no prose match found for cka-sim-audit-cluster-architecture-04-pss-enforce>

---
✓ cluster-architecture/05-audit-policy: PASS (1/1 expectations met)
---
✓ cluster-architecture/06-crd-basics: PASS (1/1 expectations met)
---
✓ cluster-architecture/07-cri-dockerd-endpoint: PASS (1/1 expectations met)
---
✓ cluster-architecture/08-priorityclass: PASS (0/0 expectations met)
---
✓ services-networking/01-networkpolicy-egress: PASS (1/1 expectations met)
---
✓ services-networking/02-service-core: PASS (1/1 expectations met)
---
✓ services-networking/03-coredns-resolution: PASS (2/2 expectations met)
---
✓ services-networking/04-ingress-path-host: PASS (0/0 expectations met)
---
✓ services-networking/05-kube-proxy-mode: PASS (1/1 expectations met)
---
✓ services-networking/06-netpol-endport: PASS (2/2 expectations met)
---
✓ storage/01-pvc-binding: PASS (5/5 expectations met)
---
✓ storage/02-storageclass-dynamic: PASS (2/2 expectations met)
---
✓ storage/03-access-modes-reclaim: PASS (4/4 expectations met)
---
ⓘ storage/04-csi-volumesnapshot: SKIPPED (unsupported-on-kind)
---
✓ storage/05-wait-for-first-consumer: PASS (5/5 expectations met)
---
✓ storage/06-pvc-mount-pod: PASS (2/2 expectations met)
---
✓ troubleshooting/01-deploy-svc-mismatch: PASS (1/1 expectations met)
---
✓ troubleshooting/02-netpol-dns-egress: PASS (2/2 expectations met)
---
✓ troubleshooting/03-coredns-resolution: PASS (2/2 expectations met)
---
✓ troubleshooting/04-debug-node: PASS (1/1 expectations met)
---
✗ troubleshooting/05-static-pod-manifest: FAIL (0 expectation(s) failed of 1)
kind | name                                   | jsonpath | claimed | actual                                                                    | verdict
-----+----------------------------------------+----------+---------+---------------------------------------------------------------------------+--------
     | troubleshooting/05-static-pod-manifest |          |         | setup.sh failed (ns=cka-sim-audit-troubleshooting-05-static-pod-manifest) | !      

---
✓ troubleshooting/06-broken-kubelet: PASS (1/1 expectations met)
---
✓ workloads-scheduling/01-deployment-requests: PASS (2/2 expectations met)
---
✓ workloads-scheduling/02-rolling-update-rollback: PASS (2/2 expectations met)
---
✓ workloads-scheduling/03-configmap-secret-env-volume: PASS (0/0 expectations met)
---
✓ workloads-scheduling/04-hpa-metrics-server: PASS (1/1 expectations met)
---
✓ workloads-scheduling/05-daemonset: PASS (1/1 expectations met)
---
ⓘ workloads-scheduling/06-static-pod: SKIPPED (unsupported-on-kind)
---
✓ workloads-scheduling/07-native-sidecar: PASS (3/3 expectations met)
---
✓ workloads-scheduling/08-nodeselector-affinity-taints: PASS (1/1 expectations met)
---

─── audit summary ───
29/31 PASS, 1 FAIL, 1 errors, 3 skipped

