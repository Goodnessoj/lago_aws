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

## Repository Structure
- terraform/bootstrap/: Terraform backend infrastructure.
- terraform/environments/dev/: Initial AWS environment.
- ansible/: Host configuration and application deployment.
- docs/decisions/: Architecture decisions and trade-offs.
- docs/diagrams/: Infrastructure and communication diagrams.

## Working Principles
- Justify each infrastructure component.
- Never commit credentials, secrets, Terraform state, or saved plans.
- Review changes and estimated costs before provisioning.
- Test recovery and document observed behavior.
- Plan teardown and explicitly identify data that must be retained.