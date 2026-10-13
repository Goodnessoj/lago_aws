# Host Observability

Creates named system/bootstrap/application log groups and CPU/status/CPU-credit/
memory/disk alarms. Inputs are instance ID, name prefix, a stable log-group map,
bounded retention, custom metric namespace, thresholds, existing SNS actions,
data mount path, and tags. Outputs expose groups, alarms, non-secret agent/Docker
configuration, and whether notification actions were supplied.

Seven-day retention is the dev default. Host agent metrics use the same custom
namespace and InstanceId aggregation as the memory/disk alarms. Disk originals
are suppressed to avoid unnecessary metric series; the maximum statistic
observes filesystem utilization. The agent configuration collects OS/bootstrap
files, while Docker's `awslogs` driver sends every container to its own named
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

No SNS destination is assumed or provisioned. With the default empty actions,
alarms are inspectable but do not send notifications. Supplying a topic enables
alarm/recovery actions; subscription confirmation and delivery testing remain
required. These host alarms do not prove application/worker health. Add service
alarms only after verifying the pinned application's signals and noise levels.

Log ARN outputs derive canonical ARNs from managed group names so the instance
policy is explicit in the plan and avoids a module-wide host/logging dependency
cycle. Resource ownership remains with the log groups.

Tests: `terraform -chdir=terraform/environments/dev test -filter=tests/observability.tftest.hcl`.
The mock suite verifies retention, agent/alarm dimensions, missing-data behavior,
and explicit notification actions; the integration test checks Docker settings.
