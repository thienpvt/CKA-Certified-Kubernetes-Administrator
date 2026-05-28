# Gate readiness on service reachability

Pack: dump-cooloo9871
Source topic: source-q04 (Readiness depends on service reachability)

Lab namespace: `${CKA_SIM_LAB_NS}`

Create pod `q04-client` with image `busybox:1.36`. Add a readiness probe that checks TCP port 80 on Service `q04-api` in this namespace. Keep the pod running with `sleep 3600`.
