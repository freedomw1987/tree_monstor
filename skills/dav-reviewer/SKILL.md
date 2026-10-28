---
name: dav-reviewer
description: >-
  人手觸發嘅審核＋交付 skill：由未參與實作的獨立 subagent 做 Gate 4（品質審核：功能正確性／代碼品質／測試覆蓋／回歸探針）＋ Gate 4.5（需求對帳：逐條比對用戶原話同最終成果）；review 通過後直接做交付摘要（對話 ＋ Markdown ＋ 反省 ＋ 需求對帳段）並更新受影響文檔同 docs/backlog.md。用戶話「review／審核／對帳／交付」時觸發；唔喺 §2.3 自動執行段內（Gate 1/2/3 由 dav-developer 自動做）。
---

# Dav Reviewer

## TL;DR

1. **做什麼**：一次過做完「**Gate 4 品質審核 → Gate 4.5 需求對帳 → 交付摘要 → 更新文檔 ＋ backlog**」。
2. **何時觸發**：用戶話「review／審核／對帳／交付」／要求交付前把關；**人手觸發**（§2.3 自動段只做 Gate 1/2/3）。
3. **關鍵紀律**：獨立性（審核 ＋ 對帳都由未參與實作嘅 subagent 做）；證據原文回傳；對帳覆蓋率 100%；交付必更新文檔 ＋ backlog。
4. **必產出物**：審核結論 ＋ `docs/reconcile/<US-ID>-reconcile.md` ＋ `docs/deliverable/<date>-<slug>.md`。

## 觸發時機

- **用戶要求 review／審核／對帳／交付** → ✅ 必須（人手叫先做）；**本次 US 有需求錨點**（`docs/req/<US-ID>-requirement.md`）→ ✅ 對帳前提
- **trust mode 進行中** → ⚠️ 見規則表；**純諮詢／一般任務（§2.6）**、**存量 US（無需求錨點）** → ❌ 不觸發

## 流程（5 步）

### Step 1 準備輸入（刻意做少）— 需求錨點檔全文 ＋ 最終變更清單（檔案 + diff）＋ 該 US 既有文件；**唔落檔**（細節 → `./workflow.md` §1）

### Step 2 開獨立 subagent 做 Gate 4 審核 — 全面校驗（功能正確性／代碼品質／測試覆蓋／回歸探針）；UI 任務必跑 playwright-cli E2E（細節 → `./review.md`）

### Step 3 開獨立 subagent 做 Gate 4.5 對帳 — 逐條比對需求錨點嘅 R-ID ＋ 最終成果 → 對帳表（覆蓋率 100% 才算完成）（細節 → `./workflow.md` §2–§3）

### Step 4 寫交付摘要 — 對話摘要 ＋ Markdown 詳錄（8 段 ＋ 反省末段 ＋ 需求對帳段）（細節 → `./deliver.md` §1）

### Step 5 更新受影響文檔 ＋ `docs/backlog.md` — 只改真係受本次改動影響嘅專案文檔 ＋ 更新 backlog 狀態；done row 移出（細節 → `./deliver.md` §2）

## 規則 / 例外 / 限制

- **審核 ＋ 對帳都要獨立 subagent**（未參與實作） — 例外：環境無 subagent 能力 → 降級並明示；限制：唔准自己審自己
- **對帳表必須覆蓋全部 R-ID ＋ 對帳未全數對上 → 不得標「完成」** — 例外：全部 ❌ 未實作 → 可標「未完成」；限制：漏一條即對帳不完整、不得視為「無需對帳」；其餘只能「部分完成」＋待補清單
- **證據要原文回傳**；**UI 任務必跑 playwright-cli E2E** — 例外：無／純後端／CLI／腳本可跳過；限制：唔准改寫成「已通過」／唔准自己填對帳表；跳過要明示「無 UI 故不適用」及理由
- **交付摘要必含 8 段 ＋ 反省末段 ＋ 需求對帳段** — 例外：小任務可精簡次要段；限制：§1／§2／§3／§5／§6／§8 不可少（v2.0 起不產 HTML）
- **交付時必更新受影響文檔 ＋ `docs/backlog.md`** — 例外：冇受影響文檔 → 對話講明；限制：唔准文件同實作漂移；done row 要移出（記錄去交付摘要 ＋ 需求錨點 ＋ git history）
- **人手觸發** — 例外：無；限制：§2.3 自動段唔會自動叫本 skill；用戶叫咗就要做齊兩道 Gate
- **trust mode 進行中不中途停下問用戶** — 例外：用戶叫停時立即收斂；限制：對帳結果照常產出，缺口記入 trust-log 代答 + need-you-help 待回覆
- **進 Gate 4／4.5 必引用 mandatory_phrase**（見 `./gates.md`） — 例外：無；限制：不引用 = 視為 gate 未觸發（偽裝通過）

## 交叉引用（純文字）

- Gate 4 ＋ Gate 4.5 定義（四欄 ＋ mandatory_phrase ＋ 豁免）→ 同套 `./gates.md`；審核流程 → 同套 `./review.md`
- 對帳流程（5 步）→ 同套 `./workflow.md`；對帳表格式 → 同套 `./reconcile-format.md`
- 交付流程（8 段 ＋ 反省 ＋ Module 級交付 ＋ 保留／歸檔 ＋ 更新 docs／backlog）→ 同套 `./deliver.md`
- 範本／清單 → 同 skill 子檔 `./templates/`（交付摘要模板、反省模板、反省檢查清單、對帳表）、`./examples/`
- 文件漂移檢查（D1..D8）工具用法 → 同套 `./doc-drift-check.md`；執行段嘅 Gate 1/2/3（自動）→ 見同套 `dav-developer` skill
