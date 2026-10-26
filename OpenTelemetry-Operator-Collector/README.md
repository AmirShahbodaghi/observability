# OpenTelemetry Operator and Collector

## 1. Overview

This repository manages OpenTelemetry components in Kubernetes using a Helm chart and additional Kubernetes YAML manifests.

Its primary responsibility is to provide a centralized telemetry collection pipeline for applications running inside Kubernetes. It receives application metrics and traces, enriches telemetry with Kubernetes metadata, exposes metrics for Prometheus, and forwards traces to Tempo.

The repository contains two types of configuration:

- **Helm chart and custom values:** Install and configure the OpenTelemetry Operator and its supporting resources.
- **Additional Kubernetes YAML manifests:** Configure the OpenTelemetry Collector, telemetry instrumentation, Prometheus scraping, and the required permissions.

## 2. Repository Responsibilities

### 2.1 OpenTelemetry Operator — Helm Chart

The Helm chart installs and configures the OpenTelemetry Operator in Kubernetes.

Its responsibilities include:

- Managing the lifecycle of OpenTelemetry custom resources.
- Creating the required Custom Resource Definitions (CRDs).
- Managing admission webhooks for validating and handling OpenTelemetry resources.
- Configuring the Operator and Collector container images.
- Configuring automatic instrumentation images for supported languages.
- Creating the required RBAC resources.
- Restricting the Operator to Linux nodes through the configured node selector.

The Operator manages resources such as `OpenTelemetryCollector` and `Instrumentation`. It does not, by itself, guarantee that application telemetry is being collected or exported.

### 2.2 OpenTelemetry Collector — `OpenTelemetryCollector`

The `OpenTelemetryCollector` manifest defines the actual telemetry collection pipeline.

Its responsibilities include:

- Running two Collector replicas in deployment mode.
- Receiving telemetry through OTLP gRPC on port `4317`.
- Receiving telemetry through OTLP HTTP on port `4318`.
- Processing incoming telemetry before exporting it.
- Enriching telemetry with Kubernetes metadata.
- Exporting metrics in Prometheus format on port `8889`.
- Forwarding traces to the configured Tempo endpoint at `IP:4317`.

The Collector separates telemetry processing from individual applications, allowing applications to send telemetry to a common endpoint.

### 2.3 Collector Processors

The Collector configuration defines three processors.

**Memory Limiter**

Controls memory usage by applying configured limits to telemetry processing, helping reduce the risk of excessive memory consumption.

**Kubernetes Attributes Processor**

Adds Kubernetes metadata to telemetry when the relevant resource information can be identified. Configured attributes include:

- Namespace name.
- Deployment name.
- Pod name.
- Node name.
- Pod UID.

**Batch Processor**

Groups telemetry data into batches to improve processing and export efficiency.

### 2.4 Collector Receivers and Exporters

**OTLP Receiver**

Accepts telemetry sent by applications or other OpenTelemetry-compatible agents over gRPC and HTTP.

**Prometheus Exporter**

Exposes processed metrics on port `8889`, allowing Prometheus to scrape the Collector's exported metrics.

**Tempo Exporter**

Forwards processed traces to the configured trace backend at `IP:4317` using OTLP.

### 2.5 ServiceMonitor — Prometheus Integration

The `ServiceMonitor` manifest configures Prometheus scraping for the Collector's metrics endpoint.

Its responsibilities include:

- Selecting the Collector Service using its labels.
- Restricting service discovery to the `monitoring` namespace.
- Scraping the `prometheus` service port.
- Collecting metrics from the `/metrics` path every 15 seconds.
- Defining a scrape timeout of 10 seconds.

The `release: kube-prometheus-stack` label associates the ServiceMonitor with the Prometheus Operator's configured selection rules.

This manifest enables scraping only when the corresponding Service, labels, port, and Prometheus Operator selection settings match.

### 2.6 RBAC — Kubernetes Metadata Access

The `ClusterRole` and `ClusterRoleBinding` manifests define the permissions needed by the Collector's Kubernetes attributes processor.

Their responsibilities include:

- Allowing read access to Pods, Namespaces, and Nodes.
- Allowing read access to ReplicaSets.
- Granting these permissions to the `otel-collector` ServiceAccount in the `monitoring` namespace.

These permissions allow the Collector to retrieve Kubernetes resource information and associate it with telemetry.

### 2.7 .NET Instrumentation — `Instrumentation`

The `Instrumentation` manifest defines automatic instrumentation settings for supported .NET applications.

Its responsibilities include:

- Configuring the OTLP exporter endpoint for application telemetry.
- Sending telemetry to the Collector through OTLP HTTP on port `4318`.
- Enabling trace-context and baggage propagation.
- Configuring parent-based trace sampling with a sampling ratio of `1.0`.
- Enabling OTLP export for metrics and traces.
- Disabling log export through this instrumentation configuration.
- Configuring additional .NET metric sources.

Applications must be eligible for and configured to use the Operator's automatic instrumentation mechanism for these settings to take effect.

## 3. Telemetry Flow

The repository supports the following telemetry flow:

**Application traces and metrics**

.NET applications with automatic instrumentation send telemetry to the OpenTelemetry Collector through OTLP HTTP.

**Collector processing**

The Collector receives telemetry, applies memory protection, enriches it with Kubernetes metadata, and batches the data.

**Metrics flow**

The Collector exposes processed metrics through its Prometheus exporter. Prometheus discovers the endpoint through the `ServiceMonitor` and scrapes it.

**Trace flow**

The Collector forwards traces to the configured Tempo endpoint using OTLP gRPC.

