# Schedule a pod onto a control-plane node safely

Pack: dump-cooloo9871
Source topic: source-q02 (Control-plane scheduling)

Lab namespace: `${CKA_SIM_LAB_NS}`

Create pod `cp-toolbox` with image `busybox:1.36`. It must target control-plane nodes using the control-plane node selector and tolerate the control-plane NoSchedule taint. Keep it running with `sleep 3600`.
