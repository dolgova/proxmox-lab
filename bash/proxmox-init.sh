#!/bin/bash
# =============================================================================
# proxmox-init.sh
# Post-install configuration script for Proxmox VE
# Run this on the Proxmox host after first boot
# Usage: bash proxmox-init.sh
# =============================================================================

set -euo pipefail

# --- Colors ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# --- Config (edit these) ---
PROXMOX_IP="192.168.1.100"       # Your Proxmox host IP
BRIDGE_IFACE="eno1"              # Physical NIC (check with: ip link)
VM_TEMPLATE_ID="9000"            # Template VM ID for cloud-init
UBUNTU_ISO_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"

# =============================================================================
echo ""
echo "=============================================="
echo "   Proxmox VE - Automated Post-Install Setup  "
echo "=============================================="
echo ""

# --- 1. Verify running as root on Proxmox ---
[[ $EUID -ne 0 ]] && error "Must run as root"
command -v pvesh &>/dev/null || error "This must run on a Proxmox VE host"
info "Running on Proxmox VE host — confirmed"

# --- 2. Fix repositories (disable enterprise, enable no-sub) ---
info "Configuring APT repositories..."
# Disable enterprise repo (requires paid subscription)
if [ -f /etc/apt/sources.list.d/pve-enterprise.list ]; then
    sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/pve-enterprise.list
    success "Enterprise repo disabled"
fi
# Add no-subscription repo
cat > /etc/apt/sources.list.d/pve-no-subscription.list <<EOF
deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription
EOF
# Remove nag screen
if [ -f /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js ]; then
    sed -i "s/Ext.Msg.show({/void({/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
    success "Subscription nag screen removed"
fi
success "Repositories configured"

# --- 3. Update system ---
info "Updating system packages (this may take a few minutes)..."
apt-get update -qq
apt-get dist-upgrade -y -qq
success "System updated"

# --- 4. Install useful tools ---
info "Installing utilities..."
apt-get install -y -qq \
    vim curl wget git htop \
    net-tools dnsutils \
    python3 python3-pip \
    jq unzip
success "Utilities installed"

# --- 5. Configure network bridge (vmbr0) ---
info "Checking network bridge vmbr0..."
if ! ip link show vmbr0 &>/dev/null; then
    warn "vmbr0 not found — writing network config"
    cat >> /etc/network/interfaces <<EOF

auto vmbr0
iface vmbr0 inet static
    address ${PROXMOX_IP}/24
    gateway $(ip route | awk '/default/ {print $3}' | head -1)
    bridge-ports ${BRIDGE_IFACE}
    bridge-stp off
    bridge-fd 0
EOF
    systemctl restart networking || warn "Restart networking manually if this fails"
fi
success "Network bridge vmbr0 configured"

# --- 6. Enable IOMMU for nested virtualization ---
info "Enabling nested virtualization (IOMMU)..."
if ! grep -q "intel_iommu=on\|amd_iommu=on" /etc/default/grub; then
    # Detect CPU vendor
    if grep -q "GenuineIntel" /proc/cpuinfo; then
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"/' /etc/default/grub
    else
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt"/' /etc/default/grub
    fi
    update-grub 2>/dev/null
    success "IOMMU enabled (reboot required)"
else
    success "IOMMU already configured"
fi

# --- 7. Create cloud-init Ubuntu template ---
info "Creating Ubuntu cloud-init VM template (ID: ${VM_TEMPLATE_ID})..."
if ! qm status ${VM_TEMPLATE_ID} &>/dev/null; then
    # Download Ubuntu cloud image
    info "Downloading Ubuntu 22.04 cloud image..."
    wget -q --show-progress -O /tmp/ubuntu-cloud.img "${UBUNTU_ISO_URL}"

    # Create base VM
    qm create ${VM_TEMPLATE_ID} \
        --name "ubuntu-cloud-template" \
        --memory 1024 \
        --cores 1 \
        --net0 virtio,bridge=vmbr0

    # Import disk
    qm importdisk ${VM_TEMPLATE_ID} /tmp/ubuntu-cloud.img local-lvm

    # Configure VM
    qm set ${VM_TEMPLATE_ID} \
        --scsihw virtio-scsi-pci \
        --scsi0 local-lvm:vm-${VM_TEMPLATE_ID}-disk-0 \
        --ide2 local-lvm:cloudinit \
        --boot c --bootdisk scsi0 \
        --serial0 socket \
        --vga serial0 \
        --agent enabled=1 \
        --ipconfig0 ip=dhcp \
        --ciuser ubuntu \
        --cipassword ubuntu123 \
        --sshkeys /root/.ssh/authorized_keys 2>/dev/null || true

    # Convert to template
    qm template ${VM_TEMPLATE_ID}
    rm -f /tmp/ubuntu-cloud.img
    success "Ubuntu cloud-init template created (ID: ${VM_TEMPLATE_ID})"
else
    warn "Template ${VM_TEMPLATE_ID} already exists — skipping"
fi

# --- 8. Set up SSH key for Ansible/Terraform ---
info "Setting up SSH keys..."
if [ ! -f /root/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N "" -q
    success "SSH key pair generated at /root/.ssh/id_rsa"
else
    success "SSH key already exists"
fi

# --- 9. Create Proxmox API token for Terraform ---
info "Creating Terraform API user and token..."
# Create role with required permissions
pveum role add TerraformRole -privs "VM.Allocate VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Monitor VM.Audit VM.PowerMgmt Datastore.AllocateSpace Datastore.Audit" 2>/dev/null || true
# Create user
pveum user add terraform@pve --password terraform123 2>/dev/null || true
# Assign role
pveum aclmod / -user terraform@pve -role TerraformRole 2>/dev/null || true
# Create API token (save this output!)
echo ""
echo "========================================="
echo "  TERRAFORM API TOKEN — SAVE THIS OUTPUT "
echo "========================================="
pveum user token add terraform@pve terraform-token --privsep=0 2>/dev/null || warn "Token may already exist"
echo "========================================="
echo ""

# --- 10. Final summary ---
echo ""
echo "=============================================="
success "Proxmox VE initialization complete!"
echo "=============================================="
echo ""
echo "  Proxmox Web UI : https://${PROXMOX_IP}:8006"
echo "  VM Template ID  : ${VM_TEMPLATE_ID}"
echo "  SSH Public Key  : /root/.ssh/id_rsa.pub"
echo ""
warn "REBOOT REQUIRED for IOMMU/grub changes to take effect"
echo ""
echo "  Next step: Run Terraform to provision VMs"
echo "  → cd ../terraform && terraform init && terraform apply"
echo ""
