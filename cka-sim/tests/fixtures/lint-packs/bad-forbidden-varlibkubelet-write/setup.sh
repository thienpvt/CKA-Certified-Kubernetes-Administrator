#!/bin/bash
set -euo pipefail
echo KUBELET_EXTRA_ARGS=--fake > /var/lib/kubelet/kubeadm-flags.env
