# docs

Three documents, meant to be read in order — each answers a different
question about this repository:

| Doc | Question it answers |
| --- | --- |
| [`01-git-to-deployment-flow.md`](01-git-to-deployment-flow.md) | A developer just pushed code. What happens between that push and it running in production? |
| [`02-module-connections.md`](02-module-connections.md) | Terraform stood up *something*. What are the 16 modules, and how do they wire into each other? |
| [`03-user-flow.md`](03-user-flow.md) | All of that is running. What actually happens when a real user hits the site? |

These are narrative/flow documents — for the component-by-component reference
table and design-principle rationale, see [`../ARCHITECTURE.md`](../ARCHITECTURE.md)
and [`../README.md`](../README.md) at the `infra-at-scale` root instead. For
all three docs' content as one picture — every module mapped to its AWS
resources plus every user type's entry point — see
[`../architecture-diagram.svg`](../architecture-diagram.svg).
