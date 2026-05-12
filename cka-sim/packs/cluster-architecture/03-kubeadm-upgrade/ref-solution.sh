#!/bin/bash
set -euo pipefail

sandbox="/tmp/q03-kubeadm-upgrade"
mkdir -p "$sandbox"
cat > "$sandbox/planned-upgrade.txt" <<'EOF'
# Upgrade plan

Target version: v1.35.0

Run kubeadm upgrade plan, confirm v1.35.0 is available, then apply v1.35.0.
EOF
cat > "$sandbox/apply-script.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
kubeadm upgrade plan
kubeadm upgrade apply v1.35.0
EOF
chmod 0755 "$sandbox/apply-script.sh"
