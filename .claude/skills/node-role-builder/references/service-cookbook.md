# Service Cookbook

Pre-built role recipes for common services. Use these as the base
rather than generating from scratch. Customize ports, versions, and
config values to match the developer's requirements.

---

## Redis

```yaml
# defaults/main.yml
redis_port: 6379
redis_version: "7.0"
redis_max_memory: "256mb"
redis_max_memory_policy: "allkeys-lru"
redis_bind: "0.0.0.0"
```

```yaml
# tasks/main.yml
- name: Install Redis
  apt:
    name: redis-server
    state: present
    update_cache: yes

- name: Write Redis configuration
  template:
    src: redis.conf.j2
    dest: /etc/redis/redis.conf
    owner: redis
    group: redis
    mode: '0640'
  notify: Restart redis

- name: Start and enable Redis
  service:
    name: redis-server
    state: started
    enabled: yes
```

Verify: `redis-cli -h {{ ansible_default_ipv4.address }} ping` → `PONG`

---

## PostgreSQL

```yaml
# defaults/main.yml
postgres_version: "15"
postgres_db: "appdb"
postgres_user: "appuser"
postgres_password: "changeme"
postgres_port: 5432
```

```yaml
# tasks/main.yml
- name: Install PostgreSQL
  apt:
    name:
      - "postgresql-{{ postgres_version }}"
      - postgresql-client
      - python3-psycopg2
    state: present
    update_cache: yes

- name: Start and enable PostgreSQL
  service:
    name: postgresql
    state: started
    enabled: yes

- name: Create application database
  become_user: postgres
  postgresql_db:
    name: "{{ postgres_db }}"
    state: present

- name: Create application user
  become_user: postgres
  postgresql_user:
    db: "{{ postgres_db }}"
    name: "{{ postgres_user }}"
    password: "{{ postgres_password }}"
    priv: ALL
```

Verify: `psql -h {{ ansible_default_ipv4.address }} -U {{ postgres_user }} -d {{ postgres_db }} -c '\l'`

---

## Node.js App (with PM2)

```yaml
# defaults/main.yml
node_version: "20"
app_port: 3000
app_dir: /opt/app
app_repo: ""         # set this — git repo URL
app_name: "myapp"
```

```yaml
# tasks/main.yml
- name: Install Node.js {{ node_version }}
  shell: |
    curl -fsSL https://deb.nodesource.com/setup_{{ node_version }}.x | bash -
    apt-get install -y nodejs
  args:
    creates: /usr/bin/node

- name: Install PM2 globally
  npm:
    name: pm2
    global: yes

- name: Create app directory
  file:
    path: "{{ app_dir }}"
    state: directory
    owner: ubuntu
    group: ubuntu

- name: Clone application repo
  git:
    repo: "{{ app_repo }}"
    dest: "{{ app_dir }}"
    force: yes
  when: app_repo != ""

- name: Install npm dependencies
  npm:
    path: "{{ app_dir }}"

- name: Start app with PM2
  become_user: ubuntu
  shell: |
    pm2 start {{ app_dir }}/app.js --name {{ app_name }} || pm2 restart {{ app_name }}
  args:
    chdir: "{{ app_dir }}"

- name: Save PM2 process list
  become_user: ubuntu
  shell: pm2 save

- name: Configure PM2 startup
  shell: pm2 startup systemd -u ubuntu --hp /home/ubuntu | tail -1 | bash
```

Nginx reverse proxy addition for `nginx.conf.j2`:
```nginx
location / {
    proxy_pass http://localhost:{{ app_port }};
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host $host;
    proxy_cache_bypass $http_upgrade;
}
```

---

## Docker + Docker Compose

```yaml
# tasks/main.yml
- name: Install Docker dependencies
  apt:
    name:
      - ca-certificates
      - curl
      - gnupg
    state: present

- name: Add Docker GPG key
  shell: |
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  args:
    creates: /etc/apt/keyrings/docker.gpg

- name: Add Docker repository
  shell: |
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | tee /etc/apt/sources.list.d/docker.list
  args:
    creates: /etc/apt/sources.list.d/docker.list

- name: Install Docker
  apt:
    name:
      - docker-ce
      - docker-ce-cli
      - containerd.io
      - docker-buildx-plugin
      - docker-compose-plugin
    state: present
    update_cache: yes

- name: Add ubuntu user to docker group
  user:
    name: ubuntu
    groups: docker
    append: yes

- name: Start and enable Docker
  service:
    name: docker
    state: started
    enabled: yes
```

---

## Prometheus Node Exporter (already installed by default playbook)

This is already included in `ansible/playbook.yml`. Do not add it again.
It runs on port 9100 on every node.

If a developer wants to add a **custom Prometheus exporter** for their app:
- Run it on a port above 9100 (e.g. 9101, 9102)
- Create a systemd service using the standard service pattern
- Add a scrape config if Prometheus is being set up

---

## Nginx Reverse Proxy Addition

When adding a new service that should be accessible via port 80, update the
existing nginx config at `ansible/roles/webserver/templates/nginx.conf.j2`.

Add a new `location` block — do not replace the existing one:

```nginx
server {
    listen 80 default_server;
    root /var/www/html;
    index index.html;

    # Existing hello world — keep this
    location / {
        try_files $uri $uri/ =404;
    }

    # New service — add below
    location /api {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```
