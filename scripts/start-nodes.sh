#!/bin/bash
# =============================================================================
# start-nodes.sh — Configure and start all Terraform-managed VMs
# Run this after every terraform apply
# Usage: bash scripts/start-nodes.sh <node_count>
# =============================================================================

COUNT=${1:-1}
BASE_IP="192.168.1"
START_IP=101

echo "Configuring and starting $COUNT node(s)..."

for i in $(seq 1 $COUNT); do
  VMID=$((99 + i))
  IP="${BASE_IP}.$((START_IP + i - 1))"
  
  echo "=== Configuring VM $VMID (web-node-$i) at $IP ==="

  ssh proxmox "
    qm stop $VMID 2>/dev/null || true
    sleep 2

    # Mount disk
    mkdir -p /mnt/vm${VMID}
    mount /dev/pve/vm-${VMID}-disk-0 /mnt/vm${VMID}

    # Configure network
    cat > /mnt/vm${VMID}/etc/network/interfaces << 'NETEOF'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address ${IP}
    netmask 255.255.255.0
    gateway 192.168.1.1
NETEOF

    # DNS
    echo 'nameserver 8.8.8.8' > /mnt/vm${VMID}/etc/resolv.conf

    # SSH keys
    mkdir -p /mnt/vm${VMID}/root/.ssh
    cat /root/.ssh/authorized_keys > /mnt/vm${VMID}/root/.ssh/authorized_keys
    chmod 700 /mnt/vm${VMID}/root/.ssh
    chmod 600 /mnt/vm${VMID}/root/.ssh/authorized_keys

    # Enable root SSH login
    grep -q 'PermitRootLogin yes' /mnt/vm${VMID}/etc/ssh/sshd_config || \
      echo 'PermitRootLogin yes' >> /mnt/vm${VMID}/etc/ssh/sshd_config

    # Remove cloud-init drive
    umount /mnt/vm${VMID}
    qm set $VMID --delete ide2 2>/dev/null || true

    # Disable KVM and start
    qm set $VMID --kvm 0
    qm start $VMID
  "

  echo "VM $VMID started at $IP"
done

# Wait for VMs to boot
echo ""
echo "Waiting 30 seconds for VMs to boot..."
sleep 30

# Generate Ansible inventory
echo ""
echo "Generating Ansible inventory..."
INVENTORY_FILE="../ansible/inventory.ini"
echo "[web_nodes]" > $INVENTORY_FILE
for i in $(seq 1 $COUNT); do
  IP="${BASE_IP}.$((START_IP + i - 1))"
  echo "web-node-$i ansible_host=$IP ansible_user=root ansible_ssh_private_key_file=~/.ssh/proxmox-lab ansible_ssh_common_args='-o StrictHostKeyChecking=no'" >> $INVENTORY_FILE
done
cat >> $INVENTORY_FILE << 'INVEOF'

[web_nodes:vars]
ansible_python_interpreter=/usr/bin/python3
INVEOF

echo "Inventory written to $INVENTORY_FILE"
cat $INVENTORY_FILE

# Start SSH on each VM
echo ""
echo "Starting SSH on all nodes..."
for i in $(seq 1 $COUNT); do
  IP="${BASE_IP}.$((START_IP + i - 1))"
  ssh -i ~/.ssh/proxmox-lab -o StrictHostKeyChecking=no root@$IP \
    "rc-service sshd start; rc-update add sshd default" 2>/dev/null && \
    echo "SSH started on web-node-$i ($IP)" || \
    echo "SSH may already be running on web-node-$i ($IP)"
done

# Test Ansible connectivity
echo ""
echo "Testing Ansible connectivity..."
cd ../ansible && ansible web_nodes -i inventory.ini -m raw -a "hostname && ip addr show eth0 | grep 'inet '"

echo ""
echo "Done! Nodes ready:"
ssh proxmox "qm list | grep web-node"
EOF
