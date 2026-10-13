# Ansible Transfer Storage

Creates a dedicated S3 bucket for `amazon.aws.aws_ssm` module transfers. Inputs
are `name_prefix`, `expiration_days` (default one day), and tags. Outputs are
`bucket_name` and `bucket_arn`. Provider/backend configuration stays in dev.

The bucket uses SSE-S3, blocked public access, enforced bucket ownership, and a
TLS-only deny policy for non-service principals. Versioning is explicitly
suspended. Expiration and multipart/noncurrent cleanup limit artifacts from
interrupted runs; lifecycle deletion is asynchronous, not immediate erasure.
Successful Ansible runs must delete their transfer objects promptly.

Never use the versioned Terraform state bucket for these transfers. The plugin
uses controller-signed URLs, so the host needs connectivity to S3 without
transfer IAM permissions. Dev exports a review-only controller policy scoped
to the host's instance-ID prefix; it does not attach it to an operator.
See [Ansible's connection requirements and storage cautions](https://docs.ansible.com/projects/ansible/latest/collections/amazon/aws/aws_ssm_connection.html).

`force_destroy = false` refuses blind deletion of leftover objects. Review and
clean transfer payloads before an approved teardown. This bucket is ephemeral
operational storage, not a backup or application object-store destination.

Tests: `terraform -chdir=terraform/environments/dev test -filter=tests/deployment_support.tftest.hcl`.
Applies in this test use a mock provider only.
