# Sprint 09 計劃 — dav-wiki OCR + 多模組索引/比對（2026-01-15）

> 對應 SOP §2.1 dav-planner 階段
> 接續 Sprint 08 (commit `5a17444`)，完成 Sprint 08 留下的 3 個 PENDING 子任務。

## 目標

清完 Sprint 08 留下的 3 個 PENDING：
- FR-2.2.3 OCR 補強（圖含文字）
- FR-2.5.1 `_index.json` 多模組索引
- FR-2.5.2 交叉引用多模組比對

完全 self-contained，不需 API key。

## FR-2.2.3 OCR 補強（0.25 SP）

### 範圍
- `tools/wiki-ocr.sh`：對 PNG/JPG 等圖片做 OCR
- 預設 mock 模式（無工具也不崩潰）
- 若裝了 tesseract → 用 tesseract 真實 OCR
- 輸出 JSON：`{ source, engine, language, text, confidence, extracted_at }`

### 驗收
- AC-O1: 單檔 PNG 處理
- AC-O2: 批次模式（--input-dir）
- AC-O3: 缺工具 → mock fallback
- AC-O4: 不存在輸入 → exit 2
- AC-O5: --help
- AC-O6: 沒給 --input → exit 1
- AC-O7: JSON 含必要欄位
- AC-O8: --language 旗標
- AC-O9: 批次 manifest.json
- AC-O10: 純白圖（無文字）不報錯

### 5 個測試 fixture
- 用既有 `tests/fixtures/pdf-multimodal/{red,blue}.png`
- AC-O10 用 ffmpeg 即時生 320x240 白圖

## FR-2.5.1 _index.json 多模組索引（0.5 SP）

### 範圍
- `tools/wiki-index.sh`：從 wiki frontmatter 收集多模組到 _index.json
- 索引結構：

  ```json
  {
    "version": 1,
    "type": "wiki-multimodal",
    "documents": [...],
    "images": [{ "source": "...", "docs": [...] }],
    "videos": [...],
    "audios": [...]
  }
  ```

- 兩種模式：
  - `--input <file>`：處理單檔 → `<basename>.index.json`
  - `--input-dir <dir>`：批次整個目錄 → `<dir>/_index.json`

### 驗收
- AC-MR1: _index.json 含 images/videos/audios 索引
- AC-MR2: 從 frontmatter 讀多模組
- AC-MR3: --input 單檔
- AC-MR4: --input-dir 批次
- AC-MR7: --help
- AC-MR8: 不存在輸入 → 錯誤
- AC-MR9: 不破壞源文件
- AC-MR10: 沒給 --input → 錯誤

### 設計
- Python 解析 frontmatter（避免 bash 字串處理 bug）
- 自製 YAML-lite parser（支援 nested dict for `images/videos/audios`）

## FR-2.5.2 交叉引用多模組比對（0.5 SP）

### 範圍
- 擴充 `tools/wiki-cross-ref.sh`：
  - 加 `--input <doc.md>` 模式（自動從 frontmatter 抽 tags/images/videos/audios）
  - 加 `--index <idx.json>` 旗標
  - 加 `--no-multimodal` 旗標
  - 多模組比對邏輯：共用 image/video/audio source 的 doc 算相關
- 向後相容：保留既有 `wiki-cross-ref.sh <index.json> <new-doc.json>` 用法

### 比對規則（與 Sprint 05 TD-020 一致）
1. tag 重疊 ≥ 50% 為初步候選
2. 候選中 keywords 重疊 ≥ 1 個才算真正相關
3. **新增**：多模組 source（image / video / audio）重疊也算相關
4. 最多 5 篇、最少 0 篇
5. 排序：score > tag overlap > doc_id（字母順序 tie-break）

### 驗收
- AC-MR5: 推薦含 doc-b（tag 重疊 react）
- AC-MR6: 共用 image source → 標為相關
- 既有的 wiki-cross-ref.bats 12 個測試繼續綠

## 4 Gate 規劃

| Gate | 時間 | 工作 |
| --- | --- | --- |
| **Gate 1** (TDD) | Sprint 09 第 1 段 | 先寫 wiki-ocr.bats + wiki-cross-ref-multimodal.bats，再實作 |
| **Gate 2** (lint) | 程式完成 | bash -n + markdownlint |
| **Gate 3** (regression) | 程式完成 | 189 → 207/207（+18） |
| **Gate 4** (reviewer) | commit 前 | self-review + P1 即時修 |

## 不在範圍

- Vision / Whisper 真實 API（已 mock 完成，可選進階）
- TD-019 deprecation 自動搬遷（保持 manual）
- 真實 OCR 多語言（僅 eng + chi_tra flag 可接受）
- _deprecated/_index.json（TD-019 方案 A 預留）

## 預期產物

- 3 個工具
- 2 個 bats（20 tests）
- 1 個 review
- 1 個 reflection
- 1 個 deliverable
- docs/backlog.md 更新（PENDING 3→0, DONE +3）

## 風險

| 風險 | 緩解 |
| --- | --- |
| macOS bash 3.2 字串處理 bug | frontmatter 解析用 Python |
| cross-ref 規則改動破壞既有測試 | 用既有測試當 lint，新功能用新測試 |
| 大量 markdownlint 噪音 | markdownlint config 已限制範圍 |
| _index.json 索引無效用 | 為 Sprint 10+ 鋪路，本次只完成基礎 |
