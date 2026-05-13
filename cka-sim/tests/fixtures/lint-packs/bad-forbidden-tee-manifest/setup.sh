#!/bin/bash
set -euo pipefail
printf x | tee /etc/kubernetes/manifests/pod.yaml
