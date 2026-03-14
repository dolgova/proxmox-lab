# Ansible Patterns

Copy these patterns exactly when generating Ansible code for this repo.

---

## Playbook Structure

`ansible/playbook.yml` is the single entry point. It imports roles and runs tasks.
New VM groups get their own play block. New tasks for existing nodes go inside the
existing `- name: Configure web nodes` play.

```yaml
# Pattern for a new VM type — add as a new play at the bottom of playbook.yml
- name: Configure {purpose} nodes
  hosts: {purpose}_nodes
  become: yes
  gather_facts: yes

  roles:
    - {purpose}        # maps to ansible/roles/{purpose}/

  tasks:
    # Additional one-off tasks go here if they don't warrant a role
```

---

## Role Structure

Every service gets its own role under `ansible/roles/`. Minimum structure:

```
ansible/roles/{rolename}/
├── tasks/
│   └── main.yml          # required
├── templates/            # Jinja2 templates (.j2)
│   └── *.j2
├── handlers/
│   └── main.yml          # optional — for notify/restart
└── defaults/
    └── main.yml          # optional — role-level variables
```

---

## Task Patterns

### Install a package

```yaml
- name: Install {package}
  apt:
    name: {package}
    state: present
    update_cache: yes
```

### Install multiple packages

```yaml
- name: Install required packages
  apt:
    name:
      - {package1}
      - {package2}
      - {package3}
    state: present
    update_cache: yes
```

### Deploy a config file from a template

```yaml
- name: Write {service} configuration
  template:
    src: {service}.conf.j2
    dest: /etc/{service}/{service}.conf
    owner: root
    group: root
    mode: '0644'
  notify: Restart {service}
```

### Start and enable a service

```yaml
- name: Start and enable {service}
  service:
    name: {service}
    state: started
    enabled: yes
```

### Create a system user (for services)

```yaml
- name: Create {service} system user
  user:
    name: {service}
    shell: /bin/false
    system: yes
    create_home: no
```

### Run a shell command (when no module exists)

```yaml
- name: {describe what this does in plain English}
  shell: {command}
  args:
    creates: /path/to/file/that/proves/it/ran   # makes it idempotent
```

### Download and extract a binary

```yaml
- name: Download {tool} v{{ {tool}_version }}
  get_url:
    url: "https://example.com/{tool}-{{ {tool}_version }}.tar.gz"
    dest: /tmp/{tool}.tar.gz

- name: Extract {tool}
  unarchive:
    src: /tmp/{tool}.tar.gz
    dest: /tmp/
    remote_src: yes

- name: Install {tool} binary
  copy:
    src: "/tmp/{tool}-{{ {tool}_version }}/{tool}"
    dest: /usr/local/bin/{tool}
    mode: '0755'
    remote_src: yes
```

### Create a systemd service

```yaml
- name: Create {service} systemd unit
  copy:
    dest: /etc/systemd/system/{service}.service
    content: |
      [Unit]
      Description={Service description}
      After=network.target

      [Service]
      User={service}
      ExecStart=/usr/local/bin/{service}
      Restart=always

      [Install]
      WantedBy=multi-user.target
  notify:
    - Reload systemd
    - Restart {service}
```

---

## Handler Patterns

Handlers go in `ansible/roles/{rolename}/handlers/main.yml`:

```yaml
---
- name: Restart {service}
  service:
    name: {service}
    state: restarted

- name: Reload {service}
  service:
    name: {service}
    state: reloaded

- name: Reload systemd
  systemd:
    daemon_reload: yes
```

---

## Template Patterns (Jinja2)

Templates live in `ansible/roles/{rolename}/templates/` with `.j2` extension.

Available variables in templates:
- `{{ ansible_hostname }}` — the VM's hostname (e.g. `web-node-1`)
- `{{ ansible_default_ipv4.address }}` — the VM's IP address
- `{{ ansible_fqdn }}` — fully qualified domain name
- `{{ inventory_hostname }}` — name from inventory (same as hostname)
- `{{ hostvars[inventory_hostname]['ansible_host'] }}` — IP from inventory

Custom variables — define in `ansible/roles/{rolename}/defaults/main.yml`:
```yaml
---
{service}_port: 6379
{service}_max_memory: "256mb"
```

Then use in templates: `{{ {service}_port }}`

---

## Running Against a Subset of Nodes

```bash
# All nodes in a group
ansible-playbook -i inventory.ini playbook.yml --limit {purpose}_nodes

# Single specific node
ansible-playbook -i inventory.ini playbook.yml --limit {purpose}-node-1

# All nodes matching a pattern
ansible-playbook -i inventory.ini playbook.yml --limit "*node*"
```

---

## Naming Conventions

| Item | Pattern | Example |
|---|---|---|
| Play name | "Configure {purpose} nodes" | "Configure db nodes" |
| Task name | Plain English verb phrase | "Install Redis from apt" |
| Role name | lowercase hyphen | `redis-server`, `node-exporter` |
| Template file | `{service}.{ext}.j2` | `redis.conf.j2` |
| Handler name | "Restart {service}" / "Reload {service}" | "Restart nginx" |
| Variable | `{service}_{property}` | `redis_port`, `redis_max_memory` |
