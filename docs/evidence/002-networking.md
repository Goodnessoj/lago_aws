# Checkpoint 002: Modular Networking

Recorded: 2026-10-11, approximately 09:56 UTC.
Status: code validated/tested and final saved plan reviewed; not applied.

## Commands and observations

| Command/check | Expected | Actual | Interpretation |
| --- | --- | --- | --- |
| AWS Ohio VPC CIDR inventory | No overlap with 10.42.0.0/16 | Existing VPC ranges do not overlap | Suitable for the current account; future connected networks remain a separate check |
| AWS availability-zone inventory | us-east-2a available | Available; opt-in not required | The selected initial AZ can be used |
| `terraform fmt -check -recursive terraform` | No formatting differences | Passed | Configuration follows Terraform formatting |
| Dev `init -input=false -lockfile=readonly` | Existing backend and pinned provider initialized | Passed; AWS 6.67.0 reused | Provider upgrade was unnecessary |
| Dev `validate -no-color` | Configuration valid | Passed | Root/module contracts and preconditions are valid |
| Networking module `test -no-color` | All mock runs pass | 5 passed, 0 failed | Baseline routing/security, additive identity, and invalid input cases verified |
| Dev `plan -input=false -no-color -out=networking.tfplan` | Initial network additions only | 7 add, 0 change, 0 destroy | Exact plan awaits approval; no host or speculative second subnet |
| GitHub repository visibility and main branch | Public repository with checkpoint commits | Repository created, public; state checkpoint pushed | Publication established without state/plans/secrets |
| Domain DNS delegation and Route 53 zone inventory | DNS management path available | Public delegation uses Route 53; public zone accessible in account | Hostname records and HTTPS are not yet configured |

The mock test baseline applies to a mocked provider only. It does not create
AWS resources. Adding a hypothetical `public_b` retains the existing VPC,
`public_a` subnet, and route-table identities. Negative plans reject overlapping,
out-of-VPC, and noncanonical subnet CIDRs.

The final live plan includes one VPC, one public subnet, an internet gateway,
an explicit route table/default route/association, and management of the new
VPC's default security group with empty ingress/egress. VPC DNS is enabled and
automatic subnet public-IP assignment is disabled.

Saved plan SHA-256:
`664829ce11701c7d6dfed58bd5d6c1544d071ec12440547da2ae0b91941dbc4d`.
Plans and state backups remain ignored by Git. No AWS account IDs, resource
IDs, credentials, or raw logs are included in this evidence.

## Remaining validation

After approved apply, inspect DNS attributes, subnet properties, route/gateway
association, default security-group rules, backend state presence, and a fresh
no-change plan. This record does not claim deployed networking, working SSM,
EC2 sizing, mounted persistence, or a deployed application.

Live M1 resource consumption could not be sampled: Docker is unavailable in
this WSL session. Sizing will use the pinned workload's requirements and
explicit headroom, with measurements recorded before claiming suitability.
