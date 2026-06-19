---
name: supervisor-monitor
description: Watchdog for the launchd-managed subagent_supervisor and cost_alarm daemons. Detects if launchd-level supervisors hang or die (independent of Hermes), and alerts David.
version: 1.0.0
platforms: [macos, linux]
metadata:
  hermes:
    tags: [monitoring, watchdog, supervisor, launchd, observability]
    related_skills: [subagent-driven-development, test-driven-development]
---

# Supervisor Monitor (Layer 2 Watchdog)

## 目的

`subagent_supervisor.py` 同 `cost_alarm_monitor.py` 已經由 **launchd plist** 喺 macOS system level 跑（**獨立於 Hermes gateway**）。但 launchd 都有可能 hang / 死。所以我哋要 Layer 2 watchdog — 喺 Hermes 入面 check launchd-managed supervisors 仲健唔健康。

**Architecture**:

```
Layer 1: launchd (macOS system level) — INDEPENDENT of Hermes
  └─ com.developer.supervisor.plist
     └─ KeepAlive=true (auto-restart on crash)
        └─ Runs scripts/subagent_supervisor.py --loop
  └─ com.developer.cost-alarm.plist
     └─ KeepAlive=true (auto-restart on crash)
        └─ Runs scripts/cost_alarm_monitor.py --loop

Layer 2: Hermes (this skill) — INDEPENDENT of launchd supervisors
  └─ Supervisor Monitor (cron every 1h)
     └─ Checks launchd plist loaded?
     └─ Checks supervisor process alive?
     └─ Checks supervisor log recent (last 10 min)?
     └─ If 3 fail → notify David

Layer 3: David (human) — Gets Discord alert if Layer 1+2 fail
```

## Trigger

- **Cron**: every 1 hour (Hermes cron job)
- **Manual**: David can invoke by saying "check supervisor health"

## Detection Logic (3 checks)

### Check 1: launchd plist loaded?

```bash
launchctl list | grep -E "com\.developer\.(supervisor|cost-alarm)"
```

- ✅ Both listed → plist loaded
- ❌ One or both missing → plist unload (need re-bootstrap)

### Check 2: Process alive?

```bash
ps aux | grep -E "subagent_supervisor\.py|cost_alarm_monitor\.py" | grep -v grep
```

- ✅ 2 processes (supervisor + cost_alarm) → alive
- ❌ 0 or 1 process → daemon crashed, launchd should auto-restart (check status)

### Check 3: Log recent (last 10 min)?

```bash
find ~/.hermes/profiles/developer/logs/supervisor-launchd.log ~/.hermes/profiles/developer/logs/cost-alarm-launchd.log \
  -mmin -10 2>/dev/null
```

- ✅ Both files modified in last 10 min → daemon actively working
- ❌ One or both not modified → daemon hung (process alive but not doing work)

## Decision Matrix

| Check 1 | Check 2 | Check 3 | Status | Action |
|---|---|---|---|---|
| ✅ | ✅ | ✅ | **HEALTHY** | Silent (no notify) |
| ✅ | ✅ | ❌ | **HUNG** | Notify David "supervisor hung" |
| ✅ | ❌ | ❌ | **CRASHED** | Notify David "supervisor crashed, launchd should restart it" |
| ❌ | ✅ | ❌ | **PLIST UNLOADED** | Notify David + suggest `launchctl bootstrap` |
| ❌ | ❌ | ❌ | **FULL OUTAGE** | Critical notify + suggest full restart |
| ✅ | ❌ | ✅ | **RARE (transient restart)** | Wait 5 min, re-check |

## Notification Format

```
🩺 **Supervisor Health Check** — STATUS

✅ launchd plist loaded: 2/2
✅ Process alive: 2/2
✅ Log recent: 2/2

**OVERALL: HEALTHY** — no action needed
```

Or on failure:
```
🩺 **Supervisor Health Check** — CRITICAL

❌ launchd plist loaded: 1/2 (com.developer.supervisor missing)
✅ Process alive: 1/2
❌ Log recent: 1/2

**OVERALL: PLIST UNLOADED**

David — 個 supervisor 嘅 launchd plist 可能 unload 咗。
建議手動跑:
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.developer.supervisor.plist
```

## Cron Setup

Hermes cron job:
```bash
hermes cron create supervisor-monitor-check \
  --schedule "every 1h" \
  --prompt "Run supervisor-monitor health checks per supervisor-monitor skill. Silent on HEALTHY. Notify David on any other status."
```

## Manual Run

David can invoke anytime:
```
請跑 supervisor-monitor skill 嘅 health check
```

## Why This Design

**Trade-off accepted**:
- Layer 1 (launchd) handles daemon crashes (KeepAlive=true)
- Layer 2 (Hermes cron) handles launchd failures (plist unload, daemon hang)
- Layer 3 (David) handles full outage (manual launchctl bootstrap)

**If all 3 fail simultaneously** = major system issue, David needs to investigate.

## Files

- `~/Library/LaunchAgents/com.developer.supervisor.plist` — launchd supervisor daemon
- `~/Library/LaunchAgents/com.developer.cost-alarm.plist` — launchd cost alarm daemon
- `~/.hermes/profiles/developer/scripts/subagent_supervisor.py` — supervisor script
- `~/.hermes/profiles/developer/scripts/cost_alarm_monitor.py` — cost alarm script
- `~/.hermes/profiles/developer/logs/supervisor-launchd.{log,err}` — launchd stdout/stderr
- `~/.hermes/profiles/developer/logs/cost-alarm-launchd.{log,err}` — launchd stdout/stderr
- `~/.hermes/profiles/developer/skills/devops/supervisor-monitor.md` — this skill
