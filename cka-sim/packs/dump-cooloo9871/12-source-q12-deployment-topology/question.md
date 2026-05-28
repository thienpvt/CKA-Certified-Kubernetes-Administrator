# Create a topology-aware Deployment

Pack: dump-cooloo9871
Source topic: source-q12 (Deployment topology)

Lab namespace: `${CKA_SIM_LAB_NS}`

Create Deployment `spread-web` with 3 replicas, image `nginx:1.27-alpine`, CPU request `25m`, memory request `32Mi`, and a topology spread constraint on `kubernetes.io/hostname` for pods labelled `app=spread-web`.
