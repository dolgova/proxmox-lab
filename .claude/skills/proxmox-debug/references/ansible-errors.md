# Ansible Error Reference

## UNREACHABLE — SSH connection refused

**Cause A:** VM is still booting (most common — cloud-init takes 60–90s).
```bash
# Wait and retry
sleep 90 && ansible web_nodes -i inventory.ini -m ping
```

**Cause B:** SSH key not on Proxmox host (so it can't be injected into VMs).
```bash
# Fix: copy key to Proxmox
ssh-copy-id root@192.168.1.100
# Then re-run terraform apply to recreate VMs with the key
```

**Cause C:** VM has no IP yet (DHCP not assigned).
```bash
# Check VM console in Proxmox UI — look for cloud-init output
# Or check from Proxmox host:
ssh root@192.168.1.100 'qm guest cmd 101 network-get-interfaces'
```

---

## FAILED — Gathering Facts — "Permission denied"

**Cause:** Wrong SSH user. VMs use `ubuntu`, not `root`.

Check `ansible/inventory.ini` — each line must have `ansible_user=ubuntu`.

If missing, it means Terraform's inventory template wrote wrong values. Check `terraform/inventory.tpl`.

---

## FAILED — "sudo: a password is required"

**Cause:** `become: yes` is not set at the play level.

All plays in this repo should have `become: yes` at the play level (not per-task). Check `ansible/playbook.yml`.

---

## FAILED — "Could not find or access '/path/to/file.j2'"

**Cause:** Template file path is wrong. Ansible looks for templates relative to the role directory.

Templates must be in `ansible/roles/{rolename}/templates/` and referenced without a path prefix:
```yaml
# Correct
src: nginx.conf.j2

# Wrong
src: roles/webserver/templates/nginx.conf.j2
```

---

## inventory.ini is empty after terraform apply

**Cause:** `local_file.ansible_inventory` resource failed silently, or `inventory.tpl` has a syntax error.

```bash
# Check Terraform state for the inventory resource
cd terraform && terraform state show local_file.ansible_inventory

# Manually regenerate from state
terraform output -json | jq -r '.vm_ips.value | to_entries[] | "\(.key) ansible_host=\(.value) ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa"' > ../ansible/inventory.ini
```

---

# App Error Reference

## Dashboard: no data / CORS error

**Cause:** Browser blocks cross-origin API calls to Proxmox (CORS not enabled).

**Fix A — use same machine:** Open `dashboard/index.html` from the machine running Proxmox, or from Windows (where Proxmox is on the local network).

**Fix B — nginx reverse proxy on Proxmox:**
```bash
ssh root@192.168.1.100
apt install -y nginx

cat > /etc/nginx/sites-available/proxmox-proxy << 'EOF'
server {
    listen 8080;
    location / {
        proxy_pass https://localhost:8006;
        proxy_ssl_verify off;
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Headers "Authorization, Content-Type";
        add_header Access-Control-Allow-Methods "GET, POST, OPTIONS";
    }
}
EOF

ln -s /etc/nginx/sites-available/proxmox-proxy /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx
```
Then use port `8080` in the dashboard instead of `8006`.

---

## Autoscaler: "No nodes found in inventory"

**Cause:** `ansible/inventory.ini` doesn't exist yet — Terraform hasn't been run.

```bash
cd terraform && terraform apply
# Then restart autoscaler
```

---

## Autoscaler scales up but Ansible fails on new node

**Cause:** New VM not ready when Ansible triggers (cloud-init still running).

The autoscaler's `scale_to()` function has a `sleep 10` before running Ansible — increase it:

```bash
# In autoscale/autoscale.sh, find:
sleep 10
# Change to:
sleep 90
```

---

## VM boots but hello world site returns 502

**Cause:** nginx didn't start, or the Ansible playbook didn't complete on this node.

```bash
# Check nginx on specific node
ansible web-node-1 -i ansible/inventory.ini \
  -m shell -a "systemctl status nginx" --become

# Re-run playbook on just this node
ansible-playbook -i ansible/inventory.ini playbook.yml --limit web-node-1
```
