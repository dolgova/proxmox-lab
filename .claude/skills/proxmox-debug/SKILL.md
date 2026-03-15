---
name: proxmox-debug
description: >
  Diagnoses and fixes errors in the Proxmox Private Cloud Lab. Use this skill whenever
  someone pastes an error from Terraform, Ansible, SSH, or the Proxmox host. Triggers on:
  any error from terraform apply/plan/init, ansible failures, SSH timeouts, API 401/403/500,
  "VMs won't boot", "KVM not available", "no route to host", "ansible can't connect",
  "pveproxy failed", "permission denied", or any "why is X not working" question.
  This environment has specific known issues: KVM must be disabled manually, Hyper-V
  conflicts with VirtualBox, the telmate provider has a bug on Proxmox 9, and VMs have
  no internet access. Always check these first before suggesting generic fixes.
---

# Proxmox Debug — Environment Diagnostics

Maps errors to root causes specific to this environment. Never give generic advice —
always reference the actual files, commands, and constraints in this repo.

---

## Known issues — check these first

| Symptom | Root cause | Fix |
|---|---|---|
| `KVM virtualisation configured, but not available` | KVM not disabled on VM | `ssh proxmox "qm set <vmid> --kvm 0 && qm start <vmid>"` |
| `Snail execution mode is active` | Hyper-V competing with VirtualBox | `bcdedit /set hypervisorlaunchtype off` + reboot |
| `VM.Monitor permission missing` | telmate provider bug on Proxmox 9 | Switch to bpg/proxmox — already done in main.tf |
| `401 authentication failure` | Password has special chars, or wrong user | Test: `curl -sk -d "username=root@pam&password=PASSWORD" https://192.168.1.100:8006/api2/json/access/ticket` |
| `No route to host` (SSH to VM) | VM not started, or sshd not running | `ssh proxmox "qm start <vmid>"` then `rc-service sshd start` in VM console |
| 100% packet loss in VM | Promiscuous mode on VirtualBox NIC | VirtualBox → Proxmox-VE → Settings → Network → Promiscuous Mode → Allow All |
| `apt-get update` 401 errors | Enterprise repos enabled on Proxmox 9 | `echo 'Enabled: no' >> /etc/apt/sources.list.d/pve-enterprise.sources` |
| pveproxy won't start | Bad CORS config in `/etc/default/pveproxy` | `echo '' > /etc/default/pveproxy && systemctl start pveproxy` |
| `python not found` in Ansible | Standard modules need Python — not installed | Use `raw` module instead |
| `apk add` fails in VM | No internet (router NAT restriction) | Use golden image — rebuild VM 100 with packages pre-installed |
| `Boot failed: not a bootable disk` | Clone didn't copy disk, or wrong boot order | `ssh proxmox "qm set <vmid> --boot order=scsi0"` |
| Terraform state mismatch | VM exists in Proxmox but not in state | `terraform state rm proxmox_virtual_environment_vm.web_node` then reimport |
| `config file does not exist` | VM ID mismatch between state and Proxmox | Clear state: `terraform state rm proxmox_virtual_environment_vm.web_node` |
| `lvcreate already exists` | Orphaned LVM from previous failed run | `ssh proxmox "lvremove -f pve/vm-<id>-cloudinit"` |
| `can't lock file` | Stale QEMU lock | `ssh proxmox "rm -f /var/lock/qemu-server/lock-<vmid>.conf"` |

---

## Diagnostic workflow

### Step 1 — Identify error source

```bash
# Test Proxmox API
curl -sk https://192.168.1.100:8006/api2/json/version

# Test Proxmox SSH
ssh proxmox "echo ok"

# Test VM SSH (active VM)
ssh -i ~/.ssh/proxmox-lab root@192.168.1.101 "echo ok"

# Check all VM status
ssh proxmox "qm list"

# Check Proxmox services
ssh proxmox "systemctl status pveproxy pvedaemon"

# Check Ansible connectivity
cd ansible && ansible web_nodes -i inventory.ini -m raw -a "hostname"
```

### Step 2 — Generate exact fix

Always provide:
1. Root cause — one sentence
2. Diagnostic commands to confirm
3. Fix commands — exact, copy-pasteable
4. Verification — what success looks like

---

## Terraform-specific errors

### `failed to authenticate` / `401`
```bash
# Test credentials directly
curl -sk -d "username=root@pam&password=Summer2026" \
  https://192.168.1.100:8006/api2/json/access/ticket | python3 -m json.tool | head -5

# Check env var is set
echo $TF_VAR_proxmox_password

# Re-set if needed
export TF_VAR_proxmox_password="Summer2026"
```

### `resource already exists` / `lvcreate error`
```bash
# Clean up orphaned volumes
ssh proxmox "lvremove -f pve/vm-<id>-cloudinit 2>/dev/null"
ssh proxmox "lvremove -f pve/vm-<id>-disk-0 2>/dev/null"
ssh proxmox "lvremove -f pve/vm-<id>-disk-1 2>/dev/null"
```

### `hotplug problem - unable to change media type`
VM is running when Terraform tries to modify cloud-init drive. Stop it first:
```bash
ssh proxmox "qm stop <vmid>"
terraform apply -auto-approve
```

### State drift (VM exists in Proxmox, not in Terraform)
```bash
terraform state rm proxmox_virtual_environment_vm.web_node
# Then either reimport or let terraform recreate
terraform apply -auto-approve
```

---

## Ansible-specific errors

### `python not found` / module fails
Switch to raw module — do not install Python (no internet):
```bash
# CORRECT
ansible web_nodes -i inventory.ini -m raw -a "hostname"

# WRONG (needs Python)
ansible web_nodes -i inventory.ini -m ping
```

### `UNREACHABLE` / `No route to host`
```bash
# Check VM is running
ssh proxmox "qm status 101"

# Start if stopped
ssh proxmox "qm start 101"

# Wait for boot, then check sshd
sleep 30
ssh -i ~/.ssh/proxmox-lab root@192.168.1.101 "rc-service sshd start"
```

### `Host key verification failed`
```bash
ssh-keygen -R 192.168.1.101
# Or use StrictHostKeyChecking=no in inventory (already set)
```

---

## Proxmox host errors

### pveproxy won't start
```bash
ssh proxmox "journalctl -u pveproxy --no-pager | tail -20"

# If CORS config is wrong:
ssh proxmox "echo '' > /etc/default/pveproxy && systemctl start pveproxy"

# If cert issue:
ssh proxmox "pvecm updatecerts --force && systemctl start pveproxy"
```

### Proxmox unreachable after operation
VirtualBox VM may have crashed. Check VirtualBox — if black screen, Machine → Reset.
Wait 90 seconds for Proxmox to boot, then:
```bash
ssh proxmox "echo ok"
```

---

## Output format

```
## Root cause
[One sentence]

## Confirm it
[diagnostic commands]

## Fix it
[fix commands]

## Verify
[what success looks like]
```
