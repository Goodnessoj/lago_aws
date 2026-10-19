# Host Observability

Creates named system/bootstrap/application log groups and exports the basic
host metrics and logging configuration consumed by Ansible. Inputs are a stable
log-group map, bounded retention, custom metric namespace, data mount path, and
tags. Outputs expose log groups and non-secret agent/Docker configuration.

Seven-day retention is the dev default. Host agent metrics use a custom
namespace and an InstanceId dimension. Original disk metrics retain their
filesystem paths so `/` and `/srv/lago-data` can be monitored independently;
there is no instance-wide disk rollup. The agent configuration collects
OS/bootstrap files, while Docker's `awslogs` driver sends every container to its own named
stream in the application group. Local dual-log caching is bounded. Nonblocking
buffers can drop logs under backpressure, so this is not an audit-log guarantee.
See [agent configuration](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-Configuration-File-Details.html),
[Docker CloudWatch logging](https://docs.docker.com/engine/logging/drivers/awslogs/),
and [local dual logging](https://docs.docker.com/engine/logging/dual-logging/).

Terraform creates resources and exports settings; Ansible must install/configure
the agent, Docker, data mount, and Compose logging. Agent metrics remain missing
until that work is complete. Missing data is not treated as a healthy signal.
Metrics publication and container logging use the host profile without putting
AWS keys in containers or host environment files.

The per-filesystem correction is not yet applied to the deployed host. A
reviewed Terraform apply must refresh the generated Ansible inventory, then
the host configuration playbook must update the agent. Verify separate `path`
dimensions for `/` and `/srv/lago-data` in CloudWatch before using them for
capacity decisions. Existing historical rolled-up series may remain visible.

Alarms, thresholds, and notification destinations are deferred to a later
checkpoint, after Lago is deployed and its normal resource usage is measured.
This stage provides troubleshooting signals, not tested alerting or proof of
application/worker health.

Log ARN outputs derive canonical ARNs from managed group names so the instance
policy is explicit in the plan and avoids a module-wide host/logging dependency
cycle. Resource ownership remains with the log groups.

Tests: `terraform -chdir=terraform/environments/dev test -filter=tests/observability.tftest.hcl`.
The mock suite verifies retention, basic metric dimensions/paths, log-group
wiring, and namespace validation; the integration test checks Docker settings
and generated Ansible inventory.
