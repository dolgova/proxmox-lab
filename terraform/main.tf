# =============================================================================
# main.tf — Provisions VMs inside Proxmox via API
# Usage:
#   terraform init
#   terraform apply                          # Creates 1 node (default)
#   terraform apply -var="node_count=3"      # Scale to 3 nodes
#   terraform apply -var="node_count=1"      # Scale back down
# =============================================================================

terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 2.9"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

# --- Provider: Connect to Proxmox API ---
provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_tls_insecure     = true  # Self-signed cert on Proxmox — expected
  pm_log_enable       = false
}

# --- Create VMs by cloning the cloud-init template ---
resource "proxmox_vm_qemu" "web_node" {
  count       = var.node_count
  name        = "web-node-${count.index + 1}"
  target_node = var.proxmox_node
  clone       = var.vm_template
  agent       = 1
  os_type     = "cloud-init"

  # Resources
  cores   = var.vm_cores
  sockets = 1
  memory  = var.vm_memory

  # Disk
  disk {
    slot    = 0
    size    = var.vm_disk_size
    type    = "scsi"
    storage = "local-lvm"
  }

  # Network
  network {
    model  = "virtio"
    bridge = var.vm_network_bridge
  }

  # Cloud-init configuration
  ipconfig0 = "ip=dhcp"
  ciuser    = "ubuntu"
  sshkeys   = file(var.ssh_public_key)

  # Wait for VM to boot and get IP before continuing
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

  # Trigger Ansible after VM is ready
  provisioner "local-exec" {
    command = <<-EOT
      echo "[web_nodes]" > ../ansible/inventory.ini
      ${join("\n", [for i in range(var.node_count) : "echo 'web-node-${i + 1} ansible_host=${proxmox_vm_qemu.web_node[i].ssh_host} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa' >> ../ansible/inventory.ini"])}
      cd ../ansible && ansible-playbook -i inventory.ini playbook.yml
    EOT
  }

  lifecycle {
    ignore_changes = [
      network,
    ]
  }
}

# --- Write dynamic Ansible inventory ---
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    nodes = proxmox_vm_qemu.web_node
  })
  filename = "../ansible/inventory.ini"

  depends_on = [proxmox_vm_qemu.web_node]
}
