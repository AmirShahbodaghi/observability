# kube-state-metrics

## Responsibility

This repository deploys **kube-state-metrics** into the Kubernetes cluster using a Helm chart.

kube-state-metrics collects information about the state of Kubernetes resources through the Kubernetes API and exposes that information as Prometheus metrics.

It provides visibility into the desired and current state of Kubernetes objects, helping monitoring systems identify resource health issues and configuration mismatches.

### Key Responsibilities

- Expose metrics about Kubernetes pods, deployments, StatefulSets, DaemonSets, Jobs, and other supported resources.
- Report desired and available replica counts for workloads.
- Expose pod status, container status, and restart-related information where supported.
- Provide Kubernetes resource metadata and status information.
- Make Kubernetes state metrics available for Prometheus to scrape.
- Support monitoring dashboards and alerting rules that depend on Kubernetes resource state.

### Integration

Prometheus scrapes metrics exposed by kube-state-metrics. These metrics can then be queried through Thanos and visualized in Grafana dashboards.

kube-state-metrics complements Node Exporter and application monitoring by providing **Kubernetes resource-state information**, rather than directly measuring operating system resource usage or application performance.

### Deployment

The component is installed and managed using Helm in the Kubernetes cluster.
