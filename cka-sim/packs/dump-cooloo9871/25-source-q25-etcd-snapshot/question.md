# Save and verify a simulated etcd snapshot

Pack: dump-cooloo9871
Source topic: source-q25 (Etcd snapshot save and restore)

Lab namespace: `${CKA_SIM_LAB_NS}`

Create Secret `q25-etcd-snapshot` with key `snapshot` value `saved`. Create ConfigMap `q25-restore-plan` with key `dataDir` value `/tmp/q25-etcd-restore`.
