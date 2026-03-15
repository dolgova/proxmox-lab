terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.78"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "proxmox" {
  endpoint = "https://192.168.1.100:8006/"
  username = "root@pam"
  password = var.proxmox_password
  insecure = true
}

resource "proxmox_virtual_environment_vm" "web_node" {
  count      = var.node_count
  name       = "web-node-${count.index + 1}"
  node_name  = var.proxmox_node
  started    = false
  boot_order = ["scsi0"]

  clone {
    vm_id = 100
    full  = true
  }

  agent {
    enabled = false
  }

  cpu {
    cores = var.vm_cores
    type  = "qemu64"
  }

  memory {
    dedicated = 256
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "192.168.1.10${count.index + 1}/24"
        gateway = "192.168.1.1"
      }
    }
    user_account {
      username = "alpine"
      keys     = [file(var.ssh_public_key)]
    }
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/../scripts/configure-node.sh ${self.vm_id} 192.168.1.10${count.index + 1}"
  }

  lifecycle {
    ignore_changes = [
      initialization,
      boot_order,
    ]
  }
}

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    nodes = proxmox_virtual_environment_vm.web_node
  })
  filename   = "../ansible/inventory.ini"
  depends_on = [proxmox_virtual_environment_vm.web_node]
}