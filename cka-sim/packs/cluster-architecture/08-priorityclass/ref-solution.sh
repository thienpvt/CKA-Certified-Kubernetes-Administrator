#!/bin/bash
set -euo pipefail

kubectl patch priorityclass q08-batch --type=merge -p '{"globalDefault":false}'
sleep 5
