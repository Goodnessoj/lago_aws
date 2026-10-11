# Terraform State and Plan Review

Bootstrap owns the existing state bucket and retains local state. Dev uses the
S3 backend in `terraform/environments/dev/backend.tf` with native S3 locking.
Never merge the two states or commit state, plan files, or secret inputs.

## Bootstrap recovery

The working bootstrap state is `terraform/bootstrap/terraform.tfstate`.
An access-controlled checkpoint backup is stored under
`.local/bootstrap-state-backups/`, excluded from Git. The directory has mode
`0700` and backup files have mode `0600`. This protects against accidental
local edits, but does not protect against losing this workstation. A separate
encrypted off-device backup is still required before closing M2A.

Before each bootstrap apply, create a uniquely named copy of the current state
in that directory with mode `0600`. Preserve the current state while inspecting
a backup. If recovery is needed, stop other Terraform operations, verify the
backup's lineage/serial and AWS resource identities privately, and review the
recovery with the operator before replacing state. Do not recreate the bucket
or import it into a new state to work around a missing file.

The bucket has versioning, SSE-S3 encryption, and all public-access blocks.
The additive hardening configuration denies non-TLS requests from non-service
principals. AWS service principals are excluded because their requests can
redact transport context. This policy does not grant additional access.
See [AWS S3 transport policy guidance](https://docs.aws.amazon.com/AmazonS3/latest/userguide/amazon-s3-policy-keys.html).

`prevent_destroy` is a Terraform safeguard while that resource configuration
exists; it is not an AWS deletion lock. Keep the bootstrap bucket during lab
teardown unless its removal is separately approved.

## Review and apply

Verify the account privately with `aws sts get-caller-identity` before applying.
Run from the repository root:

```bash
terraform fmt -check -recursive terraform
terraform -chdir=terraform/bootstrap init -input=false -lockfile=readonly
terraform -chdir=terraform/bootstrap validate
terraform -chdir=terraform/bootstrap plan -input=false -out=bootstrap.tfplan
terraform -chdir=terraform/bootstrap show -no-color bootstrap.tfplan
```

Review resource actions, policy scope, and the current identity. Approve the
exact saved plan before `terraform apply bootstrap.tfplan` in that root.
Regenerate the plan after any configuration change. Saved plans can contain
sensitive data; keep them private and outside Git.

For dev, use the corresponding commands with
`-chdir=terraform/environments/dev`. Native S3 locking requires permission to
read/write/delete the `.tflock` object, as well as the state object's required
permissions. Never force-unlock an active operation.

After an approved apply, validate the AWS controls and run a fresh plan to
check for unexpected changes. Verify that dev state exists at its configured
key only after dev resources have been applied; initialization alone does not
create populated state.
