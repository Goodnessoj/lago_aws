# Single Ubuntu Host

Creates the host security group/rules, EC2 instance, explicit EIP/association,
and a separate encrypted gp3 data volume/attachment. It accepts the VPC/subnet,
instance profile, pinned AMI/type, volume sizes, IPv4 application audiences,
HTTP toggle, name prefix, and tags. Outputs expose instance/EIP/group/volume
identifiers for configuration and inspection.

The AMI lookup verifies an explicit ID against Canonical's Ubuntu 24.04 amd64
catalogue; it never selects a moving latest release. Architecture and subnet
VPC/public-IP controls are checked with preconditions. The module currently
supports T3/T3a instances with at least 4 GiB; dev proposes `t3a.large` with
2 vCPUs and 8 GiB. This is a lab sizing proposal, not a measured capacity claim.

IMDSv2 is required with hop limit one. No key pair is selected. Only ports 443
and optional 80 can be allowed through explicit CIDR rules. Egress permits
dependencies such as DNS, HTTP package sources, registries, and AWS APIs;
restrict it later only after dependency verification. Docker publishing must
also keep internal service ports private.

CPU credits are standard, so sustained CPU use can throttle after credits are
exhausted rather than incur unlimited-mode surplus charges. EC2 API termination
protection is enabled. Reviewed changes must disable it before deliberate host
removal; stopping the host remains possible.

The 16 GiB root volume is deleted with the instance. The 30 GiB data volume is
separately managed, not an instance-owned block device, and has `prevent_destroy`.
Host replacement retains it in Terraform. Attachment detaches stop the instance
first and never force detach. Nitro device names can differ from `/dev/sdf`;
Ansible must identify the disk by volume ID, initialize only a blank disk, mount
it at `/srv/lago-data`, and gate Docker/application startup on that mount.

User data installs/starts the SSM agent and management dependencies only.
Retries allow EIP/network readiness. It contains no secrets and does not install
Docker, format storage, or deploy Lago. Changing user data can replace the host.
Revisit CPU/memory/storage settings from measurements and review replacements
before applying. Persistence and destruction guards do not provide a backup.

Tests: `terraform -chdir=terraform/environments/dev test -filter=tests/ec2.tftest.hcl`.
The mock suite checks metadata, ports, encrypted storage, restricted audiences,
and incompatible subnet/architecture rejection.
