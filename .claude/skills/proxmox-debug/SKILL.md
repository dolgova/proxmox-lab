---
name: proxmox-debug
description: >
  Diagnoses and fixes errors in the Proxmox Private Cloud Lab environment. Use this
  skill whenever a developer pastes an error message, stack trace, or unexpected
  behaviour from Terraform, Ansible, the autoscaler, the dashboard, or the Proxmox
  host itself. Triggers on: any error output from terraform apply/plan/init,
  ansible-playbook failures, SSH timeouts, 401/403/500 API errors, "nodes not
  appearing on dashboard", "VMs won't boot", "autoscaler not scaling",
  "ansible can't connect", or any request to "debug", "fix", "troubleshoot",
  or "why is X not working" in this environment. Always use this skill before
  suggesting generic Terraform or Ansible debugging steps.
---

# Proxmox Debug — Environment Diagnostics

Maps errors to root causes specific to this environment and generates exact fix
commands. Never give generic advice — every response must reference the actual
files, variables, and commands in this repo.

---

## Diagnostic workflow

### Step 1 — Identify the error source

| Error contains | Source |
|---|---|
| `401 Unauthorized` / `403 Forbidden` | Terraform API token |
| `connection refused` / `i/o timeout` on port 8006 | Proxmox host unreachable |
| `SSH connection refused` / `SSH timeout` | VM not ready yet |
| `TASK [Gathering Facts] FAILED` | Ansible can't reach VM |
| `no template found` / `template not found` | Cloud-init template missing |
| `UNREACHABLE` in Ansible output | Network / SSH issue |
| `Error: 500` from Proxmox | Proxmox internal error — check logs |
| `nested virtualization` / `KVM` / `QEMU: CPU doesn't support` | VirtualBox nested virt not enabled |
| Dashboard shows no data / CORS | Browser API access blocked |
| Autoscaler: `No nodes found in inventory` | Terraform hasn't been run |
| VM boots but no IP / can't SSH | Cloud-init didn't finish |

### Step 2 — Read the relevant reference file

| Situation | Reference file |
|---|---|
| Terraform auth/connection errors | `references/terraform-errors.md` |
| Ansible connectivity errors | `references/ansible-errors.md` |
| VM / Proxmox host errors | `references/proxmox-errors.md` |
| Dashboard / autoscaler errors | `references/app-errors.md` |

### Step 3 — Generate exact fix

Always provide:
1. **Root cause** — one sentence
2. **Diagnostic commands** to confirm the cause
3. **Fix commands** — exact, copy-pasteable
4. **Verification** — how to confirm the fix worked

---

## Output format

```
## Root cause
[One sentence]

## Confirm it
\```bash
[diagnostic commands]
\```

## Fix it
\```bash
[fix commands]
\```

## Verify
[What success looks like — command output or UI state]
```
