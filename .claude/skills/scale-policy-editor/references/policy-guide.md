# Autoscale Policy Guide

## Workload patterns → recommended policies

### Web traffic (variable, user-driven)
Default policy — good starting point for most HTTP services.
```
SCALE_UP_THRESHOLD=70
SCALE_DOWN_THRESHOLD=25
MIN_NODES=1
MAX_NODES=5
CHECK_INTERVAL=15
COOLDOWN=60
```

### Spiky batch jobs (high burst, then idle)
Higher up threshold to avoid scaling on brief spikes.
Longer cooldown to prevent thrashing between scale events.
```
SCALE_UP_THRESHOLD=85
SCALE_DOWN_THRESHOLD=20
MIN_NODES=1
MAX_NODES=5
CHECK_INTERVAL=30
COOLDOWN=120
```

### Latency-sensitive APIs (scale early, stay scaled)
Lower up threshold — scale before users feel it.
Higher down threshold — don't scale down too aggressively.
Higher min nodes — always have capacity ready.
```
SCALE_UP_THRESHOLD=55
SCALE_DOWN_THRESHOLD=35
MIN_NODES=2
MAX_NODES=5
CHECK_INTERVAL=10
COOLDOWN=90
```

### Steady-state services (gradual load increase)
Mid-range thresholds. Short interval to catch gradual growth.
```
SCALE_UP_THRESHOLD=65
SCALE_DOWN_THRESHOLD=30
MIN_NODES=1
MAX_NODES=5
CHECK_INTERVAL=20
COOLDOWN=60
```

---

## Common problems → fixes

### "Nodes keep flapping" (scale up then down repeatedly)
The gap between up and down thresholds is too narrow, or cooldown is too short.
**Fix:** Widen the gap by at least 30 percentage points, and increase cooldown.
```
SCALE_UP_THRESHOLD=75    # was 70
SCALE_DOWN_THRESHOLD=20  # was 25
COOLDOWN=120             # was 60
```

### "Autoscaler too slow to react to traffic spike"
Check interval is too long, or threshold is too high.
**Fix:** Lower threshold and check interval.
```
SCALE_UP_THRESHOLD=60    # was 70
CHECK_INTERVAL=10        # was 15
```

### "Autoscaler scales up but never scales down"
Down threshold is too low — CPU never drops that far.
**Fix:** Raise the down threshold.
```
SCALE_DOWN_THRESHOLD=35  # was 25
```

### "I want to always have at least 2 nodes running"
```
MIN_NODES=2
```

---

## Switching to memory-based scaling

The default autoscaler reads CPU load. For memory-bound workloads (Redis, Postgres),
replace the `get_node_cpu()` function in `autoscale/autoscale.sh`:

```bash
# Replace get_node_cpu() with this:
get_node_memory_usage() {
    local ip=$1
    # Query node exporter for memory available vs total
    local mem_available mem_total
    mem_available=$(curl -s --connect-timeout 3 "http://${ip}:9100/metrics" 2>/dev/null | \
        awk '/^node_memory_MemAvailable_bytes / {print $2}')
    mem_total=$(curl -s --connect-timeout 3 "http://${ip}:9100/metrics" 2>/dev/null | \
        awk '/^node_memory_MemTotal_bytes / {print $2}')

    if [[ -z "${mem_available}" ]] || [[ -z "${mem_total}" ]]; then
        echo "-1"
        return
    fi

    # Return memory usage percentage
    echo "${mem_available} ${mem_total}" | awk '{printf "%.0f", (1 - $1/$2) * 100}'
}
```

Then rename every call from `get_node_cpu` to `get_node_memory_usage` in the main loop.

Recommended thresholds for memory-based scaling:
```
SCALE_UP_THRESHOLD=75     # scale up when 75% of RAM is used
SCALE_DOWN_THRESHOLD=40   # scale down when usage drops below 40%
COOLDOWN=120              # memory changes more slowly — longer cooldown
```
