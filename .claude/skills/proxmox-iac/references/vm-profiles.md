# VM Sizing Profiles

Use these as starting points when a developer asks to add a new VM type.
Adjust based on the actual workload — these are conservative lab defaults.

---

## Profiles

| Profile | Use For | CPU | RAM | Disk | Autoscale Threshold |
|---|---|---|---|---|---|
| **micro** | Lightweight agents, proxies, exporters | 1 | 256 MB | 5G | N/A (single instance) |
| **small** | Web servers, API services, light databases | 1 | 512 MB | 10G | CPU > 70% |
| **medium** | App servers, caches (Redis), message queues | 2 | 1024 MB | 20G | CPU > 65% |
| **large** | Databases (Postgres, MySQL), batch jobs | 2 | 2048 MB | 40G | CPU > 60% |
| **xlarge** | GPU workloads, model serving, heavy compute | 4 | 4096 MB | 80G | CPU > 55% |

---

## Common Services — Recommended Sizing

| Service | Profile | Notes |
|---|---|---|
| nginx / web server | small | Default web-node profile |
| Node.js API | small–medium | Depends on concurrency |
| Redis | medium | Set `maxmemory` to 60% of VM RAM |
| PostgreSQL | large | Needs dedicated disk for data dir |
| MySQL / MariaDB | large | Same as Postgres |
| RabbitMQ / NATS | medium | Queue depth drives memory |
| Prometheus | medium | Retention period drives disk |
| Grafana | small | CPU light, needs Prometheus to query |
| Elasticsearch | xlarge | Memory-hungry — don't under-size |
| Jenkins / GitLab Runner | large | Spikes during builds |

---

## Lab Constraints

Total VirtualBox VM RAM budget:

| Component | RAM |
|---|---|
| Proxmox host overhead | ~1 GB |
| Each web-node VM | 512 MB |
| Max 5 web nodes | 2.5 GB |
| **Available for new VMs** (16 GB host) | ~12 GB |

Never provision more RAM than the Proxmox host has available. The Proxmox dashboard
shows free memory in real time — check before provisioning large VMs.

---

## Autoscale Threshold Guidance

| Workload Pattern | Recommended Up Threshold | Recommended Down Threshold | Cooldown |
|---|---|---|---|
| Web traffic (variable) | 70% | 25% | 60s |
| Batch jobs (spiky) | 85% | 20% | 120s |
| Steady-state services | 60% | 30% | 90s |
| Memory-bound (DB) | Use memory % instead | — | 120s |

For memory-bound workloads, the autoscaler needs to be modified to read `node_memory_MemAvailable_bytes`
from the node exporter instead of CPU load. See `autoscale/autoscale.sh` — replace the
`get_node_cpu` function with a memory query against port 9100.
