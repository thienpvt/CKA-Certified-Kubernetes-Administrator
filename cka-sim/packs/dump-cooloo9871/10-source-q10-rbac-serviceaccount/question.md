# Create ServiceAccount, Role, and RoleBinding

Pack: dump-cooloo9871
Source topic: source-q10 (RBAC ServiceAccount Role RoleBinding)

Lab namespace: `${CKA_SIM_LAB_NS}`

Create ServiceAccount `audit-reader`, Role `audit-reader` that can get/list/watch pods, and RoleBinding `audit-reader` binding the ServiceAccount to that Role.
