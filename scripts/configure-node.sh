#!/bin/bash
VMID=$1
IP=$2

echo "=== Configuring VM $VMID ==="

ssh -o StrictHostKeyChecking=no proxmox "
  qm set $VMID --delete ide2 2>/dev/null || true
  qm set $VMID --kvm 0
"

echo "VM $VMID configured"
