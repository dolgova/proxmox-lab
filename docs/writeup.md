# Proxmox Lab — Technical Writeup
**Maritime Capital · Private Cloud Administrator Assessment**

---

## What I Built

Rather than a minimal Proxmox exploration, I built a small production-style infrastructure to demonstrate how I'd approach the real role:

| Component | What it does |
|-----------|-------------|
| `bash/proxmox-init.sh` | Fully automates Proxmox post-install configuration |
| `terraform/` | Provisions VMs via Proxmox API — one variable controls node count |
| `ansible/` | Configures every VM identically: nginx, hello world site, Prometheus exporter |
| `dashboard/index.html` | Live monitoring dashboard, polls Proxmox API every 5s |
| `autoscale/autoscale.sh` | Monitors CPU across nodes, scales 1→5 automatically via Terraform |

---

## I. Approach & Order

**Mental model going in:** Proxmox is fundamentally a Debian Linux system with a web UI bolted on top. Everything it does is exposed via a REST API, which means it's fully automatable.

**Order of operations:**

1. Installed Proxmox VE 8.x in VirtualBox on Windows — enabled nested virtualization in VirtualBox settings (Processor → Enable Nested VT-x/AMD-V) before starting
2. Ran `proxmox-init.sh` after first boot to handle the subscription nag, repo config, and SSH key setup
3. Created an Ubuntu cloud-init template (VM 9000) — this is the key to fast provisioning; it means Terraform can clone a VM in ~30s instead of running a full OS install
4. Wrote Terraform using the Telmate provider to provision VMs by cloning that template
5. Terraform outputs write the IP list to `ansible/inventory.ini` automatically
6. Ansible playbook runs against all nodes — idempotent, so re-running it on existing nodes is safe
7. Built the dashboard to pull from the Proxmox API directly — no Grafana needed for this scale
8. Wrote the autoscaler as a bash loop that reads CPU metrics and calls `terraform apply` with a different `node_count`

**Tools used:** Proxmox docs, Telmate Terraform provider docs, Ansible docs, Claude for boilerplate acceleration

---

## II. What Surprised Me / Tripped Me Up

**Cloud-init template setup is non-obvious.** Proxmox's cloud-init integration requires the disk to be imported from a cloud image (not a standard ISO), then converted to a template. The ordering matters — you can't modify a template after converting it. I scripted this to avoid redoing it manually.

**VirtualBox nested virtualization.** On Windows with Intel CPUs, nested VT-x has to be enabled *before* the VM is created in VirtualBox settings, not after. This isn't obvious from the Proxmox installation guide.

**The Proxmox API uses self-signed TLS.** Terraform's Proxmox provider needs `pm_tls_insecure = true` in a lab environment. In production this would use a proper cert (Let's Encrypt works on internal hosts via DNS challenge).

**API token permissions are granular.** Creating a Terraform-specific API token with least-privilege permissions (VM.Allocate, Datastore.AllocateSpace, etc.) is the right practice. I scripted this in `proxmox-init.sh` rather than doing it manually through the UI.

---

## III. Similar vs Different (Compared to Other Platforms)

**Felt familiar:**
- The web UI concept — similar mental model to VMware vCenter or AWS EC2 console
- Cloud-init support — identical to how AWS/GCP handle user-data on instance launch
- REST API — same patterns as AWS EC2 API, just different endpoints
- LVM storage management — standard Linux behavior underneath

**Felt genuinely different:**
- **VMs and containers in one place.** Proxmox manages both QEMU VMs and LXC containers from the same interface. AWS separates EC2 from ECS/Fargate entirely
- **Cluster formation is simpler than expected.** Adding a second Proxmox node to a cluster is 3 commands — it's less ceremony than standing up a new ESXi host
- **No abstract "cloud" layer.** When something breaks, you SSH into the Proxmox host and it's just Linux. There's no opaque platform layer hiding the underlying behavior — I find this more comfortable for actual debugging
- **Ceph storage integration is built-in.** Shared storage for HA VM migration is a first-class feature, not an add-on

---

## IV. What I'd Automate at 20 Nodes

**The single highest-value automation: VM provisioning via Terraform + cloud-init templates.**

At 20 nodes, manual VM creation becomes untenable. The template + Terraform approach in this repo means a new node goes from zero to serving traffic in under 2 minutes:

```
terraform apply -var="node_count=20"  ← spins 20 nodes
# Terraform triggers Ansible automatically
# All 20 nodes identical, idempotent, documented as code
```

**Second priority: centralized monitoring.** At 20 nodes I'd replace the custom dashboard with Prometheus + Grafana — the node exporters are already installed by Ansible, so it's just pointing Prometheus at the inventory. The autoscale logic would read from Prometheus instead of polling node exporters directly.

**Third priority: GitLab CI/CD integration.** The Terraform and Ansible runs should be triggered by CI pipelines, not run manually. A `terraform.tfvars` change in Git → pipeline runs → infrastructure updates. This is how you get audit trails and peer review on infrastructure changes.

**Fourth: Proxmox cluster with Ceph.** At 20 nodes you want HA — if a hypervisor host fails, VMs should migrate automatically. That requires a Proxmox cluster (multiple physical hosts) with shared Ceph storage. The `proxmox-init.sh` script would be extended to handle cluster join and Ceph OSD setup.

---

## Autoscaling Demo

To see the autoscaler in action:

```bash
# Terminal 1 — start autoscaler
bash autoscale/autoscale.sh

# Terminal 2 — trigger stress test
bash autoscale/autoscale.sh --stress

# Watch the dashboard — nodes will appear as CPU climbs above 70%
open dashboard/index.html
```

Scale events:
- CPU avg > 70% → adds 1 node (up to 5 max)
- CPU avg < 25% → removes 1 node (down to 1 min)
- 60s cooldown between scale events to prevent thrashing

---

## AI Tools Used

Used Claude (Anthropic) to accelerate boilerplate — specifically for Terraform provider syntax, Ansible module options, and the dashboard JavaScript. All architectural decisions, tool choices, and configuration logic are my own. I find AI useful for "what's the exact syntax for this Ansible module" and counterproductive for "design the overall system" — the latter requires understanding the actual environment.
