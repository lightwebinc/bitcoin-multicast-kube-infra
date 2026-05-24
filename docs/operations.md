# Operations

## Day-2 procedures

### Upgrade k0s

```bash
# Edit distributions/k0s/k0sctl.yaml to bump spec.k0s.version
make bootstrap        # k0sctl performs a rolling upgrade
make verify
```

### Rolling chart upgrade

```bash
# Bump apps/environments/default.yaml chartVersions.*
make apps
```

Listener pods drain in `DRAIN_TIMEOUT` (chart value, default 5 s) so in-flight
NACK cycles complete before the socket closes.

### Drain a node

```bash
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
# perform host work
kubectl uncordon <node>
```

The listener DaemonSet pod restarts automatically when the node uncordons; the
NACK/retransmit pipeline covers the gap.

### Scale-out (1 ctrl + 2 workers)

See [`quickstart-k0s.md`](quickstart-k0s.md) §4.

## Metrics

External Prometheus scrapes the **primary CNI** pod IPs. The macvlan
secondary (`net1`) carries multicast data only — never scrape it.

```yaml
# prometheus.yml — Kubernetes SD against the k0s API
scrape_configs:
  - job_name: bitcoin-mcast
    kubernetes_sd_configs:
      - role: pod
        api_server: https://k0s.example.lan:6443
        bearer_token_file: /etc/prometheus/k0s.token
        tls_config:
          ca_file: /etc/prometheus/k0s.ca.crt
    relabel_configs:
      - source_labels: [__meta_kubernetes_namespace]
        action: keep
        regex: bitcoin-mcast
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: "true"
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        target_label: __address__
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
```

The simpler `static_configs` route via Service ClusterIPs also works:

```yaml
  - job_name: bitcoin-mcast-proxy
    static_configs:
      - targets: ['proxy.bitcoin-mcast.svc.cluster.local:9100']
  - job_name: bitcoin-mcast-listener
    static_configs:
      - targets: ['listener.bitcoin-mcast.svc.cluster.local:9100']
```

The charts ship `ServiceMonitor` templates (gated by
`metrics.serviceMonitor.enabled=false` by default) for clusters running
`kube-prometheus-stack`. This repo does **not** install Prometheus/Grafana.

## Backups

State is minimal:

| Component | State | Backup needed? |
|---|---|---|
| proxy             | none (stateless) | no |
| listener          | per-pod gap tracker (in-memory) | no |
| retry-endpoint    | freecache (in-memory) or external Redis | external Redis only |
| subtx-generator   | none | no |

Persist the **kubeconfig** and **operator-supplied** `hosts.env` /
`*.yaml` outside Git (see [`secrets.md`](secrets.md)).
