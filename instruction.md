# Lago on AWS: M2 Implementation Instructions

Status: Working implementation brief, not evidence of deployment completion.
Prepared: 2026-10-11.
Scope: First AWS provisioning phase, called M2 in the deployment guide. M1 is the completed local workload-validation phase.
Intended repository: `/home/goodnessojonuba/cba/lago_aws`.

## 1. Objective and Working Standard

Take the locally validated Lago workload to AWS through a reproducible, modular, cost-conscious deployment. Use Terraform for infrastructure, Ansible over Systems Manager (SSM) for host configuration, and Docker Compose for the application.

The project has two equally important outcomes:

- A working, testable AWS deployment that can be operated, recovered, and removed deliberately.
- Credible public engineering material: architecture decisions, reproducible examples, measured results, and honest limitations. This supports an AWS community portfolio; it does not guarantee Community Builder eligibility or acceptance.

Approach this as a junior Cloud/DevOps engineer delivering a planned project. Explain decisions clearly without presenting the work as a collection of beginner experiments. Learning comes from understanding and testing a coherent design, not from introducing unnecessary services.

### Instructions for the implementation assistant

- Inspect the repository and current state before suggesting or making changes. Do not recreate work that already exists.
- Preserve the agreed architecture and module boundaries. Do not silently substitute a flat Terraform layout or reopen settled choices.
- Work in coherent checkpoints. Present the complete component, file relationships, plan, and validation together rather than asking for confirmation after every file.
- Explain each component's requirement, purpose, alternatives, trade-off, and revisit trigger.
- Keep the user involved in design and deployment. The established workflow is user-led execution in the WSL VS Code terminal unless direct implementation access is explicitly authorized and available.
- Previously, Windows-side WSL commands returned access denied. Do not claim to have connected, edited WSL files, or run commands there without current evidence. Do not bypass access restrictions.
- Treat this file as a brief, not blanket authorization to spend money, delete data, publish content, or expand permissions. Review the actual plan and obtain approval before applying infrastructure changes or performing destructive operations.
- Keep explanations professional and practical. Distinguish agreed decisions, proposals, historical observations, and verified results.
- Update the relevant ADR and diagram when an approved design change occurs. Avoid unrelated refactoring and preserve existing user changes.

## 2. Agreed Architecture

| Area | Decision | Reason and accepted limitation |
| --- | --- | --- |
| AWS region | Ohio, `us-east-2` | User-selected region; use consistently in Terraform, Ansible, CLI examples, and estimates. |
| Environment | `dev`, portfolio/lab | Not a production billing service; use synthetic data only. |
| Network | One VPC and one public subnet in one AZ initially | Establish the smallest useful network while planning address space for later expansion. |
| Compute | One Ubuntu EC2 instance | Reuse the validated Compose workload. A host or AZ failure causes downtime. |
| Administration | SSM only, including Ansible transport | No inbound port 22, SSH key pair, or bastion. |
| Public application access | Caddy on EC2, Elastic IP, frontend/API DNS names, HTTPS | Avoid a load balancer in this phase. Domain ownership and DNS access must be confirmed. |
| Application | Pinned Lago release, Docker Compose | Preserve the known workload while changing its hosting environment. |
| Database and Redis | Containers on the same EC2 host | Keep the initial footprint small; externalize state in a later phase. |
| Storage | Encrypted EBS-backed persistent paths/volumes | Container replacement must not delete data. Persistence is not a backup. |
| Secrets | Parameter Store SecureString; protected host environment file | No secrets in Git, Terraform variables/state by design, user data, logs, or outputs. |
| Observability | CloudWatch logs and basic host/service monitoring | API availability alone is not application health. Keep retention and ingestion bounded. |
| State backend | Existing S3 bootstrap bucket, native S3 locking for dev | Keep bootstrap and environment state separate; do not add DynamoDB locking. |
| Budget target | USD 30 per month | Plan bounded lab runtime; do not assume continuous operation fits the budget. |

### Explicitly deferred

Do not provision private subnets, a second application host, NAT gateways, a bastion, ALB, EKS, RDS, ElastiCache, GitOps, or a full CI/CD platform in M2 without a new approved requirement and ADR. Application object storage migration is also deferred; S3 state and Ansible transfer storage are separate operational needs.

The earlier guide described two public and two private subnets across two AZs from the start. The user-approved deviation is to plan that expansion but create only the currently required subnet. Record this in the architecture decision log.

## 3. Known Progress and Mandatory Reconciliation

These are historical observations from the walkthrough, not a live audit of AWS:

- Local application checkout: `/home/goodnessojonuba/cba/lago`.
- Separate infrastructure repository: `/home/goodnessojonuba/cba/lago_aws`.
- Terraform `1.15.1` and AWS CLI `2.34.30` were reported installed. Ansible was reported missing. Verify again; do not upgrade merely because a newer version exists.
- AWS CLI authentication succeeded as IAM user `Admin11`, not root. Its name does not establish its permissions. Verify the intended account and current identity privately.
- Bootstrap apply succeeded: `4 added, 0 changed, 0 destroyed`.
- Reported state bucket: `lago-tfstate-us-east-2-f31e719a5b888b03e3bdf256df`.
- Its configuration included public-access blocking, versioning, SSE-S3 encryption, `force_destroy = false`, and Terraform `prevent_destroy`.
- Dev backend was proposed with key `environments/dev/terraform.tfstate`, region `us-east-2`, `encrypt = true`, and `use_lockfile = true`. Its successful initialization has not been evidenced in this brief.
- A flat `network.tf` was proposed. Whether it was saved, planned, or applied is unknown. Do not assume the network exists or does not exist.
- Git initialization and documentation setup were discussed; confirm actual commits and working-tree changes.

Start with a read-only reconciliation of files, Git, AWS identity, backend configuration, Terraform state, and matching AWS resources. Inspect each Terraform root separately. An empty state listing or a backend error is not proof that resources are absent.

If the flat network was never applied, move its configuration into the module before generating a fresh plan. If it was applied, back up state securely and use reviewed `moved` blocks or an explicitly planned state migration. The refactoring plan should preserve infrastructure, not destroy and recreate it. Discard obsolete saved plans and regenerate after any configuration change.

Do not recreate or import the bootstrap bucket blindly. Keep its existing local state until a separate, approved bootstrap-state protection or migration decision is implemented. Do not commit state or print its contents into public evidence.

## 4. Repository Blueprint

```text
lago_aws/
  instruction.md
  README.md
  .gitignore
  terraform/
    bootstrap/                 # Owns state-storage infrastructure only
    modules/
      networking/              # VPC, subnet maps, gateway, routing
      iam/                     # Instance role, policies, instance profile
      ec2/                     # Host, SG rules, EIP, storage and attachment
      observability/           # Log groups and agreed alarms
      deployment_support/      # Dedicated Ansible SSM transfer bucket
    environments/
      dev/
        backend.tf
        providers.tf
        main.tf
        variables.tf
        outputs.tf
        terraform.tfvars.example
  ansible/
    requirements.yml
    inventories/dev/
    playbooks/configure.yml
    roles/
      base/
      docker/
      security/
      cloudwatch/
      lago/
  docs/
    decisions/
    diagrams/
    runbooks/
    evidence/
```

Create files when they contain meaningful work. Do not scaffold speculative modules or add wrappers around every AWS resource. DNS records can remain in the environment root unless reuse justifies a DNS module. Keep provider configuration and backend configuration in root modules, not child modules.

### Module contracts

| Module | Principal inputs | Principal outputs |
| --- | --- | --- |
| networking | Name prefix, VPC CIDR, subnet map keyed by stable names with CIDR/AZ/type, tags | VPC ID, subnet ID maps, route table IDs |
| iam | Name prefix, explicit Parameter Store paths and log/storage resource ARNs needed by the host | Instance profile name and role ARN |
| ec2 | Subnet ID, VPC ID, instance profile, approved AMI ID/type, encrypted volume settings, ingress policy, tags | Instance ID, EIP, volume IDs, security group ID |
| observability | Log-group names, retention, agreed metric/alarm settings and notification destination | Log-group ARNs and alarm identifiers |
| deployment_support | Name prefix, transfer-object expiration, encryption and access settings | Transfer bucket name and ARN |

Use stable `for_each` keys such as `public_a`; do not use list position as a durable resource identity. Validate inputs and expose only useful, non-secret outputs. Avoid circular dependencies: the environment root composes modules and owns cross-module relationships where necessary.

Later milestones should extend these interfaces and add justified modules. Do not promise that no resource will ever require replacement; evaluate provider replacement behavior, back up state/data, and document migrations.

Commit `.terraform.lock.hcl` in each root. Ignore `.terraform/`, state and state backups, saved plans, secret inputs, credentials, and local environment files. Commit only sanitized variable examples. Review staged changes; `.gitignore` is not a secret scanner.

## 5. Network and Communication Design

Proposed address plan, subject to overlap review before deployment:

| Allocation | CIDR | M2 status |
| --- | --- | --- |
| VPC | `10.42.0.0/16` | Provision |
| Public subnet A | `10.42.1.0/24` | Provision in the selected Ohio AZ |
| Public subnet B | `10.42.2.0/24` | Document only |
| Private capacity | Remaining suitable ranges inside the VPC | Reserve in the plan; size for later workload needs |

Do not mechanically choose small private subnet ranges for future EKS workloads. Assess pod/IP capacity when that phase is designed. Validate overlaps with networks that may later connect to this VPC. The previously suggested AZ was `us-east-2a`; verify availability and record the selected AZ.

```text
Browser/API client --DNS lookup--> DNS service
Browser/API client --HTTPS--> EC2 Elastic IP
  VPC internet gateway and subnet route provide the network path
  Security group permits only the approved application ingress
  Caddy --> frontend (serves the UI)
  Caddy --> API (browser GraphQL requests and REST client requests)

Inside the EC2 Docker network:
  API --> PostgreSQL
  API --> Redis (queue/cache operations)
  Scheduler --> Redis (scheduled work)
  Worker <--> Redis (job processing)
  Worker --> PostgreSQL
  Worker --> PDF service (document rendering)
  API and worker --> shared persistent application storage

Administrator/Ansible --> AWS SSM service
  EC2 SSM Agent --> AWS SSM endpoints over outbound HTTPS
  Ansible controller and EC2 --> dedicated S3 transfer bucket
  Configured secret-fetching identity --> Parameter Store
  CloudWatch agent --> CloudWatch
```

This is a responsibility-level sketch, not an exhaustive dependency graph. Verify exact connections against the pinned Compose configuration. DNS is a lookup step, not an HTTP proxy. SSM is an administration path, not the public application endpoint.

### Network requirements

- Enable VPC DNS support and hostnames.
- Associate the public subnet with an explicit route table containing `0.0.0.0/0` to the internet gateway.
- Keep automatic subnet public-IP assignment disabled; attach the intended EIP explicitly to the host.
- Ensure required outbound connectivity exists before host configuration starts: SSM endpoints, DNS, OS repositories, container registries, S3, and AWS APIs. Do not assume HTTPS-only egress suffices without inspecting package sources and dependencies.
- No inbound SSH. Do not add port 22 temporarily to work around SSM errors.
- Publish only Caddy's required host ports. Remove inherited Compose host publishing for PostgreSQL, Redis, the API, and other internal services. Security groups alone are not a substitute for correct Compose exposure.
- Review port 80 use for redirects/certificate validation and port 443 for HTTPS. Confirm application audience and any source restrictions before applying ingress.

## 6. State, Identity, and Secrets

### Terraform state

- Reuse the verified bootstrap bucket for dev state. Do not merge bootstrap and dev state.
- Enable S3 native locking for dev with `use_lockfile = true`; keep encryption and versioning.
- Keep a recoverable, access-controlled backup of bootstrap state outside Git. Document its location and recovery method without publishing sensitive contents.
- Review bucket policy for TLS-only access. Any hardening missing from the existing bootstrap is a reviewed additive change, not a reason to recreate the bucket.
- Remember `prevent_destroy` protects only Terraform operations while the configuration retains it; it is not an AWS-side deletion lock.

### Identity and access

- Verify the deployment identity and account before each apply. Do not use root or grant AdministratorAccess to the EC2 role.
- Separate the operator's provisioning permissions from the host's runtime permissions.
- Use an instance profile for SSM and narrowly scoped runtime permissions. Require IMDSv2.
- Do not place long-lived AWS keys on EC2. Do not embed credentials in provider/backend configuration or Ansible inventory.
- Prefer temporary operator credentials where practical; do not silently replace the user's authentication setup.

### Secrets

- Keep application passwords, Rails secrets, RSA keys, and other encryption material in SecureString parameters using the least privileges needed.
- Choose and document whether the controller or the host retrieves each secret. Grant decrypt/read permissions to that identity only; do not give both identities broad access by default.
- Avoid creating secret values with ordinary Terraform resource arguments: `sensitive = true` masks display but does not keep values out of state. Use an approved separate secret-population flow, or verify a supported state-free approach before adopting it.
- Retrieve secrets at deployment time. Protect sensitive Ansible tasks with `no_log: true`, disable secret-bearing diffs, and render the host environment file with mode `0600` and appropriate ownership.
- Preserve application encryption/signing keys across restarts and restores. Do not regenerate them on each playbook run.
- Verify whether application containers need instance metadata access before choosing IMDS hop settings; do not weaken metadata controls speculatively.

### Ansible transfer storage

Use a separate encrypted, public-access-blocked S3 bucket for the `amazon.aws.aws_ssm` connection plugin. Do not reuse the versioned Terraform state bucket. The plugin transfers module files through S3; interrupted runs can leave artifacts, and versioning can retain sensitive payloads. Keep transfer-bucket versioning disabled, configure short expiration, and scope access to the required resources. Verify cleanup after failure tests. The controller needs transfer permissions; do not grant the EC2 role S3 access solely by assumption when the chosen plugin uses presigned URLs.

## 7. Delivery Checkpoints

### M2A: Reconciled, modular AWS foundation

Before provisioning, confirm:

- Current repository/state and whether any network resources already exist.
- AWS identity, Ohio region, address plan, subnet/AZ selection, domain ownership, and DNS management path.
- M1 resource measurements and an instance choice with realistic headroom. Do not choose an undersized instance solely to fit a cost target.
- Ubuntu AMI provenance, architecture compatibility with all pinned images, and a reproducible AMI selection.
- Root and application-storage size, mount paths, retention on termination, and backup destination. Default proposal: encrypted gp3 root storage plus a separately managed encrypted application-data volume whose retention is explicit; review cost before approving this choice.
- Storage initialization is repeatable and never reformats an existing volume. Docker must not start stateful services against an unmounted fallback directory.
- An hourly-runtime estimate and expected retained-resource charges fit the user's approved spending plan.

Deliver the complete modules and dev integration together, with comments only where useful. Run formatting, initialization, validation, and relevant module checks. Test that adding a hypothetical subnet key is additive; do not apply speculative resources just to test the interface.

Review the plan for region, resource count, public exposure, IAM scope, replacements, and cost-bearing services. Obtain approval for the exact saved plan. Then provision and validate SSM registration, storage encryption, routes, IAM attachment, and the absence of inbound SSH/internal-service exposure. Do not apply an old plan after editing configuration.

### M2B: Repeatable host configuration through SSM

Pin compatible Ansible and collection versions and record controller dependencies, including the Session Manager plugin. Do not assume `ansible-core` includes `amazon.aws`.

Use Ansible for package installation, Docker/Compose, directories, mount configuration, service startup, log rotation, and CloudWatch agent configuration. Limit EC2 user data to minimal non-secret bootstrapping needed to establish management access; do not duplicate the full application deployment in Terraform provisioners.

Configure system startup so required data mounts precede Lago startup. Bound Docker logs and CloudWatch retention. Use intentional handlers/restarts instead of unconditional container recreation. Inventory should identify the instance by ID and set `ansible_connection=amazon.aws.aws_ssm` and the Ohio region.

Run the configuration twice. Review the second run for idempotence; justify genuine recurring changes rather than merely claiming success. Reboot and confirm management access and required services recover. Record any manual remediation and encode repeatable fixes in the appropriate role.

### M2C: Pinned Lago deployment over HTTPS

- Keep the M1-validated Lago `v1.53.0` baseline unless compatibility or security review justifies a documented upgrade. Recheck security advisories before public exposure; do not deploy a known unsafe baseline merely to preserve an old screenshot.
- Record the exact release/commit, image references/digests, Compose version, configuration requirements, and deployment procedure. No `latest` tags.
- Deploy to `/opt/lago` using a reviewed override and reproducible Ansible configuration. Do not modify the separate M1 checkout as part of this work.
- Verify the pinned release's migrations, startup ordering, signing/encryption settings, persistence paths, and health checks.
- Configure separate frontend/API HTTPS hostnames. The frontend API base URL must match the application configuration; the operator's `LAGO_REST_URL` includes `/api/v1`. Do not confuse those two settings.
- Persist Caddy certificate/account data. Verify DNS and certificate issuance before declaring HTTPS complete; do not disable TLS verification to pass tests.
- Create the initial organization in a controlled setup window and disable public registration using the pinned release's supported setting. Verify the change. Use strong credentials and synthetic billing data.
- Record any SMTP or password-recovery limitation. Do not claim email delivery works without a configured and tested transport.

## 8. Validation and Definition of Done

Capture command, timestamp, expected outcome, actual result, and interpretation. Redact secrets, tokens, identifying data, and sensitive logs before storing public evidence.

| Test | Required evidence |
| --- | --- |
| Terraform | Format/validation pass; reviewed plan; expected apply; subsequent no-unexpected-change plan; backend configured and state present in the intended key. |
| SSM | Interactive terminal and Ansible task work without SSH ingress or a key pair. |
| Exposure | HTTPS entry points work; dependency ports are not publicly published or reachable; public signup is disabled after setup. |
| Persistence | Existing application data survives container recreation and host reboot. No destructive volume deletion in this test. |
| Configuration | Second Ansible run is idempotent apart from documented exceptions. |
| Application | Frontend login and authenticated API request succeed; migration status is verified. |
| Metering | Active customer/subscription, one uniquely identified event, and usage increase matching the configured one-cent standard charge. |
| Billing/PDF | A deliberate, documented billing action produces the expected invoice and PDF; usage accrual alone is not invoice validation. |
| Failure/recovery | Bounded Redis outage and recovery, with API and worker/scheduler observations captured separately. |
| Monitoring | Relevant logs arrive; host health, disk/memory visibility, and worker failures can be inspected. Test any configured alert delivery. |
| Backup/restore | Data and required keys/configuration are recoverable from a protected backup; demonstrate a restore without overwriting the only good copy. |
| Cost/cleanup | Actual resources and runtime recorded; teardown/stop procedure documented; residual charges identified. |

Use the established synthetic identifiers where appropriate: metric `api_calls` with count aggregation, plan `starter_api_plan`, customer `acme_ltd`, and subscription `acme_ltd_starter`. Verify existing entities before creating duplicates. Do not terminate the reference subscription merely to force an invoice screenshot; use a separate test fixture if the scenario requires termination.

For repeated metering tests, use unique transaction IDs and compare before/after usage within the active subscription's billing period. Do not assume lifetime usage remains at one event. Test duplicate-event handling separately. A terminated subscription is not a valid current-usage fixture.

Before failure tests, capture a healthy baseline and ensure backups and a recovery procedure exist. Restore the dependency promptly and verify recovery. The M1 observation was that current usage could return HTTP 200 while scheduler/Redis errors occurred. Do not generalize that every API endpoint stays available, or claim queued-event recovery/data integrity without testing them.

## 9. Cost and Lifecycle Discipline

The target is USD 30/month, not a technical hard cap. The user deferred budget-alert setup to focus on deployment; do not report alerts as configured or repeatedly block routine development on them. Before cost-bearing applies, still show a current Ohio estimate and obtain approval.

Estimate compute runtime, EBS root/data/backup storage, public IPv4/EIP allocation, DNS hosted-zone/domain costs, CloudWatch ingestion/retention, S3 storage/requests, and any applicable CPU-credit or transfer costs. Do not assume free-tier credits or unused account allowances.

Calculate an operating-hours allowance from the remaining budget after retained-resource costs and a contingency. Check existing account spending privately. If the measured workload cannot fit, propose shorter sessions or a revised scope, not a promise that it will cost less than USD 30.

Stop compute between agreed sessions where practical. Explain that stopping EC2 does not remove storage, DNS, logs, or allocated EIP charges. Deleting or releasing an EIP affects DNS and access; do it only as part of a planned teardown.

Define teardown and retention for each resource. Back up data before destruction, review `terraform plan -destroy`, and obtain explicit approval. Retain bootstrap state infrastructure unless separately authorized for removal. Retaining resources outside Terraform state requires a documented ownership and recovery plan, not an accidental orphan.

Before checkpoint closure, inspect for unexpected instances, EIPs, volumes, buckets, logs, and other retained resources. Document remaining charges. Revisit AWS Budgets and Cost Anomaly Detection as follow-up controls, without describing them as a guaranteed spending cap.

## 10. Engineering and Publication Deliverables

- A README with prerequisites, supported versions, architecture, deployment/configuration commands, validation, known limitations, and cleanup instructions.
- ADRs for incremental single-AZ networking, module boundaries, SSM-only administration, state separation, host-local data, HTTPS entry point, instance/storage sizing, and approved deviations.
- A current communication sketch showing AWS boundary, subnet/AZ, host/container responsibilities, admin path, data paths, and storage. Mark future components as planned, not deployed.
- Sanitized configuration examples and meaningful Git commits corresponding to complete checkpoints.
- Runbooks for deploy, inspect logs, restart/reboot, backup/restore, failure testing, stopping the lab, and teardown.
- Evidence-backed article notes: requirement, decision, implementation, observed result, trade-off, and what changes next.

Professional content should show reasoning and verified behavior, not the number of services used. Do not claim production readiness, high availability, zero downtime, complete security, or guaranteed Community Builder acceptance. Clearly distinguish the multi-AZ future address plan from the actual single-AZ workload.

## 11. Next Action

The networking module, remaining Terraform foundation, and Ansible host
configuration are implemented and were deployed and verified. Application
SecureStrings and frontend/API DNS records were created on 2026-10-16. EC2 was
last confirmed stopped that day; Lago and HTTPS have not been deployed.

The 2026-10-18 source corrections add fatal DNS preflight handling, an approved
maintenance/database-dump sequence before upgrade migrations, retry-safe Caddy
configuration reconciliation, and separate filesystem metrics. Local regression
checks passed; these changes have not been applied or verified on the AWS host.

Keep deployment paused until a new bounded session is approved. Before public
exposure, complete the Lago release/security review and document the Gotenberg
image deviation. Then review a fresh Terraform plan to refresh inventory for
the metric correction, update the host agent through Ansible, and deploy Lago.
Verify HTTPS, login, authenticated API requests, workers, and actual invoice/PDF
generation, followed by application repeatability and reboot persistence.
Off-host backups, restore testing, and alerting remain separate pending work;
local pre-migration database dumps do not complete backup/restore validation.

Keep the existing module structure and bootstrap. Do not resume the historical
flat-network walkthrough or apply an obsolete saved plan. This status update is
based on source changes and prior evidence, not a fresh live AWS audit.

## 12. Technical References

Consult the versions applicable to this deployment rather than copying the latest documentation into a pinned configuration blindly.

- [Terraform S3 backend and native locking](https://developer.hashicorp.com/terraform/language/backend/s3)
- [Terraform module refactoring and moved blocks](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring)
- [AWS internet gateway and public-subnet routing](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html)
- [AWS Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- [Ansible SSM connection requirements and transfer-storage cautions](https://docs.ansible.com/projects/ansible/latest/collections/amazon/aws/aws_ssm_connection.html)
- [Lago self-hosted Docker configuration](https://getlago.com/docs/guide/lago-self-hosted/docker)
- [AWS Pricing Calculator](https://calculator.aws/)

Reference baseline: Lago AWS Deployment Guide v1.1, revised sections 2-8. User-approved decisions in this brief supersede conflicting guide proposals; later changes require an explicit rationale and an updated decision record.
