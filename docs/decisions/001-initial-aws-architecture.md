# ADR 001: Initial AWS Architecture

Status: Accepted
Region: us-east-2 (Ohio)

## Context
Deploy the locally validated Lago workload to AWS using Terraform
and Ansible, evolving the architecture as requirements emerge.

## Decision
- Start with one VPC, one public subnet, and one EC2 instance.
- Plan non-overlapping address space for future subnets across two AZs.
- Run Lago, PostgreSQL, and Redis through Docker Compose.
- Use SSM for administration and Ansible connectivity; no inbound SSH.
- Use Caddy for HTTPS access to the frontend and API.
- Keep database, Redis, and PDF service ports internal.
- Include persistent storage, secrets management, and basic monitoring.
- Defer private subnets, NAT, load balancing, and managed data services.

## Rationale
Establish repeatable deployment and recovery before introducing
additional infrastructure and operational complexity.

## Accepted Limitations
The application is single-host and single-AZ. Host or AZ failure
causes downtime. Persistent storage alone is not a backup.

## Revisit When
We externalize state, require private host placement, need additional
capacity, or introduce an availability requirement.