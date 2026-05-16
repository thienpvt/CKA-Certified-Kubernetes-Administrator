# PriorityClass globalDefault

Two PriorityClasses, `q08-critical` and `q08-batch`, exist in the cluster. Neither currently has `globalDefault: true`, so Pods without an explicit `priorityClassName` fall through to whatever cluster-wide default the scheduler resolves — which on a vanilla kubeadm cluster means no priority at all.

Fix the state so exactly one PriorityClass has `globalDefault: true`.

## Constraints

- Do not delete either PriorityClass. Both `q08-critical` and `q08-batch` must still exist after your fix.
- Exactly one of them must have `globalDefault: true` after your fix. The other must have `globalDefault: false`.
- Do not create a new PriorityClass.

## Verify

```bash
kubectl get priorityclass q08-critical q08-batch \
  -o custom-columns=NAME:.metadata.name,VALUE:.value,DEFAULT:.globalDefault
```

Exactly one row should show `DEFAULT: true`.
