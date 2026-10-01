---
name: dav-planner-backlog-rules
description: dav-planner 的「Backlog 編寫規則」附件（v2.2 拆分自主檔）。含 INVEST / AC / 表格欄位 / 類型 / 更新規則 / AC 範本生成 SOP。
---

# Dav Planner — Backlog 規則（§4 完整版）

> 本檔為 dav-planner 的 Backlog 編寫規則附件，於產出 Backlog 前查閱。主檔在 `SKILL.md`。

## §4.1 INVEST 原則

- **I**ndependent — 獨立
- **N**egotiable — 可協商
- **V**aluable — 有價值
- **E**stimable — 可估算
- **S**mall — 小
- **T**estable — 可測試

## §4.2 AC 範本（Given-When-Then / DoD）

- **Given-When-Then**：3 條以上 BDD 格式
- **DoD**：技術視角（4-6 項 checklist）

## §4.3 Backlog 編寫方式

- 表格欄位：US ID / 類型 / 標題 / AC / 優先級 / Story Point / 狀態 / 依賴
- 詳細段：放在表格下方（## TMO-XXX 詳細）
- 既有 US 不主動遷移；新 US 走新格式

## §4.4 類型混合管理

- User Story（新功能）/ Defects（Bug）/ Technical Debt（技術債）/ Spike（研究）
- 頂部精細、底部粗略（Granularity）

## §4.5 Backlog 更新規則

- 每一個項目目錄只有並唯一有一份 `docs/backlog.md`
- 每次新 Backlog item 填到表格最下方，不估算 / Sprint / Module，預設 PENDING

## §4.6 AC 範本生成 SOP（v1.8 新增，含 HTML）

- **生成時機**：用戶確認新 US 後、寫進 backlog.md 之前
- **生成順序（同 turn）**：先 .md → 再 .html → 最後更新 backlog.md
- **為什麼同 turn**：避免 .md 與 .html 不同步
- **過渡期規則**：既有 US（§4.3.2 之前）不主動生成 AC 範本
- **自我檢查清單**：5 項（檔案存在 / 連結路徑 / CSS 媒體查詢）
