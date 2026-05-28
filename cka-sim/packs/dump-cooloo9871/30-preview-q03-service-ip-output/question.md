# Create pod/service and record service IPs

Pack: dump-cooloo9871
Source topic: preview-q03 (Pod and Service IP output)

Lab namespace: `${CKA_SIM_LAB_NS}`

Create pod `check-ip` labelled `app=check-ip` with image `httpd:2.4.62-alpine`. Create Service `check-ip-service` on port 80. Create ConfigMap `q30-answer` with key `serviceName` value `check-ip-service`.
