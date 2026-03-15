---
name: proxmox-iac
description: >
  Generates production-ready Terraform and Ansible code for the Proxmox Private Cloud Lab.
  Use this skill whenever someone wants to add, modify, or remove infrastructure in this repo.
  Triggers on: "add a VM", "provision a new node", "change VM memory", "add an Ansible role",
  "scale to N nodes", "add a service", "modify the template", or any request to extend or
  change the infrastructure. Also use when someone pastes a terraform apply or ansible error.
  Always use this skill for infrastructure changes — never generate code from memory alone.
  Critical: this environment uses Alpine Linux (not Ubuntu), bpg/proxmox provider (not telmate),
  Ansible raw module (no Python in VMs), golden image clone source (VM 100), and only one VM
  runs at a time. Any generated code must respect these constraints.
---

# Proxmox IaC — Infrastructure Generator

Generates Terraform and Ansible code compatible with this repo's structure. Output must be
paste-ready — no placeholders, no "fill this in".

---

## Critical environment facts — read before generating anything

**These are not defaults — they are hard requirements for this environment:**

| Item | Value | Why |
|---|---|---|
| Terraform provider | `bpg/proxmox` v0.78+ | telmate has a known bug on Proxmox 9 |
| Clone source | VM 100 (`golden-template`) | NOT VM 9000. VM 100 has SSH, password, sshd pre-configured |
| OS in VMs | Alpine Linux 3.19 | NOT Ubuntu. Uses `apk`, not `apt` |
| Ansible connection | `raw` module only | No Python in VMs — internet blocked by router |
| Active VM IP | Always `192.168.1.101` | All nodes share this IP — only one runs at a time |
| KVM | Must be disabled | `qm set <vmid> --kvm 0` before starting any VM |
| Max active VMs | 1 at a time | 7.7GB RAM host — running 2+ crashes Proxmox |
| Primary interface | `scripts/scale.sh` | Wraps terraform apply with single-VM logic |
| VM user | `root` | Not `ubuntu`, not `alpine` |
| VM password | `Alpine2026` | |
| Proxmox host | `192.168.1.100` | |
| Proxmox UI | `https://192.168.1.100:8006` | |

---

## Reference files — read before generating

| File | When to read |
|---|---|
| `references/environment.md` | Every request — IPs, storage, network, full config |
| `references/terraform-patterns.md` | Any Terraform addition or change |
| `references/ansible-patterns.md` | Any Ansible addition or change |

---

## Workflow

### Step 1 — Clarify intent (only if ambiguous)
Ask only what you can't derive from the reference files. Common clarifications:
- New VM: what service runs on it?
- Ansible task: which nodes — all or specific group?

Do NOT ask about IPs, storage, bridge names, template ID — those are in the reference files.

### Step 2 — Read reference files
Always read `references/environment.md` first.

### Step 3 — Generate code
Output must include:
- The complete block to add (never a diff)
- The exact file path (`terraform/main.tf`, etc.)
- The exact location ("add after the last resource block")
- Any dependent changes

### Step 4 — Show the commands
```bash
cd terraform && terraform plan
bash ../scripts/scale.sh <count>   # use scale.sh, NOT terraform apply directly
cd ../ansible && ansible web_nodes -i inventory.ini -m raw -a "your command"
```

---

## Ansible rules for this environment

**Always use the raw module.** Standard Ansible modules (file, template, service, apt, etc.)
require Python in the target VM. There is no Python in these Alpine VMs and no internet to
install it.

```yaml
# CORRECT — works in this environment
- name: Deploy MOTD
  raw: "printf 'Welcome\nManaged by Ansible\n' > /etc/motd"

# WRONG — will fail (no Python)
- name: Deploy MOTD
  template:
    src: motd.j2
    dest: /etc/motd
```

Alpine uses `apk`, not `apt`. But since VMs have no internet, even `apk add` won't work
at runtime. Everything must be pre-baked in the golden image (VM 100).

---

## Terraform rules for this environment

Use `bpg/proxmox` resource types, NOT `proxmox_vm_qemu`:

```hcl
# CORRECT
resource "proxmox_virtual_environment_vm" "web_node" { ... }

# WRONG — telmate provider syntax, won't work
resource "proxmox_vm_qemu" "web_node" { ... }
```

Clone from VM 100, not VM 9000:
```hcl
clone {
  vm_id = 100   # golden-template — NOT 9000
  full  = true
}
```

Always set `started = false` — KVM must be disabled before starting:
```hcl
started = false   # configure-node.sh starts it after disabling KVM
```

Always disable agent (Alpine doesn't have qemu-guest-agent):
```hcl
agent {
  enabled = false
}
```

---

## Common request patterns

### "Scale to N nodes"
→ Use `scripts/scale.sh N` — do NOT call terraform directly
→ scale.sh provisions all nodes, stops all but one, prompts for primary selection
→ Updates ansible/inventory.ini automatically

### "Change VM memory/CPU"
→ Edit `vm_memory` or `vm_cores` in `terraform/variables.tf`
→ Run `terraform apply` — existing VMs will be updated on next boot

### "Add an Ansible task"
→ Add raw module task to `ansible/playbook.yml`
→ Or add raw module tasks to an existing role
→ Test with: `ansible web_nodes -i inventory.ini -m raw -a "command"`

### "Rebuild the golden image"
→ Read `references/environment.md` — section: Golden Image Rebuild
→ This involves cloning VM 9000, configuring manually, converting to template

---

## Output format

```
## What I'm generating
[1-2 sentence summary]

## Changes needed

### 1. terraform/variables.tf
[what to add and where]
```hcl
[complete block]
```

### 2. terraform/main.tf
[what to add and where]
```hcl
[complete block]
```

## Run it
```bash
[exact commands — use scale.sh not terraform apply directly]
```

## What this does
[plain English explanation]
```
