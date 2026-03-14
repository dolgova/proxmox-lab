# =============================================================================
# outputs.tf — Shows VM IPs after terraform apply
# =============================================================================

output "vm_ips" {
  description = "IP addresses of all provisioned VMs"
  value = {
    for vm in proxmox_vm_qemu.web_node :
    vm.name => vm.ssh_host
  }
}

output "node_count" {
  description = "Current number of nodes"
  value       = var.node_count
}

output "web_urls" {
  description = "Hello World URLs for each node"
  value = [
    for vm in proxmox_vm_qemu.web_node :
    "http://${vm.ssh_host}"
  ]
}
