# ADR 003: Incremental Networking and Module Boundaries

Status: Accepted for implementation; apply pending
Date: 2026-10-11

## Requirement

Provide one DNS-enabled VPC and one explicitly routed public subnet in Ohio,
with interfaces that can support later subnet additions. Avoid adding the
future two-AZ topology to the initial lab.

## Decision

`terraform/modules/networking` owns the VPC, subnet map, internet gateway,
public route table/default route, subnet associations, and empty unused default
security group. `terraform/environments/dev` owns provider/backend settings,
dev allocations/tags, available-AZ validation, and useful module outputs.

Use `10.42.0.0/16` and `public_a = 10.42.1.0/24` in `us-east-2a`.
The address review found no overlap with current Ohio VPC primary/associated
CIDRs. Future connected on-premises/VPN/peer networks must still be checked.
Ohio's `us-east-2a` is available in the inspected account; AZ letters are
account-specific mappings, not universal physical-zone identifiers.

Disable automatic subnet public-IP assignment. Compute will attach an EIP
and a dedicated application security group; no SSH ingress will be added.
Reserve `10.42.2.0/24` for a later public subnet without provisioning it.
Remaining ranges are unallocated; private workload sizing is deferred.

## Alternatives and trade-off

A flat root is shorter initially but mixes environment configuration and the
network contract. A module with stable map keys makes ownership and future
additions explicit. This does not eliminate replacements when immutable
properties change.

Two public and two private subnets across two AZs would add unused topology.
The accepted single-AZ network keeps the initial scope small, with a documented
availability limitation. No NAT gateway, load balancer, endpoint, EIP, or
compute resource belongs to this checkpoint.

The default security group is intentionally unusable. This prevents accidental
use of AWS's permissive default rules; it does not replace the host's security
group or correct Docker port publishing.

## Revisit when

A second host/AZ, peering/VPN, private placement, or Kubernetes address demand
is approved. Extend routing semantics deliberately and inspect migration plans
before applying changes to existing subnet identities.
