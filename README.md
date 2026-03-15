# 🖥️ Proxmox Private Cloud Lab

A fully automated private cloud environment built on **Proxmox VE**, demonstrating Infrastructure as Code, configuration management, and autoscaling — running on a single Windows laptop.

> Built as part of a Private Cloud Administrator assessment for Maritime Capital, LLC.

---

## 📋 Table of Contents

- [What This Does](#what-this-does)
- [Architecture](#architecture)
- [Resource Constraints & Design Decisions](#resource-constraints--design-decisions)
- [Tool Selection & Why](#tool-selection--why)
- [Golden Image Design](#golden-image-design)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Scaling Nodes — scale.sh](#scaling-nodes--scalesh)
- [Ansible in Action](#ansible-in-action)
- [Useful Commands](#useful-commands)
- [Project Structure](#project-structure)
- [Real-World Issues & Fixes](#real-world-issues--fixes)
- [Claude Code Skills](#claude-code-skills)
- [Security Notes](#security-notes)

---

## What This Does

This lab provisions a production-style private cloud on a local Windows machine. Every component is automated — from provisioning VMs to configuration management to autoscaling.

| Capability | Implementation | Details |
|---|---|---|
| **Hypervisor** | Proxmox VE 9.1 | Runs inside VirtualBox on Windows 11 |
| **VM Provisioning** | Terraform (bpg/proxmox) | Clones Alpine VMs via Proxmox REST API |
| **Configuration** | Ansible (raw module) | SSH keys, MOTD, asset tracking — no Python needed |
| **Golden Image** | VM 100 (golden-template) | Pre-configured base — all clones inherit SSH, password, sshd |
| **Scaling** | scripts/scale.sh | Interactive wrapper — prompts for node count and primary instance |
| **Autoscaling** | autoscale/autoscale.sh | CPU threshold-based, 1–5 nodes |

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  Windows 11 Laptop  (192.168.1.76)                                           │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │  VirtualBox                                                            │  │
│  │                                                                        │  │
│  │  ┌──────────────────────────────────────────────────────────────────┐  │  │
│  │  │  Proxmox VE 9.1   (192.168.1.100:8006)                           │  │  │
│  │  │                                                                  │  │  │
│  │  │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐  │  │  │
│  │  │  │  VM 100           │  │  VM 101           │  │  VM 102+     │  │  │  │
│  │  │  │  golden-template  │  │  web-node-1       │  │  web-node-2+ │  │  │  │
│  │  │  │  (stopped)        │  │  192.168.1.101    │  │  (stopped)   │  │  │  │
│  │  │  │                   │  │  Alpine 3.19      │  │              │  │  │  │
│  │  │  │  SSH key ✓        │  │  SSH ✓ running    │  │  cloned from │  │  │  │
│  │  │  │  root pw ✓        │  │  root pw ✓        │  │  VM 100      │  │  │  │
│  │  │  │  sshd ✓           │  │  ← ACTIVE NODE    │  │              │  │  │  │
│  │  │  └──────────────────┘  └──────────────────┘  └──────────────┘  │  │  │
│  │  └──────────────────────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  WSL2 / Ubuntu                                                               │
│  │                                                                          │
│  ├─ Terraform ──────────────→  https://192.168.1.100:8006  (Proxmox API)   │
│  │   terraform apply              provisions/destroys VMs                   │
│  │   scripts/scale.sh             interactive wrapper                       │
│  │                                                                          │
│  ├─ Ansible ───────────────→  ssh root@192.168.1.101  (active VM)          │
│  │   raw module only              MOTD, SSH keys, infra-info                │
│  │   no Python needed             works without internet in VM              │
│  │                                                                          │
│  └─ autoscale.sh ──────────→  triggers terraform on CPU threshold          │
│                                                                              │
│  Network reachability:                                                       │
│  WSL2      → Proxmox API    (192.168.1.100:8006)  ✅                        │
│  WSL2      → Active VM SSH  (192.168.1.101:22)    ✅                        │
│  Active VM → Proxmox host   (192.168.1.100)        ✅                        │
│  Active VM → Internet       (8.8.8.8)              ❌ (router restriction)   │
└──────────────────────────────────────────────────────────────────────────────┘
```

**What happens when you run `bash scripts/scale.sh 2`:**
1. Terraform calls Proxmox API → clones golden-template (VM 100) for each new node
2. configure-node.sh runs automatically per VM — disables KVM, removes cloud-init drive
3. You are prompted to select which instance is the PRIMARY (active)
4. All other VMs are stopped — only one runs at a time (hardware constraint)
5. Ansible inventory is updated to point to the active node at `192.168.1.101`
6. SSH into the active node works immediately — no further setup needed

---

## Resource Constraints & Design Decisions

I built this on my personal laptop which has limited RAM — not a server, not a cloud instance. Working within those limits shaped almost every design decision in this project. I'm documenting them here so the reasoning is clear.

### Constraint 1 — Only One VM Can Run at a Time

My laptop doesn't have enough memory to run multiple VMs simultaneously. Proxmox alone eats about 1.6GB, and each Alpine VM takes another 256MB on top of that. When I tried running two or three at once, Proxmox would become unresponsive or crash entirely.

So I built a wrapper script (`scripts/scale.sh`) that lets me provision any number of VMs via Terraform — they all get created and configured — but only one actually runs at a time. When the script finishes, it asks me which node I want active and stops everything else. The others sit there stopped, ready to swap in whenever I need them.

```
bash scripts/scale.sh 3

Provisioning 3 node(s) via Terraform...
...Apply complete! Resources: 3 added.

Which node should be the PRIMARY (running)?
All others will be STOPPED to save resources
  1) web-node-1
  2) web-node-2
  3) web-node-3

Enter node number [1]: 2
Starting web-node-2... Done.
Active: web-node-2 at 192.168.1.101
```

To swap which VM is active:
```bash
ssh proxmox "qm stop 101 && qm start 102"
# Update ansible/inventory.ini to reflect the new active node
```

### Constraint 2 — No Internet Access in VMs

My home router doesn't give me access to NAT or port forwarding settings — I can't configure it. Because of this, my VMs get a local IP on the LAN and can talk to the Proxmox host and my laptop, but they can't reach the public internet.

This meant I couldn't install packages inside VMs at runtime. No `apk add nginx`, no `pip install`, nothing that needs to hit a mirror.

I solved this two ways. First, I built a **golden image** — a pre-configured VM with everything already set up (SSH keys, root password, sshd, network config) that I converted into a template. Every new VM Terraform creates is a clone of that template, so it inherits everything and is ready to go the moment it boots.

Second, for Ansible I switched to using the `raw` module instead of the standard modules. The raw module just sends shell commands over SSH — it doesn't need Python installed in the target VM at all. I can still deploy MOTD banners, manage SSH keys, write asset tracking files across all nodes with a single command. It demonstrates the same core capability, just without the runtime dependency.

---

## Tool Selection & Why

| Tool | Why I chose it |
|---|---|
| **Proxmox VE** | Free, production-grade hypervisor with a full REST API. Every action you take in the UI is also an API call — Terraform can talk directly to it without any middleware |
| **Terraform (bpg/proxmox)** | Declarative state management — I just say how many nodes I want and Terraform figures out what to create or destroy. I originally used `telmate/proxmox` but hit a known bug on Proxmox 9 and switched to `bpg/proxmox` which works correctly |
| **Ansible (raw module)** | Agentless and SSH-based. I use the raw module because my VMs don't have internet, so I can't install Python. Raw just sends shell commands over SSH — no agent needed |
| **Alpine Linux** | Uses ~90MB RAM and boots in 10 seconds. I started with Ubuntu but its cloud-init process was crashing Proxmox on my laptop. Alpine was stable from the first boot |
| **Golden Image (VM 100)** | Pre-configured template that all new VMs clone from. This was the single biggest improvement — before it I was manually configuring every VM after creation |
| **scale.sh** | A wrapper I wrote around Terraform that handles the single-active-VM constraint. I don't have to think about it — I just say how many nodes I want and the script handles the rest |

---

## Golden Image Design

VM 100 (`golden-template`) is the base for all Terraform-provisioned VMs. It stays stopped permanently — Terraform clones it for each new node, never starts it directly.

I went through a lot of frustration getting new VMs to a usable state. Every time Terraform created a fresh clone, I had to manually mount the disk, set a root password, write a network config, and enable sshd before I could even SSH in. It was slow and kept breaking.

The golden image pattern fixed all of that. I configured one VM exactly how I wanted it, then converted it to a Proxmox template. Now every clone inherits everything automatically — SSH keys, password, sshd running on boot, static IP config. The moment Terraform creates a new VM and it boots, I can SSH in. No manual steps.

**What's pre-configured in the golden image:**
- Alpine Linux 3.19
- Root password set
- My SSH public key in `/root/.ssh/authorized_keys`
- sshd running on boot with root login enabled
- Static network: `192.168.1.101/24`, gateway `192.168.1.1`
- KVM disabled

**Before vs after:**

```
Before golden image:                After golden image:
─────────────────────               ────────────────────
terraform apply                     terraform apply
  ↓                                   ↓
VM created (not bootable)           VM created
  ↓                                   ↓
Mount disk manually                 configure-node.sh: set --kvm 0
  ↓                                   ↓
Set root password                   qm start
  ↓                                   ↓
Configure static IP                 SSH works immediately ✅
  ↓
Enable sshd
  ↓
Add SSH keys
  ↓
SSH works (eventually)
```

**To rebuild the golden image if needed:**
```bash
# 1. Clone from alpine-cloud-template
ssh proxmox "qm clone 9000 100 --name golden-template --full 1"
ssh proxmox "qm set 100 --kvm 0 && qm start 100"

# 2. Open Proxmox console → VM 100 → Console, login as root (no password), then:
ip link set eth0 up
udhcpc -i eth0
cat > /etc/network/interfaces << 'EOF'
auto lo
iface lo inet loopback
auto eth0
iface eth0 inet static
    address 192.168.1.101
    netmask 255.255.255.0
    gateway 192.168.1.1
EOF
echo 'root:Alpine2026' | chpasswd
apk add openssh
rc-service sshd start
rc-update add sshd default
echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
rc-service sshd restart

# 3. Add SSH key from WSL2
ssh-copy-id -i ~/.ssh/proxmox-lab.pub root@192.168.1.101

# 4. Convert to template
ssh proxmox "qm stop 100 && qm template 100"
```

---

## Prerequisites

- Windows 10/11 (16GB RAM recommended, 8GB minimum)
- VirtualBox 7.x with Extension Pack
- WSL2 with Ubuntu
- Hyper-V **disabled** (required for VirtualBox nested virtualization)

```powershell
# Disable Hyper-V — run as Administrator, reboot after
bcdedit /set hypervisorlaunchtype off

# Re-enable WSL2 after the demo
bcdedit /set hypervisorlaunchtype auto
# Reboot required
```

---

## Installation

### Phase 1 — VirtualBox

1. Download and install VirtualBox 7.x + Extension Pack from https://www.virtualbox.org
2. Create a VM: Linux / Debian 64-bit / 4GB RAM / 60GB disk / Bridged Adapter
3. **Critical:** Set Promiscuous Mode to **Allow All** in Network settings
4. Enable nested virtualization (VM must be off):
```powershell
& "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" modifyvm "Proxmox-VE" --nested-hw-virt on
```

### Phase 2 — Install Proxmox VE

1. Download Proxmox VE 9.x ISO from https://www.proxmox.com/en/downloads
2. Attach ISO to the VM and boot
3. Install with these network settings:
   - IP: `192.168.1.100/24`, Gateway: `192.168.1.1`, DNS: `8.8.8.8`
4. After reboot, remove the ISO and access the UI at `https://192.168.1.100:8006`

### Phase 3 — Proxmox Init Script

```bash
# From WSL2
scp bash/proxmox-init.sh proxmox:/root/
ssh proxmox "bash /root/proxmox-init.sh"
# SAVE the API token printed at the end
```

### Phase 4 — WSL2 SSH Setup

```bash
ssh-keygen -t ed25519 -C 'proxmox-lab' -f ~/.ssh/proxmox-lab -N ""
ssh-copy-id -i ~/.ssh/proxmox-lab.pub root@192.168.1.100

cat >> ~/.ssh/config << 'EOF'
Host proxmox
    HostName 192.168.1.100
    User root
    IdentityFile ~/.ssh/proxmox-lab
    StrictHostKeyChecking no
EOF

ssh proxmox echo "connected"
```

### Phase 5 — Install Terraform & Ansible

```bash
bash scripts/install-deps.sh
terraform version && ansible --version
```

### Phase 6 — Set Proxmox Password

```bash
export TF_VAR_proxmox_password="YourProxmoxRootPassword"
echo 'export TF_VAR_proxmox_password="YourProxmoxRootPassword"' >> ~/.bashrc
```

### Phase 7 — Terraform Init

```bash
cd terraform/
terraform init
terraform plan
```

---

## Scaling Nodes — scale.sh

`scripts/scale.sh` is the **primary interface** for all VM provisioning. Use it instead of calling terraform directly.

```bash
# From repo root
bash scripts/scale.sh <node_count>

bash scripts/scale.sh 1    # provision 1 VM
bash scripts/scale.sh 2    # provision 2 VMs, pick which one runs
bash scripts/scale.sh 3    # provision 3 VMs, pick which one runs
```

**What the script does:**
1. Runs `terraform apply -var="node_count=N"` to provision N VMs
2. Stops all running VMs to prevent resource exhaustion
3. Prompts you to select the PRIMARY (active) instance
4. Starts only the selected VM
5. Updates `ansible/inventory.ini` to point to the active node at `192.168.1.101`

**To swap active instance without reprovisioning:**
```bash
# Stop current node, start a different one
ssh proxmox "qm stop 101 && qm start 102"

# Manually update Ansible inventory
cat > ansible/inventory.ini << 'EOF'
[web_nodes]
web-node-2 ansible_host=192.168.1.101 ansible_user=root ansible_ssh_private_key_file=~/.ssh/proxmox-lab ansible_ssh_common_args='-o StrictHostKeyChecking=no'

[web_nodes:vars]
ansible_python_interpreter=/usr/bin/python3
EOF
```

**Scale back down:**
```bash
cd terraform/
terraform apply -var="node_count=1" -auto-approve
# Terraform destroys highest-numbered nodes, keeps node 1
```

---

## Ansible in Action

All Ansible demos use the `raw` module — no Python installation required in the target VM. This is the right choice for an Alpine environment without internet access.

### Test connectivity

```bash
cd ansible/
ansible web_nodes -i inventory.ini -m raw -a "hostname"

# Expected output:
# web-node-1 | CHANGED | rc=0 >>
# localhost
```

### Demo 1 — Deploy MOTD (Message of the Day)

```bash
ansible web_nodes -i inventory.ini -m raw -a "
printf 'Welcome to Proxmox Lab\nNode: web-node-1\nIP: 192.168.1.101\nManaged by: Ansible + Terraform\nCluster: Maritime Capital Lab\n' > /etc/motd
cat /etc/motd
"
```

Verify — SSH into the node and the MOTD appears automatically:
```bash
ssh -i ~/.ssh/proxmox-lab root@192.168.1.101
# Banner appears on login
```

### Demo 2 — SSH Key Management

```bash
# Audit current authorized keys across all nodes
ansible web_nodes -i inventory.ini -m raw -a "
echo '=== Authorized Keys ===' && wc -l /root/.ssh/authorized_keys && cat /root/.ssh/authorized_keys | cut -c1-40
"

# Add a new key to all nodes at once
ansible web_nodes -i inventory.ini -m raw -a "
echo 'ssh-ed25519 AAAA...newkey user@host' >> /root/.ssh/authorized_keys
echo 'Key added. Total keys:' && wc -l /root/.ssh/authorized_keys
"

# Remove a key from all nodes (by comment/identifier)
ansible web_nodes -i inventory.ini -m raw -a "
sed -i '/olduser@host/d' /root/.ssh/authorized_keys
echo 'Key removed. Remaining keys:' && wc -l /root/.ssh/authorized_keys
"
```

### Demo 3 — Asset Tracking File (/etc/infra-info)

```bash
ansible web_nodes -i inventory.ini -m raw -a "
printf '[node]\nhostname = web-node-1\nip_address = 192.168.1.101\nos = Alpine Linux 3.19\n\n[cluster]\nname = proxmox-lab\nrole = web-node\nproxmox_host = 192.168.1.100\n\n[provisioning]\nprovisioned_by = Terraform + Ansible\nlast_configured = \$(date -u +%Y-%m-%dT%H:%M:%SZ)\n' > /etc/infra-info
cat /etc/infra-info
"
```

### Run all three demos at once

```bash
ansible web_nodes -i inventory.ini -m raw -a "
printf 'Welcome to Proxmox Lab\nManaged by: Ansible + Terraform\n' > /etc/motd
printf '[node]\nhostname=web-node-1\nip=192.168.1.101\nmanaged_by=Ansible\nlast_run=\$(date -u)\n' > /etc/infra-info
echo 'All demos deployed successfully'
cat /etc/motd
echo '---'
cat /etc/infra-info
"
```

---

## Useful Commands

### Scaling (primary interface)

```bash
# Provision and select active node
bash scripts/scale.sh 1
bash scripts/scale.sh 2
bash scripts/scale.sh 3
```

### Terraform

```bash
cd terraform/

terraform plan                                          # preview changes
terraform apply -auto-approve                           # apply
terraform apply -var="node_count=2" -auto-approve       # scale to 2
terraform apply -var="node_count=1" -auto-approve       # scale back to 1
terraform output                                        # show current state
terraform destroy -auto-approve                         # destroy ALL VMs
terraform state rm proxmox_virtual_environment_vm.web_node   # clear state
terraform import proxmox_virtual_environment_vm.web_node[0] pve/101  # import
```

### Proxmox VM Management

```bash
ssh proxmox "qm list"                             # list all VMs and status
ssh proxmox "qm status 101"                       # check specific VM
ssh proxmox "qm start 101"                        # start VM
ssh proxmox "qm stop 101"                         # stop VM
ssh proxmox "qm destroy 101"                      # delete VM permanently
ssh proxmox "qm config 101"                       # show full VM config
ssh proxmox "qm set 101 --kvm 0"                  # disable KVM on VM
ssh proxmox "qm listsnapshot 100"                 # list snapshots of golden template
ssh proxmox "ip neigh show | grep -v FAILED"      # show LAN devices and IPs
```

### SSH into active VM

```bash
ssh -i ~/.ssh/proxmox-lab root@192.168.1.101
```

### Ansible

```bash
cd ansible/

# Connectivity check
ansible web_nodes -i inventory.ini -m raw -a "hostname"

# Quick health checks
ansible web_nodes -i inventory.ini -m raw -a "uptime"
ansible web_nodes -i inventory.ini -m raw -a "ip addr show eth0 | grep inet"
ansible web_nodes -i inventory.ini -m raw -a "cat /etc/motd"
ansible web_nodes -i inventory.ini -m raw -a "cat /etc/infra-info"
ansible web_nodes -i inventory.ini -m raw -a "wc -l /root/.ssh/authorized_keys"
```

### Proxmox API

```bash
# Test API is up
curl -sk https://192.168.1.100:8006/api2/json/version

# Test credentials
curl -sk -d "username=root@pam&password=YOUR_PASSWORD" \
  https://192.168.1.100:8006/api2/json/access/ticket | python3 -m json.tool | head -5
```

---

## Project Structure

```
proxmox-lab/
│
├── README.md
├── CHANGELOG.md
├── CLAUDE.md                            # Claude Code context + skill auto-load
├── .gitignore
│
├── bash/
│   └── proxmox-init.sh                 # Run ONCE on Proxmox after install
│                                       # Fixes repos, creates cloud-init template,
│                                       # generates Terraform API token
│
├── terraform/
│   ├── main.tf                         # VM provisioning — bpg/proxmox provider
│   │                                   # Clones from VM 100 (golden-template)
│   │                                   # Calls configure-node.sh via local-exec
│   ├── variables.tf                    # node_count, memory, CPU, SSH key path
│   ├── outputs.tf                      # node_count, vm_ips, web_urls
│   └── inventory.tpl                   # Template for ansible/inventory.ini
│
├── ansible/
│   ├── playbook.yml                    # Full playbook (use raw module offline)
│   ├── inventory.ini                   # AUTO-GENERATED by scale.sh
│   │                                   # Points to active node at 192.168.1.101
│   ├── group_vars/
│   │   └── all.yml                     # SSH key list, cluster config
│   ├── roles/
│   │   ├── motd/                       # MOTD banner role
│   │   ├── ssh-keys/                   # SSH key management role
│   │   └── webserver/                  # nginx + node_exporter (requires internet)
│   └── ops/
│       └── runbook.md                  # Day-to-day command reference
│
├── scripts/
│   ├── scale.sh                        # ← PRIMARY INTERFACE — use this daily
│   │                                   # Wraps terraform with single-VM logic
│   │                                   # Prompts for node count + primary selection
│   ├── configure-node.sh               # Called by Terraform per VM
│   │                                   # Sets --kvm 0, removes cloud-init drive
│   ├── start-nodes.sh                  # Start multiple nodes (batch helper)
│   └── install-deps.sh                 # Install Terraform + Ansible in WSL2
│
├── autoscale/
│   └── autoscale.sh                    # CPU autoscaler (--stress flag for demo)
│
├── docs/
│   ├── writeup.md                      # Assessment writeup
│   └── claude-code-skills-guide.md     # Claude Code install + usage guide
│
└── .claude/
    └── skills/                         # Claude Code skills (4 skills)
```

---

## Real-World Issues & Fixes

These are the actual problems I ran into during setup — not theoretical. I hit every one of them and had to work through each fix.

### 1 — Hyper-V Conflicts with VirtualBox
WSL2 uses Hyper-V under the hood, which takes exclusive control of CPU virtualization. VirtualBox falls back to software emulation and logs `Snail execution mode is active`. Everything becomes extremely slow and Proxmox crashes randomly under any real load.

I disabled Hyper-V, rebooted, and VirtualBox got full hardware access back.
```powershell
bcdedit /set hypervisorlaunchtype off
# reboot
```
To restore WSL2 after the demo: `bcdedit /set hypervisorlaunchtype auto` and reboot.

### 2 — KVM Not Available Inside VirtualBox
Even after disabling Hyper-V, Proxmox VMs default to KVM mode which VirtualBox can't provide. Every VM start failed with `KVM virtualisation configured, but not available`.

Fix is to disable KVM on each VM before starting it. I wired this into `configure-node.sh` so it happens automatically now.

### 3 — Promiscuous Mode Blocking VM Traffic
My VMs were getting DHCP leases but had 100% packet loss to everything — including the gateway right next to them. Took a while to track down. The VirtualBox bridged adapter was set to `Promiscuous Mode: Deny`, which silently drops all traffic from MAC addresses it doesn't own.

Fix: VirtualBox → Proxmox-VE VM → Settings → Network → Promiscuous Mode → **Allow All**

### 4 — Ubuntu Cloud-Init Crashes Proxmox
I originally used Ubuntu 22.04 cloud images. On first boot, cloud-init hammers the CPU at 100%+ for several minutes under software emulation. Proxmox would either crash or the VM would reboot in a loop before finishing.

I switched to Alpine Linux. It boots in about 10 seconds and uses 90MB RAM instead of 512MB — stable from the first attempt.

### 5 — telmate/proxmox Provider Bug on Proxmox 9
The original Terraform provider I was using (`telmate/proxmox` v2.9) kept throwing `VM.Monitor permission missing` errors even after I assigned the Administrator role. I spent a long time debugging ACLs before finding out it's a known upstream bug that's never been fixed in that branch.

Switched to `bpg/proxmox` v0.78+ which handles Proxmox 9 correctly.

### 6 — Enterprise Repo 401 Errors
Fresh Proxmox install came with enterprise repos enabled by default. My init script was supposed to comment them out but Proxmox 9 switched to a `.sources` file format instead of `.list`, so my `sed` commands had no effect and `apt update` kept failing.

```bash
echo 'Enabled: no' >> /etc/apt/sources.list.d/pve-enterprise.sources
echo 'Enabled: no' >> /etc/apt/sources.list.d/ceph.sources
```

### 7 — pveproxy Crashed After CORS Config
I tried adding CORS headers to the Proxmox proxy so the dashboard could connect. The config got appended twice in the wrong format, pveproxy went into a restart loop, and the entire web UI and API went down.

Fix: clear the file completely and restart.
```bash
echo '' > /etc/default/pveproxy && systemctl start pveproxy
```

### 8 — No Internet in VMs
My home router doesn't give me access to the NAT or port forwarding configuration. VMs get a LAN IP and can reach my laptop and the Proxmox host fine, but they can't reach the internet. `apk add` always fails.

The golden image approach solved it — everything the VMs need is pre-baked before cloning. For Ansible, I use the raw module which only needs SSH. No packages to install.

---

## Claude Code Skills

This repo ships with four Claude Code skills in `.claude/skills/`. If you use Claude Code
to work on this project, these skills load automatically and give Claude full context about
the environment — the constraints, the provider quirks, the Alpine-specific commands, all of it.

### Skill structure on GitHub

```
.claude/
└── skills/
    ├── proxmox-iac/              # Infrastructure Generator
    │   ├── SKILL.md
    │   └── references/
    │       ├── environment.md    # single source of truth for all env values
    │       ├── terraform-patterns.md
    │       └── ansible-patterns.md
    ├── proxmox-debug/            # Error Diagnostics
    │   └── SKILL.md
    ├── node-role-builder/        # Ansible Role Scaffolder
    │   └── SKILL.md
    └── scale-policy-editor/      # Scaling Config
        └── SKILL.md
```

Each skill folder name is its unique identifier. CLAUDE.md at the repo root tells Claude Code
to auto-load all four when you open the project.

### Demo — what this looks like in practice

**Without skills:**
```
You: add a new Ansible task that deploys a welcome file to all nodes
Claude: Here's how to do it with the template module...
        [generates code that requires Python — won't work in this env]
```

**With skills:**
```
You: add a new Ansible task that deploys a welcome file to all nodes
Claude: [reads proxmox-iac/SKILL.md → sees "raw module only, no Python in VMs"]
        [reads references/ansible-patterns.md → sees exact patterns for this env]

        Here's the task using the raw module (required — no Python in these VMs):

        - name: deploy welcome file
          raw: "echo 'Welcome to Proxmox Lab' > /etc/welcome"
          tags: welcome

        Add it to ansible/playbook.yml and run:
        ansible web_nodes -i inventory.ini -m raw -a "cat /etc/welcome"
```

**Debugging example:**

```
You: getting this error — "KVM virtualisation configured, but not available"
Claude: [reads proxmox-debug/SKILL.md → finds this exact error in known issues table]

        Root cause: Proxmox VMs default to KVM mode but VirtualBox can't provide it.

        Fix:
        ssh proxmox "qm set 101 --kvm 0 && qm start 101"

        This is now handled automatically by configure-node.sh for all new VMs.
```

The skills essentially give Claude Code a full picture of this specific environment —
the same context that took days of troubleshooting to accumulate — available instantly
on every future conversation.

---

## Security Notes

- Root password auth is used for the demo — production would use API tokens with least-privilege roles and SSH key auth only
- SSH key auth is the only method for VM access (golden image injects the key)
- Terraform password stored as env var `TF_VAR_proxmox_password` — never in committed files
- `.gitignore` excludes: `terraform.tfvars`, `*.tfstate*`, `ansible/inventory.ini`, SSH keys, `.env`
