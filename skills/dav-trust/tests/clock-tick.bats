#!/usr/bin/env bats
#
# skills/dav-trust/tests/clock-tick.bats
#
# Locks the trust-mode clock tick (extension/clock-tick.py): trust mode runs for
# hours and the agent has no clock of its own, so this script feeds it the current
# time every 30 minutes — across hosts (pi timer, Claude Code / Qoder hooks).
# It is the ONLY implementation of that text, so its numbers must not drift.

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../extension/clock-tick.py"
  [ -f "$SCRIPT" ] || { echo "missing $SCRIPT" >&2; return 1; }
  command -v python3 >/dev/null || skip "python3 not installed"
  PROJ="$BATS_TEST_TMPDIR/proj"
  STATE="$BATS_TEST_TMPDIR/tick.json"
  mkdir -p "$PROJ/docs"
  write_log "$HEADER"
}

HEADER='# Trust Log — demo

> 啟動時間:   2026-10-23 14:23:07 +0800
> Deadline:   2026-10-23 16:23:07 +0800
> 大目標:     完成 CRM
> 時間錨點:   START_TS=2026-10-23 14:23:07 +0800、DEADLINE_TS=2026-10-23 16:23:07 +0800
> 進度錨點:   PHASE=執行、DONE=US-101、NEXT=US-102、UPDATED_AT=2026-10-23 15:02:11 +0800
'

write_log() { printf '%s' "$1" > "$PROJ/docs/trust-log.md"; }

# tick <now-iso> [extra args...] -> status JSON (stdout)
tick() {
  local now="$1"; shift
  python3 "$SCRIPT" --project "$PROJ" --state "$STATE" --now "$now" --json "$@"
}

@test "CT-1: the trust-log header yields both anchors with their real offset" {
  run tick "2026-10-23T15:53:07+08:00" --force
  [ "$status" -eq 0 ]
  OUT="$output" python3 -c '
import json, os
s = json.loads(os.environ["OUT"])
if s["due"] is not True or s["reason"] != "due": raise SystemExit("due/reason " + str(s))
if s["deadline"] != "2026-10-23 16:23:07 +0800": raise SystemExit("deadline " + s["deadline"])
if s["now"] != "2026-10-23 15:53:07 +0800": raise SystemExit("now " + s["now"])
if s["remaining_minutes"] != 30: raise SystemExit("remaining " + str(s["remaining_minutes"]))
'
}

@test "CT-2: a tick prints the absolute time plus the remaining budget" {
  run tick "2026-10-23T15:53:07+08:00" --force
  [ "$status" -eq 0 ]
  [[ "$output" == *"2026-10-23 15:53:07 +0800"* ]]
  [[ "$output" == *"30 min left"* ]]
  [[ "$output" == *"25%"* ]]
}

@test "CT-3: a normal tick pushes the relay and forbids waiting for the clock" {
  run tick "2026-10-23T15:53:07+08:00" --force
  [ "$status" -eq 0 ]
  [[ "$output" == *"L1"* ]]
  [[ "$output" == *"sleep"* ]]
  [[ "$output" != *"Converge now"* ]]
}

@test "CT-4: under 10% left the tick tells the agent to converge" {
  run tick "2026-10-23T16:19:07+08:00" --force
  [ "$status" -eq 0 ]
  [[ "$output" == *"Converge now"* ]]
  [[ "$output" == *"4 min left"* ]]
}

@test "CT-5: past the deadline the tick says stop, deliver and exit" {
  run tick "2026-10-23T16:25:07+08:00" --force
  [ "$status" -eq 0 ]
  [[ "$output" == *"has passed"* ]]
  [[ "$output" == *"PHASE=終局"* ]]
}

@test "CT-6: gates — no trust-log / no deadline / 終局 / 暫停 all stay silent" {
  run tick "2026-10-23T15:53:07+08:00" --force
  [ "$status" -eq 0 ]
  [[ "$output" == *'"due": true'* ]]

  write_log '# Trust Log — no deadline
> 進度錨點:   PHASE=執行、DONE=（無）、NEXT=US-101、UPDATED_AT=2026-10-23 15:02:11 +0800
'
  run tick "2026-10-23T15:53:07+08:00" --force
  [[ "$output" == *'"reason": "no-deadline"'* ]]

  write_log '> Deadline:   2026-10-23 16:23:07 +0800
> 進度錨點:   PHASE=終局、DONE=US-101、NEXT=（無）、UPDATED_AT=2026-10-23 16:20:00 +0800
'
  run tick "2026-10-23T15:53:07+08:00" --force
  [[ "$output" == *'"reason": "finished"'* ]]

  write_log '> Deadline:   2026-10-23 16:23:07 +0800
> 進度錨點:   PHASE=暫停、DONE=US-101、NEXT=US-102、UPDATED_AT=2026-10-23 15:58:40 +0800
'
  run tick "2026-10-23T15:53:07+08:00" --force
  [[ "$output" == *'"reason": "paused"'* ]]

  rm -f "$PROJ/docs/trust-log.md"
  run tick "2026-10-23T15:53:07+08:00" --force
  [[ "$output" == *'"reason": "no-trust-log"'* ]]
}

@test "CT-7: the state file throttles to one tick per interval (shared across hosts)" {
  run tick "2026-10-23T15:53:07+08:00"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"due": true'* ]]

  run tick "2026-10-23T16:03:07+08:00"      # +10 分鐘：未夠 30 分鐘
  [ "$status" -eq 0 ]
  [[ "$output" == *'"reason": "throttled"'* ]]

  run tick "2026-10-23T16:24:07+08:00"      # +31 分鐘：夠鐘（已過 deadline 都照報）
  [ "$status" -eq 0 ]
  [[ "$output" == *'"due": true'* ]]

  run tick "2026-10-23T16:30:07+08:00" --force
  [[ "$output" == *'"due": true'* ]]
}

@test "CT-8: hook format emits Claude Code / Qoder JSON (Stop --wake blocks the stop)" {
  run python3 "$SCRIPT" --project "$PROJ" --state "$STATE" --now "2026-10-23T15:53:07+08:00" \
    --format hook --event PreToolUse --force
  [ "$status" -eq 0 ]
  OUT="$output" python3 -c '
import json, os
out = json.loads(os.environ["OUT"])
spec = out["hookSpecificOutput"]
if spec["hookEventName"] != "PreToolUse": raise SystemExit("event")
if "clock tick" not in spec["additionalContext"]: raise SystemExit("context")
'

  run python3 "$SCRIPT" --project "$PROJ" --state "$STATE" --now "2026-10-23T15:53:07+08:00" \
    --format hook --event Stop --wake --force
  [ "$status" -eq 0 ]
  OUT="$output" python3 -c '
import json, os
out = json.loads(os.environ["OUT"])
if out.get("decision") != "block" or "clock tick" not in out.get("reason", ""): raise SystemExit(str(out))
'

  # 唔夠鐘 → 咩都唔注入（hook 必須靜靜退出，唔可以污染每一輪對話）
  run python3 "$SCRIPT" --project "$PROJ" --state "$STATE" --now "2026-10-23T15:54:07+08:00" \
    --format hook --event PreToolUse
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "CT-9: install-hooks is opt-in, idempotent and never touches other hooks" {
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.claude"
  printf '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"echo mine"}]}]},"other":1}\n' \
    > "$HOME/.claude/settings.json"

  run python3 "$SCRIPT" --install-hooks claude --scope user
  [ "$status" -eq 0 ]
  # 預設 dry-run：唔准靜靜改用戶設定
  run cat "$HOME/.claude/settings.json"
  [[ "$output" != *"dav-trust-clock-tick"* ]]

  run python3 "$SCRIPT" --install-hooks claude --scope user --apply
  [ "$status" -eq 0 ]
  SETTINGS="$HOME/.claude/settings.json" python3 -c '
import json, os
s = json.load(open(os.environ["SETTINGS"]))
cmds = json.dumps(s, ensure_ascii=False)
for event in ("SessionStart", "PreToolUse"):
    if event not in s["hooks"]: raise SystemExit("missing " + event)
if "echo mine" not in cmds: raise SystemExit("user hook lost")
if s["other"] != 1: raise SystemExit("other keys lost")
if "PreToolUse" in s["hooks"] and len(s["hooks"]["PreToolUse"]) != 1: raise SystemExit("bad groups")
'

  run python3 "$SCRIPT" --install-hooks claude --scope user --apply
  [ "$status" -eq 0 ]
  SETTINGS="$HOME/.claude/settings.json" python3 -c '
import json, os
s = json.load(open(os.environ["SETTINGS"]))
if len(s["hooks"]["PreToolUse"]) != 1: raise SystemExit("duplicated on re-apply")
if len(s["hooks"]["Stop"]) != 1: raise SystemExit("Stop groups " + str(s["hooks"]["Stop"]))
'

  # 裝過 --wake（多一個 Stop）→ 唔帶 --wake 嘅 uninstall 一樣要清乾淨
  run python3 "$SCRIPT" --install-hooks claude --scope user --wake --apply
  [ "$status" -eq 0 ]
  run python3 "$SCRIPT" --install-hooks claude --scope user --uninstall --apply
  [ "$status" -eq 0 ]
  SETTINGS="$HOME/.claude/settings.json" python3 -c '
import json, os
s = json.load(open(os.environ["SETTINGS"]))
cmds = json.dumps(s, ensure_ascii=False)
if "dav-trust-clock-tick" in cmds: raise SystemExit("left ours behind")
if "echo mine" not in cmds: raise SystemExit("removed user hook")
if "Stop" not in s["hooks"]: raise SystemExit("user Stop hook gone")
'
}
