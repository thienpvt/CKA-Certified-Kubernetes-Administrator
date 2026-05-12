# CRD Basics

Create a minimal namespaced CRD:

- name: `q06widgets.cka-sim.io`
- group: `cka-sim.io`
- kind: `Q06Widget`
- plural: `q06widgets`
- scope: `Namespaced`

Then create one `Q06Widget` custom resource in the lab namespace with numeric `spec.size`.
