# Phase 5 Deferred Items

Items discovered during plan execution that are out of scope for the current plan and tracked for a future plan/phase.

## 05-01 Discoveries

### D1: `workloads-scheduling/06-static-pod` uses literal `node-01` hostname

**Found during:** 05-01 Task 2 (lint-packs.sh pass F — BUG-3 pre-empt).

**Files affected:** `cka-sim/packs/workloads-scheduling/06-static-pod/{setup,grade,ref-solution}.sh`.

**Nature:** The Phase 4 static-pod drill is bound to the kubeadm control-plane host `node-01` — it SSHes to that specific hostname to drop a manifest into `/etc/kubernetes/manifests/` and then grades the mirror pod `q06-static-nginx-node-01`. Dynamic worker discovery via `cka_sim::setup::read_node_worker` is the wrong tool here: the static-pod mechanism is control-plane-bound by design on kubeadm, and the mirror-pod name encodes the node name suffix.

**Why deferred:** Out of scope per 05-01 (scaffolding only; no retrofit of Phase 4 content). A proper retrofit needs a new helper like `cka_sim::setup::read_node_control_plane` plus a grade-side lookup for the mirror-pod suffix — non-trivial and behavior-changing on a passing drill.

**Tracked resolution:** Phase 8 doc/retrofit polish OR a dedicated troubleshooting-pack plan. Until then, the three files carry a file-level `# cka-sim-lint: allow-node-literal` sentinel that lint-packs pass F respects.

**Regression guard intact:** Any NEW pack shell script that adds a literal `node-01`/`node-02` without the sentinel fails pass F. The sentinel is intentionally conspicuous so code review catches over-use.
