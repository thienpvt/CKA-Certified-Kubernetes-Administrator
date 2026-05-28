# Run a DaemonSet on every node

Pack: dump-cooloo9871
Source topic: source-q11 (DaemonSet on all nodes)

Lab namespace: `${CKA_SIM_LAB_NS}`

Create DaemonSet `node-log-agent` using image `busybox:1.36`. It must tolerate the control-plane NoSchedule taint so it can run on all nodes.
