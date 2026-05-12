# Reference prose sample that MUST pass the deprecated-strings lint.
#
# Prose outside fenced code blocks is a carveout per RESEARCH §13. Candidate
# reading material naturally mentions historical names to explain why a current
# API exists.
#
# The old `--container-runtime=remote` kubelet flag was removed in v1.27; in
# v1.35 only `--container-runtime-endpoint` remains. Similarly, PodSecurityPolicy
# (policy/v1beta1) was removed in v1.25 and replaced by PodSecurity admission.
# dockershim was removed in v1.24.
#
# Below is an *allowed* code block (a language the lint does not scan as
# "in-code"): just a plain block, no yaml/bash label.
#
# ```
# PodSecurityPolicy             (historical reference, plain block)
# ```
#
# Takeaway: none of the mentions above live inside yaml|bash|sh|shell fences,
# so the lint skips them as prose.
