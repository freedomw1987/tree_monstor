# docs/ac/ — Acceptance Criteria 範本目錄

> 版本：v1.0（2026-09-25 配合 dav-planner v1.8 建立）
> 對應 Backlog：[docs/backlog.md](../backlog.md)
> 對應 Skill：`dav-planner/SKILL.md` §4.3.2 + §4.6

## 用途

存放每個 User Story 的**獨立 AC（Acceptance Criteria）範本**，從 `docs/backlog.md` 表格的 AC 欄位抽出，方便：

- PO / QA 單獨校對（不打開整份 backlog）
- 利害關係人分享（給客戶 / 部門主管）
- 列印 / PDF 匯出（用 HTML 版）
- 全文搜尋（AC 內容不在表格 cell 內）

## 命名規範

| 檔案 | 用途 | 受眾 |
|------|------|------|
| `docs/ac/<US-ID>.md` | AC 範本 Markdown 版本 | 開發者（版本控管、可編輯） |
| `docs/ac/<US-ID>.html` | AC 範本 HTML 版本 | 利害關係人（閱讀、列印、分享） |

範例：
- **PoC 嘅 fixture 放 skill 內**（`skills/dav-jev-oracle/PoC/fixtures/ac/`）→
  令 `dav-jev-oracle` skill 自足（目標專案裝咗都跑得），唔使喺專案層 `docs/ac/` 養住歷史 AC
- `docs/ac/<US-ID>.html` — 該 US 的閱讀版（與 `.md` 同 turn 產生）

通用命名：`docs/ac/<US-ID>.md` 與 `docs/ac/<US-ID>.html`，其中 `<US-ID>` 是 backlog.md 中該 User Story 的 ID（如 `US-101`、`US-102`、`DE-201`）。

> **`<US-ID>` 兩種形式都算**（同一 repo 內並存，探針以「檔名 stem」為 key 對應，不做前綴假設）：
> `US-<編號>`（如 `US-101`）與 `TMO-<nnn>`（如 `TMO-071`，backlog 主表用的 ID 形式）。
> **AC 檔的 key 必須與 backlog 該列的 ID 相同**；AC 檔內另以「對應 Backlog: `<ID>`」標明它對應哪一列。

範本（抽象語法）：`docs/ac/US-XXX.md` 與 `docs/ac/US-XXX.html`。

## 生成規則

依 `dav-planner/SKILL.md` §4.6，每個新生成的 US 必須同時產出：

1. `<US-ID>.md`（AC 範本）
2. `<US-ID>.html`（對應 HTML 版）
3. 更新 `docs/backlog.md` AC 欄位為「AC 摘要 + 連結」

**既有 US 不主動生成**（過渡期共存於 backlog.md 表格內）。

## 範本結構

### .md 範本（必含）

- `# <US-ID> AC 範本`
- 對應 Backlog 引用（blockquote）
- `## 背景`（一句話）
- `## Given / When / Then`（3 條以上）
- `## DoD（Definition of Done）`（checklist）
- `## 變更歷史`（表格）

### .html 範本（必含）

- `<!DOCTYPE html>` + `<html lang="zh-Hant">`
- 內嵌 `<style>`（列印友好 CSS）
- `@media print` 媒體查詢
- 結構對應 .md

## 範例檔案

- `skills/dav-jev-oracle/PoC/fixtures/ac/US-101.md` — 信用卡快速結帳 AC 範本（Markdown；PoC 用嘅 fixture）
- `docs/ac/<US-ID>.html` — 該 US 的閱讀版（與 `.md` 同 turn 產生；已交付 US 嘅 HTML 隨 AC 一併歸檔）

## 變更歷史

| 日期 | 版本 | 變更 | 作者 |
|------|------|------|------|
| 2026-09-25 | v1.0 | 初版建立（dav-planner v1.8 SOP 落地） | Agent |
