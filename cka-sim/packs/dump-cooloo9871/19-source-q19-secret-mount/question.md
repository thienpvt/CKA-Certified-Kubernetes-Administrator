# Create a Secret and mount it into a pod

Pack: dump-cooloo9871
Source topic: source-q19 (Secret mount into pod)

Lab namespace: `${CKA_SIM_LAB_NS}`

Create Secret `app-credentials` with key `password` value `correct-horse`. Create pod `secret-reader` mounting that Secret at `/etc/secret-data`.
