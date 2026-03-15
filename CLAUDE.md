# Proxmox Lab — Claude Code Context

This is a Proxmox Private Cloud Lab built for the Maritime Capital Private Cloud
Administrator assessment. It demonstrates IaC, configuration management, and
autoscaling running on a single Windows 11 laptop via VirtualBox.

---

## Current State (as of 2026-03-15)

### Confirmed Working ✅
- Proxmox VE 9.1 running inside VirtualBox on Windows 11
- Terraform (bpg/proxmox provider) provisioning Alpine VMs via Proxmox API
- Golden image (VM 100) — all clones are SSH-accessible immediately after boot
- scripts/scale.sh — full workflow: provision N nodes, select primary, start one
- Scaling verified: node_count=1 → 2 → back to 1, Terraform destroys correctly
- Ansible raw module — MOTD, SSH key management, infra-info deployed successfully
- Direct SSH to active VM at 192.168.1.101 immediately after terraform apply

### Known Constraints ⚠️
- Only ONE VM can run at a time (7.7GB RAM host — see Hardware Constraints below)
- VMs cannot access the internet (home router NAT restriction)
- Ansible full playbook (nginx, node_exporter) requires internet — use raw module only
- dashboard/index.html not in active use — use Proxmox UI at 192.168.1.100:8006

---

## Environment

| Item | Value |
|---|---|
| Proxmox host IP | 192.168.1.100 |
| Proxmox UI | https://192.168.1.100:8006 |
| Proxmox version | VE 9.1.1 |
| Proxmox root password | Summer2026 |
| Active VM IP | 192.168.1.101 (fixed — all nodes use this IP when active) |
| Golden template | VM 100 (golden-template, always stopped) |
| Alpine template | VM 9000 (alpine-cloud-template, stopped) |
| Web nodes | VM 101+ (web-node-1, web-node-2, etc.) |
| VM RAM | 256MB per node |
| VM CPU | 1 core, qemu64 type, KVM disabled |
| VM user | root |
| VM password | Alpine2026 |
| SSH key | ~/.ssh/proxmox-lab |
| Terraform provider | bpg/proxmox v0.98+ |
| Terraform clone source | VM 100 (golden-template) — NOT VM 9000 |
| Ansible version | 2.17.14 |
| Ansible connection | raw module over SSH (no Python in VMs) |

---

## Hardware Constraints

### Single VM at a Time
Host has 7.7GB RAM. Proxmox uses ~1.6GB. Each Alpine VM uses ~256MB.
Running 2+ VMs under NEM emulation causes Proxmox to crash.

ALL nodes use IP 192.168.1.101 — only one runs at a time.
scale.sh handles this: provisions N VMs, stops all, user picks which one runs.

To swap active node manually:
```bash
ssh proxmox "qm stop 101 && qm start 102"
# Update ansible/inventory.ini to point to the new active node
```

### No Internet in VMs
Home router does not allow NAT config. VMs reach 192.168.1.100 (Proxmox) and
192.168.1.76 (WSL2 machine) but NOT the public internet.

Consequences:
- Cannot run: apk add, apt install, pip install inside VMs
- Ansible raw module used instead of standard modules (no Python needed)
- Golden image pre-bakes all required config before cloning

---

## Daily Workflow

```bash
# 1. Provision and select active node
bash scripts/scale.sh 2

# 2. SSH into active node
ssh -i ~/.ssh/proxmox-lab root@192.168.1.101

# 3. Run Ansible on active node
cd ansible/
ansible web_nodes -i inventory.ini -m raw -a "hostname"

# 4. Scale back down when done
cd terraform/
terraform apply -var="node_count=1" -auto-approve
```

---

## Claude Code Skills

Four skills are bundled in `.claude/skills/`. Claude Code loads them automatically
when you open this repo. Each skill is a self-contained folder with a `SKILL.md`
and optional `references/` files.

### Skill directory structure

```
.claude/skills/
├── proxmox-iac/              # Infrastructure Generator
│   ├── SKILL.md
│   └── references/
│       ├── environment.md    # IPs, credentials, storage — single source of truth
│       ├── terraform-patterns.md
│       └── ansible-patterns.md
├── proxmox-debug/            # Error Diagnostics
│   └── SKILL.md
├── node-role-builder/        # Ansible Role Scaffolder
│   └── SKILL.md
└── scale-policy-editor/      # Scaling & Autoscaler Config
    └── SKILL.md
```

### When each skill triggers

| Skill | Triggers on |
|---|---|
| `proxmox-iac` | "add a VM", "provision a node", "change VM memory", any infra change |
| `proxmox-debug` | Any error pasted from terraform/ansible/SSH/Proxmox |
| `node-role-builder` | "create a role", "deploy X to nodes", "add a health check" |
| `scale-policy-editor` | "change threshold", "how do I switch nodes", "scale to N" |

### Important: skills know about our constraints
All skills have been updated to reflect this environment's specific constraints:
- bpg/proxmox provider (not telmate)
- Clone from VM 100 (not VM 9000)
- Ansible raw module only (no Python in VMs)
- Single active VM at a time (hardware limit)
- Alpine Linux (not Ubuntu) — rc-service, not systemctl

---

## Key Files

| File | Purpose |
|---|---|
| `scripts/scale.sh` | PRIMARY INTERFACE — provision + pick active node |
| `scripts/configure-node.sh` | Called by Terraform per VM (sets --kvm 0) |
| `terraform/main.tf` | VM definitions — clones from VM 100, bpg/proxmox |
| `terraform/variables.tf` | node_count, memory, CPU, SSH key path |
| `ansible/inventory.ini` | Auto-updated by scale.sh — active node at 192.168.1.101 |
| `ansible/playbook.yml` | Full playbook (use raw module for offline demos) |
| `autoscale/autoscale.sh` | CPU autoscaler (--stress flag for demo) |
| `docs/writeup.md` | Assessment writeup |
| `.claude/skills/` | Claude Code skills — auto-loaded by CLAUDE.md |

---

## Ansible Usage

Always use raw module for this environment — Python is not installed in VMs:

```bash
# Correct — works offline
ansible web_nodes -i inventory.ini -m raw -a "cat /etc/motd"
ansible web_nodes -i inventory.ini -m raw -a "hostname && uptime"

# Will fail — requires Python in target VM
ansible web_nodes -i inventory.ini -m file -a "..."
ansible web_nodes -i inventory.ini -m template -a "..."
ansible-playbook playbook.yml   # uses standard modules
```

For playbook demos use offline-compatible tags only:
```bash
ansible-playbook -i inventory.ini playbook.yml --tags ssh-keys
ansible-playbook -i inventory.ini playbook.yml --tags motd
ansible-playbook -i inventory.ini playbook.yml --tags infra-info
```
