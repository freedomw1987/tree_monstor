# TMO-090 需求對帳表

> 對帳者: 獨立 Reviewer subagent（V03 二審，**未參與實作**）| 對帳時間: 2026-10-27
> 錨點: docs/req/TMO-090-requirement.md
> 覆蓋率: **4/4**
> 對帳者獨立性: 非降級路徑（未參與本次實作）

## 對帳表

| 需求 ID | 需求句（摘要）| 狀態 | 實作位置 | 證據 | 備註 |
|---------|---------------|------|---------|------|------|
| R1 | 三個 TDD 相關 skill 合併成 `dav-developer` | ✅ 已實作 | `skills/dav-developer/`（主檔 ＋ 13 個子檔 ＋ `PoC/` ＋ `tests/`）| `skills/` 只剩 `dav-developer`；舊 3 個 skill 目錄已刪；全 repo 路徑／skill 名引用同步（70+ 檔：CI、mutant 表、探針、docs、gates.json、handbook）| 主檔做**路由 ＋ 四道 Gate 定義**（Gate 1/2/3/4 齊）；內容下沉子檔 → 主檔 140 行（≤150 硬上限 ✓）|
| R2 | `dav-developer` SOP 順序：寫測試 → 紅變綠 → 探針與回歸 → Reviewer 二審；Gate 3 唔再要求全項目跑；寫測試保留嚴謹性 | ✅ 已實作 | `skills/dav-developer/SKILL.md` Step 1-4 ＋ Gate 3；`docs/sop/gates.json`（v1.2.0）| Step 1 寫測試（TDD，先紅）／Step 2 紅變綠／Step 3 埋探針 ＋ **改動範圍內**回歸／Step 4 Reviewer 二審；Gate 3 三處已由「完整測試套件」收窄成「改動範圍內」（skill 同 gates.json 兩邊一致）；fail-loud ＋ 修復建議 ＋ 禁 watch/interactive 在主檔規則段 | ⚠️ `gates.json` 與 skill 兩份一致嘅**機械鎖已於 2026-10-27 減法刪走** → 靠人手同步（已記錄）|
| R3 | `dav-reflection` 刪除，內容併入 `dav-submitter` | ✅ 已實作 | `skills/dav-submitter/`（`reflection-checklist.md` ＋ `reflection-templates.md` ＋ Step 3.5）；handbook §2.4／§2.5；`dav-trust`；`dav-designer` | 反省流程（US／Sprint／Module 三級別 ＋ 6 維度）→ `dav-submitter` Step 3.5；`skills/dav-reflection/` 已刪；全 repo 冇 `dav-reflection` 引用（覆核 grep 0 命中）| 反省屬「交付前」→ 放喺提交 skill 最合理（原本分兩個 skill 係過度切分）|
| R4 | markdown 唔用表格；規則寫入 `dav-skill-creater` 規範 | ✅ 已實作 | `skills/dav-skill-creater/editor-guide.md`「表格禁令（v2.10）」章；`SKILL.md` 規則行 ＋ 紀律行 | 章內容：規則（敘述性內容用列表）＋ 點解（可讀性／token／結構不適合）＋ 點樣寫（表 → 列表對照）＋ **三類例外** ＋ **存量 sweep 待辦** | ⚠️ 存量表格（live .md 約 241 個敘述性表）**未 sweep** → 屬另一票待辦（已記入 backlog）；新規則約束新寫／改寫內容 |

## V03 二審結果

- **第 1 輪**：`request-changes` — P1×2（`gates.json` Gate 3 未收窄；主檔 158 行 > 150 硬上限）＋ P2 死引用群（8 處）
- **實作者處置**：全部修（`gates.json` 三處收窄 ＋ version 1.2.0；主檔壓到 140 行；死引用 8 處逐個清；啞引用 4 處清；`.env.example` 路徑修；表格禁令章補 3 類例外 ＋
sweep 字眼）
- **第 2 輪（覆核）**：**`approve`** — 殘留 3 個 P2 文字層問題 → 已再修

**reviewer 冇驗嘅部分，由實作者實跑補證**：`bash scripts/check-all.sh` → **11 步全綠**；
`bash scripts/ci/check-doc-drift.sh --from-date 2026-10-26` → OK（38 項檢查完成，51 項豁免）；
markdownlint → 0 issues；主檔 13 個子檔指標全部存在 ✓。

## 結論

- **4 項已實作、0 項部分實作、0 項未實作。覆蓋率 4/4（100%）。**
- 本票屬**大規模規範改動**（skill 合併／刪除／Gate 定義收窄）→ 已依 `AGENTS.md` §1.5 V03 走獨立二審（2 輪）。
- 已記錄嘅代價：

  1. `dav-developer` context 2,098 行（超 700 軟上限 3 倍）→ ratchet baseline ＋ 建議再拆「Jev Oracle」做獨立 skill
  2. Gate 3 收窄後，跨 Module 影響／大重構要顯式跑全項目（規則已寫入）
  3. 存量表格 sweep 未做（另一票）
  4. `gates.json` ↔ skill 兩份 Gate 定義冇機械鎖 → 人手同步

## 追加：批次 A 表格 sweep（2026-10-27，用戶選 A）

- **做咗**：`skills/` ＋ `docs/sop/handbook/` 嘅敘述性表 → 列表（52 個檔；轉換後 **0 個表殘留**）
- **連帶**：mutant `DW-M4` 錨點（原本係表列文字）→ 更新成列表形態；mutant 依然會死（WTM-5 紅 ✓）
- **保留表格（批次 B）**：目標專案端被 doc-drift 解析嘅結構化資料檔（backlog row／對帳表／PRD 追溯矩陣）→ v2.10 例外
- **閘**：`bash scripts/check-all.sh` → 11 步全綠；markdownlint 0 issue

## 追加：批次 A 覆核輪（2026-10-27）

- **第 1 輪覆核**：`request-changes` — P1（表→列表令 4 個主檔破 150 行硬上限 ＋ dav-trust 行數自述過期
  ＋ editor-guide 聲明過期）＋ P2（editor-guide「欄位定義」兩段矛盾）＋ P2（5 個主檔尾連續 `---`）
- **實作者處置**：
  - 主檔全部壓回 **≤150 行**（dav-trust 191→150、dav-skill-creater 174→150、dav-planner 169→145、
    dav-submitter 168→145、dav-reconciler 159→145；做法：規則嘅「例外／限制」合併成一行 ＋ Step 段合併）
  - dav-trust 嘅「目前主檔 150 行（已頂 150 硬上限，下次加功能必須先減）」自述更新
  - editor-guide 嘅例外清單刪走「欄位定義」（改跟「點樣寫」用列表）＋ 主檔預警帶講法更新
  - 5 個主檔尾重複 `---` 已清
  - **程式碼完整性補救**：折行過程曾把 ~90 處 code fence 語言 tag 折斷（`` ```markdown `` → `` ```markdown# ``）、
    21 處 fence 首行被吞入 info string → 已逐個修復（掃描驗證：fence info string 異常 0、行內 code span 奇數 0）
- **第 2 輪覆核**：**`approve`（批次 A 範圍）** — 殘留 P1（fence tag 折斷）→ 已修
- **閘**：`bash scripts/check-all.sh` → 11 步全綠；markdownlint 0 issue；mutant 49 支全死

