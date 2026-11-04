# dav-self-compact — 安裝／驗證／故障排除

## §1 安裝

- **通用**：`./install.sh --agent <claude|pi|qoder|all>` 會把本 skill symlink 入對應 agent 嘅 skills 目錄，
  並喺 **skill 目錄上一層**寫 `dav-self-compact.host`（內容＝host 名）俾 Step 0 判定用
  （Claude Code → `~/.claude/`、Qoder → `~/.qoder/`、pi → `~/.pi/agent/`）。
- **pi 額外**：本 skill 附 extension（`ctx_status`／`ctx_compact`／`/ctx`），installer 會 symlink 成
  `~/.pi/agent/extensions/dav-self-compact`；冇 extension → 只有紀律層，冇量度 ＋ 冇自動保險絲。
- **Claude Code 額外**：手動喺 `~/.claude/settings.json` 加 `autoCompactEnabled: true` 同
  `env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE = 55`；想準確窗口就另建 `~/.claude/dav-self-compact.json`。
- **Qoder 額外**：用 `/context-window` 設當前模型窗口（設細啲 → auto-compact 提早開火）；確認冇連續壓縮失敗（熔斷）。
- **跨 agent 量度 script**：`ctx-usage.py` 喺 skill 同一層，Claude Code／Qoder 通用（唔使另外裝）。

## §2 驗證

- **pi**：`pi -p "call ctx_status and report the result"` → 應回覆 usage／zone／action ＋保險絲審核；
  `/ctx` 手動睇；改 config 閾值後即刻再量（live fuse 生效）。
- **Claude Code**：跑 `ctx-usage.py --host claude` → 應印 used／window／percent／zone；再查 transcript 有冇 `compact_boundary`。
- **Qoder**：跑 `ctx-usage.py --host qoder`；人手 `/context` 核對。
- **通用**：跑 `bats tests/skill-size.bats`（行數門檻）＋ `bats skills/dav-self-compact/tests/*.bats`。

## §3 閾值設定（單一真相源）

- **pi**：`~/.pi/agent/dav-self-compact.json`（soft 50／opportunity 55／hard 60／target 35／targetMin 20／
  absoluteCapTokens 0／noticePercents [20,40,60]／liveFuse true／autoSyncSettings true）→ 改完即時生效；
  **唔好**手改 `~/.pi/agent/settings.json` 嘅 `reserveTokens`。
- **Claude Code**：`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`（百分比）＋ `autoCompactEnabled`（開關）→ 改完重開 session。
- **Qoder**：`/context-window`（窗口）＋ Qoder 內建 auto-compact 閾值。
- **通用**：想真係長期留喺聰明區（而唔係「窗口的一半」）→ 設絕對上限：pi 用 `absoluteCapTokens`；Claude Code／Qoder 直接把窗口調細。

## §4 故障排除

- **ctx-usage.py 讀唔到 usage** → transcript 未落盤／格式變／搵錯專案目錄 → 當 soft 區處理，唔好亂報百分比。
- **percent 唔準** → 窗口值錯（Claude Code／Qoder 靠 `contextWindow` 設定）→ 校準窗口再量。
- **見到 hard 區** → 保險絲太遲（Claude Code／Qoder：閾值未設或 auto-compact 關咗）→ 收尾 ＋ 報告 ＋ 建議改閾值。
- **壓縮冇發生** → 對話未過該 host 嘅保留門檻（session too small）＝正常；其他錯誤 → 報告，唔好硬 loop。
- **pi 嘅 `ctx_status` 唔見** → extension 未載入 → 檢查 `~/.pi/agent/extensions/dav-self-compact` symlink ＋ `/reload`。
- **前台 subagent 冇 ctx_status** → agent frontmatter 加 `extensions:`（指向本 skill 嘅 extension 目錄）
  同 `tools: [..., ctx_status]`。
- **host 判定唔到** → 冇 `dav-self-compact.host` 綁定檔 → 照 `adapters.md` §1 用環境變數判定；仍然唔得就只做紀律層。
