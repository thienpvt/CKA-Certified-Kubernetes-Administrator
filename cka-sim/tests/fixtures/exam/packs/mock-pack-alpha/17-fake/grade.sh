#!/bin/bash
set -euo pipefail
printf "SCORE: 4/8
"
printf "Trap 1: : Mock trap fired
" "mock-trap-a"
printf "Trap 2: mock-trap-b: Mock trap B fired
"
exit 1
