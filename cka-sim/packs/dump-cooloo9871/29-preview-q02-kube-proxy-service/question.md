# Create a pod and service for kube-proxy inspection

Pack: dump-cooloo9871
Source topic: preview-q02 (Kube-proxy service traffic)

Lab namespace: `${CKA_SIM_LAB_NS}`

Create pod `p2-pod` labelled `app=p2-pod` with image `nginx:1.27-alpine`. Create Service `p2-service` exposing it on port 3000 targeting port 80. Create ConfigMap `q29-answer` with key `proxyMode` value `iptables`.
