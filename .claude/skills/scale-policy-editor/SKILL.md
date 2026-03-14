---
name: scale-policy-editor
description: >
  Helps configure and tune the autoscaler for the Proxmox Private Cloud Lab.
  Use this skill whenever a developer wants to change scaling thresholds, adjust
  cooldown periods, modify min/max node counts, switch from CPU-based to
  memory-based scaling, or understand why the autoscaler is behaving unexpectedly.
  Triggers on: "change the scaling threshold", "autoscaler is too aggressive",
  "autoscaler won't scale down", "scale based on memory instead of CPU",
  "nodes keep flapping", "why did it add a node", "autoscaler triggers too fast",
  "I want it to scale at 50% CPU", "increase max nodes", "change cooldown",
  or any request to tune, explain, or modify autoscaling behaviour.
---

# Scale Policy Editor

Explains autoscaler behaviour, recommends policy changes for different workload
patterns, and generates the exact `autoscale.sh` edits needed.

---

## Autoscaler config block (top of autoscale/autoscale.sh)

```bash
SCALE_UP_THRESHOLD=70       # Scale up when avg CPU% exceeds this
SCALE_DOWN_THRESHOLD=25     # Scale down when avg CPU% drops below this
MIN_NODES=1                 # Never go below this
MAX_NODES=5                 # Never go above this
CHECK_INTERVAL=15           # Seconds between CPU checks
COOLDOWN=60                 # Seconds to wait after a scale event
```

These are the only values that need to change for policy tuning.
Never modify the decision logic itself unless the developer asks explicitly.

---

## Workflow

### Step 1 — Understand the workload

Ask or infer:
- Is load **spiky** (burst then drop) or **gradual** (ramps up over time)?
- What is the **consequence of under-scaling**? (slow response vs. outage)
- What is the **consequence of over-scaling**? (wasted resources vs. acceptable)
- Is the metric **CPU** or **memory**? (most web workloads = CPU; caches/DBs = memory)

### Step 2 — Recommend a policy

Read `references/policy-guide.md` for workload-to-policy mappings.

### Step 3 — Generate the edit

Always show the before/after diff and the exact sed command or manual edit:

```bash
# Example: change SCALE_UP_THRESHOLD from 70 to 85
sed -i 's/^SCALE_UP_THRESHOLD=.*/SCALE_UP_THRESHOLD=85/' autoscale/autoscale.sh
```

### Step 4 — Explain the tradeoff

For every policy change, explain what it optimises for and what it sacrifices.
Never just change a number without explaining the consequence.

---

## Output format

```
## Recommended policy

| Setting | Current | Recommended | Why |
|---|---|---|---|
| SCALE_UP_THRESHOLD | 70 | 85 | [reason] |
| COOLDOWN | 60 | 120 | [reason] |

## Tradeoff
[What this optimises for and what it sacrifices]

## Apply it
\```bash
[sed commands or manual edit instructions]
\```

## Verify
[How to confirm the new policy is working — what to look for in autoscaler output]
```
