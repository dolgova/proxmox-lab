---
name: proxmox-iac
description: >
  Generates production-ready Terraform and Ansible code for the Proxmox Private Cloud Lab
  environment. Use this skill whenever a developer wants to add, modify, or remove
  infrastructure in this repo — even if they don't know Terraform or Ansible syntax.
  Triggers on phrases like: "add a VM", "provision a new node", "I need a Redis server",
  "add a database VM", "create a new Ansible role", "add a service to the nodes",
  "change VM memory", "add a second network", or any request to extend, modify, or
  scale the infrastructure. Also triggers when a developer pastes an error from
  terraform apply or ansible-playbook and asks how to fix it. Always use this skill
  for any infrastructure change in this environment — never generate Terraform or
  Ansible code for this repo from memory alone.
---

# Proxmox IaC — Infrastructure Generator

Generates Terraform and Ansible code that is immediately compatible with this repo's
structure, naming conventions, and Proxmox environment. Output must be paste-ready —
no placeholders, no "fill this in", no guessing.

---

## Your job

1. Understand what the developer wants (new VM, new service, config change, scale tweak)
2. Load the relevant reference file(s) before generating any code
3. Generate complete, correctly formatted code that slots into the existing files
4. Tell the developer exactly which file to edit and where to paste

Never generate code from memory. Always read the reference files first.

---

## Reference files — read before generating

| File | When to read it |
|---|---|
| `references/environment.md` | Every request — contains IPs, names, storage, network config |
| `references/terraform-patterns.md` | Any Terraform addition or change |
| `references/ansible-patterns.md` | Any Ansible addition or change |
| `references/vm-profiles.md` | When sizing a new VM (CPU, RAM, disk) |

---

## Workflow

### Step 1 — Clarify intent (if ambiguous)

Ask only what you need to generate correct code. Common clarifications:

- **New VM**: What service runs on it? Does it need to talk to existing web nodes?
- **New Ansible task**: Which nodes should it run on? All nodes or a specific group?
- **Config change**: Which variable — per-VM or global?

Do not ask about things you can derive from the reference files (IPs, storage names, bridge names, template ID).

### Step 2 — Read reference files

Always read `references/environment.md` first. Then read whichever other reference files apply.

### Step 3 — Generate code

Output must include:
- The **complete block** to add (never a diff, never partial)
- The **exact file path** to edit (`terraform/main.tf`, `terraform/variables.tf`, etc.)
- The **exact location** in the file ("add after the last `resource` block", "add to the `web_nodes` group")
- Any **dependent changes** (e.g. adding a VM resource also requires an output block and inventory entry)

### Step 4 — Show the apply commands

Always end with the exact commands to run:
```bash
cd terraform && terraform plan   # preview
cd terraform && terraform apply  # apply
cd ansible  && ansible-playbook -i inventory.ini playbook.yml  # if Ansible changed
```

---

## Code style rules

Read `references/terraform-patterns.md` and `references/ansible-patterns.md` for full
patterns. Key rules to follow without reading:

- VM names: `{purpose}-node-{index}` e.g. `db-node-1`, `cache-node-1`
- Terraform resource names match VM name with hyphens replaced by underscores: `proxmox_vm_qemu.db_node`
- All new VMs use `count` + `var.{purpose}_node_count` so they are scalable from day one
- Ansible groups named after purpose: `[db_nodes]`, `[cache_nodes]`
- New Ansible roles go in `ansible/roles/{rolename}/tasks/main.yml`
- All tasks have a `name:` that explains what it does in plain English
- Use `become: yes` at the play level, not per-task

---

## Common request patterns

### "Add a VM running X"
→ New `proxmox_vm_qemu` resource in `terraform/main.tf`
→ New count variable in `terraform/variables.tf`
→ New output block in `terraform/outputs.tf`
→ New inventory group in `terraform/inventory.tpl`
→ New Ansible role + playbook entry

### "Change memory / CPU / disk on the web nodes"
→ Edit `vm_memory`, `vm_cores`, or `vm_disk_size` in `terraform/variables.tf`
→ Run `terraform apply` — Proxmox will hot-update where possible

### "Add a task that runs on all nodes"
→ New task block in `ansible/playbook.yml` under the existing tasks section
→ Or new role in `ansible/roles/` if the logic is more than 3 tasks

### "Add a second network interface"
→ New `network {}` block in the `proxmox_vm_qemu` resource
→ Reference `references/environment.md` for available bridges

### "Make the autoscaler trigger at a different threshold"
→ Edit `SCALE_UP_THRESHOLD` and `SCALE_DOWN_THRESHOLD` in `autoscale/autoscale.sh`
→ Suggest reading `references/vm-profiles.md` for guidance on appropriate thresholds

---

## Output format

Always structure your response as:

```
## What I'm generating
[1-2 sentence summary]

## Changes needed

### 1. terraform/variables.tf
[what to add and where]
\```hcl
[complete block]
\```

### 2. terraform/main.tf
[what to add and where]
\```hcl
[complete block]
\```

[...additional files...]

## Apply it
\```bash
[exact commands]
\```

## What this does
[plain English explanation of what the infrastructure change achieves]
```
