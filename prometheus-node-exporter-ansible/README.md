# Prometheus Node Exporter Ansible

## Overview

This repository uses Ansible to automate the installation and configuration of Prometheus Node Exporter across servers in the infrastructure.

Node Exporter exposes operating system and hardware metrics that Prometheus can collect for monitoring, alerting, and troubleshooting.

This repository enables centralized monitoring of servers outside Kubernetes, complementing the monitoring components deployed inside the Kubernetes cluster.

## Purpose

The main objectives of this repository are to:

- Automate Node Exporter installation across multiple servers.
- Standardize exporter configuration across the infrastructure.
- Manage the Node Exporter service using Ansible.
- Configure the exporter to expose metrics for Prometheus.
- Apply common configuration tasks consistently across servers.
- Simplify maintenance and updates.
- Extend centralized monitoring to all supported servers.

## Architecture

```text
                 External Servers
       +--------------------------------+
       |                                |
       |  Server 1                      |
       |  +--------------------------+  |
       |  | Prometheus Node Exporter |  |
       |  | Port: 9100              |  |
       |  +------------+-------------+  |
       |               |                |
       +---------------|----------------+
                       |
                       | HTTP /metrics
                       |
                       v
                +---------------+
                |               |
                |  Prometheus   |
                |               |
                +-------+-------+
                        |
                        v
                 +-------------+
                 | Thanos Query|
                 +------+------+
                        |
                        v
                   +---------+
                   | Grafana |
                   +---------+
```

The diagram represents the logical monitoring flow. The actual integration depends on the Prometheus scrape configuration and the deployed Thanos architecture.

Ansible is used to install and configure Node Exporter on the target servers. Prometheus subsequently scrapes the metrics exposed by those exporters.

## Repository Structure

```text
prometheus-node-exporter-ansible/
├── inventory/
│
├── roles/
│   ├── _common/
│   │   ├── handlers/
│   │   ├── meta/
│   │   │   ├── argument_specs.yml
│   │   │   └── main.yml
│   │   ├── tasks/
│   │   │   ├── configure.yml
│   │   │   ├── install.yml
│   │   │   ├── preflight.yml
│   │   │   └── selinux.yml
│   │   ├── templates/
│   │   │   └── web_config.yml.j2
│   │   └── vars/
│   │
│   └── node_exporter/
│       ├── defaults/
│       ├── handlers/
│       ├── meta/
│       │   ├── argument_specs.yml
│       │   └── main.yml
│       ├── tasks/
│       │   ├── configure.yml
│       │   ├── main.yml
│       │   └── preflight.yml
│       ├── templates/
│       │   └── node_exporter.service.j2
│       └── vars/
│
├── .gitignore
├── .yamllint
├── .ansible-lint
├── node_exporter.yml
├── README.md
└── requirements.txt
```

*Note: This structure is based on the repository layout provided. Additional files or nested directories may exist.*

## Components

### 1. Inventory

The `inventory/` directory contains the target hosts and groups used by Ansible.

It determines which servers receive the Node Exporter installation and allows servers to be organized into groups.

Inventory variables can also define connection settings and other deployment parameters.

### 2. `_common` Role

**Path:** `roles/_common/`

This role contains shared tasks and configuration used by the monitoring deployment.

Based on the directory structure, its responsibilities include:

| Component | Purpose |
|---|---|
| `tasks/preflight.yml` | Performs preliminary checks before installation. |
| `tasks/install.yml` | Handles installation-related operations. |
| `tasks/configure.yml` | Applies common configuration. |
| `tasks/selinux.yml` | Handles SELinux-related configuration where required. |
| `templates/web_config.yml.j2` | Provides a template for web configuration. |
| `handlers/` | Contains handlers for actions triggered by configuration changes. |
| `meta/argument_specs.yml` | Defines argument specifications for the role. |
| `meta/main.yml` | Contains role metadata and dependencies, if configured. |
| `vars/` | Contains role variables. |

The exact behavior depends on the contents of the task files and templates.

### 3. `node_exporter` Role

**Path:** `roles/node_exporter/`

This role manages the Node Exporter deployment.

Its directory structure includes:

| Component | Purpose |
|---|---|
| `tasks/main.yml` | Entry point for the role's task execution. |
| `tasks/preflight.yml` | Performs checks before configuration or installation. |
| `tasks/configure.yml` | Applies Node Exporter configuration. |
| `templates/node_exporter.service.j2` | Generates the systemd service configuration. |
| `defaults/` | Contains default variables, if defined. |
| `handlers/` | Contains handlers for service-related actions. |
| `meta/argument_specs.yml` | Defines the role's argument specifications. |
| `meta/main.yml` | Contains role metadata and dependencies, if configured. |
| `vars/` | Contains role variables. |

The role is intended to configure Node Exporter and manage its service on the target servers.

### 4. Main Playbook

**File:** `node_exporter.yml`

This is the apparent main playbook for the deployment.

It is expected to select the target hosts and invoke the required roles and tasks.

The exact execution flow should be confirmed by inspecting `node_exporter.yml`.

### 5. Requirements

**File:** `requirements.txt`

This file may contain Python dependencies required by the repository.

Review its contents to determine which packages must be installed before running the playbook.

If the repository also uses Ansible collections or roles from Ansible Galaxy, document their installation separately if they are defined in another requirements file.

## Prerequisites

Before deploying Node Exporter, ensure that:

- Ansible is installed on the control machine.
- The target servers are accessible over SSH.
- The Ansible user has the required privileges.
- The target operating systems are supported by the playbooks.
- Required Python packages and Ansible dependencies are installed.
- TCP port `9100` is available for the Node Exporter metrics endpoint, unless another port is configured.
- Prometheus can reach the target servers over the configured network.
- Firewall and SELinux policies permit the required communication.

## Deployment

### 1. Configure the inventory

Add the servers that need to be monitored to the appropriate inventory.

For example:

```ini
[monitored_servers]
server1.example.com
server2.example.com
server3.example.com

[monitored_servers:vars]
ansible_user=ansible
```

Replace the example hostnames and username with your actual server details.

The example uses an INI inventory. Use the appropriate inventory format if your repository uses YAML or another supported format.

### 2. Verify connectivity

Test connectivity to the target servers:

```bash
ansible -i inventory/production/hosts.ini monitored_servers -m ping
```

Adjust the inventory path and group name to match your configuration.

The Ansible `ping` module verifies Ansible connectivity and Python availability on the target hosts. It does not use ICMP in the same way as the Linux `ping` command.

### 3. Review the playbook

Before deploying, review:

```bash
cat node_exporter.yml
```

Check the target host group, role execution, variables, and any required privileges.

### 4. Run the deployment

Execute the main playbook:

```bash
ansible-playbook -i inventory/production/hosts.ini node_exporter.yml
```

Replace the example inventory path with the correct path in your repository.

### 5. Verify the installation

Connect to a target server and check the Node Exporter service:

```bash
sudo systemctl status node_exporter
```

Check whether the exporter is listening on port `9100`:

```bash
sudo ss -lntp | grep 9100
```

Test the metrics endpoint:

```bash
curl http://localhost:9100/metrics
```

The endpoint should return Prometheus-formatted metrics.

If the service name, port, or listening address differs in your implementation, use the values defined by the role.

## Prometheus Integration

Once Node Exporter is running, Prometheus must be configured to scrape its metrics endpoint.

Example:

```yaml
scrape_configs:
  - job_name: "external-node-exporter"
    static_configs:
      - targets:
          - "server1.example.com:9100"
          - "server2.example.com:9100"
          - "server3.example.com:9100"
```

This is an illustrative configuration. Integrate it into the actual Prometheus configuration managed by your infrastructure.

After applying the configuration, verify that the targets appear as `UP` in Prometheus.

The collected metrics can then be queried through Prometheus or Thanos and visualized in Grafana.

## Monitoring Capabilities

Node Exporter exposes operating system and hardware metrics, including:

- CPU statistics.
- Memory usage and availability.
- Filesystem capacity and usage.
- Disk I/O statistics.
- Network interface traffic and errors.
- System load averages.
- Additional operating system metrics provided by enabled collectors.

These metrics help identify resource saturation, server availability issues, disk capacity problems, and network-related issues.

The exact metric set depends on the Node Exporter version, enabled collectors, and operating system.

## Security

For production deployments:

- Restrict port `9100` to authorized monitoring systems.
- Do not expose Node Exporter directly to the public internet.
- Use SSH keys or an approved authentication mechanism for Ansible.
- Store sensitive credentials using an approved secrets-management solution.
- Review SELinux changes and ensure that they are limited to what is required.
- Use least-privilege access wherever possible.
- Review exporter web configuration and TLS/authentication settings where required.

## Troubleshooting

### Node Exporter is not running

Check the service status:

```bash
sudo systemctl status node_exporter
```

Inspect service logs:

```bash
sudo journalctl -u node_exporter -n 100 --no-pager
```

### Metrics are not available

Check the listening port:

```bash
sudo ss -lntp | grep 9100
```

Test the endpoint locally:

```bash
curl http://localhost:9100/metrics
```

Then test the endpoint from the Prometheus server:

```bash
curl http://server1.example.com:9100/metrics
```

Check firewall rules, routing, DNS resolution, and the configured listening address if the endpoint cannot be reached.

### Ansible deployment fails

Review the Ansible output and check:

- SSH connectivity.
- Privilege escalation permissions.
- Inventory variables.
- Role defaults and required variables.
- Target operating system compatibility.
- SELinux configuration.
- Python and Ansible dependencies.

Use verbose output for additional debugging:

```bash
ansible-playbook -i inventory/production/hosts.ini node_exporter.yml -vvv
```

Do not include sensitive credentials or private keys in shared debugging output.

## Maintenance

Use Ansible to maintain a consistent deployment across monitored servers.

Recommended maintenance tasks include:

- Updating Node Exporter versions.
- Reviewing exporter configuration.
- Verifying service health.
- Updating inventory when servers are added or removed.
- Validating firewall access.
- Testing playbook changes before production deployment.
- Checking that all expected Prometheus targets remain healthy.

