# Sprint 14 RSI 反省 — US-025 rsi-sync --dry-run（2026-09-20）

## 基本資訊

- **User Story**：US-025 — rsi-sync --dry-run
- **對應 SP**：1 SP
- **對應 Sprint 14 主軸**：RSI 同步安全
- **對應設計文件**：
  - docs/prd/04-self-evolution.md §11.7
  - docs/system-design.md ADR-025（sync dry-run 對稱 rollback dry-run）

## 變更摘要

1. `tools/rsi-sync.sh` 加 `--target <path>` 旗標（覆蓋自動掃瞄）
2. 既有 `--dry-run` 已有完整實作：
   - 列每個將同步檔案：`[add] / [modify] / [skip]`
   - 計算 src/tgt md5 對比
   - 模擬 cp/merge（不實際寫入）

## 量化指標

| 指標 | 數值 |
| --- | --- |
| 新增/修改檔案 | 1（tools/rsi-sync.sh）|
| bats 數量 | 5（us025-1 ~ us025-5）|
| bats 通過率 | 5/5（100%）|
| markdownlint | 0 errors |

## 設計對稱驗證

| 操作 | 旗標 | Sprint |
| --- | --- | --- |
| rollback | `--dry-run` | Sprint 13 US-024 |
| **sync** | **`--dry-run`** | **Sprint 14 US-025** |

✅ 結構對稱（一致 UX、一致輸出格式）

## 風險評估

- **風險 1**：用 `--target` 直接傳路徑可能傳相對路徑
  - **緩解**：bats 測試都用絕對路徑（mktemp -d），且 help 有提示
- **風險 2**：dry-run 沒實際觸碰 fs 但 find 大量檔案可能慢
  - **緩解**：find 加 `2>/dev/null` 忽略權限錯誤

## SOP 規範遵守

- [x] 旗標解析加在 `while [[ $# -gt 0 ]]` 區塊
- [x] 對齊 Sprint 13 US-024 dry-run 結構
- [x] help 加 `--target` 說明
- [x] bats 覆蓋：help / 列檔 / 不實際 copy / 顯示 action / md5 對比
- [x] markdownlint 0 errors
- [x] bash -n 通過

## 下一步

- [ ] Sprint 14 §2.4 反省（待 Sprint 14 全部完成）
- [ ] Sprint 14 §2.5 提交
- [ ] Sprint 15 候選：sync 衝突策略（自動 3-way merge）

## 反思

US-025 是「對稱設計」的延伸：US-024（rollback dry-run）和 US-025（sync dry-run）
都遵循同一個 dry-run pattern（列動作 + md5 對比 + 不實際執行）。

對稱性讓使用者：
1. 學習一次，兩處都用
2. 風險評估心智模型一致
3. 未來加新破壞性操作時可直接套用同 pattern

下次若加「destroy / migrate / merge」等操作，記得同步加 `--dry-run`。
