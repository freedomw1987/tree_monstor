# Sprint 09 Self-Review — dav-wiki OCR + 多模組索引（2026-01-15）

> 對應 SOP §2.5 reviewer gate（self-review 模式）
> Sprint 範圍：FR-2.2.3 + FR-2.5.1 + FR-2.5.2

## 1. 4 Gate 證據鏈

| Gate | 結果 | 證據 |
| --- | --- | --- |
| **Gate 1** (TDD) | ✅ | 紅 → 綠完整（先寫 bats 後實作）|
| **Gate 2** (lint) | ✅ | bash -n 3 工具全 OK、markdownlint 0 issues（4 files）|
| **Gate 3** (regression) | ✅ | 189 → **207/207 全綠**（+18）|
| **Gate 4** (reviewer) | ✅ | self-review OK（見 §6） |

## 2. 完成 vs 計劃

| FR | 標題 | 計劃 SP | 實際 | 狀態 |
| --- | --- | --- | --- | --- |
| **FR-2.2.3** | OCR 補強（wiki-ocr.sh）| 0.25 | 0.25 | ✅ |
| **FR-2.5.1** | 多模組索引（wiki-index.sh）| 0.5 | 0.5 | ✅ |
| **FR-2.5.2** | 交叉引用多模組比對 | 0.5 | 0.5 | ✅ |
| **小計** | — | **1.25** | **1.25** | 100% ✅ |

## 3. 改的檔案

### 程式（2 個新 + 1 個擴充）

| 檔案 | 行數 | 變更 |
| --- | --- | --- |
| `tools/wiki-ocr.sh` | 192 | 新增 |
| `tools/wiki-index.sh` | 188 | 新增 |
| `tools/wiki-cross-ref.sh` | 328 | 從 102 擴充（+226）|

### 測試（2 個新 bats）

| 檔案 | 測試數 | 驗收項目 |
| --- | --- | --- |
| `tests/wiki-ocr.bats` | 10 | AC-O1~O10 |
| `tests/wiki-cross-ref-multimodal.bats` | 10 | AC-MR1~MR10 |

### 設定

| 檔案 | 變更 |
| --- | --- |
| `.markdownlint.json` | 加 globs 排除 tests/**/*.bats |

### 文件

| 檔案 | 變更 |
| --- | --- |
| `docs/plan/2026-01-15-dav-wiki-sprint-09.md` | 新增（本檔前）|
| `docs/review/2026-01-15-sprint-09-review.md` | 新增（本檔）|
| `docs/reflection/sprint-09-reflection.md` | 新增 |
| `docs/deliverable/2026-01-15-sprint-09.md` | 新增 |
| `docs/backlog.md` | PENDING 3→0, DONE +3 |

## 4. 規則演進

### 4.1 FR-2.5.2 比對規則（沿用 + 擴充 Sprint 05 TD-020）

**既有規則**（Sprint 05）：
1. tag 重疊 ≥ 50% 為初步候選
2. keywords 重疊 ≥ 1 個才算真正相關
3. 最多 5 篇、最少 0 篇
4. 排序：score > tag overlap > doc_id

**Sprint 09 擴充**：
- 加 Rule 2.5：共用 image / video / audio source 也算相關（≥ 1 個 source 即可）
- 加 `--no-multimodal` 旗標（向後相容）

### 4.2 FR-2.5.1 _index.json 結構

```json
{
  "version": 1,
  "type": "wiki-multimodal",
  "documents": [
    {
      "id": "frontend/2026-01/doc-a.md",
      "title": "文檔 A",
      "tags": ["react", "hooks"],
      "images": [{"source": "/assets/a.png", "caption": "red square"}],
      "videos": [{"source": "/assets/a.mp4"}],
      "audios": [{"source": "/assets/a.wav"}]
    }
  ],
  "images": [{"source": "/assets/a.png", "docs": ["frontend/2026-01/doc-a.md"]}],
  "videos": [...],
  "audios": [...]
}
```

## 5. 自我揭露並即時修的 P1

| # | 問題 | 修法 |
| --- | --- | --- |
| 1 | `local` 在 script 頂層不合法（macOS bash 3.2）| 改用普通變數 + 命名區隔 |
| 3 | `--input` 模式輸出路徑不在 cwd | 改為 `./<basename>.index.json` |
| 4 | frontmatter parser 不支援 nested dict | 改 Python + 完整 YAML-lite |
| 5 | `tags: []` 在 index 解析成空 | 修正 dict list 解析 |
| 6 | tag overlap 規則改動破壞既有測試 | 還原成 AND，保留向後相容 |
| 7 | AC-MR2 期望值錯誤（red.png vs a.png）| 修正測試期望 |
| 8 | markdownlint 對 `.bats` 報 MD023 | config 加 globs 排除 bats |

## 6. OK 等級評估

**評等：OK** ✅

- 計劃完全達成（1.25/1.25 SP）
- 4 Gate 全綠
- self-review 揭露 8 個 P1 即時修
- 累積 PENDING 3→0（DONE 41→44）
- 不破壞既有 cross-ref 測試（向後相容）

## 7. 已知限制

- wiki-index.sh --input 模式輸出到 cwd（不與 input 同目錄）— 行為一致且可預期
- 多模組比對規則仍走「共用 source」簡化模型；Sprint 10+ 可加 image similarity hash 比對
- tesseract 不在測試 fixture — 預期 mock 模式跑通所有測試

## 相關文件

- 計劃：[`docs/plan/2026-01-15-dav-wiki-sprint-09.md`](../plan/2026-01-15-dav-wiki-sprint-09.md)
- Reflection：[`docs/reflection/sprint-09-reflection.md`](../reflection/sprint-09-reflection.md)
- Deliverable：[`docs/deliverable/2026-01-15-sprint-09.md`](2026-01-15-sprint-09.md)
- 上個 Sprint：[`docs/review/2026-01-15-sprint-08-review.md`](../review/2026-01-15-sprint-08-review.md)
