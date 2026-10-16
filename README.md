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

The state bucket and all five foundation modules are deployed in Ohio. Backend
TLS enforcement, encrypted storage, routing, security groups, and SSM access
are verified. Terraform generates the Ansible inventory automatically, and the
live access playbook passed with five successful tasks and zero changes.
Both Terraform roots report no changes after deployment.

Host configuration is deployed: safe UUID-based data mounting, security,
Docker/Compose, and CloudWatch. Reboot recovery and retained storage passed;
both final configuration passes made zero changes. Host metrics, system and
bootstrap logs, and a container logging smoke test are verified.

EC2 stopped automatically after verification on 2026-10-15; the stopped state
was confirmed on 2026-10-16. EBS and EIP charges continue. Lago, HTTPS,
backup/restore, and alerting remain later work.

The current stage keeps the AWS foundation, host configuration, Docker, and
basic logs/host metrics. Alarm resources and their configuration have been
removed from code and AWS after the approved cleanup on 2026-10-16. The apply
deleted only the five alarms; no host reconfiguration was needed.

Application deployment automation is implemented and locally tested, but not
run on EC2. It prepares pinned Lago services, protected host-side secret
retrieval, and Caddy for `app.phoniex.site` and `api.phoniex.site`. Both DNS A
records are managed by Terraform and resolve publicly to the host Elastic IP
with TTL 300; the existing hosted zone and other records were preserved.
All seven SecureString parameters were created in
Ohio on 2026-10-16; metadata checks passed and a repeat run made zero changes.
Live host retrieval, deployment, HTTPS, login and PDF compatibility are not yet
verified.

DNS is defined directly in `terraform/environments/dev/dns.tf`. The environment
looks up the existing public `phoniex.site` zone and creates only the two
approved records, using the managed EIP output rather than a copied address.
No new hosted zone, DNS module, or certificate resource is needed at this stage.
DNS resolution does not mean the stopped host is serving Lago or HTTPS.

The public repository is [Goodnessoj/lago_aws](https://github.com/Goodnessoj/lago_aws).

## Prerequisites and Validation

Verified controller tools: Terraform 1.15.1 and AWS CLI 2.34.30. Root provider
lock files pin AWS provider 6.67.0; configuration requires Terraform >= 1.10
and < 2.0 for native S3 locking. The project-local Ansible/Session Manager
controller is installed and pinned; live host access over SSM is verified.

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

## Ansible Controller

```bash
source .local/ansible-venv/bin/activate
ansible --version
```

The controller uses standard Ansible commands and a Terraform-generated YAML
inventory. Dependencies are installed under ignored `.local/` directories.
After the reviewed AWS apply, inspect the generated inventory and verify access:

```bash
terraform -chdir=terraform/environments/dev output ansible_inventory_file
ansible-inventory --graph
ansible-playbook ansible/playbooks/verify-access.yml
```

Terraform's `local_file` resource writes the inventory with current host,
transfer-bucket, and volume values, mode 0600, and Git exclusion. It contains no
credentials or application secrets. See [setup and access checks](ansible/README.md).
It also carries the existing Terraform-defined agent and Docker logging settings.
The host roles are composed by `ansible/playbooks/configure.yml`. Native
verification playbooks check storage/services, exercise a deliberate reboot,
and run configuration twice before stopping the lab instance. Application
deployment remains the next checkpoint.

## Deployed Lab Settings

Dev uses a pinned Canonical Ubuntu 24.04 amd64 AMI with a `t3a.large`
(2 vCPUs, 8 GiB), 16 GiB encrypted gp3 root storage, and a separately managed
20 GiB encrypted gp3 data volume. The host uses SSM only, IMDSv2, standard CPU
credits, and Caddy-only ingress on ports 80/443. Ansible mounts application data
before Docker/containerd startup and gates their services on the intended disk.

The 20 GiB data allocation follows a measured local storage review. CPU/memory
capacity still needs workload validation; this allocation is not a production
capacity guarantee. The data volume is formatted as ext4 and mounted by UUID at
`/srv/lago-data`; Docker and containerd have separate storage roots there.

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

CloudWatch configuration retains bounded log retention and basic host metrics.
Host/bootstrap logs are delivered, and the Docker smoke test verified container
logging. Alarms, threshold tuning, and notification delivery are deferred until
after application deployment and baseline measurement.

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
