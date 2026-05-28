# Research Summary: v1.1 Dump Cooloo9871 Pack

**Date:** 2026-05-28
**Sources:**
- https://github.com/cooloo9871/cooloo9871.github.io/tree/master/cka
- https://cooloo9871.github.io/cka/index.html

## Key Findings

- Source CKA content is available in the GitHub repo under `cka/`, with `cka/index.html` exposing the question set.
- Approved scope maps to 30 source-derived topics: 25 main simulator questions, 2 extra questions, and 3 preview questions.
- Source repo tree exposes no license file, so v1.1 should use the page as topic inventory only and author original exercise wording, setup, graders, and reference solutions.
- Source tasks assume old Killer Shell style multi-cluster contexts and older Kubernetes behavior. This repo should adapt them to a single v1.35 kubeadm lab.
- Existing `cka-sim/packs/*` architecture is sufficient. No new runtime dependency is needed.

## Source-Derived Topic Groups

### Command and Inspection Tasks

- contexts/current context
- pod sorting command
- resource usage commands
- control-plane component inspection
- cluster/node/version reporting
- cluster events
- namespaced API resources
- certificate inspection
- etcd certificate/key inspection

### Object Authoring Tasks

- StatefulSet scale-down
- PV/PVC/pod volume
- RBAC ServiceAccount/Role/RoleBinding
- DaemonSet on all nodes
- Deployment with topology constraints
- multi-container pod shared volume
- secret mount
- NetworkPolicy containment
- pod/service IP and kube-proxy checks

### Operational and Host-Level Tasks

- control-plane scheduling
- readiness dependent on service reachability
- scheduler stop/manual binding
- kubelet repair
- node upgrade/join adaptation
- static pod plus service
- etcd snapshot save/restore
- eviction-priority analysis
- manual API access from pod

## Recommended Requirements Categories

1. Source inventory and adaptation plan
2. Pack scaffold and metadata
3. Low-risk command/API exercises
4. Core Kubernetes object exercises
5. Host/control-plane operational exercises
6. Grading honesty and verification

## Suggested Roadmap

Use 4 phases:

1. Pack scaffold + source inventory + low-risk file/command questions
2. Core object authoring questions
3. Host/control-plane and operational questions
4. Verification, live UAT batch, and milestone audit

## Non-Goals

- Do not vendor or copy the source repo content into this project.
- Do not add extra clusters.
- Do not add a new runtime language or new simulator command.
- Do not replace existing five domain packs or mock exam blueprints.
