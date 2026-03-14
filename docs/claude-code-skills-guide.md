# Claude Code — Skills Installation & Usage Guide

> How to install Claude Code, install the four Proxmox Lab skills, and use them
> to manage this infrastructure — with real examples specific to this environment.

---

## Table of Contents

- [Part 1 — Installing Claude Code](#part-1--installing-claude-code)
- [Part 2 — Installing the Skills](#part-2--installing-the-skills)
- [Part 3 — Usage Examples by Skill](#part-3--usage-examples-by-skill)
- [Part 4 — Workflow Tips](#part-4--workflow-tips)
- [Quick Reference](#quick-reference)

---

## Part 1 — Installing Claude Code

Claude Code is Anthropic's AI coding assistant CLI. It reads your entire project and
generates code that fits your existing structure — not generic boilerplate. It runs
inside WSL2 on Windows.

### System Requirements

| Requirement | Minimum | Notes |
|---|---|---|
| OS | Windows 10/11 with WSL2 | Claude Code runs inside WSL2 |
| Node.js | v18 or higher | Required to run the CLI |
| npm | v8 or higher | Comes with Node.js |
| Internet | Required | API calls to Anthropic |
| Anthropic API key | Required | From console.anthropic.com |

---

### Step 1 — Install Node.js in WSL2

```bash
# Install nvm (Node Version Manager)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc

# Install Node 20 LTS
nvm install 20 && nvm use 20 && nvm alias default 20

# Verify
node --version   # v20.x.x
npm --version    # 10.x.x
```

---

### Step 2 — Install Claude Code

```bash
npm install -g @anthropic-ai/claude-code

# Verify
claude --version
```

> If you get a permissions error: `npm install -g @anthropic-ai/claude-code --unsafe-perm`

---

### Step 3 — Set Your API Key

Get a key at [console.anthropic.com](https://console.anthropic.com).

```bash
# Set for this session
export ANTHROPIC_API_KEY="sk-ant-xxxxxxxxxxxxxxxx"

# Persist across sessions
echo 'export ANTHROPIC_API_KEY="YOUR_KEY"' >> ~/.bashrc && source ~/.bashrc
```

> ⚠️ Never commit your API key. It is excluded by `.gitignore`.

---

### Step 4 — Launch in the Project

```bash
cd proxmox-lab
claude
# > How can I help you with proxmox-lab?
```

Claude Code scans every file on startup — it already understands the Terraform
variables, Ansible roles, and autoscaler logic before you ask anything.

---

### Verify It Works

Inside the prompt, ask:

```
What files are in the terraform directory and what does each one do?
```

Claude should correctly describe `main.tf`, `variables.tf`, `outputs.tf`, and
`inventory.tpl` with summaries specific to this repo — not generic descriptions.

---

## Part 2 — Installing the Skills

Skills give Claude Code deep knowledge of this specific environment. Without them,
answers are generic. With them, every generated code block uses the exact variable
names, IP addresses, file paths, and naming conventions already in this repo.

### The Four Skills

| Skill | What It Does |
|---|---|
| **proxmox-iac** | Generates Terraform resources + Ansible tasks/roles, ready to paste |
| **proxmox-debug** | Maps error messages to root causes with exact fix commands |
| **node-role-builder** | Scaffolds complete Ansible roles for any service |
| **scale-policy-editor** | Recommends and applies autoscaler threshold changes |

---

### Install Method A — CLI

```bash
# From the proxmox-lab root
claude skill install .claude/skills/proxmox-iac.skill
claude skill install .claude/skills/proxmox-debug.skill
claude skill install .claude/skills/node-role-builder.skill
claude skill install .claude/skills/scale-policy-editor.skill

# Confirm
claude skill list
```

---

### Install Method B — CLAUDE.md (auto-load, recommended)

The `CLAUDE.md` file in the repo root already lists all four skills. When you run
`claude` in this directory, they load automatically — no install command needed.

To verify the file is present:
```bash
cat CLAUDE.md
# Should show the "Active Skills" section listing all four skill paths
```

---

### Verify Skills Are Active

```bash
claude

# Ask:
What is the Proxmox API URL and what variable in this repo controls node count?

# Expected (pulled from proxmox-iac skill reference files):
# API URL: https://192.168.1.100:8006/api2/json
# Node count: var.node_count in terraform/variables.tf, default 1
```

If Claude answers with values specific to this repo (not placeholders like
`YOUR_IP`), the skills are loaded and working.

---

## Part 3 — Usage Examples by Skill

---

### proxmox-iac — Infrastructure Generator

The skill reads `references/environment.md` (which contains all IPs, variable names,
storage pools, and naming conventions) before generating any code — so output drops
directly into the repo without edits.

---

**Add a Redis caching VM**

```
You: Add a Redis VM with 1GB RAM. It needs to be reachable from the web nodes.
```

Claude generates — across four files:

```hcl
# terraform/variables.tf — new variables
variable "cache_node_count" {
  description = "Number of Redis cache VMs"
  type        = number
  default     = 1
}
variable "cache_vm_memory" {
  type    = number
  default = 1024
}
```

```hcl
# terraform/main.tf — new resource block
resource "proxmox_vm_qemu" "cache_node" {
  count       = var.cache_node_count
  name        = "cache-node-${count.index + 1}"
  target_node = var.proxmox_node
  clone       = var.vm_template
  memory      = var.cache_vm_memory
  cores       = 1
  # ... full block with disk, network, cloud-init, provisioner
}
```

Plus: output block in `outputs.tf`, group entry in `inventory.tpl`, and a complete
Ansible role at `ansible/roles/redis-server/` with tasks, handlers, defaults, and a
`redis.conf.j2` template pre-set with `maxmemory 600mb`.

Apply with:
```bash
cd terraform && terraform apply
cd ansible  && ansible-playbook -i inventory.ini playbook.yml
```

---

**Scale web node RAM from 512MB to 1GB**

```
You: The web nodes keep running out of memory. Increase their RAM to 1GB.
```

```hcl
# terraform/variables.tf — one line change
variable "vm_memory" {
  default = 1024   # was 512
}
```

```bash
cd terraform && terraform apply
# Proxmox hot-updates RAM — no VM restart needed in most cases
```

---

**Add a utility package task to all nodes**

```
You: Add a task to install curl and htop on all web nodes.
```

```yaml
# ansible/playbook.yml — add inside the existing tasks: section
    - name: Install utility packages
      apt:
        name:
          - curl
          - htop
        state: present
```

```bash
cd ansible && ansible-playbook -i inventory.ini playbook.yml
```

---

**Add a PostgreSQL database VM**

```
You: I need a Postgres VM with 2GB RAM and 40GB disk for application data.
```

Claude reads `vm-profiles.md`, selects the "large" profile, and generates the full
4-file Terraform addition plus a complete Ansible role — including tasks, a templated
`pg_hba.conf`, and database/user creation tasks. Warns to verify available host
memory in Proxmox before applying.

---

### proxmox-debug — Error Diagnostics

The skill maps error strings directly to root causes for this environment and
generates copy-pasteable fix commands — no documentation hunting required.

---

**`Error: 401 Unauthorized` from terraform apply**

```
You: terraform apply is failing with 401 Unauthorized
```

```
Root cause: TF_VAR_proxmox_api_token_secret is not set in your shell.

Confirm:
  echo $TF_VAR_proxmox_api_token_secret   # empty = confirmed

Fix:
  export TF_VAR_proxmox_api_token_secret="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

Persist:
  echo 'export TF_VAR_proxmox_api_token_secret="TOKEN"' >> ~/.bashrc

Verify:
  terraform plan   # should show the plan without auth errors
```

---

**Ansible `UNREACHABLE` on all hosts right after terraform apply**

```
You: Ansible says UNREACHABLE for all hosts. Terraform just finished.
```

```
Root cause: VMs are still booting. Cloud-init takes 60–90s after Terraform
finishes before SSH is available.

Fix:
  sleep 90 && ansible web_nodes -i ansible/inventory.ini -m ping

If still failing after 2 minutes:
  # Open https://192.168.1.100:8006 → click VM → Console
  # Look for "Cloud-init complete" in the boot log

If SSH key is missing:
  ssh-copy-id root@192.168.1.100
  terraform apply   # re-creates VMs with key injected
```

---

**Dashboard connects but shows no data**

```
You: I connected the dashboard with the token but it shows nothing.
```

```
Root cause: Browser blocks cross-origin API calls to Proxmox (CORS).

Fix A (easiest): Open dashboard/index.html from your Windows machine — the
  Proxmox host is on the same LAN so the browser allows it.

Fix B (full): Add an nginx reverse proxy on the Proxmox host with CORS headers.
  [Claude generates the full nginx config to paste]
```

---

**`Error: 500 — template not found` during terraform apply**

```
You: terraform apply fails with "template not found"
```

```
Root cause: The Ubuntu cloud-init template (VM 9000) wasn't created by the
init script, or it was deleted.

Confirm:
  ssh root@192.168.1.100 'qm list | grep 9000'

Fix:
  scp bash/proxmox-init.sh root@192.168.1.100:/root/
  ssh root@192.168.1.100 'bash /root/proxmox-init.sh'
```

---

### node-role-builder — Ansible Role Scaffolder

The skill has pre-built recipes for common services. It also reads the existing
`nginx.conf.j2` before generating anything, so new services add a `location {}`
block rather than overwriting the hello world site.

---

**Deploy a Node.js API behind nginx**

```
You: Deploy my Node.js API on port 3000. I want nginx to proxy /api to it.
```

Generated role at `ansible/roles/node-app/`:

```yaml
# defaults/main.yml
node_version: "20"
app_port: 3000
app_dir: /opt/app
app_name: "myapp"
app_repo: ""   # set to your git repo URL
```

Updated `nginx.conf.j2` adds without removing the existing hello world location:
```nginx
location /api {
    proxy_pass http://localhost:3000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
```

```bash
cd ansible && ansible-playbook -i inventory.ini playbook.yml
# Verify:
curl http://192.168.1.101/api/health
```

---

**Install Docker on all nodes**

```
You: Install Docker on all web nodes so I can run containers.
```

Complete role from the service cookbook — adds Docker apt repo, installs
`docker-ce` and `docker-compose-plugin`, adds `ubuntu` user to the docker group.

```bash
# Verify after playbook runs:
ansible web_nodes -i ansible/inventory.ini -m shell -a "docker --version"
```

---

**Set up Redis as a service (standalone role)**

```
You: Deploy Redis on all nodes. Max memory 256MB, port 6379.
```

Generated `ansible/roles/redis-server/` with tasks, handlers, `redis.conf.j2`
template, and defaults you can override per-environment. Verify command:

```bash
ansible web_nodes -i ansible/inventory.ini \
  -m shell -a "redis-cli ping" --become
# Expected: PONG on every host
```

---

### scale-policy-editor — Autoscaler Tuning

The skill knows the config block at the top of `autoscale/autoscale.sh` and has
workload-to-policy mappings in its reference files.

---

**Nodes keep flapping (scale up then down repeatedly)**

```
You: The autoscaler keeps adding a node and then removing it every few minutes.
```

```
Root cause: The gap between up (70%) and down (25%) thresholds is too narrow.
With normal variance in CPU load, the metric bounces back and forth across both.

Recommended change:
  SCALE_UP_THRESHOLD:   70 → 75
  SCALE_DOWN_THRESHOLD: 25 → 20
  COOLDOWN:             60 → 120

Apply:
  sed -i 's/^SCALE_UP_THRESHOLD=.*/SCALE_UP_THRESHOLD=75/'   autoscale/autoscale.sh
  sed -i 's/^SCALE_DOWN_THRESHOLD=.*/SCALE_DOWN_THRESHOLD=20/' autoscale/autoscale.sh
  sed -i 's/^COOLDOWN=.*/COOLDOWN=120/'                       autoscale/autoscale.sh

Tradeoff: Slightly slower to react to real spikes, but no thrashing.
```

---

**Scale based on memory instead of CPU**

```
You: I'm running Redis. CPU is fine but nodes run out of RAM. Scale on memory?
```

Claude provides a complete replacement `get_node_memory_usage()` function that
reads `node_memory_MemAvailable_bytes` from the Prometheus node exporter on each
node (port 9100), plus recommended thresholds for Redis workloads:

```
SCALE_UP_THRESHOLD=75    # scale when 75% of RAM is in use
SCALE_DOWN_THRESHOLD=40
COOLDOWN=120             # memory changes more slowly than CPU
```

---

**Always keep at least 2 nodes running**

```
You: I want at least 2 nodes running at all times, even at night.
```

```bash
sed -i 's/^MIN_NODES=.*/MIN_NODES=2/' autoscale/autoscale.sh
cd terraform && terraform apply -var="node_count=2"
```

---

## Part 4 — Workflow Tips

### Prompt Patterns That Work Best

| Instead of... | Say... | Why |
|---|---|---|
| "How do I add a VM?" | "Add a MySQL VM with 2GB RAM to this project" | Gets environment-specific code |
| "Fix my error" | "[paste full error output] — fix this" | Claude needs the actual error text |
| "How does autoscaling work?" | "Why did the autoscaler add a node at 2pm?" | Specific → specific answer |
| "How do I deploy Redis?" | "Deploy Redis on all web nodes on port 6379" | Triggers role generation |

---

### Using Multiple Skills Together

A typical new-service workflow in one Claude Code session:

1. Ask `proxmox-iac`: *"Add a Postgres VM with 2GB RAM"* → generates Terraform
2. Run `terraform apply` → if it errors, paste the error → `proxmox-debug` fixes it
3. Run `ansible-playbook` → ask `node-role-builder`: *"Deploy my Flask app on port 5000"*
4. Ask `scale-policy-editor`: *"Set thresholds for a database workload"*

You don't need to tell Claude which skill to use — it loads the right one based on
what you ask.

---

### Keeping Skills Current

The skills reference files are the source of truth for code generation. When the
environment changes, keep them in sync:

| Change | Update this file |
|---|---|
| Proxmox IP changes | `.claude/skills/proxmox-iac/references/environment.md` |
| New VM group added | "Existing VM Groups" table in `environment.md` |
| Variable renamed in `variables.tf` | `terraform-patterns.md` |
| New service port opened | "Ports in Use" table in `environment.md` |

---

## Quick Reference

### Install Commands

```bash
# 1. Node.js via nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc && nvm install 20 && nvm use 20

# 2. Claude Code
npm install -g @anthropic-ai/claude-code

# 3. API key
export ANTHROPIC_API_KEY="sk-ant-xxxx"
echo 'export ANTHROPIC_API_KEY="sk-ant-xxxx"' >> ~/.bashrc

# 4. Skills (from proxmox-lab root)
claude skill install .claude/skills/proxmox-iac.skill
claude skill install .claude/skills/proxmox-debug.skill
claude skill install .claude/skills/node-role-builder.skill
claude skill install .claude/skills/scale-policy-editor.skill

# 5. Launch
cd proxmox-lab && claude
```

---

### Prompt Cheat Sheet

| Goal | What to type |
|---|---|
| Add a new VM type | `Add a [service] VM with [X]GB RAM to this project` |
| Scale VM resources | `Increase web node [CPU / RAM / disk] to [value]` |
| Fix Terraform error | `[paste error] — fix this` |
| Fix Ansible error | `[paste error] — why is this happening and how do I fix it` |
| Deploy a service | `Deploy [service] on all web nodes on port [port]` |
| Tune autoscaler | `The autoscaler is [too aggressive / too slow] for [workload]` |
| Add an Ansible task | `Add a task to install [package] on all nodes` |
| Debug the dashboard | `The dashboard shows [symptom] — what's wrong?` |
| Preview Terraform changes | `What will change if I run terraform apply right now?` |
| Understand a file | `Explain what [file] does in plain English` |
