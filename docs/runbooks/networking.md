# Review, Provision, and Inspect Networking

Run commands from the repository root. Confirm the AWS account privately,
check address overlaps, and verify that `us-east-2a` is available before apply.

```bash
terraform -chdir=terraform/environments/dev init -input=false -lockfile=readonly
terraform -chdir=terraform/environments/dev validate -no-color
terraform -chdir=terraform/environments/dev plan -input=false -out=networking.tfplan
terraform -chdir=terraform/environments/dev show -no-color networking.tfplan
```

The initial plan should contain seven additions: VPC, empty default security
group management, internet gateway, public subnet, route table, internet route,
and subnet association. There should be no changes or deletions. Review each
action rather than using the count alone as approval.

The default security group is adopted from the newly created VPC and stripped
of rules; Terraform's create action does not mean a second group is created.
See the [pinned AWS provider resource contract](https://github.com/hashicorp/terraform-provider-aws/blob/v6.67.0/website/docs/r/default_security_group.html.markdown).

This checkpoint adds no EC2, EBS, EIP, NAT, load balancer, or billable endpoint.
Core VPC components have no additional hourly charge; S3 state storage and
requests still have their normal costs. Later compute/public-IP/storage costs
must be estimated separately. See [Amazon VPC FAQs](https://aws.amazon.com/vpc/faqs/)
and [VPC pricing](https://aws.amazon.com/vpc/pricing/).

After approval of the exact saved plan:

```bash
terraform -chdir=terraform/environments/dev apply networking.tfplan
terraform -chdir=terraform/environments/dev state list
terraform -chdir=terraform/environments/dev output
terraform -chdir=terraform/environments/dev plan -input=false -detailed-exitcode
```

The final command should return 0 with no changes. Exit 2 means changes need
review; exit 1 means the check failed. Never automatically apply a drift plan.

Using the returned VPC/subnet IDs, inspect AWS for:

- VPC CIDR and enabled `enableDnsSupport`/`enableDnsHostnames` attributes.
- `public_a` CIDR/AZ and `MapPublicIpOnLaunch = false`.
- Internet gateway attached to the expected VPC.
- Explicit subnet route-table association and active `0.0.0.0/0` route to the gateway.
- No ingress or egress rules in the unused default security group.
- Dev state present at the configured S3 key and no lingering lock after completion.

Record sanitized command/results with timestamps. No host exists at this stage,
so SSM or public-application reachability cannot yet be declared complete.

Do not destroy networking while compute or persistent resources depend on it.
During approved teardown, review a destroy plan and retain the separate
bootstrap state bucket. Future subnet additions remain documentation/tests
until explicitly needed; never deploy them just to test the interface.
