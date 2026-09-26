# PRD 01 — dav-planner AC 範本獨立化 + HTML 版本

> Backlog ID: TMO-006
> 對應 Skill: `dav-planner`
> 版本: v1.0（2026-09-25 草擬）
> 狀態: Design Phase

---

## 1. 背景

### 1.1 問題

dav-planner skill (§4.3) 目前把 AC（Acceptance Criteria）整段塞在 `docs/backlog.md` 表格的「交付價值與驗收標準 (AC)」cell 內。一個 User Story 的 AC 通常含：

- Given-When-Then × 3-5 條
- DoD checklist × 4-6 項

這在 markdown 表格 cell 內有幾個問題：

1. **閱讀體驗差**：cell 內 `<br>` 分行，視覺擠、難 scan
2. **不易分享**：利害關係人（QA / PO / 客戶）要單獨校對 AC，必須整份 backlog 一起給
3. **不易列印**：表格 cell 內的 `<br>` 在 PDF / 列印時排版破
4. **難搜尋**：AC 內容跟其他欄位混在一起，無法快速找「所有提到『結帳』的 AC」

### 1.2 目標

AC 從 `docs/backlog.md` 表格 cell 抽出，每個 User Story 配一份獨立 AC 範本：

- `docs/ac/<US-ID>.md` — Markdown 版本（版本控管、可編輯、給開發者）
- `docs/ac/<US-ID>.html` — HTML 版本（易閱讀、列印、分享，給利害關係人）

`docs/backlog.md` 表格 AC 欄位精簡為「AC 摘要 + 連結」，backlog.md 仍是 single source of truth（看項目進度用）。

### 1.3 範圍

**做**：
1. `docs/ac/` 目錄結構（按 US 分檔）
2. AC 範本 .md 模板（Given-When-Then + DoD 結構）
3. AC 範本 .html 生成規則（Agent 寫 .md 同時生成 .html）
4. `dav-planner/SKILL.md` §4.3 改動（AC 欄位精簡 + 連結規則）
5. `dav-planner/SKILL.md` §4.6 新增（HTML 生成 SOP）
6. 既有 backlog.md 不動（過渡期共存）
7. bats 守護測試（防 SKILL.md 章節被靜默移除）
8. changelog v1.8 同步更新

**不做**：
- 不動既有 backlog.md 的 US 條目（過渡期共存）
- 不做 AC 範本的自動 lint / 校對
- 不做 docs/ac/ 的全文搜尋 / index 頁
- 不做 HTML 主題切換（dark mode / 列印樣式優化）

---

## 2. 使用者故事

### US-006-1：作為 PO，我想單獨看某個 User Story 的 AC，以便校對驗收標準

**AC**：
- 給定某個 US-XXX（如 US-101）
- 當 PO 打開 `docs/ac/US-101.html`
- 則看到結構化的 AC（Given-When-Then 條列、DoD checklist）
- 且 HTML 有列印友好的 CSS

### US-006-2：作為開發者，我想在編輯 AC 時有 markdown 版本，以便版本控管

**AC**：
- 給定 `docs/ac/US-101.md` 存在
- 當開發者用任何 markdown 編輯器打開
- 則可正常編輯（無格式問題）
- 且 git diff 可正常追蹤變更

### US-006-3：作為 dav-planner Agent，我想生成 US 時自動產 AC 範本，以便符合新 SOP

**AC**：
- 給定 dav-planner 與用戶確認新 US（如 US-101）
- 當 Agent 寫入 `docs/backlog.md` 時
- 則同時（同一次 turn）寫入 `docs/ac/US-101.md` + `docs/ac/US-101.html`
- 且 backlog.md AC 欄位精簡為「AC 摘要 + 連結」

---

## 3. 檔案結構設計

### 3.1 目錄結構

```
docs/
├── ac/                          # 新增目錄
│   ├── README.md                 # 目錄說明（生成規則、命名規範、範例）
│   ├── US-XXX.md                 # 每個 US 一份 AC .md 範本
│   └── US-XXX.html               # 對應的 .html 閱讀版
├── backlog.md                    # AC 欄位精簡為「摘要 + 連結」
└── ...
```

### 3.2 檔案命名

- `docs/ac/<US-ID>.md` — 與 backlog.md 的 US ID 完全對應（如 `US-101.md`）
- `docs/ac/<US-ID>.html` — 與 .md 同名，僅副檔名不同
- 不分大小寫（建議全大寫以匹配 backlog 慣例）

### 3.3 範本結構

#### `docs/ac/US-XXX.md` 範本

```markdown
# US-XXX AC 範本

> 對應 Backlog: [US-XXX in docs/backlog.md](../backlog.md)
> 最後更新: 2026-09-25

## 背景

（一句話描述：本 AC 對應 US-XXX「<標題>」，作為 <persona> 我想 <action> 以便 <value>）

## Given / When / Then

- **Given** <前置條件 1>
  **When** <用戶動作 / 系統觸發>
  **Then** <可觀察結果>

- **Given** <前置條件 2>
  **When** <動作>
  **Then** <結果>

## DoD（Definition of Done）

- [ ] <技術驗收 1>（如：單元測試覆蓋率 ≥ 80%）
- [ ] <技術驗收 2>（如：通過 CI lint / type check）
- [ ] <技術驗收 3>（如：文件已更新 README / API doc / changelog）
- [ ] <技術驗收 4>（如：已在 staging 環境驗證）

## 變更歷史

| 日期 | 版本 | 變更 | 作者 |
|------|------|------|------|
| 2026-09-25 | v1.0 | 初版建立 | Agent |
```

#### `docs/ac/US-XXX.html` 範本（Agent 自動生成）

HTML 結構（嵌入 CSS）：

```html
<!DOCTYPE html>
<html lang="zh-Hant">
<head>
  <meta charset="UTF-8">
  <title>US-XXX AC 範本</title>
  <style>
    /* 列印友好 CSS：黑白、單欄、checklist 加大 */
    body { font-family: -apple-system, "PingFang TC", sans-serif;
           max-width: 800px; margin: 2em auto; padding: 0 1em;
           line-height: 1.7; color: #222; }
    h1 { border-bottom: 2px solid #333; padding-bottom: 0.3em; }
    h2 { color: #2c5282; margin-top: 2em; }
    .ac-item { background: #f7fafc; padding: 1em; margin: 1em 0;
               border-left: 4px solid #4299e1; }
    .dod-item { padding: 0.3em 0; }
    blockquote { color: #666; font-style: italic; }
    @media print {
      body { font-size: 11pt; }
      .ac-item { page-break-inside: avoid; }
    }
  </style>
</head>
<body>
  <h1>US-XXX AC 範本</h1>
  <blockquote>對應 Backlog: <a href="../backlog.md">US-XXX</a></blockquote>

  <h2>背景</h2>
  <p>...</p>

  <h2>Given / When / Then</h2>
  <div class="ac-item"><strong>Given</strong> ... <strong>When</strong> ... <strong>Then</strong> ...</div>

  <h2>DoD（Definition of Done）</h2>
  <ul>
    <li class="dod-item">☐ 單元測試覆蓋率 ≥ 80%</li>
    ...
  </ul>

  <h2>變更歷史</h2>
  <table border="1" cellpadding="6" cellspacing="0">
    <tr><th>日期</th><th>版本</th><th>變更</th><th>作者</th></tr>
    ...
  </table>
</body>
</html>
```

---

## 4. SOP 改動設計

### 4.1 `docs/backlog.md` 表格 AC 欄位改動

**改動前**（一個 cell 內塞全部 AC）：

```markdown
| **US-101** | User Story | 作為顧客，我想使用信用卡快速結帳... | **Given** 已登入+有商品<br>**When** 點結帳<br>**Then** 3 秒內到付款頁<br>**DoD** 單元測試 80%+ | ... |
```

**改動後**（精簡為摘要 + 連結）：

```markdown
| **US-101** | User Story | 作為顧客，我想使用信用卡快速結帳... | **AC 摘要**：3 秒內到付款頁 / 見 [../ac/US-101.md](../ac/US-101.md) | ... |
```

### 4.2 `dav-planner/SKILL.md` §4.3 新增 §4.3.2

新增小節，內容：

- AC 欄位精簡規則
- 摘要撰寫原則（≤ 2 行 / 30 字內）
- 連結格式
- `docs/ac/` 範本檔案結構

### 4.3 `dav-planner/SKILL.md` §4.3 之後新增 §4.6

新增小節「AC 範本生成 SOP（Agent 必做）」，內容：

- 何時生成（用戶確認 US 後）
- 生成順序（先 .md 再 .html，同一 turn）
- 範本引用（本 PRD §3.3）
- 既有 US 不主動生成（過渡期規則）

### 4.4 changelog v1.8

於 `docs/sop/handbook/changelog.md` 新增 v1.8 條目，記錄本次變更。

---

## 5. Story Point 估算

| 子任務 | 點數 | 理由 |
|--------|------|------|
| AC 範本 .md / .html 模板設計 | 2 | 本 PRD 已完成大半 |
| SKILL.md §4.3.2 新增（AC 精簡規則）| 2 | 需精準改既有 §4.3 結構 |
| SKILL.md §4.6 新增（HTML 生成 SOP）| 1 | 新章節，從無到有 |
| bats 守護測試 | 2 | 5 個探針 × 設計 + 跑通 |
| changelog v1.8 | 1 | 模板化條目 |
| **合計** | **8** | |

---

## 6. 風險與緩解

| 風險 | 等級 | 緩解 |
|------|------|------|
| 既有 backlog.md 條目被誤改 | 中 | 過渡期不動既有 US；新規則只適用 §4.5 之後新增的 US |
| docs/ac/ 命名衝突（如 US-101 重複） | 低 | 用 US-ID 唯一識別；既有 backlog 已用 ID 區隔 |
| HTML 樣式在不同瀏覽器不一致 | 中 | 用基礎 CSS（web-safe font、避免 vendor prefix）；不依賴框架 |
| Reviewer 二審抓出 SOP 一致性問題 | 高（依 V03 必走） | 提前請 dev-checker-loop subagent 檢查 |
| bats 測試在 macOS / Linux 跨平台失敗 | 低 | 沿用既有 bats 慣例（homebrew + linux）；檔案存在性檢查跨平台一致 |

---

## 7. 完成標準（DoD）

- [ ] `docs/ac/README.md` 已建立（說明目錄用途 + 命名規範 + 範例）
- [ ] `docs/ac/US-101.md` 範例檔已建立（含真實 AC 內容）
- [ ] `docs/ac/US-101.html` 範例檔已建立（含 CSS）
- [ ] `dav-planner/SKILL.md` §4.3.2 已新增（AC 精簡規則）
- [ ] `dav-planner/SKILL.md` §4.6 已新增（HTML 生成 SOP）
- [ ] `tests/dav-planner-ac-templates.bats` 已建立（≥ 5 個探針）
- [ ] 全部 bats 測試通過
- [ ] `docs/sop/handbook/changelog.md` v1.8 已新增
- [ ] Reviewer subagent verdict: PASS（無 blocker）
- [x] `docs/backlog.md` 中 TMO-006 狀態更新為 done

---

## 8. 開放問題（待用戶確認）

無（本 PRD 內所有決策已於 §1.3 確認）
