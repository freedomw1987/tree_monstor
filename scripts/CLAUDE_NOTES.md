# scripts/CLAUDE_NOTES.md

Operational notes for `scripts/`. Read before adding/removing scripts or cron jobs.

## 2026-06-24 — 兩個 cron jobs 移除

**移除 jobs（cron/jobs.json 已清空）：**

| Job ID | 名稱 | schedule | 移除原因 |
|--------|------|----------|----------|
| `be6b1aadc9cd` | `auto-archive-sessions` | `0 3 * * *` | shell script 不存在 |
| `757736b81b92` | `nightly-memory-normalize` | `0 2 * * *` | shell script 不存在 |

**背景：**

- jobs.json 引用路徑 `~/.hermes/profiles/developer/scripts/`，但該目錄不存在；hermes profile 結構也未啟用
- scripts/ 內只有 `cost_alarm_monitor.py`（370 行）和 `subagent_supervisor.py`（300+ 行），**兩個都是 reference impl，從未被 cron 觸發過**
- 兩個 jobs 從 2026-06-19 起每晚失敗但**無 alert**，jobs.json 只 silently 累積 `last_error`
- 對應的 cron output dirs `cron/output/be6b1aadc9cd/` 和 `cron/output/757736b81b92/` 是 stale empty dirs

**保留：**

- `cost_alarm_monitor.py` — cost alarm 參考實作，未來若要重啟監控可參考
- `subagent_supervisor.py` — zombie task detection 參考實作，同上

**未來重啟 cron 的前置條件（不在本次 scope）：**

1. 確認 hermes profile 結構是否仍存在 / 啟用
2. 建立對應的 shell scripts（`auto-archive-sessions.sh` 和 `memory-normalize.sh`）— **不只是改 jobs.json 路徑**
3. 加上 `last_status: error` 時主動通知 David 的 alert（避免再次 silent failure）
4. Cleanup cron output stale dirs

**參考：** 紅線 35（auto-maintenance cron 唔好 block），incident 流程見 `docs/incident-*.md`。