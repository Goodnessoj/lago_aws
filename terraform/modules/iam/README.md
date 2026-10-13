# Host IAM

Creates an EC2-trusted role, an inline runtime policy, and an instance profile.
The profile waits for policy creation before it is passed to compute.

Inputs are `name_prefix`, exact `parameter_paths`, optional customer-managed
`parameter_kms_key_arns`, explicit `log_group_arns`, `metric_namespace`, and tags.
Outputs are `instance_profile_name`, `role_arn`, and non-secret parameter ARNs.
Terraform does not read or create secret values.

Session Manager uses AWS's minimal session-channel permissions rather than
attaching `AmazonSSMManagedInstanceCore`, whose parameter-read permissions are
not restricted to this workload. Channel operations require Resource `*`.
This role is not a Patch Manager or State Manager administration role.
See [minimal Session Manager role guidance](https://docs.aws.amazon.com/systems-manager/latest/userguide/getting-started-create-iam-instance-profile.html)
and [the managed policy](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonSSMManagedInstanceCore.html).

The host retrieves explicit SecureString parameters during Ansible host tasks
using its instance profile. Application containers receive a protected rendered
environment file and do not need IMDS access. No wildcard path/history reads
or transfer-bucket S3 permissions are granted. Custom parameter-key decrypt is
restricted to SSM, the supplied keys, and named parameter encryption contexts;
key policies must also authorize the role. The AWS-managed SSM key uses its
existing service key policy when no custom key is supplied.

CloudWatch log writes are restricted to the supplied groups; metric publication
is restricted to the custom namespace. Provisioning and controller permissions
remain separate. Revisit this policy when runtime dependencies change rather
than attaching general administrator/server policies.

Tests: `terraform -chdir=terraform/environments/dev test -filter=tests/iam.tftest.hcl`.
These tests mock AWS and validate scope, wildcard rejection, and KMS context.
