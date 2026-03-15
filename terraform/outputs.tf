output "vm_ips" {
  description = "IP addresses of provisioned VMs"
  value = {
    for vm in proxmox_virtual_environment_vm.web_node :
    vm.name => vm.ipv4_addresses
  }
}

output "node_count" {
  description = "Number of VMs provisioned"
  value       = var.node_count
}

output "web_urls" {
  description = "Hello world URLs"
  value = [
    for vm in proxmox_virtual_environment_vm.web_node :
    "http://${vm.name}"
  ]
}
