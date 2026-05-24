# EKS distribution (stub)

Placeholder for AWS Elastic Kubernetes Service. Not implemented yet.

## Recommended approach when this lands

1. Provision the cluster with Terraform (`terraform-aws-modules/eks/aws` is the
   reference module). Outputs a kubeconfig.
2. Implement `bootstrap.sh` as a thin wrapper around `terraform apply` +
   `aws eks update-kubeconfig --name <cluster> --kubeconfig "${KUBECONFIG_PATH}"`.
3. Implement `teardown.sh` as `terraform destroy`.
4. Pick a **multicast-friendly** path. EKS does not support IPv6 multicast on
   the primary VPC CNI; options:
   - `EGRESS_MODE=unicast-list` on the proxy (Phase 7 in the upstream roadmap)
     — required for EKS production. Does not need Multus.
   - Run a self-hosted overlay (e.g. WeaveNet was an option, now deprecated).
5. Skip Multus on EKS — there is no dedicated fabric NIC. The `platform/multus/`
   release should be conditional (`enabled: false` in the EKS environment).

## Open questions when implementation begins

- IPv6 dual-stack support level on the chosen EKS version.
- Use of EKS Auto Mode vs. self-managed node groups.
- Secret backend: AWS Secrets Manager via ESO (already a stub-ready provider in
  `platform/secrets/cluster-secret-store.example.yaml`).

## Contract reference

See [`../common.md`](../common.md) for the distribution contract every
implementation must satisfy.
