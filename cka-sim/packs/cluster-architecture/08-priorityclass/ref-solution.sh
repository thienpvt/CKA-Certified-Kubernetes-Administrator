#!/bin/bash
set -euo pipefail

kubectl patch priorityclass q08-critical --type=merge -p '{"globalDefault":true}'
sleep 5
