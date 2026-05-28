# dump-cooloo9871 Pack

This pack contains 30 independently authored CKA practice drills adapted from the topic outline on the cooloo9871 CKA page.

The source page is used only as prior-art topic context. Task wording, setup state, grading, reset behavior, and reference solutions are authored for this simulator and Kubernetes v1.35.

Use:

```bash
cka-sim list packs
cka-sim drill dump-cooloo9871 1
```

The pack follows the standard seven-file runtime shape for every question: `question.md`, `metadata.yaml`, `setup.sh`, `grade.sh`, `reset.sh`, `ref-solution.sh`, and `expected-symptom.yaml`.

High-risk host and control-plane topics are simulated with namespace-scoped or lab-safe resources where direct host mutation would be unsafe. Full live UAT is recorded at milestone close.
