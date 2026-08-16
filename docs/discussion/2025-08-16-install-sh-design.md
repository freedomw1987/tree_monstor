# install.sh 設計討論記錄

**日期**：2025-08-16
**主題**：為 tree_monstor 加入 `install.sh`，讓 Claude Code、Pi Agent 等 AI agent 能調用到 `AGENTS.md`、`SOUL.md` 和 `skills/`
**狀態**：進行中（一題一題問）

---

## 問題清單（按順序）

1. ✅ **「讓 agent 讀取到」具體是什麼意思？**（已回答）
   - 用戶選擇：**D. A + C（軟連結 + 安裝到本機 `.agents/`）**
   - Agent 推薦：D
   - 記錄：採用雙軌設計——軟連結確保源檔變更即時生效；`.agents/` 安裝符合官方慣例，未來易於分享。

2. ✅ **要支援哪些 agent？**（已回答）
   - 用戶選擇：**C. Claude Code + Pi Agent**
   - Agent 推薦：C
   - 記錄：第一版只支援這兩個；架構設計為可擴充，未來可加其他 agent。

3. ✅ **AGENTS.md 和 SOUL.md 要怎麼處理？**（已回答）
   - 用戶選擇：**C. 兩者都做，按 agent 分流**
   - Agent 推薦：C
   - 記錄：Claude Code 用 wrapper + `@` 引用；Pi Agent 用直接軟連結源檔。

4. ✅ **安裝模式：全域 vs 專案層？**（已回答）
   - 用戶選擇：**C. 兩個都支援，加旗標**
   - Agent 推薦：C
   - 記錄：預設全域；加 `--local` 裝到當前目錄；加 `--target` 指定路徑。

5. ✅ **冪等性與卸載**（已回答）
   - 用戶選擇：**B. 完全冪等 + `--uninstall` 旗標**
   - Agent 推薦：B
   - 記錄：重複執行安全；自動修復損壞連結；wrapper 加 marker comment 讓卸載能識別。`--uninstall` 支援全域與專案層。

6. ✅ **其他需求 / 限制**（已回答）
   - 用戶選擇：**A. 全部採納 Agent 推薦**
   - Agent 推薦：純 Bash + 寫 README + 排除 .obsidian/.git/.DS_Store + 不加 git hook + 加 `--dry-run` + 彩色輸出
   - 記錄：採用全部 6 項推薦。

---

## 🎯 討論結論總�

| 項 | 決定 |
|---|---|
| 1. 安裝方式 | A + C：軟連結 + 本機 `.agents/` |
| 2. 支援 agent | Claude Code + Pi Agent |
| 3. AGENTS/SOUL 處理 | 按 agent 分流：Claude 用 wrapper + `@`；Pi 用軟連結 |
| 4. 安裝範圍 | 全域 + 專案層都支援，加旗標切換 |
| 5. 冪等 + 卸載 | 完全冪等 + `--uninstall` 旗標 |
| 6. 其他 | 純 Bash + README + 排除 .obsidian/.git/.DS_Store + `--dry-run` + 彩色輸出 |

---

## 📂 下一步

進入 **SOP 2.2 — 計劃**：使用 `dav-designer` 技能撰寫詳細執行計劃（包含任務拆分、技術架構、測試策略、反省點），交付給用戶過目後再動工。
