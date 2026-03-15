---
name: node-role-builder
description: >
  Scaffolds Ansible roles and tasks for the Proxmox lab nodes. Use when someone wants
  to deploy a new service or configuration to nodes, create a new Ansible role, add
  monitoring, manage files or users, or extend the playbook. Triggers on: "add nginx",
  "deploy X to the nodes", "create a role for Y", "configure Z on all nodes",
  "add a health check", "set up monitoring", "manage users", "deploy a config file".
  Critical constraint: ALL tasks must use the raw module — no Python in VMs, no internet.
  Standard Ansible modules (template, service, package, file, copy) will fail.
  Alpine Linux uses apk and rc-service, not apt and systemctl.
---

# Node Role Builder — Ansible Role Scaffolder

Builds Ansible roles and tasks compatible with this environment's constraints:
Alpine Linux, no Python, no internet, raw module only.

---

## Hard constraints — never violate

1. **Raw module only** — no template, file, copy, service, package, apt, yum modules
2. **No package installs at runtime** — no internet in VMs; everything must be in golden image
3. **Alpine service manager** — `rc-service` not `systemctl`; `rc-update add` not `systemctl enable`
4. **gather_facts: false** — facts require Python, must be disabled
5. **Single active node** — roles run against one VM at a time (inventory only has active node)

---

## Role structure

```
ansible/roles/{rolename}/
├── tasks/
│   └── main.yml     # All tasks using raw module
└── README.md        # What the role does, how to run it
```

No `templates/`, `files/`, `vars/`, `handlers/` — those require Python to process.

---

## Role template

```yaml
---
# ansible/roles/{rolename}/tasks/main.yml

- name: "{rolename} - step 1"
  raw: |
    # your shell commands here
    echo "done"
  tags: {rolename}

- name: "{rolename} - step 2"
  raw: |
    # next step
  tags: {rolename}
```

## Playbook entry

```yaml
# In ansible/playbook.yml, add:
- name: Apply {rolename}
  hosts: web_nodes
  gather_facts: false
  roles:
    - {rolename}
```

---

## Common role patterns

### MOTD banner

```yaml
- name: motd - deploy banner
  raw: |
    printf 'Welcome to Proxmox Lab\nNode: {{ inventory_hostname }}\nManaged by: Ansible + Terraform\nCluster: proxmox-lab\n' > /etc/motd
  tags: motd
```

### SSH key management

```yaml
- name: ssh-keys - ensure authorized_keys exists
  raw: "mkdir -p /root/.ssh && touch /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys"
  tags: ssh-keys

- name: ssh-keys - add key for user
  raw: |
    grep -q 'USER_IDENTIFIER' /root/.ssh/authorized_keys || \
    echo 'ssh-ed25519 AAAA... user@host' >> /root/.ssh/authorized_keys
  tags: ssh-keys

- name: ssh-keys - audit keys
  raw: "echo 'Authorized keys:' && wc -l /root/.ssh/authorized_keys && cat /root/.ssh/authorized_keys | cut -c1-60"
  tags: ssh-keys
```

### Asset tracking file

```yaml
- name: infra-info - deploy tracking file
  raw: |
    printf '[node]\nhostname={{ inventory_hostname }}\nip=192.168.1.101\nos=Alpine Linux 3.19\n\n[cluster]\nname=proxmox-lab\nrole=web-node\nproxmox_host=192.168.1.100\n\n[provisioning]\nprovisioned_by=Terraform+Ansible\nlast_configured={{ ansible_date_time.iso8601 | default("unknown") }}\n' > /etc/infra-info
  tags: infra-info
```

Since `ansible_date_time` requires facts (Python), use shell date instead:
```yaml
- name: infra-info - deploy tracking file
  raw: |
    printf '[node]\nhostname={{ inventory_hostname }}\nip=192.168.1.101\nos=Alpine Linux 3.19\n\n[provisioning]\nprovisioned_by=Terraform+Ansible\nlast_configured=' > /etc/infra-info
    date -u +%Y-%m-%dT%H:%M:%SZ >> /etc/infra-info
  tags: infra-info
```

### Health check

```yaml
- name: health - check services
  raw: |
    echo "=== $(hostname) ===" && \
    echo "Uptime: $(uptime)" && \
    echo "IP: $(ip addr show eth0 | grep 'inet ' | awk '{print $2}')" && \
    echo "SSH: $(rc-service sshd status)" && \
    echo "Keys: $(wc -l /root/.ssh/authorized_keys) authorized keys"
  tags: health
```

### Ensure sshd running and enabled

```yaml
- name: sshd - start and enable
  raw: |
    rc-service sshd start 2>/dev/null || true
    rc-update add sshd default 2>/dev/null || true
    echo "sshd status: $(rc-service sshd status)"
  tags: sshd
```

---

## Run a role

```bash
# Run specific role via tag
ansible-playbook -i inventory.ini playbook.yml --tags {rolename}

# Run ad-hoc without a role
ansible web_nodes -i inventory.ini -m raw -a "your command here"

# Test against active node
ssh -i ~/.ssh/proxmox-lab root@192.168.1.101 "your command"
```
