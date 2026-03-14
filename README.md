# 🖥️ Proxmox Private Cloud Lab

A fully automated private cloud environment built on **Proxmox VE**, demonstrating Infrastructure as Code, configuration management, autoscaling, and real-time monitoring — all running on a single Windows machine.

> Built as part of a Private Cloud Administrator assessment for Maritime Capital, LLC.

---

## 📋 Table of Contents

- [What This Does](#what-this-does)
- [Architecture](#architecture)
- [Tool Selection & Why](#tool-selection--why)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Accessing the Hello World Sites](#accessing-the-hello-world-sites)
- [Monitoring Dashboard](#monitoring-dashboard)
- [Scaling Nodes](#scaling-nodes)
- [Autoscaling & Stress Test](#autoscaling--stress-test)
- [Ansible in Action](#ansible-in-action)
- [Project Structure](#project-structure)
- [Troubleshooting](#troubleshooting)
- [Security Notes](#security-notes)
- [Contributing](#contributing)

---

## What This Does

This lab provisions a mini production-style private cloud entirely on your local machine. Every component is automated — from provisioning VMs to deploying web servers to scaling under load.

| Capability | Implementation | Details |
|---|---|---|
| **Hypervisor** | Proxmox VE 8.x | Runs inside VirtualBox on Windows |
| **VM Provisioning** | Terraform | Clones Ubuntu VMs via Proxmox REST API |
| **Configuration** | Ansible | SSH keys, MOTD, nginx, hello world site, metrics agent, asset tracking |
| **Monitoring** | Custom HTML dashboard | Polls Proxmox API live — no server needed |
| **Autoscaling** | Bash autoscaler | Scales 1 → 5 nodes based on CPU threshold |
| **Hello World** | Nginx on each node | Each page shows its own hostname + IP |

---

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  Your Windows Machine                                        │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  VirtualBox                                            │  │
│  │                                                        │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │  Proxmox VE 8.x  (192.168.1.100:8006)            │  │  │
│  │  │                                                  │  │  │
│  │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐       │  │  │
│  │  │  │web-node-1│  │web-node-2│  │web-node-N│  ...  │  │  │
│  │  │  │:80 nginx │  │:80 nginx │  │:80 nginx │       │  │  │
│  │  │  │:9100 exp │  │:9100 exp │  │:9100 exp │       │  │  │
│  │  │  └──────────┘  └──────────┘  └──────────┘       │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  WSL2 / Ubuntu                                               │
│  ├── Terraform   → Proxmox API → creates / destroys VMs      │
│  ├── Ansible     → SSH into VMs → configures them            │
│  ├── Autoscaler  → CPU monitor → triggers terraform          │
│  └── dashboard/index.html → open in any browser              │
└──────────────────────────────────────────────────────────────┘
```

**What happens when a new node is added:**
1. Autoscaler (or you manually) triggers `terraform apply -var="node_count=N+1"`
2. Terraform calls the Proxmox API → clones the Ubuntu cloud-init template (~30s per VM)
3. Cloud-init configures the VM hostname, SSH key, and networking on first boot
4. Terraform writes the new VM IP to `ansible/inventory.ini`
5. Ansible SSHes in → installs nginx, deploys hello world site, starts Prometheus node exporter
6. Dashboard polls Proxmox API → new node card appears within 5 seconds

---

## Tool Selection & Why

### Proxmox VE — Hypervisor
Chosen over VMware ESXi or plain KVM because:
- **Free** — no licence required for lab or production use
- **REST API is first-class** — every UI action is also available via API, making full automation straightforward
- **Cloud-init support built in** — clone a template and a new VM self-configures without manual OS install
- **Unified interface** for both QEMU/KVM VMs and LXC containers
- Directly mirrors the tech stack specified in the role

### Terraform — VM Provisioning
Chosen for VM lifecycle (not Ansible) because:
- **Declarative** — you describe the desired end state (`node_count = 3`), not the steps
- **Idempotent** — running `terraform apply` twice with the same vars changes nothing the second time
- **State tracking** — Terraform knows exactly which VMs it created and destroys only those on scale-down
- **Plan before apply** — preview a diff of changes before anything is touched
- The [Telmate Proxmox provider](https://registry.terraform.io/providers/Telmate/proxmox/latest) maps Terraform resources directly to Proxmox VM objects

### Ansible — Configuration Management
Chosen for what runs *inside* VMs because:
- **Agentless** — communicates over SSH, no pre-installed daemon required
- **Idempotent** — re-running a playbook on a healthy node produces zero changes
- **Roles** — the webserver role applies identically to 1 node or 20
- Clean division: Terraform owns the VM lifecycle, Ansible owns the OS and application layer

### Custom HTML Dashboard — Monitoring
Chosen over Prometheus + Grafana for this lab because:
- **Zero dependencies** — single `index.html`, open in any browser
- **Proxmox API** already returns CPU, RAM, disk, and uptime per VM — no separate pipeline needed
- Immediately presentable without a running server
- Note: Prometheus node exporter **is** installed on every VM by Ansible (port 9100) — ready to wire into Grafana at production scale

### Bash — Autoscaler
Chosen over Python or Go because:
- Calls the exact `terraform apply` and `ansible-playbook` commands a human operator would run
- Simple polling loop with clear decision logic — readable and auditable
- No additional runtime dependencies beyond what is already installed

---

## Prerequisites

### System Requirements

| Requirement | Minimum | Recommended |
|---|---|---|
| OS | Windows 10 | Windows 11 |
| RAM | 12 GB | 16 GB+ |
| Disk | 50 GB free | 80 GB free |
| CPU | VT-x / AMD-V enabled | 4+ cores |

**Verify CPU virtualisation is on:**
Task Manager → Performance → CPU → **Virtualization: Enabled**

If it shows Disabled, reboot into BIOS and enable Intel VT-x or AMD-V.

### Software to Install

| Tool | Download | Notes |
|---|---|---|
| VirtualBox 7.x | [virtualbox.org](https://www.virtualbox.org/wiki/Downloads) | Windows hosts package |
| VirtualBox Extension Pack | Same page | Must match your VirtualBox version |
| Proxmox VE 8.x ISO | [proxmox.com/en/downloads](https://www.proxmox.com/en/downloads) | Proxmox VE ISO Installer |
| WSL2 + Ubuntu | `wsl --install` in PowerShell (Admin) | Reboot required |
| Git | [git-scm.com](https://git-scm.com) | For cloning this repo |

Terraform and Ansible are installed **inside WSL2**, not on Windows.

---

## Installation

### Step 1 — VirtualBox & Proxmox VM

1. Install VirtualBox → then install the Extension Pack: **File → Tools → Extension Pack Manager**
2. Create a new VM with these exact settings:

   | Setting | Value |
   |---|---|
   | Name | Proxmox-VE |
   | Type | Linux / Debian (64-bit) |
   | RAM | 4096 MB min — 8192 MB recommended |
   | CPU | 2 cores min — 4 recommended |
   | Disk | 50 GB, VDI, Dynamically allocated |
   | Network | **Bridged Adapter** → your active NIC |

3. **Enable nested virtualisation** (VM must be powered off first):
   ```powershell
   # PowerShell as Administrator
   VBoxManage modifyvm "Proxmox-VE" --nested-hw-virt on
   ```
   > ⚠️ Without this, VMs inside Proxmox will not boot. This is the most commonly missed step.

4. Attach the ISO: VM Settings → Storage → CD icon → Choose a disk file → select the `.iso`

### Step 2 — Install Proxmox VE

1. Start the VM — boot from ISO → select **Install Proxmox VE (Graphical)**
2. Accept EULA → select the 50 GB virtual disk
3. On the Management Network screen set:

   | Field | Value |
   |---|---|
   | IP Address | `192.168.1.100/24` (adjust to your subnet) |
   | Gateway | Your router IP — usually `192.168.1.1` |
   | DNS | `8.8.8.8` |
   | Hostname | `pve.local` |

4. Set a strong root password → click **Install** (5–10 minutes)
5. Remove the ISO → reboot
6. Verify: open `https://192.168.1.100:8006` in your Windows browser → accept the cert warning → log in as `root`

### Step 3 — WSL2 Setup

```powershell
# PowerShell as Administrator
wsl --install
# Reboot, then set a WSL2 username and password when prompted
```

### Step 4 — Clone Repo & Run Init Script

```bash
# In WSL2 (Ubuntu terminal)

# Generate SSH key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""

# Copy key to Proxmox host
ssh-copy-id root@192.168.1.100

# Clone repo
git clone https://github.com/YOUR_USERNAME/proxmox-lab.git
cd proxmox-lab

# Upload and run init script on Proxmox
scp bash/proxmox-init.sh root@192.168.1.100:/root/
ssh root@192.168.1.100 'bash /root/proxmox-init.sh'
```

The init script: fixes APT repos, updates the system, creates the Ubuntu cloud-init template (VM 9000), and creates the Terraform API user + token.

**At the end of the script, save the token — it is only shown once:**
```
=========================================
  TERRAFORM API TOKEN — SAVE THIS OUTPUT
=========================================
Full token ID:  terraform@pve!terraform-token
Token value:    xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
=========================================
```

Then reboot Proxmox:
```bash
ssh root@192.168.1.100 'reboot'
```

### Step 5 — Install Terraform & Ansible

```bash
# In WSL2, inside the proxmox-lab directory
bash scripts/install-deps.sh

# Verify
terraform --version    # 1.6.x or higher
ansible --version      # 2.14.x or higher
```

### Step 6 — Provision VMs with Terraform

```bash
cd terraform

# Set your API token (replace with your actual value)
export TF_VAR_proxmox_api_token_secret="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Persist across sessions (optional)
echo 'export TF_VAR_proxmox_api_token_secret="YOUR_TOKEN"' >> ~/.bashrc

# Download the Proxmox provider
terraform init

# Preview what will be created (no changes made)
terraform plan

# Create 1 VM
terraform apply
# Type 'yes' when prompted
```

When complete, Terraform prints the VM IPs:
```
Outputs:
vm_ips  = { "web-node-1" = "192.168.1.101" }
web_urls = [ "http://192.168.1.101" ]
```

### Step 7 — Configure VMs with Ansible

Terraform writes `ansible/inventory.ini` automatically. Run the playbook:

```bash
cd ../ansible
ansible-playbook -i inventory.ini playbook.yml
```

Ansible installs on each VM: `nginx` (hello world site on port 80), `prometheus-node-exporter` (metrics on port 9100), and applies SSH hardening.

When the playbook finishes you will see:
```
PLAY RECAP
web-node-1 : ok=12  changed=10  unreachable=0  failed=0
```

---

## Accessing the Hello World Sites

Each VM runs nginx on **port 80**. After Ansible completes, open your Windows browser and navigate to the IP of any node:

```
http://192.168.1.101     ← web-node-1
http://192.168.1.102     ← web-node-2
http://192.168.1.103     ← web-node-3
```

> Get the IPs any time with: `terraform output` or by reading `ansible/inventory.ini`

**What the page looks like:**

```
┌────────────────────────────────┐
│                                │
│   Hello from                   │
│                                │
│        web-node-1              │
│                                │
│        192.168.1.101           │
│                                │
│   ● Node is running · Proxmox Lab │
│                                │
└────────────────────────────────┘
```

Each node shows its own unique hostname and IP. When you scale to 3 nodes, open three browser tabs — you can confirm each is a distinct VM serving its own page.

**Verify nginx from the terminal:**
```bash
# Quick HTTP check from WSL2
curl http://192.168.1.101

# Check HTTP status code only
curl -I http://192.168.1.101        # Expect: HTTP/1.1 200 OK

# Check nginx is running across all nodes at once
ansible web_nodes -i ansible/inventory.ini \
  -m shell -a "systemctl status nginx --no-pager" --become
```

**Check the raw Prometheus metrics endpoint on any node:**
```
http://192.168.1.101:9100/metrics
```
This is what the autoscaler reads to get CPU usage. You can see every system metric in Prometheus format.

---

## Monitoring Dashboard

The dashboard is a single self-contained HTML file — no web server, no install.

**Open it:**
```bash
# From WSL2
explorer.exe dashboard/index.html

# Or in Windows Explorer, navigate to the repo and double-click dashboard/index.html
```

---

### Connecting to Live Data

The dashboard opens in **demo mode** with sample data so it can be shown before connecting. To see live data:

1. **Proxmox Host** → `192.168.1.100`
2. **Port** → `8006` (default, leave as-is)
3. **Token** → your full token string including the prefix:
   ```
   terraform@pve!terraform-token=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   ```
4. Click **CONNECT**

The dashboard immediately loads your live nodes and refreshes every 5 seconds.

---

### Dashboard Panels Explained

**Summary strip (top row)** — shows aggregate health across all nodes:

| Panel | What It Shows |
|---|---|
| **Active Nodes** | VMs currently in `running` state out of 5 max |
| **Avg CPU** | Average CPU % across all running VMs — this is what the autoscaler watches |
| **Avg Memory** | Average RAM utilisation across all running VMs |
| **Uptime (host)** | How long the Proxmox hypervisor has been running |

**Node cards** — one card per VM, updating live every 5 seconds:

| Element | What It Shows |
|---|---|
| Name + pulsing dot | VM name and running/stopped status |
| IP address | The VM's network IP — click to open in new tab |
| CPU bar | Current CPU % — bar turns amber >60%, red >85% |
| Memory bar | Used RAM / total RAM |
| Disk bar | Used disk / total disk |
| Uptime | How long this specific VM has been running |
| ↗ Proxmox | Direct link to the Proxmox web UI |

**Bar colour guide:**

| Colour | CPU Range | Meaning |
|---|---|---|
| 🔵 Cyan | 0 – 59% | Normal |
| 🟡 Amber | 60 – 84% | Elevated — watch it |
| 🔴 Red | 85%+ | High — autoscaler will trigger scale-up |

**Scale controls panel:**

Use the **−** and **+** buttons to set your desired node count, then click **APPLY SCALE**. The panel generates and displays the correct `terraform apply` command — copy it and run it in WSL2.

**Activity log:**

Every event is timestamped at the bottom — connections, scale triggers, errors. New entries appear at the top.

---

## Scaling Nodes

### Manual Scaling

All commands run from the `terraform/` directory in WSL2:

```bash
cd terraform

# See what is currently running
terraform output

# Scale to 2 nodes
terraform apply -var="node_count=2"

# Scale to 3 nodes
terraform apply -var="node_count=3"

# Scale to maximum — 5 nodes
terraform apply -var="node_count=5"

# Scale back down to 1
terraform apply -var="node_count=1"

# Remove all VMs entirely
terraform destroy
```

**What happens on scale-up:**
1. Terraform calls Proxmox API → clones the cloud-init template for each new VM
2. New VMs boot and self-configure (hostname, SSH key, networking) via cloud-init
3. `ansible/inventory.ini` is updated with the new IPs
4. Ansible runs on new nodes only — existing nodes are untouched
5. New node cards appear on the dashboard at next poll cycle (~5s)

**What happens on scale-down:**
1. Terraform identifies VMs to remove (highest-numbered first)
2. Calls Proxmox API to gracefully stop and delete those VMs
3. `ansible/inventory.ini` is updated to remove their entries
4. Dashboard cards disappear at next poll cycle

---

## Autoscaling & Stress Test

The autoscaler watches average CPU across all running nodes and calls `terraform apply` automatically when thresholds are crossed.

### Autoscale Thresholds

| Condition | Action |
|---|---|
| Avg CPU **> 70%** | Add 1 node (up to max of 5) |
| Avg CPU **< 25%** | Remove 1 node (down to min of 1) |
| After each scale event | 60s cooldown before next decision |

### Running the Autoscaler

```bash
cd autoscale

# Start in foreground — see live output (Ctrl+C to stop)
bash autoscale.sh

# Start in background
bash autoscale.sh &

# Stop background autoscaler
kill %1
```

**What the autoscaler prints every 15 seconds:**
```
[14:22:01] Nodes: 1 active | Avg CPU: 18%  192.168.1.101:18%
[14:22:16] Nodes: 1 active | Avg CPU: 18%  192.168.1.101:18%
[14:22:31] CPU within range — no scaling needed
```

When a scale event fires:
```
[14:35:17] ⟳ SCALE CPU 74% > 70% threshold → scaling UP to 2 nodes
[14:35:47] ✓ Scaled to 2 nodes
```

---

### Running the Stress Test

The stress test installs the `stress` tool on your nodes and saturates CPU — causing the autoscaler to react and add nodes in real time.

**You need two WSL2 terminal windows open:**

**Terminal 1 — start the autoscaler:**
```bash
cd autoscale
bash autoscale.sh
```

**Terminal 2 — trigger the stress test:**
```bash
cd autoscale
bash autoscale.sh --stress
```

**Then open your browser to the dashboard** and watch nodes appear as CPU climbs.

---

### What to Expect During the Stress Test

```
Time 0:00  — 1 node running, CPU ~5%
             Stress tool installed and started on node-1
Time 0:30  — CPU climbs to ~85% on node-1
             Autoscaler detects avg > 70%
Time 1:00  — web-node-2 appears on dashboard
             CPU load is now split: node-1 ~50%, node-2 ~50%
Time 1:30  — If still >70%, node-3 is provisioned
             ...continues until CPU drops below 70% or 5 nodes reached
Time 5:00  — stress tool stops (300s timeout)
             CPU drops back below 25%
Time 5:60  — Cooldown expires, autoscaler begins scaling down
             Nodes removed one at a time until back to 1
```

**Watch the hello world sites during the test:**

Open a browser tab for each node IP as they come online:
```
http://192.168.1.101   ← node-1 (running before test starts)
http://192.168.1.102   ← node-2 (appears ~1 min into test)
http://192.168.1.103   ← node-3 (appears if load stays high)
```

Each page appears when its node finishes provisioning and Ansible has deployed nginx — roughly 90 seconds from the scale event.

---

## Ansible in Action

Ansible manages everything that runs *inside* each VM — packages, config files, SSH keys, services, and the login experience. All tasks are **idempotent**: re-running the playbook on a healthy node produces zero changes.

### What Ansible configures on every node

| What | How | Where to see it |
|---|---|---|
| nginx + hello world site | Jinja2 template → `/var/www/html/index.html` | `http://192.168.1.101` |
| SSH authorized keys | `authorized_key` module from central key files | `~/.ssh/authorized_keys` |
| Dynamic MOTD banner | Jinja2 template → `/etc/update-motd.d/01-proxmox-lab` | SSH into any node |
| Asset tracking file | Jinja2 template → `/etc/infra-info` | `cat /etc/infra-info` |
| Prometheus node exporter | Binary install + systemd unit | `http://192.168.1.101:9100/metrics` |
| SSH hardening | `lineinfile` on `/etc/ssh/sshd_config` | `sshd -T \| grep PermitRoot` |

---

### Demo 1 — The MOTD (Message of the Day)

Every node shows a live banner the moment you SSH in. The banner is rendered by a Jinja2 template — each node's hostname, IP, role, and service status are injected at deploy time.

```bash
# SSH into any node
ssh ubuntu@192.168.1.101
```

You'll see something like:

```
  ██████╗ ██████╗  ██████╗ ██╗  ██╗███╗   ███╗ ██████╗ ██╗  ██╗
  ...
                     Private Cloud Lab

  ┌─────────────────────────────────────────────────┐
  │  Node       : web-node-1                        │
  │  IP Address : 192.168.1.101                     │
  │  Cluster    : proxmox-lab                       │
  │  Role       : web-node (primary)                │
  │  Managed by : Ansible / Terraform               │
  │  Proxmox    : 192.168.1.100                     │
  └─────────────────────────────────────────────────┘

  System
  ──────────────────────────────────────────────────
  Uptime  : 2 hours, 14 minutes
  Load    : 0.08
  Memory  : 23% used
  Disk    : 2.1G/9.6G (22% used)

  Services
  ──────────────────────────────────────────────────
  ✓  nginx
  ✓  node_exporter

  ⚠  This system is managed by Ansible. Manual changes will be overwritten.
```

**Deploy or refresh the MOTD:**
```bash
cd ansible

# Deploy to all nodes
ansible-playbook -i inventory.ini playbook.yml --tags motd

# Deploy to one node
ansible-playbook -i inventory.ini playbook.yml --tags motd --limit web-node-1

# Preview what the MOTD outputs without SSHing in
ansible web_nodes -i inventory.ini \
  -m shell -a "/etc/update-motd.d/01-proxmox-lab" --become
```

---

### Demo 2 — SSH Key Management

Authorized keys are managed from a single source of truth: `group_vars/all.yml`. One playbook run distributes or revokes keys across every node simultaneously.

```
ansible/
├── group_vars/
│   └── all.yml                      ← central key list lives here
└── roles/
    └── ssh-keys/
        └── files/
            └── keys/
                ├── admin.pub        ← one file per person/service
                └── deploy-bot.pub
```

#### Add a new key

```bash
# 1. Put the public key file in the keys directory
cp ~/.ssh/id_rsa.pub ansible/roles/ssh-keys/files/keys/yourname.pub

# 2. Register it in group_vars/all.yml
#    Under ssh_authorized_keys:, add:
#      - yourname.pub

# 3. Push to all nodes
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --tags ssh-keys
```

Ansible output shows exactly which nodes were updated:
```
TASK [Add authorized keys from key files] ****
changed: [web-node-1] => (item=yourname.pub)
changed: [web-node-2] => (item=yourname.pub)
```

#### Revoke a key

```bash
# 1. Remove the filename from ssh_authorized_keys in group_vars/all.yml
# 2. Add the full key string to ssh_revoked_keys:
#      ssh_revoked_keys:
#        - "ssh-rsa AAAA... oldkey@laptop"
# 3. Push revocation to all nodes
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --tags ssh-keys
```

#### Audit who can access what

```bash
# List authorized keys on every node
ansible web_nodes -i ansible/inventory.ini \
  -m shell -a "cat /home/ubuntu/.ssh/authorized_keys" --become

# Count keys per node
ansible web_nodes -i ansible/inventory.ini \
  -m shell -a "wc -l /home/ubuntu/.ssh/authorized_keys" --become
```

---

### Demo 3 — /etc/infra-info (Asset Tracking File)

Ansible drops a structured info file on every node at `/etc/infra-info`. This is a real ops pattern — it gives you a quick way to confirm provisioning state, last-configured timestamp, and cluster membership from any shell.

```bash
# Read the file on all nodes simultaneously
ansible web_nodes -i ansible/inventory.ini \
  -m shell -a "cat /etc/infra-info" --become
```

Sample output (per node):
```ini
[node]
hostname     = web-node-1
ip_address   = 192.168.1.101
os           = Ubuntu 22.04
cpu_cores    = 1
ram_mb       = 512

[cluster]
name         = proxmox-lab
role         = web-node (primary)
proxmox_host = 192.168.1.100

[provisioning]
provisioned_by  = Terraform + Ansible
last_configured = 2026-03-13T14:22:01Z

[access]
ssh_user        = ubuntu
auth_method     = key-only (password auth disabled)
authorized_keys = managed by Ansible (ansible/roles/ssh-keys)
```

```bash
# Check last_configured timestamp across all nodes (quick drift detection)
ansible web_nodes -i ansible/inventory.ini \
  -m shell -a "grep last_configured /etc/infra-info" --become
```

---

### Core Playbook Commands

```bash
cd ansible

# Full run — configure all nodes
ansible-playbook -i inventory.ini playbook.yml

# Dry run — preview changes without touching anything
ansible-playbook -i inventory.ini playbook.yml --check

# Single node only
ansible-playbook -i inventory.ini playbook.yml --limit web-node-2

# Run specific task group only
ansible-playbook -i inventory.ini playbook.yml --tags ssh-keys
ansible-playbook -i inventory.ini playbook.yml --tags motd

# Quick connectivity check
ansible web_nodes -i inventory.ini -m ping
```

For the full ad-hoc command reference, see [`ansible/ops/runbook.md`](ansible/ops/runbook.md).

---

## Project Structure

```
proxmox-lab/
│
├── README.md
├── CHANGELOG.md
├── CLAUDE.md                            # Claude Code context + skill auto-load
├── LICENSE
├── .gitignore
│
├── bash/
│   └── proxmox-init.sh                 # Run once on Proxmox after install
│                                       # Repos, cloud-init template, API token
│
├── terraform/
│   ├── main.tf                         # VM provisioning via Proxmox API
│   ├── variables.tf                    # All config: count, CPU, RAM, disk, IPs
│   ├── outputs.tf                      # Post-apply VM IPs and URLs
│   ├── inventory.tpl                   # Template → ansible/inventory.ini
│   └── terraform.tfvars.example
│
├── ansible/
│   ├── playbook.yml                    # Main playbook — full node configuration
│   ├── inventory.ini.example           # Format reference (actual file gitignored)
│   │
│   ├── group_vars/
│   │   └── all.yml                     # Shared variables: SSH key list, MOTD config
│   │
│   ├── host_vars/
│   │   └── web-node-1.yml.example      # Per-node overrides example
│   │
│   ├── roles/
│   │   ├── webserver/
│   │   │   └── templates/
│   │   │       ├── index.html.j2       # Hello world page (hostname + IP per node)
│   │   │       └── nginx.conf.j2       # Nginx site config
│   │   │
│   │   ├── motd/
│   │   │   ├── tasks/main.yml          # MOTD deploy tasks
│   │   │   ├── defaults/main.yml       # Cluster name, role, proxmox host
│   │   │   └── templates/
│   │   │       ├── motd.j2             # SSH login banner (Jinja2, per-node values)
│   │   │       └── infra-info.j2       # /etc/infra-info asset tracking file
│   │   │
│   │   └── ssh-keys/
│   │       ├── tasks/main.yml          # Key add/revoke/audit tasks
│   │       ├── defaults/main.yml       # ssh_authorized_keys, ssh_revoked_keys
│   │       ├── templates/
│   │       │   └── known_hosts.j2      # Intra-cluster known_hosts
│   │       └── files/keys/
│   │           ├── admin.pub.example   # Drop .pub files here
│   │           └── deploy-bot.pub.example
│   │
│   └── ops/
│       └── runbook.md                  # Day-to-day Ansible command reference
│
├── dashboard/
│   └── index.html                      # Browser monitoring UI — no server needed
│
├── autoscale/
│   └── autoscale.sh                    # CPU autoscaler (--stress for demo)
│
├── scripts/
│   └── install-deps.sh                 # Install Terraform + Ansible in WSL2
│
├── docs/
│   ├── writeup.md                      # Assessment writeup
│   └── claude-code-skills-guide.md     # Claude Code install + skills usage guide
│
├── .claude/
│   └── skills/                         # Claude Code skills (proxmox-iac, debug, etc.)
│
└── .github/
    ├── workflows/validate.yml          # CI: terraform validate, ansible-lint, shellcheck
    └── pull_request_template.md
```

---

## Troubleshooting

### Proxmox web UI unreachable after install
- VirtualBox network adapter must be **Bridged**, not NAT
- From WSL2: `ping 192.168.1.100` — if no reply, check the VM is running in VirtualBox
- Confirm the IP you set during install matches what you are browsing to

### VMs inside Proxmox won't boot
- Nested virtualisation is not enabled — the VM must be powered off first:
  ```powershell
  VBoxManage modifyvm "Proxmox-VE" --nested-hw-virt on
  ```

### `terraform apply` fails with 401 Unauthorized
- Token not set: `export TF_VAR_proxmox_api_token_secret="your-token"`
- Wrong token — re-run `proxmox-init.sh` to generate a new one
- Wrong Proxmox IP in `variables.tf` — update `proxmox_api_url`

### `terraform apply` fails with 500 / connection refused
- Proxmox is still rebooting after the init script — wait 60 seconds and retry

### Ansible: SSH connection refused or timeout
- VM is still booting — wait 60–90 seconds after `terraform apply` finishes, then retry
- SSH key not copied: `ssh-copy-id root@192.168.1.100`
- Check the VM console in the Proxmox web UI (click the VM → Console) to see if cloud-init has finished

### Dashboard shows no data after connecting
- Token format must include the prefix: `terraform@pve!terraform-token=YOUR_TOKEN`
- CORS restriction — browser-based API calls to Proxmox may be blocked when accessing from a different machine. Access the dashboard from the same machine, or add a reverse proxy on the Proxmox host:
  ```bash
  # Quick workaround on the Proxmox host
  apt install nginx
  # configure nginx to proxy https://localhost:8006 with CORS headers
  ```

### Autoscaler shows "No nodes found in inventory"
- Run `terraform apply` first to provision at least one node and generate the inventory file

### Hello world site returns 502 or connection refused
- nginx may not have started: `ansible web_nodes -i ansible/inventory.ini -m service -a "name=nginx state=started" --become`
- Check if the VM's IP is reachable: `ping 192.168.1.101`

---

## Security Notes

This is a **lab environment** — several settings are intentionally simplified for ease of setup:

- Proxmox uses a self-signed TLS certificate (`pm_tls_insecure = true` in Terraform is expected)
- The VM default password (`ubuntu123`) is set in `proxmox-init.sh` — change this before any non-lab deployment
- The Terraform API token is stored in an environment variable — use HashiCorp Vault or a secrets manager in production
- SSH password authentication is disabled by the Ansible playbook after first run (key-only)
- The Terraform API user has least-privilege permissions — it can only manage VMs, not the Proxmox host itself

---

## Contributing

1. Fork the repo
2. Create a feature branch: `git checkout -b feature/my-change`
3. Make your changes
4. Validate before pushing:
   ```bash
   cd terraform && terraform fmt && terraform validate
   cd ../ansible && ansible-playbook --syntax-check -i inventory.ini.example playbook.yml
   shellcheck bash/proxmox-init.sh autoscale/autoscale.sh scripts/install-deps.sh
   ```
5. Submit a pull request — the PR template will guide you through what to include

---

## License

MIT — free to use, modify, and distribute.
