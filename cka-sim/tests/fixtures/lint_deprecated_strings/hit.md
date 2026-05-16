# Reference fixture that MUST FAIL the deprecated-strings lint.
#
# A forbidden string inside a fenced yaml code block is NOT prose and is a
# regression we want to catch at CI.
#
# ```yaml
# apiVersion: policy/v1beta1           # <-- inside yaml block -> fail
# kind: PodSecurityPolicy              # <-- inside yaml block -> fail
# metadata:
#   name: bad
# spec:
#   volumes:
#     - gitRepo:                        # <-- inside yaml block -> fail
#         repository: https://example.org/repo
# ```
