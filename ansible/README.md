# Ansible

Ansible will configure the single Lago EC2 host over SSM. The project uses a
Terraform-generated YAML inventory, standard commands, and playbooks/roles.
Terraform creates the infrastructure and inventory; Ansible manages the host
and application after provisioning.

## Controller setup

Run commands from the repository root on Ubuntu / WSL with Python 3.12.
The existing project-local environment is already installed. For a fresh setup:

```bash
python3 -m venv .local/ansible-venv
source .local/ansible-venv/bin/activate
python -m pip install -r ansible/requirements.txt
ansible-galaxy collection install -r ansible/requirements.yml -p .local/ansible/collections
```

The requirements files pin Ansible core 2.21.5, boto3/botocore 1.43.112, and
amazon.aws 11.5.0, ansible.posix 2.1.0, and community.general 12.6.2. Pip manages
supporting Python dependencies. Python is Ansible's
runtime; this repository does not need custom Python controller code.

The Session Manager plugin is also required. Its existing binary is extracted
under `.local/session-manager-plugin/` and linked into the environment's bin
directory. For a fresh Linux x86_64 setup, use the official pinned package:

```bash
mkdir -p .local/downloads
curl -fsSL --retry 3 \
  https://s3.amazonaws.com/session-manager-downloads/plugin/1.2.896.0/ubuntu_64bit/session-manager-plugin.deb \
  -o .local/downloads/session-manager-plugin.deb
echo '53f51fcc67314a4bf85888a38a3967cd41f8d0f28a60a9469a63acf935ba713e  .local/downloads/session-manager-plugin.deb' | sha256sum -c -
dpkg-deb -x .local/downloads/session-manager-plugin.deb .local/session-manager-plugin
ln -sfn ../../session-manager-plugin/usr/local/sessionmanagerplugin/bin/session-manager-plugin \
  .local/ansible-venv/bin/session-manager-plugin
```

See [AWS's plugin installation guidance](https://docs.aws.amazon.com/systems-manager/latest/userguide/install-plugin-debian-and-ubuntu.html).
Installed dependencies and downloads stay outside Git.

For each terminal session:

```bash
source .local/ansible-venv/bin/activate
ansible --version
session-manager-plugin --version
```

The root `ansible.cfg` selects the inventory, collection location, Python
interpreter, role path, and local working directory. Use the operator's existing
AWS credential chain. Do not add access keys or application secrets to inventory.

## Inventory

Terraform writes `ansible/inventories/dev/hosts.yml` during a successful dev
apply using the current instance ID, transfer bucket, and application-volume
settings. The file has mode 0600 and is ignored by Git. No manual copying or
custom generator is needed. Only non-secret settings belong in this resource;
its content is also stored in Terraform state.

After the reviewed plan is approved and applied, inspect the inventory:

```bash
terraform -chdir=terraform/environments/dev output ansible_inventory_file
ansible-inventory --graph
```

Ansible reads the generated file through `ansible.cfg`. Terraform refreshes it
when those values change during apply; editing the generated file manually
creates drift. The sanitized example documents the shape, not a deployed host.

The file is created on the machine running Terraform. On a different controller,
review a fresh plan and apply to recreate the missing local file. Never apply an
old saved plan after configuration changes. Consider native AWS dynamic inventory
when managing multiple hosts. Inventory generation does not execute Ansible.

## Verify access

```bash
ansible-inventory --graph
ansible-playbook ansible/playbooks/verify-access.yml --syntax-check
ansible-playbook ansible/playbooks/verify-access.yml
```

The first two commands parse inventory/playbooks locally. The final command
contacts the deployed host: it checks settings, waits for SSM, runs Ansible
ping, and verifies root privilege. Placeholder instance/volume values are
rejected before connecting.

The live access check passed on 2026-10-15: five successful tasks, zero changes,
zero failed or unreachable hosts. Temporary transfer objects were cleaned up.
The host is now stopped; start it for an agreed configuration session before
running live playbooks again.

The controller needs the reviewed SSM/session-document and transfer-S3
permissions. Terraform's transfer policy output is not attached automatically.
The host uses presigned S3 URLs rather than transfer credentials. See
[the SSM connection requirements](https://docs.ansible.com/projects/ansible/latest/collections/amazon/aws/aws_ssm_connection.html).

## Host Configuration

Verified on 2026-10-15: host roles applied, reboot/storage/service recovery
passed, and both final configuration passes were unchanged. The repeatability
workflow stopped EC2 afterward; AWS confirmed it remained stopped on 2026-10-16.
All temporary transfer objects were cleaned up. This does not establish Lago
availability, application recovery, or alarm notification delivery.

`configure.yml` verifies SSM access, gathers Ubuntu facts, then runs four roles:

- `base`: dependencies, EBS identity/signature checks, ext4 initialization of an
  explicitly approved blank disk, UUID mount and `/opt/lago` directory.
- `security`: unattended security updates without automatic reboots, disabled
  SSH service/socket, bounded journald and rsyslog rotation.
- `docker`: official signed apt repository, pinned Engine/containerd/Compose,
  separate data roots on EBS, mount-gated services and bounded awslogs settings.
- `cloudwatch`: versioned/checksummed agent package and the Terraform-defined
  metrics/log configuration. Alarm notification delivery is separate work.

No custom Python controller or installation shell scripts are used. The standard
filesystem/mount collections are pinned in `requirements.yml`. The disk role
rejects another volume, partitions, non-ext4 signatures, conflicting mounts and
existing fallback data. Existing ext4 is retained, never reformatted. Existing
Docker/containerd root-disk data requires deliberate migration; it is not moved
or deleted automatically.

Terraform inventory now carries the agent and Docker logging settings. Its raw
Jinja block protects Docker's Go-template log tag during Ansible rendering.
The local template test checks that the daemon receives the literal tag.

After reviewing the roles, inventory and selected disk, and starting the host
for an agreed bounded session, the first initialization uses:

```bash
ansible-playbook ansible/playbooks/configure.yml -e lago_initialize_data_volume=true
```

The flag authorizes formatting only when the disk passes all blank-disk checks.
Do not routinely supply it. Subsequent configuration and verification use:

```bash
ansible-playbook ansible/playbooks/configure.yml
ansible-playbook ansible/playbooks/verify-host.yml
ansible-playbook ansible/playbooks/smoke-test.yml
```

Review the second configuration recap for zero changes, then deliberately test
reboot recovery during an approved session:

```bash
ansible-playbook ansible/playbooks/reboot-host.yml
ansible-playbook ansible/playbooks/configure.yml
```

The reboot playbook verifies the mount/services first, writes a non-secret
persistence marker, reboots through SSM, then checks the marker and services.
It is an explicit operation, not part of normal configuration runs. It rearms a
temporary 45-minute stop timer after reboot for this lab. Stop compute after
verification; retained resources still cost money.

The separate smoke test runs the official amd64 hello-world image by digest,
publishes no ports, and removes its container afterward. The small cached image
and CloudWatch log stream remain. It intentionally reports a change and is not
part of configuration-idempotence testing. Verify its log stream in CloudWatch
before claiming container-log delivery.

Local checks do not contact or format a disk:

```bash
ansible-playbook ansible/tests/storage.yml
ansible-playbook ansible/tests/templates.yml
ansible-playbook ansible/playbooks/configure.yml --syntax-check
ansible-playbook ansible/playbooks/verify-host.yml --syntax-check
```

Storage tests use synthetic facts and rescue expected assertion failures. A
successful recap has zero failed tasks; the seven rescued rejections are
intentional. Template tests require the updated generated inventory but use a
local connection. First-boot `--check` is not a provisioning simulation: packages
and a filesystem needed by later probes do not yet exist. Use syntax/policy
tests before first apply and check mode only on an already configured host.

For a bounded repeatability session, `verify-repeatability.yml` verifies access,
arms a temporary 45-minute stop timer, then runs normal configuration twice.
It finally stops the existing EC2 instance from the controller using the
operator's AWS credentials. This is an operational stop, not provisioning.
The timer can legitimately add one change to the combined recap; inspect both
configuration passes separately for unexpected changes. This is a native
playbook, not a controller script. Start this workflow while the host is
available, or have it waiting for SSM before starting a stopped lab host:

```bash
ansible-playbook ansible/playbooks/verify-repeatability.yml
```

It waits up to five minutes for access. Do not leave EC2 running while awaiting
further execution approvals; confirm the workflow's final stopped state.

Runtime versions are pinned in the Docker/CloudWatch role defaults. Review
security advisories and test upgrades deliberately rather than keeping pins
forever. The CloudWatch package checksum was verified against AWS's detached
signature and documented signing-key fingerprint before selecting the pin;
see [AWS verification guidance](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/verify-CloudWatch-Agent-Package-Signature.html).

Docker's storage roots follow its
[daemon configuration guidance](https://docs.docker.com/engine/daemon/).
Only the later Lago Compose deployment may publish Caddy ports; Docker-published
ports can bypass host firewall rules. The AWS security group remains HTTP/HTTPS
only. No secrets, Lago services, DNS records, or HTTPS certificates are configured
by these host roles.

## Application Deployment

Implemented and offline-tested on 2026-10-16; not yet deployed. This is a
separate playbook and `lago` role, not an addition to routine host configuration.
It uses pinned `community.docker` 5.4.0 and its pinned inventory-filtering
dependency. Compose modules call Docker CLI; no custom Python scripts are used.

The local application settings are in ignored
`ansible/inventories/dev/application.yml`; the sanitized `.example` documents
their shape. Approved hostnames are `app.phoniex.site` and `api.phoniex.site`.
The initial organization name is `Lago Lab` unless reviewed otherwise.

Before live execution, review the target account, release/security assessment,
DNS plan, and bounded EC2 session. Both A records must resolve directly to the
current host EIP, with no conflicting AAAA records. DNS creation is not hidden
inside Ansible. The deploy preflight rejects missing or conflicting records.

Both records were created through Terraform on 2026-10-16 with TTL 300 and
verified against public and authoritative DNS. EC2 remains stopped. Live
deployment and certificate issuance are still separate, unverified steps.

Local validation:

```bash
ansible-playbook ansible/tests/application.yml
ansible-playbook ansible/tests/deployment.yml
ansible-playbook ansible/playbooks/create-secrets.yml --syntax-check
ansible-playbook ansible/playbooks/deploy.yml --syntax-check \
  -e @ansible/inventories/dev/application.yml
```

The template tests use synthetic values and the real Compose parser without
contacting AWS or Docker Engine. They do not prove application health.
The deployment tests run the real DNS preflight and maintenance/Caddy tasks
with isolated AWS, DNS, and Docker command doubles. They verify failure gates,
operation order, and interrupted retries; they do not exercise real container
shutdown, database recovery, or TLS issuance. The shell fixture under
`tests/fixtures/` is only an offline test double, not deployment tooling.

After explicit approval, create only missing SecureStrings from the controller:

```bash
ansible-playbook ansible/playbooks/create-secrets.yml \
  -e lago_create_missing_secrets=true
```

The default is to refuse execution before any AWS call. Once approved, the
playbook checks the operator account against Terraform and generates values
in memory. Creation uses `community.aws.ssm_parameter` from pinned collection
11.2.0 with `overwrite_value: never` and `decryption: false`. Existing values
are never rotated. RSA uses 3072 bits and a single-line base64 encoding. No
persistent controller secret files or Terraform secret values are created;
standard Ansible temporary-file handling still applies.

Verified on 2026-10-16: all seven parameters exist as Standard SecureStrings,
version 1, encrypted with `alias/aws/ssm`. The first successful playbook run
reported ok=8, changed=3 (six writes in one loop, RSA generation, RSA storage),
failed=0. The repeat run reported ok=6, changed=0, failed=0. Verification read
metadata only. Host-side retrieval and application use remain unverified.

With reviewed DNS in place and EC2 started for an agreed session:

```bash
ansible-playbook ansible/playbooks/deploy.yml \
  -e @ansible/inventories/dev/application.yml
```

The playbook validates DNS, verifies the host/data mount, then retrieves exactly
seven parameters using the EC2 instance role. It renders a root-owned 0600
`.env`, starts PostgreSQL/Redis/PDF, runs the upstream migration/organization
seed, and starts API/worker/scheduler/frontend/Caddy. The setup container is
removed afterward; only it receives the initial administrator password.
Public registration is disabled in both API and frontend from the start.

All images use immutable amd64 digests. Named database, Redis, shared upload,
and Caddy volumes inherit the verified EBS-backed Docker root. No dependency
ports or Docker socket are published. Caddy alone publishes TCP 80/443 and
blocks public metrics/Sidekiq/Karafka paths. SMTP is not configured or tested.

An initialization marker on the mounted data disk records the successful
configuration/environment fingerprint. Only a matching marker skips the job;
failed updates keep the old fingerprint so the next attempt retries migrations
even if the files are already written. Caddy has a separate applied-file
checksum checkpoint. The running process must acknowledge a reload before that
checkpoint advances; a failed/interrupted run retries unchanged files rather
than depending on a template-change notification. Live repeatability, reboot
behavior, authenticated requests and billing/PDF tests remain unverified.
Preserve all volumes and keys;
never use `down -v`. Changing Parameter Store encryption keys is not a supported
rotation procedure, and changing the initial password parameter does not reset
an existing Lago user's password.

Verification includes migration status, expected initial account, server-side
signup setting, public HTTPS, frontend API URL, and blocked operational routes:

```bash
ansible-playbook ansible/playbooks/verify-application.yml \
  -e @ansible/inventories/dev/application.yml
```

This does not yet prove login, authenticated API requests, metering, invoices,
backup/restore or notification delivery. Retrieve the initial password privately
through Parameter Store, never through chat or committed evidence. End the
agreed live session by stopping EC2 and verifying its state; unlike the host
repeatability playbook, `deploy.yml` does not automatically stop the instance.

### Updating an Existing Installation

The DNS/settings preflight uses `any_errors_fatal: true`: failure aborts later
plays before host verification or deployment. A configuration change requiring
migrations on an existing database also requires explicit downtime approval:

```bash
ansible-playbook ansible/playbooks/deploy.yml \
  -e @ansible/inventories/dev/application.yml \
  -e lago_allow_maintenance=true
```

Review the release and available disk space before this operation. The existing
database must be running the pinned image; PostgreSQL image upgrades require a
separate reviewed procedure. A missing database from an initialized deployment
is treated as a recovery problem, not a fresh installation.

The maintenance sequence is:

1. Stop Caddy/frontend to prevent new public work.
2. Stop the scheduler, API, and worker with a 120-second shutdown allowance.
3. Confirm writer containers are stopped and were not OOM-killed or terminated
   with exit code 137. A rejected shutdown requires investigation before retry.
4. Take a PostgreSQL custom-format dump using the existing container, check its
   archive catalog, and retain a nonempty mode-0600 file under
   `/srv/lago-data/upgrade-backups/pre-migration-*/database.dump`.
5. Start dependencies, run migrations, start the application, reconcile Caddy,
   and check for pending migrations before writing the initialization marker.
6. Run the existing account, registration, and public HTTPS checks.

Stopping traffic creates downtime; this is not a rolling upgrade. Once writers
are stopped, a subsequent failure before application startup leaves them
stopped. Migrations do not run when shutdown or dump checks fail. There is no
automatic rollback or attempt to restart old code against a potentially changed
schema. An unchanged completed
configuration skips maintenance and migrations. A first installation with no
database or application containers skips the maintenance/backup path.

These dumps are **local database upgrade safeguards**, not complete backups.
They do not capture Redis queues, uploaded files, secrets, or Caddy state and
cannot survive loss of the data volume. Catalog validation is not a restore
test. Off-host backups and a tested recovery procedure remain pending. Dumps
are retained without automatic pruning: review capacity and retention before
each update, preserve the required recovery points, and never commit dumps.

References: [Ansible fatal errors](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_error_handling.html#aborting-on-the-first-error-any-errors-fatal),
[PostgreSQL dumps](https://www.postgresql.org/docs/15/app-pgdump.html),
[Sidekiq shutdown](https://github.com/sidekiq/sidekiq/wiki/Deployment), and
[Caddy reload](https://caddyserver.com/docs/command-line#caddy-reload).
