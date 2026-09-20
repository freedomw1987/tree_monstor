# Gate 5 反省 — US-020 規則庫擴充 8→12（2026-09-20）

> **US-ID**：US-020
> **SP**：2
> **狀態**：✅ **DONE**

## 1. 完成內容

- `rsi-propose.sh lookup_proposal()` 加 4 個新規則（circular_ref / skill_timeout / agent_hang / commit_no_msg）
- `docs/prd/04-self-evolution.md` §11.4 加 4 個新規則清單
- `docs/sop/rsi-rule-extension-2026-09-20.md` 規則庫擴充日誌
- 7 個 bats 全綠
- 規則庫：8 → 12（+50%）

## 2. 5 Gate 驗證

| Gate | 結果 | 證據 |
|---|---|---|
| Gate 1 (TDD) | ✅ | 紅 → 綠，7 個 bats 全綠 |
| Gate 2 (lint) | ✅ | 0 issues |
| Gate 3 (regression) | ✅ | 60 個 sprint 10/11 bats 全綠 |
| Gate 4 (reviewer) | ✅ | V03 三條禁區零違規 |
| Gate 5 (RSI) | ✅ | 本檔 |

## 3. 重要發現

### 3.1 TDD 反覆試錯：grep「circular_ref」會匹配 generic 提案輸出

- **問題**：測試 AC-2 用 `grep -qF "circular_ref"` 對 propose 輸出匹配，但通用樣板也會顯示事件名 → 假綠
- **修法**：改驗 4 個新事件各自的「修法描述」（「雙向跳脫」「frontmatter」「timeout」「conventional」）
- **教訓**：grep「事件名」永遠會匹配到通用樣板，要 grep「修法描述」才驗得到規則庫

### 3.2 TDD 反覆試錯：grep -c 計算「### 提案」匹配所有事件

- **問題**：測試 AC-3 用 `grep -c "^### 提案"` 對 12 個事件 → 14 行（含 header）→ 假綠
- **修法**：改用「`! grep -qF "待定"`」（確認不是通用樣板）+「`grep -qF "雙向跳脫"`」（確認有對應修法）
- **教訓**：用 grep -c 計數易假綠，要雙驗證

### 3.3 rsi-aggregate 只認 gate_results，不認 events 陣列

- **問題**：原 mock 用 `events: [{type, count}]` 格式，rsi-aggregate 不認
- **事實**：rsi-aggregate 只從 `gate_results` 算 fail gate 名稱
- **修法**：測試 mock 改用 `gate_results` + `violations` 陣列格式
- **教訓**：觀察記錄 schema 仍以 `gate_results` 為主，events 是次要參考

## 4. Sprint 11 規則庫擴充

| # | 規則 | Sprint | 修法 |
|---|---|---|---|
| 9 | circular_ref | 11 | 修 AGENTS.md ↔ handbook 雙向跳脫 |
| 10 | skill_timeout | 11 | 減少 frontmatter 字段 |
| 11 | agent_hang | 11 | 加 timeout 機制 |
| 12 | commit_no_msg | 11 | commit 自動補 conventional |

**累計**：12 個規則（Sprint 09: 3 + Sprint 10: 5 + Sprint 11: 4）

## 5. AC 對齊

| AC | 結果 |
|---|---|
| 分析 US-019 觀察（mock 預演） | ✅ |
| 加 4 個新規則到 lookup_proposal | ✅ |
| 12+ 規則庫 | ✅ 12 個 |
| 規則擴充日誌 | ✅ rsi-rule-extension-2026-09-20.md |
| ≥ 7 個 bats | ✅ 7 個 |
| confidence 過濾 | ✅ 主要/Low Confidence 標記 |
| 信心分數公式 | ✅ freq × 0.05 + projects × 0.1 |

## 6. Sprint 11 §2.3 完成

| ID | SP | 狀態 |
|---|---|---|
| TD-033 | 0.5 | ✅ DONE |
| TD-034 | 0.5 | ✅ DONE |
| US-019 | 3 | ✅ DONE |
| US-020 | 2 | ✅ DONE |
| **小計** | **6/6（100%）** | |

## 7. 待批准

請用戶批准 US-020 DONE，進 §2.4 反省。
