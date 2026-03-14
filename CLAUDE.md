# Proxmox Lab — Claude Code Context

This is a Proxmox Private Cloud Lab built for the Maritime Capital Private Cloud
Administrator assessment. It demonstrates IaC, configuration management, autoscaling,
and real-time monitoring running locally on a single Windows machine via VirtualBox.

## Project Summary

- **Hypervisor:** Proxmox VE 8.x inside VirtualBox
- **Provisioning:** Terraform (Telmate provider) → Proxmox API
- **Configuration:** Ansible → nginx, Prometheus node exporter, app deployment
- **Monitoring:** Custom HTML dashboard polling Proxmox API every 5s
- **Autoscaling:** Bash autoscaler, 1–5 nodes, CPU threshold-based
- **Proxmox host:** 192.168.1.100 | API: https://192.168.1.100:8006/api2/json

## Active Skills

Load these skills automatically for any task in this repo:

- `.claude/skills/proxmox-iac/SKILL.md`
  Use for: adding VMs, changing Terraform config, adding Ansible tasks or roles,
  any infrastructure addition or modification

- `.claude/skills/proxmox-debug/SKILL.md`
  Use for: any error output from terraform, ansible-playbook, or the autoscaler

- `.claude/skills/node-role-builder/SKILL.md`
  Use for: deploying a new service to the nodes, creating Ansible roles,
  setting up Redis / Postgres / Node.js / Docker

- `.claude/skills/scale-policy-editor/SKILL.md`
  Use for: changing autoscaler thresholds, fixing flapping, switching to
  memory-based scaling

## Key Files

| File | Purpose |
|---|---|
| `terraform/variables.tf` | All configurable values — start here for any infra change |
| `terraform/main.tf` | VM resource definitions |
| `ansible/playbook.yml` | Main Ansible entry point |
| `autoscale/autoscale.sh` | Autoscaler — config variables at the top |
| `dashboard/index.html` | Monitoring UI — open directly in browser |
| `.claude/skills/` | Skill definitions and reference files |
| `docs/claude-code-skills-guide.md` | Full Claude Code installation and usage guide |
