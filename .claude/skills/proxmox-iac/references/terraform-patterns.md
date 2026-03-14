# Terraform Patterns

Copy these patterns exactly when generating new Terraform code.
Do not invent new patterns — extend these.

---

## Adding a New VM Type

Every new VM type follows this exact 4-file pattern.

### 1. variables.tf — add count + sizing variables

```hcl
variable "{purpose}_node_count" {
  description = "Number of {purpose} VMs to provision"
  type        = number
  default     = 1
}

variable "{purpose}_vm_memory" {
  description = "RAM per {purpose} VM in MB"
  type        = number
  default     = 1024
}

variable "{purpose}_vm_cores" {
  description = "CPU cores per {purpose} VM"
  type        = number
  default     = 1
}
```

### 2. main.tf — add resource block

```hcl
resource "proxmox_vm_qemu" "{purpose}_node" {
  count       = var.{purpose}_node_count
  name        = "{purpose}-node-${count.index + 1}"
  target_node = var.proxmox_node
  clone       = var.vm_template
  agent       = 1
  os_type     = "cloud-init"

  cores   = var.{purpose}_vm_cores
  sockets = 1
  memory  = var.{purpose}_vm_memory

  disk {
    slot    = 0
    size    = var.vm_disk_size
    type    = "scsi"
    storage = "local-lvm"
  }

  network {
    model  = "virtio"
    bridge = var.vm_network_bridge
  }

  ipconfig0 = "ip=dhcp"
  ciuser    = "ubuntu"
  sshkeys   = file(var.ssh_public_key)

  provisioner "remote-exec" {
    inline = ["echo 'VM is up'"]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host        = self.ssh_host
      timeout     = "3m"
    }
  }

  lifecycle {
    ignore_changes = [network]
  }
}
```

### 3. outputs.tf — add IP output

```hcl
output "{purpose}_node_ips" {
  description = "IP addresses of all {purpose} VMs"
  value = {
    for vm in proxmox_vm_qemu.{purpose}_node :
    vm.name => vm.ssh_host
  }
}
```

### 4. inventory.tpl — add new group

```
[{purpose}_nodes]
%{ for node in {purpose}_nodes ~}
${node.name} ansible_host=${node.ssh_host} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa ansible_ssh_common_args='-o StrictHostKeyChecking=no'
%{ endfor ~}

[{purpose}_nodes:vars]
ansible_python_interpreter=/usr/bin/python3
```

Also update the `local_file.ansible_inventory` resource in `main.tf` to pass the new nodes:

```hcl
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    nodes          = proxmox_vm_qemu.web_node
    {purpose}_nodes = proxmox_vm_qemu.{purpose}_node   # add this line
  })
  filename   = "../ansible/inventory.ini"
  depends_on = [proxmox_vm_qemu.web_node, proxmox_vm_qemu.{purpose}_node]
}
```

---

## Changing VM Resources (Existing VMs)

Edit `variables.tf` only — never hardcode in `main.tf`:

```hcl
# Increase web node RAM from 512 to 1024
variable "vm_memory" {
  default = 1024   # was 512
}
```

Then run:
```bash
terraform apply   # Proxmox hot-updates memory where possible; CPU/disk may require restart
```

---

## Adding a Second Network Interface

Add inside the existing `proxmox_vm_qemu` resource block, after the first `network {}`:

```hcl
network {
  model  = "virtio"
  bridge = "vmbr1"    # second bridge — must exist on Proxmox host
}
```

---

## Static IP Instead of DHCP

Replace `ipconfig0 = "ip=dhcp"` with:

```hcl
ipconfig0 = "ip=192.168.1.${count.index + 110}/24,gw=192.168.1.1"
```

Adjust the base offset (`110`) to avoid conflicts with DHCP range.

---

## Adding a Provisioner to Trigger Ansible on New Nodes Only

This is already in the web_node resource. For new VM types, copy the same pattern:

```hcl
provisioner "local-exec" {
  command = "cd ../ansible && ansible-playbook -i inventory.ini playbook.yml --limit {purpose}-node-${count.index + 1}"
}
```

---

## Variable Naming Conventions

| Pattern | Example |
|---|---|
| Node count | `{purpose}_node_count` |
| VM memory | `{purpose}_vm_memory` |
| VM cores | `{purpose}_vm_cores` |
| Shared values | `vm_disk_size`, `vm_network_bridge`, `vm_template` |
| Proxmox connection | `proxmox_api_url`, `proxmox_api_token_id`, `proxmox_node` |
