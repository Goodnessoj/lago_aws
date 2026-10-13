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

Architecture notes, runbooks, and evidence are maintained locally in the
ignored `docs/` directory.

## Verified Status

The existing state bucket is deployed with versioning, encryption, and public
access blocking. Additive TLS hardening is implemented and awaits plan approval.
All five foundation modules and dev integration are implemented and validated.
Their AWS apply is pending. Ansible configuration and Lago over HTTPS are not
deployed. DNS records and secret values will be configured in those checkpoints.

The public repository is [Goodnessoj/lago_aws](https://github.com/Goodnessoj/lago_aws).

## Prerequisites and Validation

Verified controller tools: Terraform 1.15.1 and AWS CLI 2.34.30. Root provider
lock files pin AWS provider 6.67.0; configuration requires Terraform >= 1.10
and < 2.0 for native S3 locking. Ansible and Session Manager controller setup
will be pinned in the host-configuration checkpoint.

Use an authorized non-root AWS identity in `us-east-2`. The dev backend expects
the existing bootstrap bucket; do not run bootstrap apply blindly in a new
account or delete its local state. Local Terraform state and plans stay outside
Git. Restricted local bootstrap-state backups are stored under
`.local/bootstrap-state-backups/`; a protected off-device backup is still required.

```bash
terraform fmt -check -recursive terraform
terraform -chdir=terraform/environments/dev init -input=false -lockfile=readonly
terraform -chdir=terraform/environments/dev validate -no-color
terraform -chdir=terraform/environments/dev test -no-color
terraform -chdir=terraform/modules/networking test -no-color
terraform -chdir=terraform/environments/dev plan -input=false -out=foundation.tfplan
terraform -chdir=terraform/environments/dev show -no-color foundation.tfplan
```

Module tests use a mock AWS provider and never provision infrastructure.
Module READMEs describe contracts, limits, and focused test commands.
Review and approve the saved plan before applying; regenerate it after
configuration/state changes. After an approved apply, verify VPC DNS, subnet
public-IP settings, explicit internet routing, security-group rules, remote
state presence, and a fresh no-change plan. Verify SSM registration, IAM scope,
storage encryption, and EIP attachment before host configuration.

## Proposed Lab Settings

Dev proposes a pinned Canonical Ubuntu 24.04 amd64 AMI with a `t3a.large`
(2 vCPUs, 8 GiB), 16 GiB encrypted gp3 root storage, and a separately managed
30 GiB encrypted gp3 data volume. The host uses SSM only, IMDSv2, standard CPU
credits, and Caddy-only ingress on ports 80/443. Application data must be mounted
before Docker startup through the later Ansible roles.

The data volume has `prevent_destroy`; root storage is deleted with the host.
EC2 termination protection must be deliberately disabled before reviewed host
removal. Stopping compute retains EBS/EIP charges. Backup/restore is a separate
checkpoint, not a property of persistent storage.

The USD 30/month target requires bounded runtime. On 2026-10-11 the Ohio Pricing
API returned USD 0.0752/hour for the host and USD 0.08/GiB-month for gp3.
An allocated public IPv4 costs USD 0.005/hour even while compute is stopped
([AWS pricing](https://aws.amazon.com/vpc/pricing/)). Continuous compute alone
is about USD 54.90 for 730 hours. Review the full service estimate and current
account spending before approving an apply; no free-tier allowance is assumed.

Secret values remain outside Terraform. Host tasks will retrieve the seven named
SecureString parameters and render a protected environment file. The separate
Ansible transfer bucket has short expiration, suspended versioning, encryption,
and blocked public access. The controller policy output is review-only and is
not attached to an operator automatically.

CloudWatch has bounded log retention and five host alarms. No notification
destination is configured by default; agent metrics and container logs require
Ansible configuration before they can be verified.

## Repository Structure
- terraform/bootstrap/: Terraform backend infrastructure.
- terraform/environments/dev/: Initial AWS environment.
- terraform/modules/: Networking, IAM, EC2, observability, and deployment support.
- ansible/: Host configuration and application deployment.
- docs/: Local documentation, runbooks, and evidence; excluded from Git.

## Working Principles
- Justify each infrastructure component.
- Never commit credentials, secrets, Terraform state, or saved plans.
- Review changes and estimated costs before provisioning.
- Test recovery and document observed behavior.
- Plan teardown and explicitly identify data that must be retained.
