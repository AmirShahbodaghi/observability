# kube-prometheus-stack

## 1. Overview

This repository deploys a lightweight Prometheus monitoring component inside Kubernetes using the `kube-prometheus-stack` Helm chart.

The primary purpose of this deployment is to collect metrics from Kubernetes workloads and forward them to two external Prometheus-compatible endpoints for centralized monitoring and long-term storage.

The in-cluster Prometheus instance is configured with a short local retention period of **one day**. Metrics are forwarded to external monitoring servers using Prometheus remote write.

The deployment is intentionally minimal: Grafana, Alertmanager, Node Exporter, kube-state-metrics, default alerting rules, and several Kubernetes control-plane monitoring targets are disabled.

Prometheus is exposed through a Kubernetes Gateway API HTTPRoute rather than a traditional Ingress resource.

### Key features

- Prometheus deployment inside Kubernetes.
- Automatic discovery of ServiceMonitor and PodMonitor resources across namespaces.
- Remote write to two external Prometheus-compatible endpoints.
- One-day local metric retention.
- Gateway API-based HTTP routing.
- Prometheus Operator CRDs enabled.
- Reduced installation footprint by disabling unnecessary monitoring components.
- Private container image registry configuration for the CRD upgrade job.

---

## 2. Architecture

### High-level architecture

```text
                  KUBERNETES CLUSTER
             +---------------------------+
             |                           |
             | Applications and Services|
             |          |                |
             |          v                |
             |  ServiceMonitor /         |
             |  PodMonitor resources     |
             |          |                |
             |          v                |
             |   +------------------+    |
             |   |   Prometheus     |    |
             |   |                  |    |
             |   | Local retention  |    |
             |   |      1 day       |    |
             |   +--------+---------+    |
             |            |              |
             +------------|--------------+
                          |
                     Remote Write
                          |
               +----------+----------+
               |                     |
               v                     v
       +---------------+     +---------------+
       | External      |     | External      |
       | Prometheus A  |     | Prometheus B  |
       |               |     |               |
       | IP  |     | IP  |
       | :9090         |     | :9090         |
       +-------+-------+     +-------+-------+
               |                     |
               +----------+----------+
                          |
                          v
                Centralized Monitoring
                and Historical Storage
                (depending on the
                 external architecture)
```

**Important:** This repository configures the in-cluster Prometheus to send metrics to both external endpoints. It does not configure the external Prometheus servers, Thanos, or object storage.

The diagram illustrates the intended metrics flow. The external architecture must be configured separately.

### Metrics flow

1. Applications and monitoring endpoints expose Prometheus metrics.
2. Prometheus discovers eligible targets through its configured scrape configuration.
3. Prometheus collects metrics and stores them in its local TSDB.
4. Prometheus forwards collected samples to both remote-write endpoints.
5. External monitoring infrastructure receives and stores the metrics.
6. Grafana and other monitoring components can query the external infrastructure, depending on their configuration.

Remote write operates independently of whether users are currently viewing dashboards.

---

## 3. Repository Responsibilities

This repository is responsible for deploying and configuring the in-cluster Prometheus component.

| Responsibility | Status |
|---|---|
| Deploy Prometheus | Enabled |
| Deploy Grafana | Disabled |
| Deploy Alertmanager | Disabled |
| Deploy Node Exporter | Disabled |
| Deploy kube-state-metrics | Disabled |
| Create default monitoring rules | Disabled |
| Monitor Kubernetes API server | Disabled |
| Monitor Kubernetes controller manager | Disabled |
| Monitor Kubernetes scheduler | Disabled |
| Monitor etcd | Disabled |
| Monitor kube-proxy | Disabled |
| Install Prometheus Operator CRDs | Enabled |
| Upgrade CRDs through the upgrade job | Disabled |
| Discover ServiceMonitor resources | All namespaces |
| Discover PodMonitor resources | All namespaces |
| Configure remote write | Two endpoints |
| Configure local retention | One day |
| Configure traditional Ingress | Disabled |
| Configure Gateway API HTTPRoute | Enabled |

The exact components installed also depend on the Helm chart version and any additional configuration supplied during deployment.

---

## 4. Helm Configuration

The deployment is configured through Helm values.

### 4.1 Disabled components

The following components are disabled:

```yaml
grafana:
  enabled: false

alertmanager:
  enabled: false

nodeExporter:
  enabled: false

prometheus-node-exporter:
  enabled: false

kubeStateMetrics:
  enabled: false

kube-state-metrics:
  enabled: false

defaultRules:
  create: false

kubeApiServer:
  enabled: false

kubeControllerManager:
  enabled: false

kubeScheduler:
  enabled: false

kubeEtcd:
  enabled: false

kubeProxy:
  enabled: false
```

This configuration reduces the scope of the installation by disabling components that are managed elsewhere or are not required in this cluster.

**Note:** Disabling these components means their corresponding functionality is not provided by this chart installation. For example, disabling Alertmanager does not prevent Prometheus from evaluating custom alerting rules, but it removes the Alertmanager deployment managed by this chart.

Likewise, disabling the default rules means the chart will not create its standard monitoring rules. Any required custom rules must be managed separately.

### 4.2 Prometheus Operator CRDs

```yaml
crds:
  enabled: true

  upgradeJob:
    enabled: false
    forceConflicts: true

    image:
      busybox:
        registry: pull-devops.example.ir
        repository: busybox
        tag: "latest"
        pullPolicy: IfNotPresent

      kubectl:
        registry: pull-devops.example.ir
        repository: kubectl
        tag: ""
        pullPolicy: IfNotPresent
```

Prometheus Operator CRDs extend the Kubernetes API with monitoring-specific resources.

Examples include:

- `ServiceMonitor`
- `PodMonitor`
- `PrometheusRule`
- `Probe`
- `Prometheus`

The CRDs enable Kubernetes-native management of Prometheus monitoring resources.

The CRD upgrade job is disabled in this configuration. Therefore, the configured BusyBox and kubectl images are not necessarily used during a normal deployment.

If CRDs must be upgraded, follow the procedure supported by the installed chart version and your cluster's CRD lifecycle policy.

**Important:** CRDs are cluster-scoped resources. Coordinate upgrades carefully when multiple Prometheus Operator installations share the same cluster.

---

## 5. Prometheus Configuration

### 5.1 Enable Prometheus

```yaml
prometheus:
  enabled: true
```

Prometheus is the primary component deployed by this repository.

It scrapes configured metrics endpoints, stores samples locally, and forwards samples to external monitoring servers.

### 5.2 Local retention

```yaml
prometheusSpec:
  retention: 1d
```

Prometheus retains local metrics for approximately one day.

This short retention period is suitable for a design in which external monitoring infrastructure provides longer-term storage.

Local retention is not a guarantee of exactly 24 hours of queryable data. Actual behavior also depends on storage capacity, Prometheus lifecycle behavior, and other configuration settings.

### 5.3 ServiceMonitor and PodMonitor discovery

```yaml
serviceMonitorSelectorNilUsesHelmValues: false
podMonitorSelectorNilUsesHelmValues: false

serviceMonitorSelector: {}
podMonitorSelector: {}
```

These settings allow Prometheus to select ServiceMonitor and PodMonitor resources without restricting selection to the chart's default Helm release labels.

An empty selector `{}` matches all resources of the relevant type with respect to the selector itself.

However, selecting a ServiceMonitor or PodMonitor does not automatically guarantee that its targets will be scraped. Namespace selectors, endpoint configuration, label selectors on the monitored services or pods, RBAC permissions, and network connectivity still affect discovery.

The intention is to support monitoring resources across namespaces.

**Operational consideration:** Cluster-wide discovery can increase the number of scrape targets and the volume of collected metrics. Review resource consumption and access controls.

---

## 6. Remote Write Configuration

Prometheus forwards metrics to two external endpoints.

```yaml
remoteWrite:
  - url: "http://IP:9090/api/v1/write"
    queueConfig:
      capacity: 10000
      maxSamplesPerSend: 5000
      maxShards: 10
      minShards: 1
      batchSendDeadline: 5s

  - url: "http://IP:9090/api/v1/write"
    queueConfig:
      capacity: 10000
      maxSamplesPerSend: 5000
      maxShards: 10
      minShards: 1
      batchSendDeadline: 5s
```

### Endpoint A

- Address: `IP`
- Port: `9090`
- Path: `/api/v1/write`
- Protocol: HTTP

### Endpoint B

- Address: `IP`
- Port: `9090`
- Path: `/api/v1/write`
- Protocol: HTTP

Both destinations receive copies of the metrics sent by this Prometheus instance.

### Remote-write queue settings

| Setting | Value | Purpose |
|---|---:|---|
| `capacity` | `10000` | Capacity of each remote-write shard's queue, measured in samples. |
| `maxSamplesPerSend` | `5000` | Maximum samples per remote-write request. |
| `maxShards` | `10` | Maximum number of parallel shards per remote-write destination. |
| `minShards` | `1` | Minimum number of parallel shards per destination. |
| `batchSendDeadline` | `5s` | Maximum wait for a batch to be sent when it has not otherwise filled. |

These settings control buffering and transmission behavior. Actual throughput depends on scrape volume, sample sizes, network performance, and destination processing capacity.

### Important: Remote write is not a load-balancing configuration

The two endpoints are configured as separate destinations.

Prometheus attempts to send the collected metrics to both endpoints; it does not choose one endpoint as the active destination and automatically switch to the other.

This provides two independent copies of the metric stream, assuming both destinations are reachable and accept the samples.

It does not, by itself, guarantee zero data loss during outages.

### Requirements on the external endpoints

Both external destinations must:

1. Be reachable from the Kubernetes cluster.
2. Listen on the configured address and port.
3. Accept Prometheus remote-write requests.
4. Have remote-write receiving enabled if the receiving software requires an explicit setting.
5. Have sufficient capacity to process incoming samples.
6. Be monitored for errors and ingestion delays.

For example, an external Prometheus receiver may require its remote-write receiver feature to be explicitly enabled.

The actual requirements depend on the software listening at each endpoint.

### Network and security considerations

The configured endpoints use HTTP rather than HTTPS.

Before using this configuration in production, verify that the traffic is protected by appropriate network controls or change the configuration to use an authenticated, encrypted transport where supported.

Remote write can carry a substantial amount of operational data. Restrict access to the receiving endpoints.

---

## 7. Gateway API Exposure

Traditional Ingress is disabled:

```yaml
ingress:
  enabled: false
```

Prometheus is instead configured with a Gateway API HTTPRoute:

```yaml
route:
  main:
    enabled: true

    hostnames:
      - "pk-prod-devops.example.ir"

    parentRefs:
      - name: gateway
        namespace: envoy-gateway-system

    matches:
      - path:
          type: PathPrefix
          value: /
```

### Configuration details

| Setting | Value | Description |
|---|---|---|
| HTTPRoute | Enabled | Enables the chart's configured route resource. |
| Hostname | `pk-prod-devops.example.ir` | Hostname matched by the route. |
| Parent Gateway | `gateway` | Gateway referenced by the HTTPRoute. |
| Gateway namespace | `envoy-gateway-system` | Namespace containing the parent Gateway. |
| Path type | `PathPrefix` | Matches paths beginning with `/`. |
| Path | `/` | Matches requests under the root path. |

### Requirements

The Gateway API implementation and Gateway must already exist and be configured correctly.

Verify:

- The Gateway resource exists.
- Its listeners accept the configured hostname.
- The Gateway's allowed routes configuration permits the HTTPRoute.
- DNS points to the intended Gateway endpoint.
- TLS is configured if HTTPS is required.
- The HTTPRoute is accepted and its parent reference is resolved.

The values shown configure the HTTPRoute, but they do not independently guarantee external reachability or HTTPS.

**Security note:** Prometheus commonly exposes operational data and administrative endpoints. Restrict access using Gateway policies, authentication, network controls, or other approved mechanisms before exposing it outside a trusted network.

---

## 8. Prerequisites

Before deployment, ensure that the following requirements are satisfied.

- A working Kubernetes cluster.
- Helm installed and configured to access the cluster.
- The `kube-prometheus-stack` chart repository or a local chart package.
- Permission to create the required monitoring resources.
- Prometheus Operator CRDs available or installable.
- A compatible Gateway API implementation.
- A Gateway named `gateway` in the `envoy-gateway-system` namespace.
- Network connectivity to both remote-write endpoints.
- Remote-write receiving configured on the external destinations.
- Appropriate network policies, access controls, and storage capacity.

The exact Kubernetes and Helm versions should be selected according to the chart version used by the repository.

---

## 9. Installation and Upgrade

The following commands are examples. Adjust the release name, namespace, chart source, and values filename to match the repository.

### 9.1 Add the Helm repository

```bash
helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts

helm repo update
```

### 9.2 Validate the values

Assuming the configuration is saved as `values.yaml`:

```bash
helm lint ./chart
```

If using the remote chart repository, render the templates:

```bash
helm template monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values values.yaml
```

If `./chart` is not a local chart directory, use the actual local chart path or omit the `helm lint` command.

Review the rendered output to confirm that the intended components are enabled or disabled and that the HTTPRoute is generated as expected.

### 9.3 Install or upgrade

```bash
helm upgrade --install monitoring \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values values.yaml
```

For a local chart:

```bash
helm upgrade --install monitoring ./chart \
  --namespace monitoring \
  --create-namespace \
  --values values.yaml
```

Pin and document the chart version used in production to make deployments reproducible.

### 9.4 Check the deployment

```bash
helm list -n monitoring
kubectl get pods -n monitoring
kubectl get svc -n monitoring
kubectl get httproute -n monitoring
```

The commands assume that the chart is installed in the `monitoring` namespace and that the relevant resources are created there.

If the HTTPRoute is deployed in a different namespace, adjust the command accordingly.

---

## 10. Verification

### 10.1 Verify Prometheus health

Find the Prometheus service:

```bash
kubectl get svc -n monitoring
```

Forward a local port to the appropriate Prometheus service:

```bash
kubectl port-forward -n monitoring svc/<prometheus-service-name> 9090:9090
```

Then open the Prometheus interface at:

```text
http://localhost:9090
```

Replace `<prometheus-service-name>` with the actual service name returned by Kubernetes.

### 10.2 Check scrape targets

Open the Prometheus targets page:

```text
http://localhost:9090/targets
```

Check that the expected monitoring targets are present and healthy.

### 10.3 Check remote-write status

In the Prometheus query interface, inspect:

```promql
prometheus_remote_storage_samples_pending
```

This metric can help identify samples waiting to be sent.

Also inspect:

```promql
prometheus_remote_storage_samples_failed_total
```

And:

```promql
prometheus_remote_storage_samples_retried_total
```

The exact metrics available can vary by Prometheus version. Verify their presence before using them in dashboards or alert rules.

Review Prometheus logs for remote-write errors:

```bash
kubectl logs -n monitoring <prometheus-pod-name>
```

Search for messages related to remote write, connection failures, HTTP errors, timeouts, or rejected samples.

### 10.4 Verify external ingestion

Check each destination independently.

Confirm that:

- The receiving service is healthy.
- Remote-write requests are accepted.
- New samples appear in queries.
- Expected labels are preserved.
- No unexpected ingestion errors occur.

A successful HTTP connection alone does not prove that all samples are being ingested correctly.

### 10.5 Verify the Gateway API route

```bash
kubectl get httproute -n monitoring
kubectl describe httproute <httproute-name> -n monitoring
kubectl get gateway -n envoy-gateway-system
```

Review the route's status conditions and confirm that the intended Gateway has accepted the route.

---

## 11. Troubleshooting

### Prometheus pod is not starting

Check:

```bash
kubectl get pods -n monitoring
kubectl describe pod <prometheus-pod-name> -n monitoring
kubectl logs <prometheus-pod-name> -n monitoring
```

Common causes include invalid configuration, insufficient resources, scheduling problems, storage issues, or missing CRDs.

### No ServiceMonitor or PodMonitor targets appear

Check:

- The resources exist.
- Prometheus selectors match the resources.
- Namespace selectors are correct.
- Monitored services or pods expose the expected ports and paths.
- Required RBAC permissions exist.
- The resources contain valid endpoint definitions.

An empty label selector does not override every other discovery requirement.

### Remote-write samples are not arriving

Check:

1. Connectivity from the Prometheus pod to both endpoints.
2. Whether the receiving software is listening on port `9090`.
3. Whether the `/api/v1/write` endpoint is enabled.
4. Whether HTTP requests are accepted.
5. Whether firewalls or network policies block traffic.
6. Whether the receiver rejects samples because of validation or capacity limits.
7. Prometheus remote-write queue and error metrics.
8. Receiver-side logs.

Test both endpoints independently because one destination may work while the other fails.

### HTTPRoute is not working

Check:

- Gateway API CRDs are installed.
- The parent Gateway exists.
- The route is accepted by the Gateway.
- The hostname matches the Gateway listener.
- DNS points to the intended endpoint.
- TLS and listener settings are correct.
- The route is permitted by the Gateway configuration.

### Historical metrics are missing

The local Prometheus retention is configured as one day.

If historical metrics are required beyond this period, verify that they have been forwarded successfully and retained by the external monitoring infrastructure.

The remote-write configuration alone does not guarantee long-term retention. The external systems must store the incoming samples according to their own retention policies.

---

## 12. Operational Considerations

### Local retention and resource usage

One-day retention reduces the amount of data retained locally compared with longer retention periods. It does not eliminate the need to size the TSDB and persistent storage appropriately.

### Remote-write reliability

Monitor remote-write failures, pending samples, retries, and ingestion delays.

If a destination is unavailable, Prometheus can buffer samples in its remote-write queue and WAL-backed storage, subject to its configuration and limits. A prolonged outage can eventually cause samples to be lost if they cannot be delivered before the relevant data is discarded or overwritten.

### Duplicate data

Both destinations receive the same intended metric stream.

If the external monitoring architecture later combines both copies, ensure that the query layer and storage architecture handle duplication and replica labels correctly.

### Configuration management

Store the Helm values in version control and review changes before deployment.

Avoid committing credentials or other sensitive information. Keep the deployed chart version, Kubernetes version, and configuration changes documented.

---

## 13. Summary

The `kube-prometheus-stack` repository deploys Prometheus inside Kubernetes as a lightweight metrics collection component.

Its primary responsibilities are:

- Discovering configured monitoring targets.
- Collecting application and Kubernetes metrics.
- Retaining metrics locally for one day.
- Forwarding metrics to two external endpoints.
- Exposing Prometheus through a Gateway API HTTPRoute.
- Providing the Prometheus Operator CRDs required by Kubernetes-native monitoring resources.

Grafana, Alertmanager, Node Exporter, kube-state-metrics, default rules, and several Kubernetes control-plane monitoring targets are disabled in this deployment.

Long-term storage, centralized querying, dashboards, and alert notifications are handled by other components of the overall monitoring platform.