# Lago on AWS

An evolving deployment of Lago, moving from a validated local
Docker Compose environment to AWS.

## Current Milestone
M2: AWS foundation, host configuration, and application deployment.

- M2A: Provision infrastructure with Terraform.
- M2B: Configure the host with Ansible over SSM.
- M2C: Deploy and validate Lago over HTTPS.

## Initial Architecture
Region: us-east-2 (Ohio).

One VPC, one public subnet, and one EC2 instance running Lago,
PostgreSQL, and Redis through Docker Compose.

Administration uses SSM, with no inbound SSH. Caddy provides HTTPS.
This initial deployment is not highly available.

Architecture decisions are recorded in docs/decisions/.

## Verified Status

The existing state bucket is deployed with versioning, encryption, and public
access blocking. Additive TLS hardening is implemented and awaits plan approval.
The networking module and dev integration are implemented; provisioning is
pending. Compute, Ansible configuration, and Lago over HTTPS are not deployed.

The public repository is [Goodnessoj/lago_aws](https://github.com/Goodnessoj/lago_aws).
See [the communication diagram](docs/diagrams/m2-architecture.md) for deployed
versus planned components.

## Prerequisites and Validation

Verified controller tools: Terraform 1.15.1 and AWS CLI 2.34.30. Root provider
lock files pin AWS provider 6.67.0; configuration requires Terraform >= 1.10
and < 2.0 for native S3 locking. Ansible and Session Manager controller setup
will be pinned in the host-configuration checkpoint.

Use an authorized non-root AWS identity in `us-east-2`. The dev backend expects
the existing bootstrap bucket; do not run bootstrap apply blindly in a new
account or delete its local state. Local Terraform state and plans stay outside
Git. See [state recovery](docs/runbooks/terraform-state.md).

```bash
terraform fmt -check -recursive terraform
terraform -chdir=terraform/environments/dev init -input=false -lockfile=readonly
terraform -chdir=terraform/environments/dev validate -no-color
terraform -chdir=terraform/environments/dev plan -input=false -out=networking.tfplan
```

Module tests use a mock AWS provider and never provision infrastructure. See
[the module contract and tests](terraform/modules/networking/README.md).
Review and approve the saved plan before applying; regenerate it after
configuration/state changes. Follow the [networking runbook](docs/runbooks/networking.md)
for apply and post-apply inspection.

## Repository Structure
- terraform/bootstrap/: Terraform backend infrastructure.
- terraform/environments/dev/: Initial AWS environment.
- terraform/modules/networking/: VPC, subnet maps and public routing.
- ansible/: Host configuration and application deployment.
- docs/decisions/: Architecture decisions and trade-offs.
- docs/diagrams/: Infrastructure and communication diagrams.
- docs/runbooks/: State recovery and provisioning procedures.
- docs/evidence/: Sanitized validation results; no deployment claims without evidence.

## Working Principles
- Justify each infrastructure component.
- Never commit credentials, secrets, Terraform state, or saved plans.
- Review changes and estimated costs before provisioning.
- Test recovery and document observed behavior.
- Plan teardown and explicitly identify data that must be retained.
