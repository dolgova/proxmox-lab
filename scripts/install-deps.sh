#!/bin/bash
# =============================================================================
# install-deps.sh
# Installs Terraform + Ansible in WSL2 (Ubuntu)
# Usage: bash scripts/install-deps.sh
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }

info "Installing dependencies for proxmox-lab..."

# Update
sudo apt-get update -qq

# Install common tools
info "Installing base tools..."
sudo apt-get install -y -qq curl wget git jq unzip python3 python3-pip

# ── Terraform ──────────────────────────────────────────
info "Installing Terraform..."
wget -qO- https://apt.releases.hashicorp.com/gpg | \
    sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null

sudo apt-get update -qq
sudo apt-get install -y -qq terraform
success "Terraform $(terraform --version | head -1 | awk '{print $2}') installed"

# ── Ansible ────────────────────────────────────────────
info "Installing Ansible..."
sudo apt-get install -y -qq software-properties-common
sudo add-apt-repository -y ppa:ansible/ansible 2>/dev/null || true
sudo apt-get update -qq
sudo apt-get install -y -qq ansible
success "Ansible $(ansible --version | head -1) installed"

# ── SSH key ────────────────────────────────────────────
if [ ! -f ~/.ssh/id_rsa ]; then
    info "Generating SSH key pair..."
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -q
    success "SSH key created at ~/.ssh/id_rsa"
else
    success "SSH key already exists at ~/.ssh/id_rsa"
fi

echo ""
echo "=============================================="
success "All dependencies installed!"
echo "=============================================="
echo ""
echo "Next steps:"
echo "  1. Copy SSH key to Proxmox: ssh-copy-id root@192.168.1.100"
echo "  2. Run init script:         scp bash/proxmox-init.sh root@192.168.1.100:/root/"
echo "                              ssh root@192.168.1.100 'bash /root/proxmox-init.sh'"
echo "  3. Set Terraform token:     export TF_VAR_proxmox_api_token_secret='YOUR_TOKEN'"
echo "  4. Provision VMs:           cd terraform && terraform init && terraform apply"
echo ""
