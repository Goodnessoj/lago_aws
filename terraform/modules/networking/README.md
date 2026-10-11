# Networking Module

Creates the initial IPv4 VPC, a public subnet map, an internet gateway, explicit
public routing, and subnet associations. It also manages the new VPC's default
security group with no rules; compute will use its own dedicated group.
Provider and backend configuration belong to the environment root.

## Contract

| Input | Purpose |
| --- | --- |
| `name_prefix` | Resource Name-tag prefix |
| `vpc_cidr` | Canonical IPv4 VPC range, /16 through /28 |
| `subnets` | Map of stable keys to `cidr_block`, `availability_zone`, and `type` |
| `tags` | Additional tags; the module owns Name tags |

| Output | Consumer |
| --- | --- |
| `vpc_id` | EC2/security-group integration |
| `public_subnet_ids` | Host placement using a stable key such as `public_a` |
| `route_table_ids` | Inspection and future routing integration |

Only `type = "public"` is currently supported. Private routing and NAT are
deferred. VPC DNS support/hostnames are enabled; subnet automatic public-IP
assignment is disabled. An EIP will be attached explicitly at the compute
stage. A public route alone does not allocate a public IP or open host ports.

Input validation rejects invalid/noncanonical IPv4 CIDRs and unsupported subnet
types. VPC preconditions reject out-of-range and overlapping subnets. The dev
root validates availability zones against the live provider region.

## Identity and testing

Resource addresses use subnet keys, not list positions. Adding `public_b`
creates its subnet and route association without changing `public_a`'s
identity. Renaming a key or changing a CIDR/AZ can require replacement and
still needs a reviewed plan.

The test suite uses a mocked AWS provider. Its baseline mock apply establishes
test state locally; subsequent plans check identity preservation and rejected
inputs. It never calls AWS or provisions hypothetical infrastructure.

```bash
terraform -chdir=terraform/modules/networking init -backend=false
terraform -chdir=terraform/modules/networking test -no-color
```

For exact project-version tests, copy the dev root's provider lock file into
this module directory before initialization. That local copy is ignored; the
two environment/bootstrap root lock files are the committed version records.
