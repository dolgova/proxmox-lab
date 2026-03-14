# Terraform Error Reference

## 401 Unauthorized

**Cause:** API token not set or wrong value.

```bash
# Confirm: check if env var is set
echo $TF_VAR_proxmox_api_token_secret

# Fix: set it
export TF_VAR_proxmox_api_token_secret="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Fix permanently
echo 'export TF_VAR_proxmox_api_token_secret="YOUR_TOKEN"' >> ~/.bashrc && source ~/.bashrc
```

**Verify:** `terraform plan` runs without auth error.

---

## 403 Forbidden

**Cause:** Token exists but the `terraform@pve` user lacks permissions.

```bash
# Fix: re-run the init script to recreate the role + token
ssh root@192.168.1.100 'bash /root/proxmox-init.sh'
# Copy the new token from the output
```

---

## connection refused / dial tcp 192.168.1.100:8006

**Cause:** Proxmox host is down, still booting, or IP is wrong.

```bash
# Confirm reachability
ping 192.168.1.100

# Confirm API is up
curl -sk https://192.168.1.100:8006/api2/json/version | jq .data.version

# If unreachable — check VirtualBox VM is running
# Open VirtualBox Manager → confirm Proxmox-VE is "Running"
```

---

## Error: 500 Internal Server Error — "template not found"

**Cause:** The cloud-init template (VM 9000) was not created by the init script.

```bash
# Confirm template exists
ssh root@192.168.1.100 'qm list | grep 9000'

# Fix: re-run the init script
scp bash/proxmox-init.sh root@192.168.1.100:/root/
ssh root@192.168.1.100 'bash /root/proxmox-init.sh'
```

---

## terraform init fails — "provider not found"

**Cause:** No internet access from WSL2, or HashiCorp registry is blocked.

```bash
# Test connectivity from WSL2
curl -I https://registry.terraform.io

# If blocked — check Windows firewall / VPN settings
# Terraform providers must be downloadable on first init
```

---

## "The argument 'ssh_public_key' is required"

**Cause:** SSH public key file doesn't exist at `~/.ssh/id_rsa.pub`.

```bash
# Fix: generate keypair
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
```
