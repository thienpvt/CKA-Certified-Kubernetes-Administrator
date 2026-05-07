# cka-sim — CKA Exam Simulator

Bash-only, kubectl-driven exam simulator for the CKA v1.35 syllabus. Runs against your own 1+2 kubeadm cluster. Ship trap-aware grading, timed mocks, and domain drilling.

This README is a placeholder. Full quickstart and architecture docs land in Phase 8 (DOC-01). For now:

## Quickstart (Phase 1)

```bash
# On the control-plane node of your existing 1+2 cluster:
cd <repo-root>
./cka-sim/bin/cka-sim bootstrap    # Phase 2 delivers the body
./cka-sim/bin/cka-sim doctor       # Phase 2 delivers the body
```

## Layout

```
cka-sim/
├── bin/cka-sim         router (only thing on $PATH)
├── lib/
│   ├── colors.sh       ANSI color vars (TTY-detected)
│   ├── log.sh          info / ok / warn / err / die / header
│   ├── preflight.sh    cluster & dependency checks (Plan 02)
│   └── cmd/
│       ├── bootstrap.sh
│       ├── doctor.sh
│       ├── list.sh
│       ├── drill.sh    (stub, phase 3)
│       ├── exam.sh     (stub, phase 7)
│       ├── score.sh    (stub, phase 7)
│       ├── help.sh
│       └── version.sh
└── README.md
```

## Status

Phase 1 of 8 in milestone v1.0. See `.planning/ROADMAP.md` for full build plan.
