# Monitoring Platform

## 1. Overview

This repository collection provides a centralized monitoring and observability platform for Kubernetes workloads and external servers.

The platform collects metrics, application telemetry, network metrics, and distributed traces. It provides centralized querying, long-term storage, visualization, and monitoring capabilities across multiple infrastructure environments.

The platform consists of the following technologies:

- **Prometheus:** Collects and stores time-series metrics.
- **Thanos:** Provides a unified query layer and long-term metrics storage using object storage.
- **Ceph S3:** Provides object storage for long-term monitoring data.
- **Grafana:** Provides dashboards and visualization.
- **Beyla:** Uses eBPF to observe application and network activity.
- **OpenTelemetry Operator:** Manages OpenTelemetry instrumentation and related Kubernetes resources.
- **kube-state-metrics:** Exposes Kubernetes object state metrics.
- **Prometheus Node Exporter:** Exposes host-level operating system metrics.
- **Ansible:** Automates monitoring component installation on external servers.

This documentation describes the overall architecture and explains the responsibilities of each repository.

---

## 2. Architecture

The monitoring platform is divided into two main environments.

### 2.1 Kubernetes Monitoring

Monitoring components deployed inside Kubernetes collect telemetry from applications, Kubernetes resources, and worker nodes.

Components include:

- kube-prometheus-stack
- kube-state-metrics
- prometheus-node-exporter
- Beyla
- OpenTelemetry Operator

The Kubernetes monitoring components provide visibility into application behavior, cluster resources, node health, and network communication.

### 2.2 External Monitoring Infrastructure

The external monitoring infrastructure provides centralized metric querying, storage, and visualization.

Components include:

- Grafana
- Thanos Query
- Thanos Sidecars
- Prometheus servers
- Thanos Store Gateway
- Thanos Compactor
- Ceph S3 object storage

### 2.3 High-Level Architecture

```text
                  KUBERNETES CLUSTER
              +-------------------------+
              |                         |
              |  Applications           |
              |       |                 |
              |       v                 |
              |  Beyla / eBPF           |
              |       |                 |
              |       +---- Metrics     |
              |       |                 |
              |       +---- Traces -----+----------+
              |                         |          |
              |  kube-state-metrics     |          |
              |  Node Exporter          |          |
              |  Prometheus            |          |
              +-------------------------+          |
                                                   |
                     Metrics                       | OTLP
                        |                          |
                        v                          v
                +---------------+           +-------------+
                | Prometheus    |           | OpenTelemetry|
                | Collection    |           | Trace Backend|
                +-------+-------+           +-------------+
                        |
                        v
                 Prometheus Storage
                        |
                        v
                 Thanos Sidecar
                        |
                        v
                 Thanos Components
                        |
                        v
                  Ceph S3 Storage
                        |
                        v
                 Thanos Store Gateway
                        |
                        v
                   Thanos Query
                        |
                        v
                     Grafana
```

**Important:** This diagram is a conceptual overview, not a complete deployment diagram. The exact metrics forwarding path depends on the deployed Prometheus configuration. Confirm whether the Kubernetes Prometheus instance sends metrics to an external Prometheus server, exposes them through a Thanos Sidecar, or uses another remote-write or federation mechanism.

The diagram also does not imply that Grafana queries Ceph S3 directly. Grafana queries Thanos Query, which retrieves metrics from the configured Thanos data sources.

---

## 3. External Metrics Architecture

The external metrics architecture uses Prometheus and Thanos to provide a centralized monitoring system.

```text
                        +-----------+
                        |  Grafana  |
                        +-----+-----+
                              |
                              | 
                              v
                       +--------------+
                       | Thanos Query |
                       +------+-------+
                              |
          +-------------------+-------------------+
          |                   |                   |
          v                   v                   v
   +------------+      +------------+      +--------------+
   | Sidecar 1  |      | Sidecar 2  |      | Store Gateway|
   +-----+------+      +-----+------+      +------+-------+
         |                   |                    |
         v                   v                    v
   +------------+      +------------+       +-----------+
   | Prometheus |      | Prometheus |       | Ceph S3   |
   | Server 1   |      | Server 2   |       | Object    |
   | 10-day TSDB|      | 10-day TSDB|       | Storage   |
   +------------+      +------------+       +-----+-----+
                                                   ^
                                                   |
                                           +-------+------+
                                           | Thanos       |
                                           | Compactor    |
                                           +--------------+
```

### Component responsibilities

| Component | Responsibility |
|---|---|
| Grafana | Displays metrics through dashboards and panels. |
| Thanos Query | Queries and combines metrics from multiple Thanos data sources. |
| Prometheus Server 1 | Collects metrics and stores them locally for approximately 10 days. |
| Prometheus Server 2 | Collects metrics and stores them locally for approximately 10 days. |
| Thanos Sidecars | Expose Prometheus data to Thanos Query and support uploading Prometheus blocks to object storage when configured. |
| Thanos Store Gateway | Makes historical metric blocks in object storage available to Thanos Query. |
| Ceph S3 | Stores historical metrics as Thanos blocks. |
| Thanos Compactor | Compacts, deduplicates where configured, and applies retention policies to stored blocks. |

The actual local retention, object-storage retention, compactor settings, and upload behavior must be verified against the deployed configuration.

### Query flow

1. A user opens a Grafana dashboard.
2. Grafana sends a query to Thanos Query.
3. Thanos Query retrieves data from the available Sidecars and Store Gateway.
4. Sidecars provide access to recent Prometheus data.
5. The Store Gateway provides access to historical data stored in Ceph S3.
6. Thanos Query combines the results and returns them to Grafana.

### Storage flow

1. Prometheus collects metrics and stores them in its local TSDB.
2. Thanos Sidecar makes Prometheus data available to Thanos and uploads completed blocks when configured.
3. Ceph S3 stores the uploaded metric blocks.
4. Thanos Store Gateway serves historical blocks.
5. Thanos Compactor processes stored blocks and enforces configured retention policies.

**Retention note:** The 10-day Prometheus retention and 30-day object-storage retention are intended values based on the architecture. Verify the actual configuration before treating them as enforced limits.

---

## 4. Repository Inventory

The following repositories manage different parts of the monitoring platform.

| Repository | Technology | Primary responsibility |
|---|---|---|
| `beyla` | Helm | Deploys Beyla for eBPF-based application and network observability. |
| `grafana-dashboard` | Grafana dashboards | Stores and manages monitoring dashboards. |
| `kube-prometheus-stack` | Helm | Deploys Prometheus and related Kubernetes monitoring components. |
| `kube-state-metrics` | Helm | Exposes metrics about Kubernetes resource states. |
| `opentelemetry-operator` | Helm | Installs and manages the OpenTelemetry Operator. |
| `prometheus-node-exporter` | Helm | Deploys Node Exporter inside Kubernetes. |
| `prometheus-node-exporter-ansible` | Ansible | Installs and configures Node Exporter on external servers. |
| `prometheus-ansible` | Ansible | Automates Prometheus-related installation and configuration on external infrastructure. |

The exact responsibilities of the Ansible repositories should be confirmed against their playbooks, roles, inventory files, and templates.

---

## 5. Repository Details

### 5.1 Beyla

**Repository:** `beyla`

**Deployment method:** Helm chart

**Purpose:**

Deploys Beyla to observe application and network activity using eBPF.

The supplied configuration enables application telemetry, network metrics, Kubernetes metadata, and OpenTelemetry trace export.

**Key configuration:**

- Network monitoring is enabled.
- Network traffic direction is set to `both`.
- The configured CIDR is `0.0.0.0/0`.
- Kubernetes metadata is enabled.
- Services are discovered across Kubernetes namespaces.
- Services in `kube-system`, `monitoring`, and `grafana` are excluded from discovery.
- Application, HTTP, process, service graph, span, and network metric features are enabled.
- Unmatched routes use heuristic detection.
- Prometheus metrics are exposed on port `9090` at `/metrics`.
- Traces are exported using OTLP over gRPC to `IP:4317`.
- HTTP, gRPC, SQL, Redis, Kafka, and MongoDB instrumentations are configured.
- Request-header tracking is enabled.
- Context propagation is configured as `all`.

**Integration:**

Beyla provides application and network telemetry that can be collected by the metrics pipeline and sent to the configured OpenTelemetry trace backend.

**Important configuration considerations:**

- Verify that the OTLP endpoint is reachable from the Beyla pods.
- Confirm which collector or trace backend listens on `IP:4317`.
- Verify whether the configured metrics endpoint is scraped by Prometheus.
- Review request-header tracking because headers can contain sensitive information.
- Review network monitoring scope and permissions before deploying in production.

### 5.2 Grafana Dashboards

**Repository:** `grafana-dashboard`

**Purpose:**

Stores dashboards used to visualize metrics collected by the monitoring platform.

Dashboards can provide visibility into:

- Kubernetes cluster health.
- Node CPU, memory, disk, and network usage.
- Pod and container resource consumption.
- Application request rates and latency.
- Application errors.
- Service-to-service communication.
- Network activity.
- Prometheus and Thanos health.

**Integration:**

Grafana dashboards query configured data sources, including Thanos Query for metrics and Tempo for traces if Tempo is deployed and configured.

**Repository contents to document:**

- Dashboard JSON files.
- Dashboard provisioning configuration.
- Folder organization.
- Data-source references.
- Import and update procedures.

### 5.3 kube-prometheus-stack

**Repository:** `kube-prometheus-stack`

**Deployment method:** Helm chart

**Purpose:**

Deploys Prometheus-based monitoring components inside Kubernetes.

Depending on the chart configuration, it can include:

- Prometheus.
- Prometheus Operator.
- Alertmanager.
- Kubernetes monitoring rules.
- ServiceMonitor and PodMonitor support.
- Related monitoring resources.

**Integration:**

Prometheus collects metrics from Kubernetes workloads and exporters. Those metrics must then be exposed or forwarded to the external monitoring infrastructure using the configured integration.

**Important:**

The exact components installed depend on the chart values. Document the actual configuration rather than assuming every component is enabled.

### 5.4 kube-state-metrics

**Repository:** `kube-state-metrics`

**Deployment method:** Helm chart

**Purpose:**

Exposes metrics representing the state of Kubernetes API objects.

Examples include:

- Deployment replica counts.
- Pod phases.
- DaemonSet status.
- StatefulSet status.
- Job status.
- Kubernetes resource metadata.

**Integration:**

Prometheus scrapes kube-state-metrics to obtain information about Kubernetes resource states.

These metrics complement CPU, memory, and network measurements collected from nodes and containers.

**Important distinction:**

kube-state-metrics reports Kubernetes object state. It does not directly measure all application performance or operating system resource usage.

### 5.5 OpenTelemetry Operator

**Repository:** `opentelemetry-operator`

**Deployment method:** Helm chart

**Purpose:**

Installs the OpenTelemetry Operator to manage supported OpenTelemetry resources and instrumentation components in Kubernetes.

Depending on its configuration, the Operator can manage:

- OpenTelemetry Collector resources.
- Collector deployments and configurations.
- Supported instrumentation resources.
- Automatic instrumentation integrations.

**Integration:**

The Operator can support the deployment and management of telemetry collection components used by applications and other observability agents.

**Important:**

Installing the Operator does not automatically mean that an OpenTelemetry Collector is deployed or that traces are being received. Verify the relevant custom resources, Collector configuration, receivers, processors, exporters, and endpoints.

### 5.6 Prometheus Node Exporter

**Repository:** `prometheus-node-exporter`

**Deployment method:** Helm chart

**Purpose:**

Deploys Node Exporter inside Kubernetes to expose operating system and host-level metrics from the configured nodes.

Examples include:

- CPU statistics.
- Memory statistics.
- Filesystem usage.
- Disk I/O.
- Network interface statistics.
- System load.

**Integration:**

Prometheus scrapes the metrics endpoint exposed by Node Exporter.

The exact collection scope depends on the chart values, host mounts, security settings, and deployment configuration.

### 5.7 Prometheus Node Exporter Ansible

**Repository:** `prometheus-node-exporter-ansible`

**Deployment method:** Ansible

**Purpose:**

Automates Node Exporter installation and configuration on external servers that are not managed as Kubernetes workloads.

Typical responsibilities include:

- Installing the Node Exporter binary or package.
- Creating a service account.
- Installing systemd service configuration.
- Starting and enabling the service.
- Configuring the listening address and port.
- Verifying service health.

**Integration:**

The external Prometheus server scrapes Node Exporter endpoints on the configured servers.

**Important:**

Document the supported operating systems, required privileges, target inventory, version, listening port, and firewall requirements based on the actual Ansible implementation.

### 5.8 Prometheus Ansible

**Repository:** `prometheus-ansible`

**Deployment method:** Ansible

**Purpose:**

Automates Prometheus-related installation and configuration on external infrastructure.

Depending on the playbooks and roles, this repository may manage:

- Prometheus installation.
- Prometheus configuration files.
- Scrape jobs.
- Service discovery.
- Systemd configuration.
- Service lifecycle.
- Prometheus retention settings.
- Thanos Sidecar integration.
- Remote-write or federation configuration.

**Integration:**

This repository supports the external metrics collection infrastructure.

Its exact role must be confirmed by inspecting the playbooks, roles, templates, and inventory.

---

## 6. Metrics and Traces

The platform supports two distinct telemetry types.

### Metrics

Metrics are numerical time-series measurements collected over time.

Examples:

- CPU usage.
- Memory consumption.
- Request rate.
- HTTP error rate.
- Request duration.
- Network traffic.
- Pod restart counts.

**Primary components:** Prometheus, Thanos, Ceph S3, and Grafana.

### Traces

Traces represent the journey of a request across application components.

They can help identify:

- Slow services.
- Slow database queries.
- Inter-service latency.
- Failed requests.
- Bottlenecks in distributed applications.

**Primary components:** Beyla, the configured OpenTelemetry trace pipeline, the trace backend, and Grafana.

If Tempo is the deployed trace backend, Grafana can query Tempo to explore distributed traces.

Metrics and traces provide complementary views of system behavior. Metrics help detect abnormal behavior, while traces help investigate individual requests and their execution paths.

---

## 7. Data Retention

The intended retention model is:

| Storage layer | Intended retention | Purpose |
|---|---|---|
| Prometheus local TSDB | 10 days | Recent metrics and local queries. |
| Ceph S3 object storage | 30 days | Historical metrics and longer-term analysis. |
| Thanos Compactor | Configured by policy | Processes blocks and applies object-storage retention. |

The actual retention values must be verified against the deployed Prometheus flags, Thanos configuration, and object-storage settings.

Object-storage retention is not guaranteed merely because Ceph S3 is available. It requires the appropriate Thanos configuration.

---

## 8. Deployment Responsibilities

The repositories are divided by deployment target and function.

| Deployment target | Repositories |
|---|---|
| Kubernetes application observability | `beyla` |
| Kubernetes metrics collection | `kube-prometheus-stack` |
| Kubernetes resource-state metrics | `kube-state-metrics` |
| Kubernetes node metrics | `prometheus-node-exporter` |
| OpenTelemetry management | `opentelemetry-operator` |
| External server metrics | `prometheus-node-exporter-ansible` |
| External Prometheus infrastructure | `prometheus-ansible` |
| Dashboard management | `grafana-dashboard` |

Deployment order depends on dependencies and the actual infrastructure design.

A typical dependency sequence is:

1. Prepare external monitoring endpoints, networking, credentials, and storage.
2. Deploy and configure the external Prometheus and Thanos infrastructure.
3. Deploy Kubernetes monitoring components.
4. Configure metrics collection and the forwarding or querying path.
5. Deploy the OpenTelemetry components and configure trace export.
6. Deploy or configure Grafana data sources.
7. Import and validate dashboards.
8. Test metrics, traces, retention, and alerts.

---

## 9. Security Considerations

The monitoring platform handles operational telemetry and may have access to sensitive infrastructure metadata.

Follow these practices:

- Use dedicated service accounts with least-privilege permissions.
- Restrict access to Prometheus, Thanos, Grafana, and exporter endpoints.
- Protect Ceph S3 credentials.
- Use TLS and authentication where supported and required.
- Restrict network access to OTLP endpoints.
- Review the use of `insecure_skip_verify`.
- Review whether request headers should be collected.
- Avoid storing credentials in Helm values or Ansible repositories in plaintext.
- Use an approved secrets-management solution.
- Restrict access to Grafana dashboards and administrative functions.
- Validate eBPF privileges and host access requirements before production deployment.

---

## 10. Troubleshooting

### Metrics are missing from Grafana

Check:

1. The Grafana data source configuration.
2. Thanos Query availability.
3. Whether the relevant Prometheus targets are healthy.
4. Whether Thanos Sidecars are connected to their Prometheus servers.
5. Whether the expected Store Gateway data is available.
6. Whether the requested metric exists.
7. Whether the time range and labels are correct.

### Kubernetes metrics are missing

Check:

1. The Prometheus deployment and service.
2. Prometheus target discovery.
3. ServiceMonitor and PodMonitor configuration, if used.
4. kube-state-metrics availability.
5. Node Exporter availability.
6. RBAC permissions.
7. Network policies and endpoint reachability.

### Beyla metrics are missing

Check:

1. Beyla pod status and logs.
2. eBPF permissions and kernel compatibility.
3. Service discovery and exclusion rules.
4. The metrics endpoint on port `9090`.
5. Prometheus scrape configuration.
6. Network connectivity and relevant Kubernetes metadata settings.

### Traces are missing

Check:

1. Beyla instrumentation and trace export settings.
2. Reachability of `IP:4317`.
3. OTLP gRPC receiver configuration.
4. Collector or trace-backend logs.
5. Exporter errors and TLS settings.
6. Trace storage configuration.
7. Grafana Tempo data-source configuration, if Tempo is used.

### External server metrics are missing

Check:

1. Ansible deployment results.
2. Node Exporter service status.
3. The exporter listening address and port.
4. Firewall rules.
5. Prometheus scrape configuration.
6. Connectivity between Prometheus and the target server.

---

## 11. Repository Documentation Standards

Each repository should contain a README with the following sections where applicable:

1. Overview.
2. Purpose and responsibilities.
3. Architecture and integrations.
4. Prerequisites.
5. Repository structure.
6. Configuration and important values.
7. Installation and deployment.
8. Verification.
9. Troubleshooting.
10. Security considerations.
11. Maintenance and upgrade procedures.
12. Dependencies and related repositories.

The main monitoring README should explain how all repositories fit together. Individual repository READMEs should document implementation-specific details.

---

## 12. Future Improvements

Potential improvements to the platform include:

- Centralized alerting and notification management.
- Alert rules based on service-level objectives.
- Better correlation between metrics, logs, and traces.
- Automated validation of Prometheus scrape targets.
- Monitoring of Thanos and object-storage health.
- Documented backup and recovery procedures.
- Standardized Helm values and Ansible inventories.
- Automated deployment validation.
- Runbooks for common infrastructure incidents.

---

