# Sprint 05 計劃 — TD-021 cleanup 強化（2026-01-15）

> **Sprint 主題**：清掉 Sprint 04 reviewer 找到的 P2/P3 + 7 個邊緣案例 + cleanup README 重建
> **總 SP**：3-4 SP（中等偏輕）
> **前置**：Sprint 04 ✅ DONE

## 1. Sprint 目標

把 Sprint 04 留下的 16 條問題清掉，讓 dav-wiki + cleanup 工具進入「可上 production」狀態。

## 2. Sprint Backlog

| ID | 標題 | SP | 優先級 |
| --- | --- | --- | --- |
| **TD-021.1** | `wiki-cleanup.sh` README 重建（補 step [9] 實作） | 0.5 | P1 |
| **TD-021.2** | `wiki-cleanup.sh` 修 `errors` counter 不變問題 | 0.25 | P2 |
| **TD-021.3** | `wiki-cross-ref.sh` 加第三排序鍵 tie 確定性 | 0.25 | P2 |
| **TD-021.4** | `wiki-cleanup.sh` 程式碼風格（刪 TO_CLEAN=() 冗餘 / 改註解） | 0.25 | P3 |
| **TD-021.5** | `wiki-cross-ref.sh` 旗標解析風格統一 | 0.25 | P3 |
| **TD-021.6** | examples.md 範例 1 補 keywords 步驟 | 0.25 | P2 |
| **TD-021.7** | 7 個邊緣案例測試（E1-E7） | 1 | P1 |

### 邊緣案例（E1-E7）

| ID | 測試內容 | 對應工具 |
| --- | --- | --- |
| **E1** | `--purge` 真刪除模式 | wiki-cleanup |
| **E2** | 季度分類正確性（deprecated_at=2026-02 → `2026-Q1`） | wiki-cleanup |
| **E3** | 無效 `deprecated_at` fallback | wiki-cleanup |
| **E4** | 冪等性（重跑第二次應 0 個動作） | wiki-cleanup |
| **E5** | new-doc.tags=[] 應回 0 推薦 | wiki-cross-ref |
| **E6** | self-match 排除（新 doc 已在 _index.json 中） | wiki-cross-ref |
| **E7** | tie 排序 deterministic（兩個 doc 同分） | wiki-cross-ref |

## 3. 執行順序

```
[1] TD-021.7 邊緣案例測試（先寫測試 → 揭漏 → 修）  [TDD]
    ↓
[2] TD-021.1 README 重建補實作  [功能]
    ↓
[3] TD-021.2 / 021.3 / 021.4 / 021.5 / 021.6 程式碼品質  [Polish]
    ↓
[4] Sprint 05 reflection + submitter
```

## 4. 風險

| 風險 | 影響 | 緩解 |
| --- | --- | --- |
| E6 self-match 需要 _index.json 結構改變 | 可能破壞既有 schema | 加 `id` 欄位比對（已存在），不動 schema |
| E1 `--purge` 真刪除測試如果出錯會刪掉 fixture | 風險低（用 mktemp） | 加 `setup` 用 mktemp |

## 5. 成功指標

- bats 全套不退步（96 → 103+）
- TD-021 從 PENDING 移到 DONE
- `wiki-cleanup.sh` 補 step [9] README 重建
- 程式碼風格統一（兩個 CLI 用相同旗標解析模式）
- Sprint 05 reflection 報告 + deliverable 產出

## 6. 對話記錄

- 用戶決策：2026-01-15 選擇「A 跑 TD-021」
- 規劃模式：dav-planner（單輪決策，不需探索）
- 計劃產出：本檔 + 對應 backlog 更新