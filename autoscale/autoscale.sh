#!/bin/bash
# =============================================================================
# autoscale.sh — Monitors CPU across all nodes and scales via Terraform
#
# How it works:
#   1. Reads current node IPs from Ansible inventory
#   2. Polls CPU usage from each node's Prometheus node exporter
#   3. If avg CPU > SCALE_UP_THRESHOLD   → terraform apply node_count+1
#   4. If avg CPU < SCALE_DOWN_THRESHOLD → terraform apply node_count-1
#
# Usage:
#   bash autoscale.sh          # Run in foreground
#   bash autoscale.sh &        # Run in background
#   bash autoscale.sh --stress # Trigger stress test (installs stress tool on nodes)
# =============================================================================

set -euo pipefail

# --- Config ---
SCALE_UP_THRESHOLD=70       # Scale up when avg CPU% exceeds this
SCALE_DOWN_THRESHOLD=25     # Scale down when avg CPU% drops below this
MIN_NODES=1
MAX_NODES=5
CHECK_INTERVAL=15           # Seconds between checks
COOLDOWN=60                 # Seconds to wait after a scale event
TERRAFORM_DIR="../terraform"
ANSIBLE_DIR="../ansible"
INVENTORY="${ANSIBLE_DIR}/inventory.ini"

# --- Colors ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
log()     { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}[$(date '+%H:%M:%S')] ✓${NC} $1"; }
warn()    { echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠${NC} $1"; }
scale()   { echo -e "${CYAN}[$(date '+%H:%M:%S')] ⟳ SCALE${NC} $1"; }

# --- Get current node count from Terraform state ---
get_current_node_count() {
    cd "${TERRAFORM_DIR}"
    terraform show -json 2>/dev/null | jq '.values.root_module.resources | map(select(.type=="proxmox_vm_qemu")) | length' 2>/dev/null || echo "${MIN_NODES}"
}

# --- Get node IPs from inventory ---
get_node_ips() {
    grep -E '^web-node-[0-9]' "${INVENTORY}" 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i~/^ansible_host=/) {split($i,a,"="); print a[2]}}' || echo ""
}

# --- Query CPU usage from a single node's node exporter ---
get_node_cpu() {
    local ip=$1
    local idle
    # node_cpu_seconds_total{mode="idle"} gives idle CPU time
    idle=$(curl -s --connect-timeout 3 "http://${ip}:9100/metrics" 2>/dev/null | \
        awk '/^node_cpu_seconds_total\{.*mode="idle".*\}/ {sum+=$2; count++} END {if(count>0) print sum/count; else print -1}')
    
    if [[ "${idle}" == "-1" ]] || [[ -z "${idle}" ]]; then
        echo "-1"
        return
    fi
    # Return approx CPU usage % (simplified: compare to previous reading)
    # For demo purposes, read /proc/stat equivalent via node exporter summary
    local usage
    usage=$(curl -s --connect-timeout 3 "http://${ip}:9100/metrics" 2>/dev/null | \
        awk '/^node_load1 / {print $2}' | head -1)
    # Normalize load1 to percent (load1/cores * 100), assume 1 core per node
    usage=$(echo "${usage:-0}" | awk '{printf "%.0f", $1 * 100}')
    echo "${usage}"
}

# --- Scale nodes ---
scale_to() {
    local count=$1
    scale "Adjusting to ${count} node(s)..."
    
    cd "${TERRAFORM_DIR}"
    terraform apply -auto-approve -var="node_count=${count}" 2>&1 | tail -5
    
    # Run Ansible only on new nodes (inventory auto-updates from Terraform)
    sleep 10
    cd "../${ANSIBLE_DIR}"
    ansible-playbook -i inventory.ini playbook.yml 2>&1 | tail -10
    
    success "Scaled to ${count} nodes"
}

# --- Stress test mode ---
run_stress_test() {
    echo ""
    echo "=============================================="
    echo "   AUTOSCALE STRESS TEST"
    echo "   Will scale from ${MIN_NODES} → ${MAX_NODES} nodes"
    echo "=============================================="
    echo ""
    
    local ips
    ips=$(get_node_ips)
    
    if [[ -z "${ips}" ]]; then
        warn "No nodes found in inventory. Run Terraform first."
        exit 1
    fi
    
    log "Installing stress tool on all nodes..."
    cd "${ANSIBLE_DIR}"
    ansible web_nodes -i inventory.ini -m apt -a "name=stress state=present" --become 2>/dev/null
    
    log "Starting CPU stress on existing nodes (watch the dashboard!)..."
    ansible web_nodes -i inventory.ini -m shell -a "nohup stress --cpu 1 --timeout 300 &" --become 2>/dev/null &
    
    log "Stress test running — autoscaler will now react. Monitoring..."
    echo ""
}

# =============================================================================
# MAIN LOOP
# =============================================================================

echo ""
echo "=============================================="
echo "   Proxmox Lab Autoscaler"
echo "   Scale range: ${MIN_NODES} – ${MAX_NODES} nodes"
echo "   Check interval: ${CHECK_INTERVAL}s"
echo "   Up threshold: ${SCALE_UP_THRESHOLD}% CPU"
echo "   Down threshold: ${SCALE_DOWN_THRESHOLD}% CPU"
echo "=============================================="
echo ""

# Handle stress test flag
if [[ "${1:-}" == "--stress" ]]; then
    run_stress_test
fi

last_scale_time=0

while true; do
    current_count=$(get_current_node_count)
    node_ips=$(get_node_ips)
    
    if [[ -z "${node_ips}" ]]; then
        warn "No nodes found — waiting for Terraform to provision nodes first"
        sleep "${CHECK_INTERVAL}"
        continue
    fi
    
    # Collect CPU from all nodes
    total_cpu=0
    online_count=0
    node_details=""
    
    while IFS= read -r ip; do
        [[ -z "${ip}" ]] && continue
        cpu=$(get_node_cpu "${ip}")
        if [[ "${cpu}" != "-1" ]]; then
            total_cpu=$((total_cpu + cpu))
            online_count=$((online_count + 1))
            node_details="${node_details} ${ip}:${cpu}%"
        else
            warn "Node ${ip} unreachable"
        fi
    done <<< "${node_ips}"
    
    if [[ $online_count -eq 0 ]]; then
        warn "No nodes responding"
        sleep "${CHECK_INTERVAL}"
        continue
    fi
    
    avg_cpu=$((total_cpu / online_count))
    now=$(date +%s)
    cooldown_remaining=$((last_scale_time + COOLDOWN - now))
    
    log "Nodes: ${current_count} active | Avg CPU: ${avg_cpu}% |${node_details}"
    
    # --- Scale decision ---
    if [[ $cooldown_remaining -gt 0 ]]; then
        log "Cooldown active — ${cooldown_remaining}s remaining before next scale"
    elif [[ $avg_cpu -gt $SCALE_UP_THRESHOLD ]] && [[ $current_count -lt $MAX_NODES ]]; then
        new_count=$((current_count + 1))
        scale "CPU ${avg_cpu}% > ${SCALE_UP_THRESHOLD}% threshold → scaling UP to ${new_count} nodes"
        scale_to "${new_count}"
        last_scale_time=$(date +%s)
    elif [[ $avg_cpu -lt $SCALE_DOWN_THRESHOLD ]] && [[ $current_count -gt $MIN_NODES ]]; then
        new_count=$((current_count - 1))
        scale "CPU ${avg_cpu}% < ${SCALE_DOWN_THRESHOLD}% threshold → scaling DOWN to ${new_count} nodes"
        scale_to "${new_count}"
        last_scale_time=$(date +%s)
    else
        log "CPU within range — no scaling needed"
    fi
    
    sleep "${CHECK_INTERVAL}"
done
