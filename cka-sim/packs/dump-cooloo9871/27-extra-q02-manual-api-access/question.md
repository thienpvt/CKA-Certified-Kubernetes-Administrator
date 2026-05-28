# Contact the Kubernetes API manually from a pod

Pack: dump-cooloo9871
Source topic: extra-q02 (Manual API access)

Lab namespace: `${CKA_SIM_LAB_NS}`

Create ServiceAccount `api-caller`. Create pod `api-curl` using that ServiceAccount and image `curlimages/curl:8.8.0`, running `sleep 3600`. Create ConfigMap `q27-answer` with key `apiPath` value `/api`.
