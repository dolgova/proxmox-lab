---
name: scale-policy-editor
description: >
  Manages scaling configuration and the scale.sh wrapper script for the Proxmox lab.
  Use when someone wants to change autoscaler thresholds, modify how many VMs are
  provisioned, change which VM is active, fix scaling issues, or understand how
  scale.sh works. Triggers on: "change scale threshold", "why won't it scale",
  "autoscaler not working", "how do I switch active node", "scale to N nodes",
  "too many VMs running", "Proxmox keeps crashing when scaling".
  Critical: this environment can only run ONE VM at a time due to 7.7GB RAM.
  scale.sh is the primary scaling interface — not terraform apply directly.
---

# Scale Policy Editor

Manages the scaling workflow for a resource-constrained single-laptop environment.

---

## How scaling works in this environment

This is not a normal multi-VM environment. Key constraints:

- **7.7GB RAM total** — Proxmox uses ~1.6GB, each VM uses ~256MB
- **Only ONE VM can be running at a time** — running 2+ crashes Proxmox under NEM emulation
- **All active VMs use IP 192.168.1.101** — same IP, just different VM IDs
- **scale.sh is the primary interface** — handles the provision + stop-all + start-one logic

---

## scale.sh — how it works

```bash
bash scripts/scale.sh <count>
```

1. Runs `terraform apply -var="node_count=<count>"` — creates all VMs
2. Stops all running VMs
3. Asks: "Which node should be the PRIMARY?"
4. Starts only the selected VM
5. Rewrites `ansible/inventory.ini` to point to active node

---

## Switching active node without reprovisioning

```bash
# Stop current active node
ssh proxmox "qm stop 101"

# Start a different node
ssh proxmox "qm start 102"

# Update inventory to point to new active node
cat > ansible/inventory.ini << 'EOF'
[web_nodes]
web-node-2 ansible_host=192.168.1.101 ansible_user=root ansible_ssh_private_key_file=~/.ssh/proxmox-lab ansible_ssh_common_args='-o StrictHostKeyChecking=no'

[web_nodes:vars]
ansible_python_interpreter=/usr/bin/python3
EOF
```

---

## Autoscaler — autoscale/autoscale.sh

The autoscaler monitors CPU and calls terraform to scale up or down.

```bash
# Run normally (monitors in background)
bash autoscale/autoscale.sh

# Demo mode — forces CPU high to trigger scale-up
bash autoscale/autoscale.sh --stress
```

### Key variables to tune

```bash
# In autoscale/autoscale.sh — edit these:
SCALE_UP_THRESHOLD=80    # CPU % that triggers adding a node
SCALE_DOWN_THRESHOLD=20  # CPU % that triggers removing a node
SCALE_UP_COOLDOWN=120    # Seconds between scale-up events
SCALE_DOWN_COOLDOWN=300  # Seconds between scale-down events
MIN_NODES=1              # Never go below this
MAX_NODES=2              # IMPORTANT: keep at 2 max for this hardware
POLL_INTERVAL=30         # How often to check CPU
```

**Important:** Keep MAX_NODES at 2 for this environment. Even though scale.sh only
runs one VM at a time, the autoscaler needs to provision 2 to demonstrate the
scale-up behavior. Running 3+ simultaneously will crash Proxmox.

---

## Fixing scale issues

### "Proxmox crashes when I scale to 2"
The autoscaler or scale.sh started both VMs simultaneously. Fix:
```bash
ssh proxmox "qm stop 102"  # stop the second node immediately
```
Then ensure MAX_NODES=2 and scale.sh is used (not terraform apply directly).

### "scale.sh picked wrong node as primary"
Re-run scale.sh — it will stop all nodes and ask again:
```bash
bash scripts/scale.sh 2
# Enter your preferred node number when prompted
```

### "Terraform created too many VMs"
```bash
# Check what exists
ssh proxmox "qm list"

# Scale down via terraform
cd terraform && terraform apply -var="node_count=1" -auto-approve

# If state is inconsistent
terraform state rm proxmox_virtual_environment_vm.web_node
terraform apply -var="node_count=1" -auto-approve
```

### "Wrong node showing in Ansible"
scale.sh rewrites inventory.ini. Check which node is actually running:
```bash
ssh proxmox "qm list | grep running"
```
Then update inventory manually to match.

---

## Demo sequence for interview

```bash
# Show current state
terraform output
ssh proxmox "qm list"

# Scale up — provision 2, select which runs
bash scripts/scale.sh 2
# Pick node 1 when prompted

# Verify node 1 active, node 2 stopped
ssh proxmox "qm list"

# Run Ansible on active node
cd ansible
ansible web_nodes -i inventory.ini -m raw -a "hostname"

# Scale back down
cd ../terraform
terraform apply -var="node_count=1" -auto-approve

# Verify cleanup
ssh proxmox "qm list"
terraform output
```

Key talking points:
- `node_count=N` is the single variable that controls cluster size
- Terraform only changes what's different — idempotent
- scale.sh manages the hardware constraint transparently
- Ansible inventory updates automatically — one command reaches all active nodes
