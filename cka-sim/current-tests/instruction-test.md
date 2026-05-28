 Prerequisites

  - v1.0.1 GCP lab cluster (1 control-plane + 2 workers, Calico, enforcing CNI)
  - kubectl from control-plane node with cka-sim repo cloned
  - python3 + python3-yaml + jq installed (apt-get install -y jq python3-yaml)
  - Latest main checked out: git pull origin main — should be at 3574ce1

  Step 1 — Sanity check the harness

  cd cka-sim
  bash bin/cka-sim --help              # Should list audit subcommand
  bash bin/cka-sim audit --help        # Should show usage + 3 scopes
  bash scripts/test.sh                 # Should report 88/88 cases pass on Linux
  Expected: Test suite green. If unit tests fail with expected 1 got 0 on baseline_capture_smoke, that's the BLG-07 GHA-runner delta — not a blocker for live
   verification.

  Step 2 — Full live audit (the headline)

  export CKA_SIM_ROOT="$(pwd)"
  bash bin/cka-sim audit --report /tmp/v102-live-audit.md
  Expected: 31/31 PASS, 0 FAIL, 0 errors, 3 skipped (3 BLG-02 unsupported-on-kind skipped — but on a real cluster they SHOULD work, see Step 3). Save
  /tmp/v102-live-audit.md as evidence.

  Step 3 — The 3 kind-skipped questions (real cluster only)

  These 3 are skipped on kind (no etcd CLI, no CSI snapshots, no /etc/kubernetes/manifests/) but should work on the lab cluster. Run drill-mode against each:
  bash bin/cka-sim drill cluster-architecture/02-etcd-backup-restore
  bash bin/cka-sim drill storage/04-csi-volumesnapshot
  bash bin/cka-sim drill workloads-scheduling/06-static-pod
  Expected: Each prompts for solution, runs grade.sh, scores ≥0/N. Verify ref-solution scores max/max:
  for q in cluster-architecture/02-etcd-backup-restore storage/04-csi-volumesnapshot workloads-scheduling/06-static-pod; do
    ns="cka-sim-drill-$(echo $q | tr / -)"
    CKA_SIM_LAB_NS="$ns" CKA_SIM_ROOT="$(pwd)" bash packs/$q/setup.sh
    CKA_SIM_LAB_NS="$ns" CKA_SIM_ROOT="$(pwd)" bash packs/$q/ref-solution.sh
    CKA_SIM_LAB_NS="$ns" CKA_SIM_ROOT="$(pwd)" bash packs/$q/grade.sh
    CKA_SIM_LAB_NS="$ns" CKA_SIM_ROOT="$(pwd)" bash packs/$q/reset.sh
  done

  Step 4 — Verify the 4 v1.0.2 bug fixes on real cluster

  BUG-H07 (grep -F locale safety):
  LC_ALL=C bash packs/troubleshooting/05-static-pod-manifest/setup.sh   # rc=0

  BUG-H08 (audit-policy 4 assertions):
  CKA_SIM_LAB_NS=cka-sim-drill-ca-05 CKA_SIM_ROOT="$(pwd)" \
    bash packs/cluster-architecture/05-audit-policy/setup.sh
  CKA_SIM_LAB_NS=cka-sim-drill-ca-05 CKA_SIM_ROOT="$(pwd)" \
    bash packs/cluster-architecture/05-audit-policy/ref-solution.sh
  CKA_SIM_LAB_NS=cka-sim-drill-ca-05 CKA_SIM_ROOT="$(pwd)" \
    bash packs/cluster-architecture/05-audit-policy/grade.sh
  # Expect: SCORE: 4/4

  BUG-M11 (jq scalar fix on real cluster, not kind):
  bash bin/cka-sim audit cluster-architecture/04-pss-enforce
  # Expect: PASS (3/3)

  BUG-M12 (report golden on Linux):
  bash scripts/test.sh 2>&1 | grep report_golden
  # Expect: ✓ case passed: report_golden

  Step 5 — Live drill UAT batch (mirror v1.0.1 pattern)

  v1.0.1 batched UAT into per-phase drivers. Create cka-sim/scripts/uat-phase18-21.sh that runs setup + ref-solution + grade + reset for each remediated
  question and asserts max/max:
  # Suggested structure (mirrors uat-phase10.sh / uat-phase13.sh shape)
  for q in troubleshooting/05-static-pod-manifest \
           cluster-architecture/05-audit-policy \
           cluster-architecture/04-pss-enforce; do
    # setup → ref-solution → grade → assert max/max → reset 
  done
  Document results in .planning/forensics/FORENSIC-v102.md Live UAT section as closed-by evidence.

  Step 6 — Lock the ledger

  After UAT passes, update .planning/forensics/FORENSIC-v102.md:
  # Add to each BUG-* row in Closure Status table:
  # closed-by: <commit-sha-from-uat-driver-commit>
  Commit as docs(forensics): record live UAT closure for BUG-H07..M12.

  Step 7 — Record close-out in STATE.md

  Append a ### v1.0.2 Close-Out section (mirrors v1.0.1's pattern at STATE.md:38-49) with:
  - Lab cluster + commit SHA used for UAT
  - Per-bug pass evidence
  - Audit re-run summary (31/31 PASS confirmed on real cluster)
  - Outstanding items: BLG-06, BLG-07 (now formally v1.0.3 scope)

  Step 8 — Optional: clean up local scratch