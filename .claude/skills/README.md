# Claude Code Skills — Proxmox Lab

Four Claude Code skills that make this infrastructure accessible to developers
who don't know Terraform or Ansible. Each skill gives Claude deep context about
this specific environment so it can generate correct, paste-ready code without
guessing at variable names, IP addresses, or file structures.

---

## Skills Overview

| Skill | What it does | Triggers when you say... |
|---|---|---|
| `proxmox-iac` | Generates Terraform + Ansible code for any infra change | "add a Redis VM", "increase node RAM", "add a Postgres server" |
| `proxmox-debug` | Diagnoses errors with exact fix commands | "401 error", "ansible can't connect", "VMs won't boot" |
| `node-role-builder` | Scaffolds Ansible roles for deploying any service | "deploy my Node.js app", "install Docker on the nodes" |
| `scale-policy-editor` | Tunes autoscaler thresholds for different workloads | "autoscaler is too aggressive", "scale at 50% CPU" |

---

## Installing Skills in Claude Code

### Option A — Install from .skill files (recommended)

```bash
# Navigate to the skills directory
cd .claude/skills

# Install each skill
claude skill install proxmox-iac.skill
claude skill install proxmox-debug.skill
claude skill install node-role-builder.skill
claude skill install scale-policy-editor.skill
```

### Option B — Reference directly in CLAUDE.md

Add to your project's `CLAUDE.md` file:

```markdown
## Skills

Load these skills when working with infrastructure in this repo:
- .claude/skills/proxmox-iac/SKILL.md — for any Terraform or Ansible changes
- .claude/skills/proxmox-debug/SKILL.md — for debugging errors
- .claude/skills/node-role-builder/SKILL.md — for deploying new services
- .claude/skills/scale-policy-editor/SKILL.md — for autoscaler tuning
```

### Option C — Auto-load via .claude/settings.json

```json
{
  "skills": [
    ".claude/skills/proxmox-iac",
    ".claude/skills/proxmox-debug",
    ".claude/skills/node-role-builder",
    ".claude/skills/scale-policy-editor"
  ]
}
```

---

## Skill Details

### proxmox-iac — Infrastructure Generator

Knows all environment values (IPs, variable names, storage pools, network bridges,
naming conventions) so generated code drops directly into the repo without edits.

**Reference files it uses:**
- `environment.md` — all IPs, ports, variable names, file paths
- `terraform-patterns.md` — exact patterns for adding VMs, changing resources
- `ansible-patterns.md` — task, handler, template, and role patterns
- `vm-profiles.md` — CPU/RAM/disk sizing profiles for common services

**Example prompts:**
```
"Add a Redis VM with 1GB RAM"
"Scale the web nodes to 2 cores each"
"Add a Postgres database node"
"Add a task to install curl on all nodes"
```

---

### proxmox-debug — Environment Diagnostics

Maps error messages to root causes specific to this setup — not generic Terraform
or Ansible docs. Covers every common failure mode with diagnostic commands and exact fixes.

**Reference files it uses:**
- `terraform-errors.md` — 401/403/500 errors, provider issues, template missing
- `ansible-errors.md` — SSH failures, UNREACHABLE, become errors, inventory issues
- `app-errors.md` — dashboard CORS, autoscaler not triggering, nginx 502

**Example prompts:**
```
"terraform apply gives 401 Unauthorized"
"ansible says UNREACHABLE for all hosts"
"dashboard shows no data after connecting"
"autoscaler says no nodes found"
```

---

### node-role-builder — Ansible Role Scaffolder

Generates complete Ansible roles for real application deployment. Includes a
service cookbook with pre-built recipes for Redis, Postgres, Node.js, and Docker.
Knows the existing nginx template so new services don't conflict.

**Reference files it uses:**
- `service-cookbook.md` — ready-to-use recipes for common services
- `role-patterns.md` — task, handler, template, and defaults patterns

**Example prompts:**
```
"Deploy my Node.js API on port 3000 behind nginx"
"Set up Redis on all nodes"
"Add Docker and run a container from my image"
"Replace the hello world site with my Python Flask app"
```

---

### scale-policy-editor — Autoscaler Config Assistant

Explains the current autoscaler behaviour and recommends threshold changes for
different workload patterns. Covers CPU-based and memory-based scaling, flapping
prevention, and cooldown tuning.

**Reference files it uses:**
- `policy-guide.md` — workload patterns, recommended policies, common problems

**Example prompts:**
```
"Nodes keep scaling up and down repeatedly"
"I want to scale based on memory, not CPU"
"The autoscaler triggers too slowly during traffic spikes"
"Always keep at least 2 nodes running"
"Change the max nodes to 10"
```

---

## Directory Structure

```
.claude/skills/
├── README.md                          # This file
│
├── proxmox-iac/
│   ├── SKILL.md                       # Skill instructions
│   ├── references/
│   │   ├── environment.md             # All env values
│   │   ├── terraform-patterns.md      # TF code patterns
│   │   ├── ansible-patterns.md        # Ansible code patterns
│   │   └── vm-profiles.md             # VM sizing guide
│   └── proxmox-iac.skill              # Packaged .skill file
│
├── proxmox-debug/
│   ├── SKILL.md
│   ├── references/
│   │   ├── terraform-errors.md
│   │   └── ansible-errors.md
│   └── proxmox-debug.skill
│
├── node-role-builder/
│   ├── SKILL.md
│   ├── references/
│   │   └── service-cookbook.md        # Redis, Postgres, Node.js, Docker recipes
│   └── node-role-builder.skill
│
└── scale-policy-editor/
    ├── SKILL.md
    ├── references/
    │   └── policy-guide.md            # Workload patterns + thresholds
    └── scale-policy-editor.skill
```
