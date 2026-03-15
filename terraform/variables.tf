variable "proxmox_api_url" {
  description = "Proxmox API endpoint"
  type        = string
  default     = "https://192.168.1.100:8006/api2/json"
}
variable "proxmox_api_token_id" {
  description = "API token ID"
  type        = string
  default     = "terraform@pve!terraform-token"
}
variable "proxmox_api_token_secret" {
  description = "API token secret"
  type        = string
  sensitive   = true
}
variable "node_count" {
  description = "Number of VMs to provision"
  type        = number
  default     = 1
}
variable "vm_template" {
  description = "Proxmox template name to clone from"
  type        = string
  default     = "alpine-cloud-template"
}
variable "vm_cores" {
  description = "CPU cores per VM"
  type        = number
  default     = 1
}
variable "vm_memory" {
  description = "RAM per VM in MB"
  type        = number
  default     = 256
}
variable "vm_disk_size" {
  description = "Disk size per VM"
  type        = string
  default     = "2G"
}
variable "vm_network_bridge" {
  description = "Network bridge"
  type        = string
  default     = "vmbr0"
}
variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
  default     = "~/.ssh/proxmox-lab.pub"
}
variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  default     = "pve"
}
variable "proxmox_password" {
  description = "Proxmox root password"
  type        = string
  sensitive   = true
}
