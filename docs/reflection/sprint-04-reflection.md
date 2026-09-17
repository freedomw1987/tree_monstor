# Sprint 04 反省 — dav-wiki 優化（2026-01-15）

> 對應 SOP §2.4 dav-reflection 階段

## 1. Sprint 概覽

| 項目 | 計畫 | 實際 |
| --- | --- | --- |
| 範圍 | US-010 + TD-019 + TD-020 | 100% 涵蓋 |
| Story Point | 5 SP | 5 SP |
| Sprint 期間 | 1 輪對話完成 | 1 輪對話完成 |
| P1 問題 | 預期 0 | reviewer 找到 3（已修） |
| P2 + P3 問題 | 預期 0 | 8 條（登記 TD-021） |

## 2. 6 維度反省

### 2.1 用戶體驗（UX）

**結論**：✅ 通過

- V01/V02 紀律嚴格遵循：每個問題編號、推薦放第一
- SKILL.md 互動流程清晰（7 步有編號）
- smoke-test 揭露的 10 條問題都有對應優化方向

**亮點**：
- 用 `/tmp/dav-wiki-smoke/` 隔離測試環境，不污染真實 `docs/wiki/` — 讓實戰測試零風險
- reviewer 報告格式一致（summary + 雙模式 + 問題清單）

**待改善**：
- smoke-test §6 表格初版過度承諾（宣稱修了 7 條但只實際修了 2 條）— reviewer 即時抓到，已修

### 2.2 RWD / 跨平台

**結論**：⚠️ 部分注意

- `wiki-cleanup.sh` 處理 macOS / Linux `date` 差異（BSD vs GNU）✅
- `wiki-cross-ref.sh` 用 Python 處理 JSON，避免 bash JSON 陷阱 ✅
- markdownlint 在 Linux/macOS 行為一致 ✅

**但**：
- 沒實機在 Linux 跑過（環境是 macOS）— TD-006（GitHub Actions CI）仍未做
- 沒實機用真實 pandoc / pdf2text 跑過 PDF — 環境沒裝

### 2.3 技術債（避坑 vs 累積）

**結論**：⚠️ 新增 1 條 P1 技術債（TD-021）

#### 本 Sprint 還的債
- ✅ TD-019 軟刪除磁碟清理機制
- ✅ TD-020 交叉引用品質改善（keywords 機制）

#### 本 Sprint 累積的債
- ⚠️ **TD-021 新增**：cleanup 工具強化 + README 重建 + 8 條 reviewer findings

#### reviewer 揭露的「未對齊問題」
- smoke-test 報告初版過度承諾（承諾修了 7 條，實際只修 2 條）— 文件誠實性問題
- 已修：表格加 ✅/⚠️/❌ 標示

### 2.4 可維護性

**結論**：✅ 通過

- 程式碼結構清晰（旗標解析 → 工具函式 → 主流程）
- 文件結構清晰（為什麼 / 策略 / 使用 / 流程 / 邊緣 / 反悔）
- 測試覆蓋率 96/96（76 → 96，+20）
- 所有交付物互相連結（handbook ↔ SKILL.md ↔ examples.md ↔ tools/）

**亮點**：
- `wiki-cleanup.sh` 用季度分組（`2025-Q3`）避免目錄爆炸
- `wiki-cross-ref.sh` 決策表（tag + keywords 雙重比對）易理解

### 2.5 測試覆蓋

**結論**：✅ 96/96 全綠，但有 7 個邊緣案例未測

| 測試套件 | 通過/總數 | 變化 |
| --- | --- | --- |
| agents-md | 10/10 | — |
| dav-wiki | 20/20 | — |
| install | 41/41 | — |
| regression-guard | 5/5 | — |
| **wiki-cleanup** | **13/13** | **+13 (新)** |
| **wiki-cross-ref** | **7/7** | **+7 (新)** |

**未覆蓋邊緣案例**（已登記 TD-021）：
- E1: `--purge` 真刪除測試
- E2: 季度分類正確性
- E3: 無效 `deprecated_at` fallback
- E4: 冪等性（重跑第二次應 0 個動作）
- E5: 0 tags new-doc 應回 0 推薦
- E6: self-match 排除
- E7: tie 排序 deterministic

### 2.6 需求對齊

**結論**：✅ 100% 對齊

| 需求 | 來源 | 達成 |
| --- | --- | --- |
| 實戰測試 dav-wiki | US-010 AC-1 ~ AC-5 | ✅ 5/5 |
| 軟刪除磁碟清理 | TD-019 方案 A（保留 + 移到 _deprecated） | ✅ |
| 交叉引用品質改善 | TD-020 keywords 機制 | ✅ |
| 4 Gate 全綠 | gates.json | ✅ |
| V01/V02 紀律 | AGENTS.md §1.5 | ✅ |

## 3. 行動項目

### 必修（下個 Sprint 開工）

- **TD-021**：cleanup 工具強化 + README 重建 + 8 條 reviewer findings
  - P2: C2 errors counter / C6 tie 排序 / D2 examples 範例 1 / D8 backlog 狀態 / T1 test 結構
  - P3: C3/C5/C7 程式碼風格
  - 邊緣案例: E1-E7

### 監控項

- 真實演的真實 PDF（環境需裝 pandoc）— 等有需要時再做
- `wiki-cross-ref.sh` 在多 doc 大檔時效能（目前用 list + sort，檔案 100+ 可能慢）

## 4. 學習

1. **smoke-test 揭露的問題比預期多**：原本估計揭露 2-3 條，實際揭露 10 條 — 證明實戰測試價值
2. **文件誠實性是常見陷阱**：smoke-test §6 表格初版過度承諾（已修）— 之後要在 sprint 結束時誠實對照實際完成情況
3. **跨平台考量要早點進設計階段**：Sprint 03 US-009 沒考慮 macOS/Linux date 差異，本 Sprint 才補（但已補）

## 5. 結論

Sprint 04 **成功** ✅

- US-010 + TD-019 + TD-020 三項全完成
- 4 Gate 通過
- 揭露 10 條 smoke-test 問題（本 Sprint 修 2 條 + 1 條部分修，其餘登記 TD-021）
- 96/96 bats tests pass（+20 新增）
- 揭露 1 條新 P1 技術債（TD-021）

下一個 Sprint 重點：TD-021（cleanup README 重建 + 8 條 reviewer findings + 7 個邊緣案例測試）。