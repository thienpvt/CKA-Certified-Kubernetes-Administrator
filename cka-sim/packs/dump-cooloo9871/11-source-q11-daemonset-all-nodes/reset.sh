#!/bin/bash
set -uo pipefail
: "${CKA_SIM_LAB_NS:?CKA_SIM_LAB_NS must be set}"
kubectl delete namespace "$CKA_SIM_LAB_NS" --ignore-not-found --wait=false >/dev/null 2>&1 || true
case "11" in
  06) kubectl delete pv q06-data-pv --ignore-not-found >/dev/null 2>&1 || true ;;
esac
rm -rf "/tmp/cka-sim/dump-q11-daemonset-all-nodes/"
exit 0
