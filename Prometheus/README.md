Prometheus and Grafana Deployment with HA Replication
===================================================

```
+-------------------+
                 |      Grafana      |
                 +---------+---------+
                           | Queries (PromQL)
                           v
                 +-------------------+
                 |   Thanos Query    |
                 +----+---------+----+
                      |         |
         gRPC (Store) |         | gRPC (Store)
                      v         v
         +------------+---+ +---+------------+
         | Thanos Sidecar | | Thanos Sidecar |
         +--------+-------+ +-------+--------+
                  |                 | Local Disk
                  v                 v
         +--------+-------+ +-------+--------+
         | Prometheus 1   | | Prometheus 2   |
         | (Replica A)    | | (Replica B)    |
         +----------------+ +----------------+

```

```
Thanos Sidecar: Runs alongside each Prometheus instance. It exposes the Thanos Store API over gRPC, letting Thanos Query read fresh metrics directly from Prometheus's local TSDB (Time Series Database). Every 2 hours (when Prometheus flushes TSDB blocks to disk), the sidecar can also back up those finalized blocks.
```

```
Thanos Query: The brain of the read path. It presents a standard PromQL HTTP interface (so Grafana thinks it is talking to a regular Prometheus server). When a query comes in, it fan-outs the request to all connected endpoints (Sidecars, Store Gateways), merges the streams, deduplicates double-scraped data based on the replica label, and returns a single clean dataset.
```

This repository contains an Ansible deployment for:

- 2 Prometheus servers on separate hosts
- 1 Grafana server on a single host
- Thanos for HA replication and global query across Prometheus replicas

The playbook installs Prometheus and Grafana using best practices including:

- dedicated system users
- separate config and data directories
- systemd-managed services
- HA replication using Thanos sidecars and object storage
- Grafana datasource provisioning for global metrics queries

Files
-----

- ansible.cfg: Ansible configuration for this project
- ansible/site.yml: Main playbook for Prometheus and Grafana deployment
- ansible/inventory/hosts.yml: Sample inventory with 2 Prometheus hosts and 1 Grafana host
- ansible/inventory/group_vars/all.yml: Shared deployment variables and placeholders
- ansible/roles/common: Bootstrap packages and system users
- ansible/roles/prometheus: Prometheus install, configuration, and Prometheus systemd service
- ansible/roles/thanos: Thanos sidecar on Prometheus hosts and Thanos Query on Grafana host
- ansible/roles/grafana: Grafana install and datasource provisioning

How to use
----------

1. Replace the sample hostnames and ansible_host addresses in `ansible/inventory/hosts.yml`.
2. Update `ansible/inventory/group_vars/all.yml` with your Thanos object storage endpoint and credentials.
3. Use `ansible-vault` for secrets before running in production:
   - `ansible-vault encrypt_string 'YOUR_SECRET' --name 'thanos_objstore_secret_key'`
4. Run from the repository root:
   - `ansible-playbook -i ansible/inventory/hosts.yml ansible/site.yml --tags prometheus`
   - `ansible-playbook -i ansible/inventory/hosts.yml ansible/site.yml --tags "prometheus,thanos"`

Architecture
------------

Prometheus:
- Runs on two nodes for redundancy.
- Uses a shared scrape configuration and external labels to distinguish replicas.
- Each Prometheus instance has a Thanos sidecar that uploads blocks to object storage.

Grafana:
- Runs on a single node.
- Queries metrics through Thanos Query to provide a single global view.

Replication best practice
-------------------------

Prometheus does not provide native active-active replication by itself. The recommended pattern is:

1. Run two Prometheus servers with identical scrape configurations.
2. Attach a Thanos sidecar to each server.
3. Upload TSDB blocks to durable object storage.
4. Run Thanos Query to access a globally consistent, de-duplicated view.

This gives you:
- HA reads and failover
- replicated long-term storage
- central query access for Grafana

Customization
-------------

- Add application scrape jobs in `ansible/roles/prometheus/templates/prometheus.yml.j2`.
- Adjust retention, scrape interval, and ports in `ansible/inventory/group_vars/all.yml`.
- Extend Grafana provisioning with additional dashboards or datasources.

Prepaire
-------------

- chmod +x setup_env.sh
- ./setup_env.sh


- make setup
- make clean 
