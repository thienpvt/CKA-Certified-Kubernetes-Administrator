# Create PV, PVC, and mounted pod

Pack: dump-cooloo9871
Source topic: source-q06 (Storage PV PVC pod volume)

Lab namespace: `${CKA_SIM_LAB_NS}`

Create PersistentVolume `q06-data-pv`, PersistentVolumeClaim `q06-data`, and pod `q06-reader`. The pod must mount the PVC at `/data`.
