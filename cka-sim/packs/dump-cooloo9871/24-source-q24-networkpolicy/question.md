# Create a NetworkPolicy containment rule

Pack: dump-cooloo9871
Source topic: source-q24 (NetworkPolicy)

Lab namespace: `${CKA_SIM_LAB_NS}`

Create NetworkPolicy `frontend-egress` selecting pods with `app=frontend`. It must include policy type `Egress` and allow TCP port 443.
