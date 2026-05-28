# Repair a simulated kubelet flag file

Pack: dump-cooloo9871
Source topic: source-q18 (Fix kubelet)

Lab namespace: `${CKA_SIM_LAB_NS}`

Patch ConfigMap `kubelet-flags` so key `runtimeEndpoint` is exactly `unix:///run/containerd/containerd.sock` and key `status` is exactly `repaired`.
