# Create a static-pod manifest model and service

Pack: dump-cooloo9871
Source topic: source-q21 (Static pod and Service)

Lab namespace: `${CKA_SIM_LAB_NS}`

Create ConfigMap `q21-static-manifest` with key `source=file` and create Service `static-web` selecting `app=static-web` on port 80.
