# =============================================================================
# variables.tf — Configure these to match your Proxmox environment
# =============================================================================

variable "proxmox_api_url" {
  description = "Proxmox API endpoint"
  type        = string
  default     = "https://192.168.1.100:8006/api2/json"
}

variable "proxmox_api_token_id" {
  description = "API token ID (from proxmox-init.sh output)"
  type        = string
  default     = "terraform@pve!terraform-token"
}

variable "proxmox_api_token_secret" {
  description = "API token secret (from proxmox-init.sh output)"
  type        = string
  sensitive   = true
  # Set via: export TF_VAR_proxmox_api_token_secret="your-token-here"
}

variable "node_count" {
  description = "Number of VMs to provision (autoscaler changes this)"
  type        = number
  default     = 1
}

variable "vm_template" {
  description = "Proxmox template ID to clone from"
  type        = string
  default     = "ubuntu-cloud-template"
}

variable "vm_cores" {
  description = "CPU cores per VM"
  type        = number
  default     = 1
}

variable "vm_memory" {
  description = "RAM per VM in MB"
  type        = number
  default     = 512
}

variable "vm_disk_size" {
  description = "Disk size per VM"
  type        = string
  default     = "10G"
}

variable "vm_network_bridge" {
  description = "Network bridge"
  type        = string
  default     = "vmbr0"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "proxmox_node" {
  description = "Proxmox cluster node name (check UI top-left)"
  type        = string
  default     = "pve"
}
