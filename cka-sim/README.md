# cka-sim — CKA Exam Simulator

Bash-only, kubectl-driven exam simulator for the CKA v1.35 syllabus. Runs against your own 1+2 kubeadm cluster.

## Setup

Clone the repo on your control-plane node and add the `bin/` directory to your PATH:

```bash
git clone <repo-url> ~/CKA-Certified-Kubernetes-Administrator
export PATH="$HOME/CKA-Certified-Kubernetes-Administrator/cka-sim/bin:$PATH"
```

To make it permanent, add the `export` line to your `~/.bashrc`.

## SSH to Worker Nodes

Some questions (e.g., static-pod placement) require passwordless SSH from the control-plane to worker nodes. If `cka-sim bootstrap` cannot run `ssh-copy-id` automatically (common on manually provisioned GCP VMs), distribute the key manually:

```bash
# On the control-plane node — generate the key if it doesn't exist:
[ -f ~/.ssh/cka_sim_ed25519 ] || ssh-keygen -t ed25519 -N '' -f ~/.ssh/cka_sim_ed25519

# Copy the public key:
cat ~/.ssh/cka_sim_ed25519.pub

# On each worker node — paste into authorized_keys:
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo "<paste-pubkey-here>" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

Verify with: `ssh -i ~/.ssh/cka_sim_ed25519 -o BatchMode=yes <worker-ip> true`

## Quickstart

```bash
# On the control-plane node:
cka-sim bootstrap          # SSH setup + environment
cka-sim doctor             # Verify cluster health
cka-sim drill <domain>     # Practice a single question
cka-sim exam blueprint-alpha  # Timed 2-hour mock (17 questions)
cka-sim score              # View your last score report
cka-sim list history       # All completed sessions
```

## Architecture

```
cka-sim/
├── bin/cka-sim            # Entry-point router
├── lib/                   # Core libraries (grade.sh, traps.sh, exam-*.sh, cmd/)
├── packs/                 # Domain question packs (5 domains)
├── exams/                 # Blueprint manifests (alpha, bravo)
├── scripts/               # Lint, test, validate tooling
├── tests/                 # Unit + integration tests
└── traps/                 # Trap catalog (catalog.yaml)
```

## Domain Packs

| Domain | Weight | Questions |
|--------|--------|-----------|
| Storage | 10% | 6 |
| Workloads & Scheduling | 15% | 8 |
| Services & Networking | 20% | 6 |
| Cluster Architecture | 25% | 8 |
| Troubleshooting | 30% | 6 |

## Mock Exams

Two blueprint manifests ship with cka-sim. Each draws 17 questions across all five domains, weighted to match the CKA v1.35 blueprint. A 2-hour countdown timer enforces exam pacing. `blueprint-alpha` and `blueprint-bravo` use different question draws so you can retake without memorization bias.

## Development

```bash
bash scripts/test.sh            # Full test suite (unit + lint)
bash scripts/lint-packs.sh      # Pack structure + content lint
bash scripts/validate-local.sh  # shellcheck + yamllint
```

## Disclaimer

> Not real CKA exam content; independently authored. Targets v1.35 CKA blueprint.
