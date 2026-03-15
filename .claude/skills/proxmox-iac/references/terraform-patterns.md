# Terraform Patterns — Proxmox Lab

Correct patterns for the `bpg/proxmox` provider in this environment.
Read before generating any Terraform code.

---

## Provider Configuration

```hcl
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.78.0"
    }
  }
}

provider "proxmox" {
  endpoint = "https://${var.proxmox_host}:8006/"
  username = "root@pam"
  password = var.proxmox_password
  insecure = true   # Self-signed cert

  ssh {
    agent = false
  }
}
```

**Do NOT use the telmate/proxmox provider** — it has a `VM.Monitor` permission bug
on Proxmox 9 that prevents VM creation.

---

## VM Resource Pattern

```hcl
resource "proxmox_virtual_environment_vm" "web_node" {
  count     = var.node_count
  name      = "web-node-${count.index + 1}"
  node_name = "proxmox"
  vm_id     = 101 + count.index

  clone {
    vm_id = 100    # golden-template — NOT 9000
    full  = true
  }

  # MUST be false — KVM disabled manually before starting
  started = false

  # Alpine doesn't have qemu-guest-agent
  agent {
    enabled = false
  }

  cpu {
    cores = var.vm_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.vm_memory
  }

  network_device {
    bridge = "vmbr0"
  }

  disk {
    datastore_id = var.storage_pool
    interface    = "scsi0"
    size         = 2    # GB — keep small for fast cloning
  }

  # Cloud-init for hostname only (network pre-configured in golden image)
  initialization {
    hostname = "web-node-${count.index + 1}"
  }

  lifecycle {
    ignore_changes = [
      started,    # Managed by scale.sh, not Terraform
    ]
  }
}
```

---

## Variables Pattern

```hcl
# terraform/variables.tf

variable "node_count" {
  description = "Number of web nodes to provision"
  type        = number
  default     = 1
}

variable "vm_memory" {
  description = "RAM per VM in MB"
  type        = number
  default     = 256
}

variable "vm_cores" {
  description = "CPU cores per VM"
  type        = number
  default     = 1
}

variable "proxmox_host" {
  description = "Proxmox host IP"
  type        = string
  default     = "192.168.1.100"
}

variable "proxmox_password" {
  description = "Proxmox root password"
  type        = string
  sensitive   = true
}

variable "clone_vm_id" {
  description = "Template VM to clone from"
  type        = number
  default     = 100
}

variable "storage_pool" {
  description = "Proxmox storage pool"
  type        = string
  default     = "local-lvm"
}
```

---

## Outputs Pattern

```hcl
# terraform/outputs.tf

output "vm_ids" {
  description = "VM IDs of provisioned nodes"
  value       = proxmox_virtual_environment_vm.web_node[*].vm_id
}

output "vm_names" {
  description = "Names of provisioned nodes"
  value       = proxmox_virtual_environment_vm.web_node[*].name
}

output "node_count" {
  description = "Number of provisioned nodes"
  value       = var.node_count
}
```

---

## Common Mistakes to Avoid

### Wrong provider

```hcl
# WRONG — telmate provider, will fail on Proxmox 9
resource "proxmox_vm_qemu" "web_node" { ... }

# CORRECT — bpg provider
resource "proxmox_virtual_environment_vm" "web_node" { ... }
```

### Wrong clone source

```hcl
# WRONG — raw cloud image, no SSH configured
clone {
  vm_id = 9000
}

# CORRECT — golden image with SSH ready
clone {
  vm_id = 100
}
```

### VM started = true

```hcl
# WRONG — KVM must be disabled before starting
started = true

# CORRECT — configure-node.sh handles startup
started = false
```

### Agent enabled

```hcl
# WRONG — qemu-guest-agent not installed in Alpine
agent {
  enabled = true
}

# CORRECT
agent {
  enabled = false
}
```

### Using terraform apply directly

```bash
# WRONG — doesn't manage single-VM constraint
terraform apply -var="node_count=2"

# CORRECT — handles stop-all + start-one + inventory update
bash scripts/scale.sh 2
```

---

## Adding a New Resource

When adding infrastructure beyond VMs (e.g., LXC containers, storage, networks):

1. Use `bpg/proxmox` resource types — check provider docs for correct resource name
2. Reference existing variables where applicable
3. Keep `started = false` pattern for anything that needs manual config before boot
4. Update `scripts/scale.sh` if the new resource interacts with the scaling workflow
5. Test with `terraform plan` before applying
