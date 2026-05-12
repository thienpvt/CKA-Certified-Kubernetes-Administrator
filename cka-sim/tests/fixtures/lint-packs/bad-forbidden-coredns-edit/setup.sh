#!/bin/bash
set -euo pipefail
kubectl edit configmap coredns -n kube-system
