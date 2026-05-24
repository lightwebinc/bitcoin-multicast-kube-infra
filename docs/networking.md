# Networking

## Two-layer model

| Layer | Carries | Implementation |
|---|---|---|
| Primary CNI         | control + metrics + NACK/ACK + beacons (over IPv6 unicast) | Calico / Cilium / kube-router |
| Multus secondary `net1` | IPv6 multicast frame data plane | macvlan over the dedicated fabric NIC |

Pod annotation:

```yaml
metadata:
  annotations:
    k8s.v1.cni.cncf.io/networks: |
      [{ "name": "mcast-fabric", "interface": "net1",
         "ips": ["fd20::21/64"] }]
```

The chart's `networking.mode: multus` value renders this annotation
automatically; chart-side env (`MULTICAST_IF=net1`) is wired in lockstep.

## CNI choices

```bash
make platform CNI=calico       # default; Calico via tigera-operator
make platform CNI=cilium       # eBPF dataplane, native BGP control plane
make platform CNI=kube-router  # k0s-bundled; no Helm install
```

For BGP-aware deployments (peering pods/Service CIDRs into a fabric router):

- **Calico**: enable `bgp` in `platform/environments/default.yaml`, then apply
  `BGPPeer` CRs separately. Calico's BGP runs on the **primary CNI** NIC, not
  the multicast NIC.
- **Cilium**: set `bgp.enabled=true` and apply `CiliumBGPPeeringPolicy` CRs.

The dedicated multicast NIC is reserved exclusively for the multicast fabric
data plane. Do not run BGP over it.

## NetworkAttachmentDefinitions (NADs)

Templates live under `platform/nads/`. `scripts/platform-apply.sh` reads the
`NADS` env var to decide which to apply (default `mcast-fabric` only). Add
others on the command line:

```bash
NADS=mcast-fabric,bgp-transit,bgp-ibgp \
  BGP_TRANSIT_IFACE=enp6s0 BGP_IBGP_IFACE=enp7s0 \
  scripts/platform-apply.sh
```

## Kernel sysctls

Each k0s worker that joins multicast groups needs:

```
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.<fabric_iface>.disable_ipv6 = 0
net.ipv6.conf.all.force_mld_version = 2
```

`distributions/k0s/bootstrap.sh` applies these via SSH and persists them under
`/etc/sysctl.d/80-bitcoin-mcast.conf`.

## NACK source-address pitfall

The retry endpoint must bind its NACK socket to the **same** IPv6 the listener
addresses it by, otherwise SLAAC source-address selection causes ACKs to be
silently dropped (see the upstream
[`bitcoin-retry-endpoint` README](https://github.com/lightwebinc/bitcoin-retry-endpoint)).
The chart pattern enforced by `apps/helmfile.yaml` sets `config.nackAddr`
explicitly per release — do not leave it empty.

## Cloud-friendly fallback (Phase 7)

When `EGRESS_MODE=unicast-list` lands in the proxy, the entire stack can run
on a standard CNI (no Multus, no `hostNetwork`). The `apps/helmfile.yaml`
setting `networkingMode: unicast` will switch the rendered chart values; the
platform layer can then skip the Multus and NADs releases on EKS.
