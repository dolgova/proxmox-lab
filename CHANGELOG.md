# Changelog

All notable changes to this project are documented here.

Format: [Semantic Versioning](https://semver.org)

---

## [1.2.0] — 2026-03-13

### Added — Ansible demonstrations

- `ansible/roles/motd/` — Dynamic Message of the Day role
  - Jinja2 template renders per-node hostname, IP, cluster role, and live service status
  - Visible immediately on SSH login — no extra commands needed
  - Disables noisy default Ubuntu MOTD scripts
- `ansible/roles/ssh-keys/` — SSH key management role
  - Distributes authorized keys from a central source (`group_vars/all.yml`)
  - Supports add, revoke, and audit workflows via tags (`--tags ssh-keys`)
  - One file per person/service in `roles/ssh-keys/files/keys/`
- `ansible/roles/motd/templates/infra-info.j2` — Asset tracking file
  - Deploys `/etc/infra-info` to every node with hostname, IP, OS, provisioning metadata
  - Last-configured timestamp shows when Ansible last ran on each node
- `ansible/group_vars/all.yml` — Shared variable file
  - Central SSH key list, MOTD config, node exporter version
- `ansible/host_vars/web-node-1.yml.example` — Per-node override example
- `ansible/ops/runbook.md` — Full day-to-day command reference
  - Add/revoke key workflows, service management, health checks, debugging

### Updated
- `ansible/playbook.yml` — All three Ansible demos integrated with `--tags` support
- `README.md` — "Ansible in Action" section with demos, output examples, command reference
- Project structure diagram updated

---

## [1.1.0] — 2026-03-13

### Added
- `CLAUDE.md` — auto-loads all four skills when Claude Code starts in this directory
- `.claude/skills/proxmox-iac/` — Infrastructure Generator skill
- `.claude/skills/proxmox-debug/` — Environment Diagnostics skill
- `.claude/skills/node-role-builder/` — Ansible Role Scaffolder skill
- `.claude/skills/scale-policy-editor/` — Autoscaler Config skill
- `docs/claude-code-skills-guide.md` — Full Claude Code install and usage guide

---

## [1.0.0] — 2026-03-13

### Added
- `bash/proxmox-init.sh` — full Proxmox post-install automation
- `terraform/` — VM provisioning via Proxmox API (Telmate provider)
- `ansible/` — VM configuration: nginx, hello world site, node exporter, SSH hardening
- `dashboard/index.html` — browser-based monitoring UI (live CPU/RAM/disk, 5s refresh)
- `autoscale/autoscale.sh` — CPU-based autoscaler (1–5 nodes, --stress demo flag)
- `scripts/install-deps.sh` — WSL2 dependency installer
- `.github/workflows/validate.yml` — CI for Terraform, Ansible, and shell scripts
- `docs/writeup.md` — assessment writeup
