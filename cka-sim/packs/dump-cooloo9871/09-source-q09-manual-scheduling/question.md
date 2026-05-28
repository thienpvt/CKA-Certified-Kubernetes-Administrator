# Manually bind a pod without stopping scheduler

Pack: dump-cooloo9871
Source topic: source-q09 (Manual scheduling)

Lab namespace: `${CKA_SIM_LAB_NS}`

Create pod `manual-nginx` with image `nginx:1.27-alpine` and bind it directly by setting `spec.nodeName` to the worker named in ConfigMap `q09-scheduler-sim` key `targetNode`.
