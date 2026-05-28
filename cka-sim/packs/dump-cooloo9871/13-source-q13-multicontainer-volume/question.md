# Create a multi-container pod with shared volume

Pack: dump-cooloo9871
Source topic: source-q13 (Multi-container pod shared volume)

Lab namespace: `${CKA_SIM_LAB_NS}`

Create pod `shared-tools` with two containers named `writer` and `reader`, both using image `busybox:1.36`, sharing an `emptyDir` volume mounted at `/shared`.
