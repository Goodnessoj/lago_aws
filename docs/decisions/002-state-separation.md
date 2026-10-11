# ADR 002: Separate Bootstrap and Environment State

Status: Accepted
Date: 2026-10-11

## Requirement and decision

Reuse the existing Ohio S3 state bucket. Keep bootstrap state local for now,
and keep dev state at `environments/dev/terraform.tfstate` with encryption and
native S3 locking. Commit provider lock files in both roots.

Preserve the existing bucket and add a TLS-only policy for non-service
principals. Do not recreate the bucket to harden it. Protect bootstrap state
with restricted local checkpoint backups; off-device protection remains an
open requirement.

## Alternatives and trade-off

DynamoDB locking adds a separate service and conflicts with the agreed native
S3 locking choice. Putting bootstrap state in the bucket it manages introduces
a recovery dependency; that migration needs its own reviewed decision.
Local bootstrap state avoids that dependency but requires deliberate backup
and a single operator until a shared recovery workflow is agreed.

## Revisit when

Multiple operators need bootstrap access, the workstation recovery plan
changes, or the bootstrap backend is deliberately migrated. The Ansible
transfer bucket remains separate from the versioned state bucket.
