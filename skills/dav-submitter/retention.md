---
name: dav-submitter-retention
description: dav-submitter 的「保留 vs 歸檔」規格附件。定義交付摘要只留最近一次、Backlog 只留未完成、docs/ 層面保留／歸檔清單同每次交收嘅執行次序。流程見主檔。
---

# Dav Submitter — 交付摘要 ＋ docs 保留策略

> 本檔為 `dav-submitter` 嘅「保留 vs 歸檔」規格（2026-10-27 訂）。
> 引用：主檔 `SKILL.md` Step 3（寫交付摘要）＋ Step 5（更新 Backlog）＋ 規則表。

## 為什麼要有這份規格

`docs/` 會隨住每一票交付而累積；完成嘅記錄留喺度，agent 每次都要重讀已完嘅嘢
→ 浪費時間同 LLM token。**做法：完成嘅記錄靠 git history（可追溯），文件樹只留「仲有用」嘅。**

⚠️ 前提：**刪之前先 commit**（內容入咗 git history 先刪，唔好未 commit 就刪）。

## 交付摘要：只留最近一次

- **位置**：`docs/deliverable/<YYYY-MM-DD>-<task-slug>.md`
- **保留**：**只留最近一次**交付摘要；舊嘅刪（靠 git history）
- **例外（要留低）**：**嗰次交付嘅引用鏈**：`docs/req/<US>-requirement.md` ＋ `docs/reconcile/<US>-reconcile.md`
- **點解要留引用鏈**：文件漂移檢查嘅 **D8 硬門檻**（窗內要有交付摘要可對帳）靠佢；唔留 → 檢查件數為 0 → fail-closed 紅

## Backlog：只留未完成

- `docs/backlog.md` 只留 **未完成**（`todo`／`doing`／`⏸️`）嘅 row
- **完成（done）嘅 row 要移出**（記錄去交付摘要 ＋ 需求錨點 ＋ git history）
- 每次更新 backlog 都要順手檢查：有冇已完成 row 殘留 → 有就移出
- 規格細節 ＋ 去邊記錄 → 見同套 `dav-planner` skill

## `docs/` 保留 vs 歸檔（全局判斷）

**保留**（仲有用／現行規範）：

- `docs/sop/`（SOP handbook ＋ gates.json 機器可讀副本）
- `docs/ci/`（CI 相關 SOP ＋ 漂移白名單）、`docs/cleanup/`（減磅工具）
- `docs/glossary_list.md`（術語表 → 各階段統一用語）
- `docs/DESIGN.md`、`docs/system-design.md`（設計／架構依據）
- `docs/install-reference.md`（安裝說明）、`docs/need-you-help.md`、`docs/trust-log.md`（活躍檔）
- `docs/ac/README.md`（AC 範本）＋ **未完成 US 嘅** ac／req／reconcile
- **最近一次交付摘要 ＋ 佢嘅引用鏈**

**歸檔**（靠 git history，刪之前先 commit）：

- 已完成 US 嘅 `docs/ac/<US>.md`、`.html`、對應 `docs/req/`、`docs/reconcile/`
- 已交付專案嘅 `docs/prd/<...>.md`
- 除最近一次外嘅 `docs/deliverable/*.md`

**點解**：文件樹愈積愈大 → agent 每次都要重讀已完嘅嘢，浪費時間同 token；
而 git history 已經完整保留咗「當時做咗乜」。

## 執行次序（每次交收）

1. 寫新交付摘要（`docs/deliverable/<date>-<slug>.md`）
2. **先 commit**（內容入 git history）
3. 刪舊交付摘要（保留新嗰次 ＋ 佢嘅引用鏈）
4. 歸檔已完成 US 嘅 ac／req／reconcile（保留未完成嘅）
5. 更新 `docs/backlog.md`：移出完成 row、留低未完成 row
6. 跑本專案嘅檢查（文件漂移檢查會驗 D1／D6／D7／D8 一致 → 有漏就會紅）
