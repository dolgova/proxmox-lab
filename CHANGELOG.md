# Changelog

All notable changes to this project are documented here.

---

## [1.4.0] — 2026-03-15

### Added — Golden Image & Scale Wrapper

#### Golden Image (VM 100 — golden-template)

The single biggest improvement to the workflow. Previously every new VM required
manual post-clone work: mounting the disk, setting a password, configuring the
network, enabling sshd. Under hardware constraints this was slow and unreliable.

Solution: Configure one VM perfectly, then convert it to a Proxmox template.
Every Terraform clone inherits everything automatically.

What VM 100 contains:
- Alpine Linux 3.19
- Root password pre-set
- SSH authorized keys pre-injected
- sshd installed, running on boot, PermitRootLogin enabled
- Static IP: 192.168.1.101/24, gateway 192.168.1.1
- KVM disabled at config level

Result: All clones are SSH-accessible immediately after boot. Zero post-config.
Terraform clones from VM 100 (changed from VM 9000 alpine-cloud-template).

#### scripts/scale.sh — Hardware-Aware Scaling Wrapper

Wraps terraform apply with single-VM-at-a-time logic required by the hardware.

Usage:
  bash scripts/scale.sh 3

Flow:
1. Runs terraform apply -var="node_count=3" — provisions 3 VMs
2. Stops all VMs (prevents memory exhaustion on 7.7GB host)
3. Prompts: "Which node should be the PRIMARY?" — user picks 1, 2, or 3
4. Starts only the selected VM
5. Updates ansible/inventory.ini to point to the active node

Why: Running 2+ Alpine VMs simultaneously under NEM emulation exhausts the
7.7GB host RAM and causes Proxmox to crash. scale.sh makes this constraint
transparent — users provision any number of nodes and pick which one is active.

#### scripts/configure-node.sh

Called automatically by the Terraform local-exec provisioner immediately after
each VM is created. Disables KVM (--kvm 0) and removes the cloud-init drive
before first boot. No disk mounting required — clones inherit everything from
the golden image.

### Changed — Terraform Clone Source

Changed clone vm_id from 9000 (alpine-cloud-template) to 100 (golden-template).
This is the change that makes clones immediately SSH-accessible.

### Removed — dashboard/index.html

Removed from active use. The dashboard required a CORS proxy to connect to the
Proxmox API from a browser, adding complexity without value for the demo.
The Proxmox web UI at https://192.168.1.100:8006 provides equivalent monitoring
(VM status, CPU, RAM, task history) without any additional setup.

---

## [1.3.0] — 2026-03-14

### Scope Change — Ubuntu to Alpine Linux

Original design used Ubuntu 22.04 cloud images. Hardware constraints and real-world
installation blockers required switching to Alpine Linux.

Why Alpine:
- Ubuntu cloud-init first-boot: 100%+ CPU for 2+ minutes under NEM emulation
- Proxmox crashes before Ubuntu finishes setup
- Alpine: boots in under 10 seconds, uses ~90MB RAM vs ~512MB for Ubuntu
- No cloud-init overhead — network and auth configured via golden image pattern

### Provider Change — telmate/proxmox to bpg/proxmox

telmate/proxmox v2.9 incorrectly reports "VM.Monitor permission missing" on
Proxmox VE 8+/9 even when the API token has Administrator role. This is a
known upstream bug with no fix in the v2.9 branch.

Switched to bpg/proxmox v0.78+ which correctly handles Proxmox 9 permissions.

### Ansible Approach — Raw Module

Because VMs have no internet access (router restriction), Python3 cannot be
installed at runtime via apk. Switched all Ansible tasks to use the raw module
which runs shell commands over SSH directly — no Python agent required.

This still fully demonstrates configuration management: deploying MOTD banners,
managing SSH authorized keys, writing asset tracking files (/etc/infra-info) —
all from a single Ansible command across all nodes.

### Known Issues Encountered and Fixed

| Issue | Symptom | Fix applied |
|---|---|---|
| Hyper-V / NEM conflict | Snail execution mode, crashes | bcdedit /set hypervisorlaunchtype off |
| KVM unavailable | KVM not available on VM start | configure-node.sh sets --kvm 0 |
| Promiscuous mode | VMs get IP but 100% packet loss | VirtualBox Promiscuous Mode: Allow All |
| Ubuntu cloud-init | CPU 100%+ then crash | Switched to Alpine Linux 3.19 |
| telmate provider bug | VM.Monitor missing | Switched to bpg/proxmox v0.78+ |
| Enterprise repo 401 | apt-get update fails | echo Enabled: no to .sources files |
| pveproxy CORS loop | API unreachable after config | Cleared /etc/default/pveproxy |
| No internet in VMs | apk add fails | Golden image + Ansible raw module |

### Terraform Changes

- main.tf: bpg/proxmox provider, started = false, agent disabled, lifecycle ignore_changes
- variables.tf: vm_memory default 512MB → 256MB
- inventory.tpl: ansible_user changed from ubuntu to root, static IP pattern

---

## [1.2.0] — 2026-03-13

### Added — Ansible Roles

- ansible/roles/motd/ — Dynamic MOTD role (Jinja2 template, per-node values)
- ansible/roles/ssh-keys/ — SSH key management (add/revoke/audit with tags)
- ansible/roles/motd/templates/infra-info.j2 — Asset tracking file per node
- ansible/group_vars/all.yml — Central SSH key list, cluster config
- ansible/ops/runbook.md — Day-to-day command reference

---

## [1.1.0] — 2026-03-13

### Added — Claude Code Skills

- CLAUDE.md — auto-loads all skills when Claude Code opens this repo
- .claude/skills/proxmox-iac/ — Infrastructure Generator
- .claude/skills/proxmox-debug/ — Environment Diagnostics
- .claude/skills/node-role-builder/ — Ansible Role Scaffolder
- .claude/skills/scale-policy-editor/ — Autoscaler Config
- docs/claude-code-skills-guide.md — Full Claude Code install and usage guide

---

## [1.0.0] — 2026-03-13

### Added — Initial Release

- bash/proxmox-init.sh — Proxmox post-install automation
- terraform/ — VM provisioning via Proxmox API (telmate provider, later replaced)
- ansible/ — VM configuration playbook
- dashboard/index.html — Browser monitoring UI (later removed)
- autoscale/autoscale.sh — CPU-based autoscaler (1-5 nodes, --stress demo flag)
- scripts/install-deps.sh — WSL2 dependency installer
- .github/workflows/validate.yml — CI: terraform validate, ansible-lint, shellcheck
- docs/writeup.md — Assessment writeup
