# Ansible Operations Runbook

Day-to-day command reference for managing the Proxmox Lab cluster.
All commands run from the `ansible/` directory.

---

## Full Provisioning Run

```bash
# Configure all nodes (run after terraform apply)
ansible-playbook -i inventory.ini playbook.yml

# Dry run — see what would change without touching anything
ansible-playbook -i inventory.ini playbook.yml --check

# Verbose — see each task's before/after state
ansible-playbook -i inventory.ini playbook.yml -v
```

---

## Targeting Specific Nodes or Tags

```bash
# Run on a single node only
ansible-playbook -i inventory.ini playbook.yml --limit web-node-2

# Run only SSH key tasks across all nodes
ansible-playbook -i inventory.ini playbook.yml --tags ssh-keys

# Run only MOTD tasks across all nodes
ansible-playbook -i inventory.ini playbook.yml --tags motd

# Combine: MOTD on a single node
ansible-playbook -i inventory.ini playbook.yml --tags motd --limit web-node-1
```

---

## SSH Key Management

### Add a new key

```bash
# 1. Copy the public key file into the keys directory
cp /path/to/newperson.pub roles/ssh-keys/files/keys/newperson.pub

# 2. Add the filename to group_vars/all.yml
#    Under ssh_authorized_keys:, add: - newperson.pub

# 3. Push the key to all nodes
ansible-playbook -i inventory.ini playbook.yml --tags ssh-keys

# Verify it landed
ansible web_nodes -i inventory.ini -m shell \
  -a "grep newperson /home/ubuntu/.ssh/authorized_keys" --become
```

### Revoke a key

```bash
# 1. Remove the filename from ssh_authorized_keys in group_vars/all.yml
# 2. Add the full key string to ssh_revoked_keys in group_vars/all.yml
# 3. Push the revocation to all nodes
ansible-playbook -i inventory.ini playbook.yml --tags ssh-keys

# Confirm the key is gone
ansible web_nodes -i inventory.ini -m shell \
  -a "cat /home/ubuntu/.ssh/authorized_keys" --become
```

### Audit — who can access what

```bash
# Print current authorized keys on every node
ansible web_nodes -i inventory.ini \
  -m shell -a "cat /home/ubuntu/.ssh/authorized_keys" --become

# Count keys per node
ansible web_nodes -i inventory.ini \
  -m shell -a "wc -l /home/ubuntu/.ssh/authorized_keys" --become

# Check for any unexpected keys (compare against what Ansible manages)
ansible-playbook -i inventory.ini playbook.yml --tags audit
```

---

## MOTD and infra-info

```bash
# Deploy/refresh MOTD on all nodes
ansible-playbook -i inventory.ini playbook.yml --tags motd

# Preview the MOTD on one node without Ansible (SSH in and run directly)
ssh ubuntu@192.168.1.101
# → MOTD appears automatically on login

# Or trigger it manually without logging out
/usr/bin/run-parts /etc/update-motd.d

# Read the infra-info file on all nodes
ansible web_nodes -i inventory.ini \
  -m shell -a "cat /etc/infra-info" --become

# Check last_configured timestamp (when Ansible last touched a node)
ansible web_nodes -i inventory.ini \
  -m shell -a "grep last_configured /etc/infra-info" --become
```

---

## Service Management

```bash
# Check nginx status across all nodes
ansible web_nodes -i inventory.ini \
  -m shell -a "systemctl status nginx --no-pager" --become

# Restart nginx on all nodes
ansible web_nodes -i inventory.ini \
  -m service -a "name=nginx state=restarted" --become

# Check node_exporter on all nodes
ansible web_nodes -i inventory.ini \
  -m shell -a "systemctl status node_exporter --no-pager" --become

# Verify metrics endpoint is responding
ansible web_nodes -i inventory.ini \
  -m uri -a "url=http://localhost:9100/metrics return_content=no"
```

---

## Quick Health Check

```bash
# Ping all nodes
ansible web_nodes -i inventory.ini -m ping

# Check uptime
ansible web_nodes -i inventory.ini -m shell -a "uptime"

# Check disk usage
ansible web_nodes -i inventory.ini -m shell -a "df -h /" --become

# Check memory
ansible web_nodes -i inventory.ini -m shell -a "free -h"

# One-liner full status report
ansible web_nodes -i inventory.ini -m shell \
  -a "hostname && uptime && df -h / | tail -1 && free -h | grep Mem"
```

---

## Node Exporter / Metrics

```bash
# Test metrics endpoint on every node
for ip in $(grep ansible_host inventory.ini | awk '{print $2}' | cut -d= -f2); do
  echo "=== $ip ===" && curl -s "http://${ip}:9100/metrics" | grep "node_load1 " 
done

# Check CPU load via metrics (same metric the autoscaler reads)
ansible web_nodes -i inventory.ini \
  -m uri -a "url=http://localhost:9100/metrics return_content=yes" \
  | grep node_load1
```

---

## Debugging

```bash
# Test connectivity before running playbook
ansible web_nodes -i inventory.ini -m ping

# Show all facts Ansible has gathered about a node
ansible web-node-1 -i inventory.ini -m setup

# Show specific facts
ansible web-node-1 -i inventory.ini -m setup \
  -a "filter=ansible_default_ipv4"

# Run a playbook with full debug output
ansible-playbook -i inventory.ini playbook.yml -vvv 2>&1 | tee /tmp/ansible-debug.log
```
