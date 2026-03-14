---
name: node-role-builder
description: >
  Scaffolds complete Ansible roles for deploying any service onto nodes in the
  Proxmox Private Cloud Lab. Use this skill whenever a developer wants to deploy
  their own application or service to the VMs instead of (or alongside) the default
  nginx hello world site. Triggers on: "deploy my app", "install X on the nodes",
  "add a Node.js service", "set up Redis", "configure Postgres", "add a reverse proxy",
  "deploy a Python app", "run a Docker container on the VMs", "replace the hello world
  site with my app", or any request to install, configure, or run a custom service
  on the Proxmox lab nodes. Always use this skill for service deployment — it knows
  the existing role structure, nginx template, and playbook layout.
---

# Node Role Builder — Ansible Role Scaffolder

Generates a complete, drop-in Ansible role for any service, matched to the structure
and conventions of this repo. Output is immediately usable — no further editing needed
beyond filling in app-specific config values.

---

## What you generate

For every request, produce:

1. `ansible/roles/{rolename}/tasks/main.yml` — complete task list
2. `ansible/roles/{rolename}/handlers/main.yml` — restart/reload handlers
3. `ansible/roles/{rolename}/defaults/main.yml` — configurable variables with sensible defaults
4. Any templates needed in `ansible/roles/{rolename}/templates/`
5. The addition to `ansible/playbook.yml` — where to add the role

---

## Reference files

| File | When to read |
|---|---|
| `references/role-patterns.md` | Every request — contains full task, handler, and template patterns |
| `references/service-cookbook.md` | When the service is in the list (Redis, Postgres, Node.js, Docker, etc.) — use the pre-built recipe |

---

## Workflow

### Step 1 — Understand the service

Ask only if the answer is not inferable:
- What port does it listen on?
- Does it need to be behind nginx (reverse proxy) or serve directly?
- Should it run on all web nodes or a dedicated VM group?
- Is there a config file that needs to be templated?

### Step 2 — Check the service cookbook

Read `references/service-cookbook.md`. If the service is listed, use that recipe
as the base — don't generate from scratch.

### Step 3 — Check for nginx conflict

If the new service also uses port 80 or needs nginx as a reverse proxy, the existing
`roles/webserver` role must be updated. Read the existing
`ansible/roles/webserver/templates/nginx.conf.j2` and generate an updated version
that adds the new `location {}` block without removing the hello world site.

### Step 4 — Generate the role

Follow patterns in `references/role-patterns.md` exactly.

### Step 5 — Show where to add to playbook.yml

Generate the exact play block to append to `ansible/playbook.yml`.

---

## Output format

```
## Role: {rolename}

### ansible/roles/{rolename}/tasks/main.yml
\```yaml
[complete file]
\```

### ansible/roles/{rolename}/handlers/main.yml
\```yaml
[complete file]
\```

### ansible/roles/{rolename}/defaults/main.yml
\```yaml
[complete file]
\```

### ansible/roles/{rolename}/templates/{file}.j2  (if needed)
\```
[complete file]
\```

### Add to ansible/playbook.yml
[Exact location — "append this play block at the bottom of playbook.yml"]
\```yaml
[play block]
\```

## Apply it
\```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
\```

## Verify
[How to confirm the service is running — curl command, log to check, port to test]
```
