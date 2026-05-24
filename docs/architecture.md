# Architecture

This repo deploys the four bitcoin multicast components onto a Kubernetes
cluster while staying **distribution-agnostic**. The first concrete distribution
is k0s; AWS EKS and others can be added without touching the platform or app
layers.

## Three layers

```
distributions/<dist>/    bring up a healthy cluster, write KUBECONFIG
        |
        v
platform/                CNI + Multus + ESO + namespace + NADs
        |
        v
apps/                    bitcoin charts via Helmfile
```

Each layer depends only on the previous one's output (a healthy cluster, a
healthy platform). No layer is coupled to a specific distribution.

## Distribution contract

See [`../distributions/common.md`](../distributions/common.md). Summary:

- `bootstrap.sh` is idempotent and writes a kubeconfig to `KUBECONFIG_PATH`.
- `teardown.sh` is idempotent and reverses the bootstrap.
- `*.example.*` templates are committed; operator copies are `.gitignored`.
- The distribution is responsible for kernel sysctls (multicast prerequisites).

## Platform layer

`platform/helmfile.yaml` composes the cluster-level addons:

- **CNI** — Calico (default), Cilium, or k0s-bundled kube-router. Selected by
  the `CNI` environment variable.
- **Multus** — installs the multi-network DaemonSet that lets pods request a
  secondary macvlan interface on the dedicated multicast NIC.
- **External Secrets Operator** — installed but un-configured. The
  `ClusterSecretStore` stub is shipped without a provider; operators choose
  Vault, AWS Secrets Manager, etc.
- **NADs** — `mcast-fabric` is applied by default. `bgp-transit` and
  `bgp-ibgp` are available for BGP scenarios but not applied by default.

## Application layer

`apps/helmfile.yaml` installs the four bitcoin charts (`bitcoin-shard-proxy`,
`bitcoin-shard-listener`, `bitcoin-retry-endpoint`, `bitcoin-subtx-generator`)
from OCI. Per-node retry-endpoint releases are generated from the values list,
matching `composition-spec.md` Option A in the upstream docs.

## Reference topology

The default reference is **1 controller with worker role enabled**. To grow to
**1 controller + 2 workers (one integrated)**, add two `role: worker` entries
to `distributions/k0s/k0sctl.yaml` and re-run `make bootstrap`. The platform
and app layers do not change — Helmfile re-renders against the new node count
and the listener DaemonSet automatically schedules onto the new nodes.

## Cross-references

- [`bitcoin-multicast/containerization/`](https://github.com/lightwebinc/bitcoin-multicast/tree/main/containerization) — design rationale.
- [`bitcoin-multicast/containerization/k0s-deployment.md`](https://github.com/lightwebinc/bitcoin-multicast/blob/main/containerization/k0s-deployment.md) — the reference architecture this repo implements.
- [`bitcoin-multicast/containerization/composition-spec.md`](https://github.com/lightwebinc/bitcoin-multicast/blob/main/containerization/composition-spec.md) — operator wiring patterns.
