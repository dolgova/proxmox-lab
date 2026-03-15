#!/bin/bash
COUNT=${1:-1}
TERRAFORM_DIR="$(dirname $0)/../terraform"
ANSIBLE_DIR="$(dirname $0)/../ansible"
FIXED_IP="192.168.1.101"

cd $TERRAFORM_DIR

echo "Provisioning $COUNT node(s) via Terraform..."
terraform apply -var="node_count=$COUNT" -auto-approve

echo ""
echo "============================================="
echo "  Which node should be the PRIMARY (running)?"
echo "  All nodes use IP: $FIXED_IP"
echo "============================================="
for i in $(seq 1 $COUNT); do
  echo "  $i) web-node-$i"
done
echo ""
read -p "Enter node number [1]: " PRIMARY
PRIMARY=${PRIMARY:-1}
PRIMARY_VMID=$((100 + PRIMARY))

# Stop all VMs
echo "Stopping all nodes..."
for i in $(seq 1 $COUNT); do
  ssh proxmox "qm stop $((100 + i)) 2>/dev/null || true"
done
sleep 5

# Start only primary
echo "Starting web-node-$PRIMARY (VM $PRIMARY_VMID)..."
ssh proxmox "qm start $PRIMARY_VMID"
sleep 30

# Update Ansible inventory
cat > $ANSIBLE_DIR/inventory.ini << INVEOF
[web_nodes]
web-node-$PRIMARY ansible_host=$FIXED_IP ansible_user=root ansible_ssh_private_key_file=~/.ssh/proxmox-lab ansible_ssh_common_args='-o StrictHostKeyChecking=no'

[web_nodes:vars]
ansible_python_interpreter=/usr/bin/python3
INVEOF

echo ""
echo "Done! Active: web-node-$PRIMARY at $FIXED_IP"
ssh proxmox "qm list | grep web-node"
