# Beyla — Kubernetes Application and Network Observability

![Chart Version](https://img.shields.io/badge/Chart-1.16.10-informational?style=flat-square)
![Chart Type](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![App Version](https://img.shields.io/badge/Beyla-3.25.0-informational?style=flat-square)

## 1. Overview

This repository deploys [Grafana Beyla](https://grafana.com/oss/beyla-ebpf/), an eBPF-based observability tool, into Kubernetes using Helm.

Beyla automatically observes supported application and network activity without requiring application code changes or traditional language-specific instrumentation in every application.

It provides telemetry that can be used to monitor application behavior, investigate performance problems, and understand communication between services.

This deployment is configured to collect:

- Application metrics.
- HTTP application metrics.
- Application process metrics.
- Application service graph metrics.
- Application span metrics.
- Network metrics.
- Kubernetes metadata.
- Distributed traces exported through OpenTelemetry Protocol (OTLP).

Beyla is part of the wider monitoring platform, which uses Prometheus and Thanos for metrics, Ceph S3 for long-term metrics storage, and Grafana for visualization. The configured trace-export endpoint is `IP:4317`.

> **Important:** The trace-export endpoint must be backed by a compatible OTLP gRPC receiver. Confirm which collector or tracing component owns this address before deployment.

---

## 2. Repository Information

| Property | Value |
|---|---|
| Repository | `beyla` |
| Deployment method | Helm |
| Helm chart version | `1.16.10` |
| Application version | `3.25.0` |
| Chart type | Application |
| Default Beyla image repository | `grafana/beyla` |
| Default metrics port | `9090` |
| Default metrics path | `/metrics` |
| Trace export protocol | OTLP gRPC |
| Trace export endpoint | `IP:4317` |
| Kubernetes deployment | DaemonSet, when enabled |
| Configuration source | Helm values |

### Official resources

- **Homepage:** [Grafana Beyla](https://grafana.com/oss/beyla-ebpf/)
- **Source code:** [grafana/beyla](https://github.com/grafana/beyla)
- **Helm chart documentation:** [Grafana Beyla documentation](https://grafana.com/docs/beyla/latest/)

The chart metadata and values table are generated using `helm-docs` v1.14.2.

---

## 3. Architecture

Beyla runs inside Kubernetes and observes supported application and network activity using eBPF.

The collected telemetry is exposed or exported to the relevant components of the monitoring platform.

```text
                    KUBERNETES CLUSTER
    +------------------------------------------------+
    |                                                |
    |  +------------------+                          |
    |  | Application Pods |                          |
    |  +--------+---------+                          |
    |           |                                    |
    |           | Application and network activity   |
    |           v                                    |
    |  +------------------+                          |
    |  | Beyla DaemonSet   |                          |
    |  | eBPF Observability|                          |
    |  +--------+---------+                          |
    |           |                                    |
    +-----------|------------------------------------+
                |
        +-------+----------------+
        |                        |
        | Prometheus metrics     | OTLP traces
        | HTTP :9090/metrics     | gRPC :4317
        v                        v
 +-------------------+    +------------------------+
 | Prometheus        |    | Configured OTLP         |
 | Metrics Collection|    | Receiver / Trace Backend|
 +---------+---------+    +------------------------+
           |                        |
           v                        v
 +-------------------+    +------------------------+
 | Thanos Query      |    | Trace Storage           |
 | and Object Storage|    | and Query Backend       |
 +---------+---------+    +-----------+------------+
           |                          |
           +------------+-------------+
                        |
                        v
                   +---------+
                   | Grafana |
                   +---------+
```

This is a logical architecture. The actual metrics path depends on the Prometheus scrape configuration, while the trace path depends on the configured OTLP receiver and tracing backend.

Beyla does not itself replace Prometheus, Thanos, or a trace-storage backend.

### 3.1 Metrics flow

1. Beyla observes supported application and network activity.
2. Beyla generates the configured metrics.
3. The metrics endpoint exposes data on port `9090` at `/metrics`.
4. Prometheus must be configured to scrape this endpoint.
5. Collected metrics can then be queried through the configured Prometheus and Thanos infrastructure.
6. Grafana visualizes the resulting metrics using dashboards.

The supplied values configure the metrics endpoint. They do not, by themselves, guarantee that Prometheus discovers or scrapes it.

### 3.2 Trace flow

1. Beyla observes supported application operations.
2. Beyla generates trace telemetry using the configured instrumentations.
3. Beyla exports traces through OTLP over gRPC.
4. The configured receiver accepts the traces.
5. The tracing backend stores and makes the traces available for querying.
6. Grafana can visualize the traces if an appropriate trace data source is configured.

The endpoint in this repository is `IP:4317`.

### 3.3 Kubernetes metadata

Beyla enriches telemetry with Kubernetes metadata, including:

- Cluster name.
- Namespace name.
- Deployment name.
- Pod name.
- Node name.
- Service name.
- Service namespace.

This metadata makes it easier to identify which Kubernetes resources are associated with a metric or trace.

---

## 4. Deployment Model

The chart supports deploying Beyla as a Kubernetes DaemonSet.

A DaemonSet normally schedules one pod on each eligible node, subject to node selectors, affinity, tolerations, and other scheduling constraints.

This model allows Beyla to observe supported activity on the nodes where it runs.

The chart also supports an optional Kubernetes metadata cache service.

### Main components

| Component | Purpose |
|---|---|
| Beyla DaemonSet | Observes application and network activity using eBPF. |
| Kubernetes metadata integration | Enriches telemetry with Kubernetes resource information. |
| Prometheus metrics endpoint | Exposes collected metrics for scraping. |
| OTLP trace exporter | Sends trace telemetry to the configured receiver. |
| Optional metadata cache | Provides a separate Kubernetes metadata cache service when enabled. |

The metadata cache is optional and is not enabled merely by setting `k8sCache.replicas` to its default value of `0`.

---

## 5. Configuration

The deployment is configured through Helm values.

The following sections explain the important settings in the supplied configuration.

### 5.1 Configuration management

```yaml
config:
  skipConfigMapCheck: false
  create: true
```

- `config.create: true` enables the chart's configuration creation behavior.
- `config.skipConfigMapCheck: false` keeps the chart's ConfigMap-related validation enabled.

The complete configuration is supplied through `config.data`.

### 5.2 Network observability

```yaml
network:
  enable: true
  direction: "both"
  cidrs:
    - "0.0.0.0/0"
```

This configuration enables network observability in both directions and specifies the IPv4 CIDR `0.0.0.0/0`.

The CIDR covers all IPv4 addresses. It is a broad scope, not a restriction to internal Kubernetes traffic.

Review the resulting telemetry volume, network visibility, and security implications before using this setting in production.

### 5.3 Kubernetes attributes

```yaml
attributes:
  kubernetes:
    enable: true
    meta_restrict_local_node: false
    resource_attributes:
      - k8s.cluster.name
      - k8s.namespace.name
      - k8s.deployment.name
      - k8s.pod.name
      - k8s.node.name
      - service.name
      - service.namespace
```

Kubernetes metadata enrichment is enabled.

The selected attributes help associate telemetry with clusters, namespaces, deployments, pods, nodes, and services.

`meta_restrict_local_node: false` disables the restriction that limits Kubernetes metadata retrieval to the local node. Verify the implications for your Beyla version and deployment topology.

### 5.4 External service naming

```yaml
rename_unresolved_hosts: "external"
rename_unresolved_hosts_outgoing: "external-out"
rename_unresolved_hosts_incoming: "external-in"
```

These settings define names for hosts that cannot be resolved to known service identities.

They help distinguish unresolved external destinations and incoming or outgoing network activity.

The exact naming behavior depends on the telemetry type and the Beyla version.

### 5.5 Service discovery and exclusions

```yaml
discovery:
  services:
    - k8s_namespace: ".*"

  exclude_services:
    - k8s_namespace: "^(kube-system|monitoring|grafana)$"

  exclude_otel_instrumented_services: false
```

The discovery configuration selects services across Kubernetes namespaces.

The following namespaces are excluded:

- `kube-system`
- `monitoring`
- `grafana`

The namespace exclusion expression is anchored to match these complete namespace names.

`exclude_otel_instrumented_services: false` means services already instrumented through OpenTelemetry are not excluded by this setting.

Review this choice to avoid unnecessary duplicate telemetry or overlapping instrumentation.

### 5.6 Metrics features

```yaml
metrics:
  features:
    - application
    - application_http
    - application_process
    - application_service_graph
    - application_span
    - network
```

The enabled features cover several types of telemetry.

| Feature | Purpose |
|---|---|
| `application` | General application-level metrics supported by Beyla. |
| `application_http` | HTTP application metrics. |
| `application_process` | Application process-related metrics. |
| `application_service_graph` | Metrics used to represent relationships between services. |
| `application_span` | Metrics derived from observed application spans. |
| `network` | Network-level metrics supported by Beyla. |

Available measurements depend on the observed protocols, application behavior, and Beyla version.

### 5.7 Route detection

```yaml
routes:
  unmatched: heuristic
```

This enables heuristic route identification for requests whose routes cannot otherwise be identified.

Route grouping can help make application latency and request-rate metrics more useful.

Validate the resulting route labels to ensure that they provide useful aggregation without introducing excessive metric cardinality.

### 5.8 Prometheus metrics export

```yaml
prometheus_export:
  port: 9090
  path: /metrics
```

Beyla exposes metrics on the configured endpoint:

```text
http://<beyla-pod-or-service>:9090/metrics
```

The actual reachable address depends on the pod networking and service configuration.

For Prometheus to collect these metrics, the scrape configuration must target the correct endpoint.

The chart supports an optional Kubernetes Service and ServiceMonitor. In the supplied chart defaults, both are disabled unless explicitly enabled.

### 5.9 OpenTelemetry trace export

```yaml
otel_traces_export:
  endpoint: "http://IP:4317"
  protocol: grpc
  insecure_skip_verify: true
  instrumentations:
    - http
    - grpc
    - sql
    - redis
    - kafka
    - mongo
```

Beyla is configured to export traces using OTLP over gRPC.

The configured instrumentations cover HTTP, gRPC, SQL, Redis, Kafka, and MongoDB.

The receiver must support the expected OTLP protocol and be reachable from the Beyla pods.

**Security consideration:** Review `insecure_skip_verify: true` and confirm its exact behavior for your Beyla version and endpoint configuration. Certificate verification should not be disabled unnecessarily in production.

The endpoint shown in this repository should also be checked against the actual receiver configuration. An address alone does not establish whether the receiver is a Collector, Tempo, or another compatible service.

### 5.10 eBPF settings

```yaml
ebpf:
  track_request_headers: true
  context_propagation: all
```

`track_request_headers: true` enables the configured request-header tracking behavior.

`context_propagation: all` configures the requested context-propagation behavior.

Review header collection carefully. Sensitive headers, such as authorization credentials and session identifiers, should not be exposed in telemetry.

The effective behavior of these settings depends on the Beyla application version and supported configuration options.

---

## 6. Installation and Upgrade

Use the chart's actual repository URL and deployment namespace when installing or upgrading Beyla.

### 6.1 Prerequisites

Before deployment, verify that:

- A Kubernetes cluster is available.
- Helm is installed.
- The intended namespace exists or can be created.
- The cluster supports the required eBPF functionality.
- The Beyla pods have the required permissions.
- Prometheus can reach the metrics endpoint.
- The configured OTLP receiver is reachable.
- Any applicable network policies permit the required traffic.

Beyla's eBPF requirements depend on the host kernel, deployment configuration, and security restrictions.

### 6.2 Inspect the chart

If the chart is available locally:

```bash
helm lint .
helm template beyla . -n monitoring -f values.yaml
```

These commands validate the chart and render its Kubernetes manifests. Run them from the chart directory and adjust the namespace and values filename to match your repository.

### 6.3 Install or upgrade

For a local chart:

```bash
helm upgrade --install beyla . \
  --namespace monitoring \
  --create-namespace \
  --values values.yaml
```

For a chart stored in a remote Helm repository, use that repository's configured chart reference instead.

### 6.4 Verify the deployment

```bash
helm status beyla -n monitoring
kubectl get daemonset -n monitoring
kubectl get pods -n monitoring -o wide
kubectl get events -n monitoring --sort-by=.lastTimestamp
```

Check the pod logs if Beyla does not start:

```bash
kubectl logs -n monitoring <beyla-pod-name>
```

If the DaemonSet has multiple containers, specify the appropriate container.

---

## 7. Validation

### 7.1 Check Beyla pods

Verify that the expected DaemonSet pods are scheduled and ready.

```bash
kubectl get daemonset -n monitoring
kubectl get pods -n monitoring -o wide
```

Investigate scheduling failures, permission errors, image-pull failures, and repeated container restarts.

### 7.2 Check the metrics endpoint

If port-forwarding is appropriate for your deployment:

```bash
kubectl port-forward -n monitoring <beyla-pod-name> 9090:9090
```

In another terminal:

```bash
curl -fsS http://127.0.0.1:9090/metrics
```

If port `9090` is not directly exposed by the pod, verify the rendered chart and configured endpoint before troubleshooting further.

### 7.3 Check Prometheus

Confirm that Prometheus has discovered the Beyla target and that the target is healthy.

If a ServiceMonitor is used, verify that:

- The chart creates the expected ServiceMonitor.
- The relevant Prometheus instance selects it.
- Its label selectors match.
- The associated Service exposes the correct port.
- Network connectivity is available.

### 7.4 Check trace export

Verify connectivity from the Beyla deployment to:

```text
IP:4317
```

Then check the receiver's logs and confirm that traces are accepted and available in the trace backend.

Network connectivity alone does not guarantee that trace export is correctly configured.

---

## 8. Troubleshooting

### Beyla pods are not starting

Check:

- DaemonSet scheduling.
- Node selectors, affinity, and tolerations.
- Image availability.
- eBPF and kernel compatibility.
- Container security settings.
- RBAC permissions.
- Pod events and logs.

### Metrics are missing

Check:

- Whether Beyla is running.
- Whether the metrics endpoint is exposed.
- Whether Prometheus can reach the endpoint.
- Whether the target is discovered and healthy.
- Whether the requested metrics feature is enabled.
- Whether the observed application uses a supported protocol.

### Kubernetes metadata is missing

Check:

- Kubernetes metadata configuration.
- Service-account permissions.
- Namespace and resource discovery.
- The configured resource attributes.
- Beyla logs for metadata or discovery errors.

### Traces are missing

Check:

- The configured OTLP endpoint.
- The gRPC receiver and port.
- Network policies and routing.
- Receiver logs.
- TLS and certificate settings.
- Supported instrumentation and context propagation.
- Trace-backend ingestion and storage.

### Unexpected telemetry volume

Check:

- Network monitoring scope.
- Service discovery exclusions.
- Enabled metrics features.
- Route grouping.
- Metric labels and cardinality.
- Duplicate instrumentation.

### No service graph data

Check whether the expected application activity is observed and whether the service graph metrics are generated, scraped, and queried correctly.

Also verify that the relevant telemetry includes the service identity and relationship information needed by the dashboards.

---

## 9. Security Considerations

Beyla uses eBPF and may require elevated host-level permissions, depending on the deployment configuration.

Review the following before production deployment:

- Required Linux capabilities and privileges.
- Host and kernel compatibility.
- Access to host-level resources.
- RBAC permissions.
- Namespace discovery scope.
- Network visibility.
- Request-header collection.
- OTLP endpoint security.
- Certificate verification.
- Exposure of the metrics endpoint.

The chart's supplied defaults include privileged execution. Do not assume that the deployment can run with reduced privileges without validating the required eBPF functionality.

Restrict access to telemetry endpoints and avoid collecting or exporting sensitive request data.

---

## 10. Maintenance

For chart upgrades:

1. Review the release notes for the target chart version.
2. Review application-version changes.
3. Check changes to the chart's values and defaults.
4. Render the manifests before deployment.
5. Validate eBPF compatibility.
6. Deploy through the approved release process.
7. Confirm metrics and trace ingestion after the upgrade.

Useful commands:

```bash
helm get values beyla -n monitoring
helm get manifest beyla -n monitoring
helm history beyla -n monitoring
```

These commands help inspect the deployed values, rendered resources, and release history.

---

## 11. Repository Values Reference

The chart's complete `values.yaml` reference is maintained separately from this operational documentation.

Use the autogenerated Helm values table to inspect all supported chart options, including:

- Image configuration.
- Scheduling and resource settings.
- RBAC and service-account settings.
- Security configuration.
- Kubernetes metadata cache.
- Service and ServiceMonitor configuration.
- Pod labels and annotations.
- Additional volumes and manifests.
- Beyla configuration.

Do not assume that a chart option is enabled just because it is supported.

The effective deployment is determined by the chart defaults, the values supplied by this repository, and any overrides applied during installation.

---

