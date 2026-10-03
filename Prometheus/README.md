Your current README does not match the repo (wrong paths, Query on `:9090`, Vault, Docker Compose, a single `thanos` role, 15d retention). Use this as `README.md`.

```markdown
# Prometheus Ansible

Ansible project that deploys a highly available Prometheus stack with Thanos, Grafana, and optional Tempo.

Prometheus keeps **10 days** locally. Thanos Sidecar can ship TSDB blocks to Ceph RGW (S3). Thanos Store Gateway serves history. Thanos Compactor enforces **30 days** in the bucket. Grafana queries **Thanos Query**, not Prometheus directly.

## Contents

- [Architecture](#architecture)
- [Components](#components)
- [Repository layout](#repository-layout)
- [Requirements](#requirements)
- [Configuration](#configuration)
- [Inventory](#inventory)
- [Deployment](#deployment)
- [Lifecycle](#lifecycle)
- [Verification](#verification)
- [Ports](#ports)
- [Object storage](#object-storage)
- [Troubleshooting](#troubleshooting)
- [Security](#security)

## Architecture

```text
                         +-----------+
                         |  Grafana  |
                         +-----+-----+
                               |
                               | HTTP :10902
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
    | Prom 1     |      | Prom 2     |       | Ceph S3   |
    | 10 days    |      | 10 days    |       | 30 days   |
    +------------+      +------------+       +-----+-----+
                                                   ^
                                                   |
                                            +------+-------+
                                            |  Compactor   |
                                            |  singleton   |
                                            +--------------+
```

Without S3 (`thanos_enable_objstore: false`), Query talks only to the two sidecars. Store Gateway and Compactor are not required until the bucket exists.

Tempo is optional and independent (OTLP traces). Enable it with `tempo_enable: true` after its bucket exists.

## Components

| Role | Purpose |
|------|---------|
| `prometheus` | Two scrape replicas, unique `replica` label, local TSDB 10d |
| `thanos_sidecar` | StoreAPI for live data; optional upload of 2h blocks to S3 |
| `thanos_query` | Unified PromQL API for Grafana; dedup on `replica` |
| `thanos_store` | Reads historical blocks from S3 |
| `thanos_compactor` | One instance per bucket; compact, downsample, 30d retention |
| `grafana` | Dashboards; datasource is Thanos Query |
| `tempo` | Trace ingest (OTLP 4317/4318) and query API (3200) |

Prometheus HA is two independent scrapers, not a shared TSDB. Thanos Query merges them using `external_labels.replica`.

## Repository layout

```text
Prometheus-ansible/
├── inventory/
│   ├── group_vars/
│   │   └── all.yml          # all operational variables
│   └── hosts.yml
├── playbooks/
│   ├── clean-data.yml
│   ├── clean.yml
│   ├── lifecycle.yml
│   ├── reboot.yml
│   └── verify.yml
├── roles/
│   ├── prometheus/
│   ├── grafana/
│   ├── tempo/
│   ├── thanos_sidecar/
│   ├── thanos_query/
│   ├── thanos_store/
│   └── thanos_compactor/
├── .gitlab-ci.yml
├── ansible.cfg
├── Makefile
├── README.md
├── requirements.txt
├── requirements.yml
├── setup_env.sh
└── site.yml
```

Edit variables only in `inventory/group_vars/all.yml`. Do not treat role `defaults/` as the source of truth.

## Requirements

Control node:

- Ansible
- Python 3
- SSH key access to targets

Targets:

- Docker Engine
- Python 3 (`ansible_python_interpreter` in inventory)
- SSH and sudo

```bash
ansible --version
docker --version
```

Install collections:

```bash
ansible-galaxy collection install -r requirements.yml
```

## Configuration

File: `inventory/group_vars/all.yml`

Important keys:

```yaml
thanos_enable_objstore: false
tempo_enable: false
grafana_tracing_enabled: false

prometheus_retention: "10d"

thanos_objstore_bucket: "thanos-metric"
thanos_objstore_endpoint: "s3-devops.test.ir"
thanos_objstore_access_key: "CHANGE_ME"
thanos_objstore_secret_key: "CHANGE_ME"
thanos_objstore_insecure: true

thanos_compactor_retention_raw: "30d"
thanos_compactor_retention_5m: "30d"
thanos_compactor_retention_1h: "30d"
```

Leave `thanos_enable_objstore: false` until the Ceph bucket and keys exist. Sidecar then runs without `--objstore.config-file`. Query does not dial Store Gateway (`:10905`). Grafana does not send OTLP to Tempo.

Each Prometheus host must have a unique `replica_name` in `hosts.yml` (`prom1`, `prom2`). Do not change `external_labels` after data has been uploaded to S3.

## Inventory

File: `inventory/hosts.yml`

```yaml
all:
  vars:
    ansible_user: root
    ansible_port: 10022
    ansible_python_interpreter: /usr/bin/python3.13
    ansible_ssh_private_key_file: /root/.ssh/ansible_ed25519
  children:
    prometheus:
      hosts:
        etcd02:
          ansible_host: 192.168.114.135
          replica_name: prom1
        etcd03:
          ansible_host: 192.168.114.136
          replica_name: prom2
    thanos_sidecar:
      hosts:
        etcd02:
          ansible_host: 192.168.114.135
        etcd03:
          ansible_host: 192.168.114.136
    thanos_query:
      hosts:
        etcd02:
          ansible_host: 192.168.114.135
    thanos_store:
      hosts:
        etcd03:
          ansible_host: 192.168.114.136
    thanos_compactor:
      hosts:
        etcd03:
          ansible_host: 192.168.114.136
    grafana:
      hosts:
        etcd02:
          ansible_host: 192.168.114.135
    tempo:
      hosts:
        etcd03:
          ansible_host: 192.168.114.136
```

Sidecar must be co-located with Prometheus (shared TSDB volume). Compactor must be a **single** host per bucket.

Check SSH:

```bash
ansible all -m ping -i inventory/hosts.yml
```

## Deployment

Syntax check:

```bash
ansible-playbook site.yml --syntax-check -i inventory/hosts.yml
```

Install **one app at a time**. Order matters.

```bash
INV="-i inventory/hosts.yml"

ansible-playbook site.yml --tags prometheus $INV
ansible-playbook playbooks/verify.yml --tags prometheus $INV

ansible-playbook site.yml --tags thanos_sidecar $INV
ansible-playbook playbooks/verify.yml --tags thanos_sidecar $INV

ansible-playbook site.yml --tags thanos_query $INV
ansible-playbook playbooks/verify.yml --tags thanos_query $INV

ansible-playbook site.yml --tags grafana $INV
ansible-playbook playbooks/verify.yml --tags grafana $INV
```

Skip until S3 is ready:

```text
thanos_store
thanos_compactor
tempo
```

After the bucket and keys are set (`thanos_enable_objstore: true`):

```bash
ansible-playbook site.yml --tags thanos_sidecar $INV
ansible-playbook site.yml --tags thanos_store $INV
ansible-playbook site.yml --tags thanos_compactor $INV
ansible-playbook site.yml --tags thanos_query $INV
```

Query must be redeployed so it adds `--endpoint=<store-host>:10905`. First blocks appear in S3 about **2 hours** after the sidecar shipper is enabled (`min-block-duration` = `max-block-duration` = `2h`).

Full verify:

```bash
ansible-playbook playbooks/verify.yml -i inventory/hosts.yml
```

Makefile shortcuts (if present):

```bash
make deploy-prometheus
make verify-prometheus
make deploy-grafana
```

Do not use `--tags prometheus,restart`. Ansible tags are OR, not AND. Use `playbooks/lifecycle.yml` with `service_action`.

## Lifecycle

```bash
INV="-i inventory/hosts.yml"
APP=prometheus   # prometheus | thanos_sidecar | thanos_store | thanos_compactor | thanos_query | grafana | tempo

ansible-playbook playbooks/lifecycle.yml --tags "$APP" -e service_action=start   $INV
ansible-playbook playbooks/lifecycle.yml --tags "$APP" -e service_action=stop    $INV
ansible-playbook playbooks/lifecycle.yml --tags "$APP" -e service_action=restart $INV
ansible-playbook playbooks/lifecycle.yml --tags "$APP" -e service_action=reset   $INV
```

`reset` recreates the container and **keeps volumes**. It does not wipe TSDB or S3.

## Verification

| Service | URL |
|---------|-----|
| Prometheus | `http://<host>:9090/-/healthy` |
| Sidecar | `http://<host>:10904/-/healthy` |
| Query | `http://<host>:10902/-/healthy` |
| Query stores | `http://<host>:10902/stores` |
| Store Gateway | `http://<host>:10906/-/healthy` |
| Compactor | `http://<host>:10908/-/healthy` |
| Grafana | `http://<host>:3000/api/health` |
| Tempo | `http://<host>:3200/ready` |

Grafana datasource (Prometheus):

```text
http://thanos-query:10902
```

Do not point Grafana at Prometheus `:9090` if you need HA deduplication and S3 history.

On Query `/stores` with S3 disabled you should see two sidecars only. With S3 enabled you should see two sidecars plus Store Gateway.

## Ports

| Service | Host HTTP | Host gRPC |
|---------|-----------|-----------|
| Prometheus | 9090 | - |
| Sidecar | 10904 | 10901 |
| Query | 10902 | 10903 |
| Store Gateway | 10906 | 10905 |
| Compactor | 10908 | - |
| Grafana | 3000 | - |
| Tempo | 3200 | 4317 (OTLP gRPC), 4318 (OTLP HTTP) |

Sidecar HTTP is published on **10904** so it does not clash with Query HTTP **10902** on the same host.

## Object storage

Ceph RGW must be reachable from sidecar, store, and compactor hosts.

1. Create a dedicated RGW user and bucket (`thanos-metric`).
2. Put access key, secret, endpoint, and bucket in `inventory/group_vars/all.yml`.
3. Set `thanos_enable_objstore: true`.
4. Deploy sidecar, store, compactor, then query.

Compactor is a **singleton**. Two compactors on the same bucket will corrupt data.

Objstore template (sidecar, store, compactor):

```text
roles/<role>/templates/objstore.yml.j2
```

Example:

```yaml
type: S3
config:
  bucket: {{ thanos_objstore_bucket }}
  endpoint: {{ thanos_objstore_endpoint }}
  access_key: {{ thanos_objstore_access_key }}
  secret_key: {{ thanos_objstore_secret_key }}
  insecure: {{ thanos_objstore_insecure | bool | lower }}
```

Each of those roles must contain that file. A missing template fails with `Could not find or access 'objstore.yml.j2'`.

Tempo uses a separate bucket (`tempo_objstore_bucket`). Do not deploy Tempo until that bucket exists (`tempo_enable: true`).

## Troubleshooting

**Prometheus handler: connection refused on `/-/reload`**

The reload handler ran before Prometheus was listening. Wait for `/-/healthy` on `127.0.0.1`, and skip reload when the container was just created.

**Sidecar assert: S3 keys**

Set `thanos_enable_objstore: false` until keys are real. The assert must run only when objstore is enabled.

**Query: `dial tcp 192.168.114.136:10905: connection refused`**

Query is targeting Store Gateway, which is not running. Keep `thanos_enable_objstore: false` and redeploy Query so store endpoints are omitted.

**Grafana: `dial tcp 192.168.114.136:4317: connection refused`**

Grafana OTLP tracing points at Tempo. Keep `tempo_enable: false` and `grafana_tracing_enabled: false`, then redeploy Grafana.

**Store role: missing `objstore.yml.j2`**

Create `roles/thanos_store/templates/objstore.yml.j2` (and the same file under `thanos_compactor`). Copy from sidecar if that template already exists.

**Sidecar cannot reach Prometheus**

They must share `monitoring_network`. URL should be `http://prometheus:9090`. TSDB volume must be mounted rw at `/prometheus` so the shipper can write `thanos.shipper.json`.

**No data in Grafana**

1. Prometheus `/-/healthy`
2. Sidecar `/-/healthy`
3. Query `/stores`
4. Grafana datasource `http://thanos-query:10902`

**No objects in S3**

Sidecar only uploads completed 2h blocks. Confirm objstore is enabled, keys work, and `--objstore.config-file` is on the sidecar command.

## Security

- Put credentials only in `inventory/group_vars/all.yml` (mode `0600`). Do not commit real keys.
- Do not expose Thanos gRPC ports (10901, 10903, 10905) on public networks.
- Restrict 9090, 10902, 3000, 3200, 4317, and 4318 with host firewall rules.
- Use a dedicated RGW user for Thanos, not Ceph admin credentials.
- Change the Grafana admin password from the default.

This repository does not use Ansible Vault. If you add it later, encrypt only the secret keys and keep the rest of `all.yml` in plain YAML.

