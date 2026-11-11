# dav-trust 樣例檔 — 機械報時嘅 hook 裝法（Claude Code／Qoder）

> 配合 [`../time-anchor.md`](../time-anchor.md) §7 使用：紀律喺嗰邊，呢度只放**可直接複製嘅安裝步驟 ＋ 範本**。
> 判定同文字**只喺一支腳本**：`../extension/clock-tick.py`（pi 嘅 extension 同呢兩個 host 嘅 hook 都叫佢）。

---

## 1. 為什麼要 hook（Claude Code／Qoder 冇 timer）

| Host | 報時機制 | 觸發時機 |
|---|---|---|
| pi | extension `setInterval` | 每 30 分鐘（連 agent 閒置都會叫醒） |
| Claude Code | `PreToolUse` ＋ `SessionStart` hook | 每次工具呼叫／開場（**節流**成每 30 分鐘最多一次） |
| Qoder | 同上（事件名同 JSON 形態一致） | 同上 |

三個 host 共用同一份節流 state（`~/.dav-trust/tick.json`，按專案記 `last_emit`）→ 換 host、或者 hook 事件重疊，都唔會重複報時。
判定唔會報時嘅情況：冇 `docs/trust-log.md`／解析唔到 `> Deadline:`／`PHASE=終局`／`PHASE=暫停`／未夠 30 分鐘。

## 2. 安裝（一行；預設只印 patch，`--apply` 才寫入）

```bash
SKILL=~/.claude/skills/dav-trust/extension        # Claude Code（Qoder 就 ~/.qoder/skills/...）

python3 "$SKILL/clock-tick.py" --install-hooks claude --scope user               # 睇 patch（唔會改檔）
python3 "$SKILL/clock-tick.py" --install-hooks claude --scope user --apply       # 合併入 ~/.claude/settings.json（寫前備份）
python3 "$SKILL/clock-tick.py" --install-hooks claude --scope user --uninstall --apply   # 只移除本 skill 嘅 hook

python3 "$SKILL/clock-tick.py" --install-hooks qoder --scope project --apply --project . # Qoder 專案層
```

- **安全**：合併而唔覆寫（保留你自己嘅 hook 同其他 key）；寫前備份 `settings.json.bak.<epoch>`；重複執行唔會加兩份；
  `--uninstall` 只移除帶 marker `tree-monstor:dav-trust-clock-tick` 嘅組。
- **路徑**：hook 命令內嵌腳本嘅絕對路徑 → 之後搬過 skill／repo 要重跑一次 `--apply`。
- 加 `--wake` 會多裝一個 `Stop` hook（見 §4）。

## 3. 裝完之後會多咗嘅設定（範本）

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [{ "type": "command", "command": "python3 '/…/clock-tick.py' --format hook --event SessionStart  # tree-monstor:dav-trust-clock-tick", "timeout": 10 }] }
    ],
    "PreToolUse": [
      { "matcher": "*", "hooks": [{ "type": "command", "command": "python3 '/…/clock-tick.py' --format hook --event PreToolUse  # tree-monstor:dav-trust-clock-tick", "timeout": 10 }] }
    ]
  }
}
```

hook 由 stdin 收 `cwd` → 腳本據此讀**嗰個專案**嘅 `docs/trust-log.md`。輸出（stdout，只有夠鐘才有嘢）：

```json
{"hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": "[dav-trust] ⏱ clock tick … now 2026-10-23 15:53:07 +0800. Deadline 2026-10-23 16:23:07 +0800 → 30 min left, 25% of the 120 min budget (elapsed 90 min). …"}}
```

## 4. `Stop` 叫醒（可選，`--wake`）

`Stop` 事件係唯一可以叫醒「已經停低」嘅 agent 嘅位置（trust mode 唔應該閒置）：

```json
{"decision": "block", "reason": "<同一段報時文字>"}
```

⚠️ **唔係預設**：如果專案留住一份舊 `PHASE=執行` 嘅 trust-log（其實已經收工），`--wake` 會每 30 分鐘嘈一次。要開就喺收工時記得寫 `PHASE=終局`。

## 5. 人手查／驗證

```bash
python3 "$SKILL/clock-tick.py" --json                       # 睇判定（due/reason/phase/deadline）
python3 "$SKILL/clock-tick.py" --json --force               # 忽略節流
python3 "$SKILL/clock-tick.py" --format hook --event PreToolUse --force   # 睇真正會注入嘅 JSON
python3 "$SKILL/clock-tick.py" --now 2026-10-23T16:19:07+08:00 --force    # 試「剩 < 10%」形態
```

閘門／節流／文字格式嘅機械證據：`../tests/clock-tick.bats`。

## 6. 如果某個 host 版本唔支援 `additionalContext`

兩個 host 嘅 hook 契約係按官方文件寫（事件名 ＋ `hookSpecificOutput.additionalContext`）；如果實測發現某個版本唔收：

- **降級做法**：改用支援阻塞嘅事件（`Stop`），以 `stderr` ＋ `exit 2` 把同一段文字餵返俾 agent（`clock-tick.py` 目前只出 JSON；
  要降級就喺 hook 命令包一層 `jq -r .reason` 之類）。
- **唔收**就唔好強行注入（避免污染每一輪對話）→ 只靠 §4 嘅 `Stop` 叫醒 ＋ trust-log 自己記時間。

## 7. 同 `dav-self-compact` 嘅分工

報時（本檔）同 context 量度（`dav-self-compact` 嘅 `ctx-usage.py`）係兩件事：呢邊講「而家幾點、剩幾多時間」，
嗰邊講「context 燒到幾 %」。兩者都係「agent 自己冇嘅感知」→ 都由 host 適配層補。
