# Sprint 08 計劃 — dav-wiki 多模組擴充（2026-01-15）

> **Sprint 主題**：單一檔案內含「文字 + 圖片 + 影片」時，dav-wiki 完整處理所有模組
> **總 SP**：13 SP（FR-2.x 系列）
> **前置**：Sprint 07 ✅ DONE（技術債清零）

## 1. Sprint 目標

擴充 dav-wiki 的 [2] 內容處理步驟，從「純文字抽取」升級為「多模組完整理解」：

| 模組 | 輸入 | 處理 | 輸出 |
| --- | --- | --- | --- |
| **文字** | PDF/DOCX/PPTX 內文 | 既有（pandoc/pdf2text）| Markdown 內文 |
| **圖片** | 文件內嵌圖 | 提取 → 存檔 → Vision 模型描述 → OCR 補強 | `assets/images/xxx.png` + AI 描述章節 |
| **影片** | 文件內嵌影片 | 提取 → 抽 frame → Whisper 字幕 → 場景偵測 → 章節切分 | `assets/videos/xxx.mp4` + 字幕.md + 章節摘要 |
| **音訊** | 文件內嵌音訊 | 提取 → Whisper 轉錄 → 段落切分 | `assets/audio/xxx.mp3` + 字幕.md |
| **表格** | 文件內嵌表格 | 既有（pandoc 處理）+ Markdown 表格化 | Markdown 表格 |

## 2. Sprint Backlog

### FR-2.1：文件類型偵測與資產提取

| ID | 標題 | SP | 優先級 |
| --- | --- | --- | --- |
| **FR-2.1.1** | PDF 資產提取（圖片 / 影片 / 音訊 / 表格） | 2 | P1 |
| **FR-2.1.2** | DOCX 資產提取（圖片 / 影片 / 音訊 / 表格） | 1 | P1 |
| **FR-2.1.3** | PPTX 資產提取（圖片 / 影片 / 音訊 / 表格 / slide 分割） | 1.5 | P1 |

### FR-2.2：圖片處理

| ID | 標題 | SP | 優先級 |
| --- | --- | --- | --- |
| **FR-2.2.1** | 圖片存檔至 `docs/wiki/{category}/{YYYY-MM}/assets/images/` | 0.25 | P1 |
| **FR-2.2.2** | Vision 模型生圖片描述（1-3 句）| 1 | P1 |
| **FR-2.2.3** | OCR 補強（圖含文字）| 0.25 | P2 |
| **FR-2.2.4** | 圖片加入 frontmatter `images` 陣列 + 文中插入 `![[xxx.png]]` | 0.5 | P1 |

### FR-2.3：影片處理

| ID | 標題 | SP | 優先級 |
| --- | --- | --- | --- |
| **FR-2.3.1** | 影片存檔至 `docs/wiki/{category}/{YYYY-MM}/assets/videos/` | 0.25 | P1 |
| **FR-2.3.2** | Whisper 轉字幕（多語言）| 1 | P1 |
| **FR-2.3.3** | ffmpeg 抽關鍵 frame（場景偵測）| 0.5 | P1 |
| **FR-2.3.4** | 章節切分 + AI 摘要（每章 1-3 句）| 1 | P1 |
| **FR-2.3.5** | 影片資訊加入 frontmatter `videos` 陣列 + 文中插入 `<video>` / 章節摘要 | 0.5 | P1 |

### FR-2.4：音訊處理

| ID | 標題 | SP | 優先級 |
| --- | --- | --- | --- |
| **FR-2.4.1** | 音訊存檔至 `docs/wiki/{category}/{YYYY-MM}/assets/audio/` | 0.25 | P1 |
| **FR-2.4.2** | Whisper 轉錄 + 段落切分 | 0.5 | P1 |

### FR-2.5：交叉引用擴充

| ID | 標題 | SP | 優先級 |
| --- | --- | --- | --- |
| **FR-2.5.1** | `_index.json` 加 `images` / `videos` / `audio` 索引 | 0.5 | P2 |
| **FR-2.5.2** | 交叉引用演算法支援「同文件 / 同主題」多模組比對 | 0.5 | P2 |

### FR-2.6：工具與測試

| ID | 標題 | SP | 優先級 |
| --- | --- | --- | --- |
| **FR-2.6.1** | `tools/wiki-extract-media.sh`：PDF/DOCX/PPTX 媒體提取腳本 | 1 | P1 |
| **FR-2.6.2** | `tools/wiki-media-describe.sh`：Vision + Whisper 調用腳本 | 0.5 | P1 |
| **FR-2.6.3** | 邊緣案例測試（PPT 內含影片 / PDF 含中文字幕 / 純圖片無文字）| 1 | P2 |

## 3. 架構決策

### 3.1 資產存放結構

```
docs/wiki/{category}/{YYYY-MM}/
├── {title}.md              # 主文件
└── assets/
    ├── images/{n}.png
    ├── videos/{n}.mp4
    └── audio/{n}.mp3
```

**為什麼用相對路徑**：
- Obsidian `![[images/1.png]]` 自動解析
- Markdown 內 `![](../assets/images/1.png)` 在 GitHub 也能看

### 3.2 Vision 模型選擇

| 選項 | 優點 | 缺點 |
| --- | --- | --- |
| **OpenAI GPT-4V** | 最強、API 簡單 | 貴（$0.01/image）|
| **Anthropic Claude 3.5 Sonnet** | 性價比好、可批次 | API 金鑰 |
| **本地 LLaVA** | 免費、私密 | 效果差、要 GPU |
| **推薦 GPT-4V**（**首選**）| 圖含程式碼也懂 | 成本 |

### 3.3 Whisper 模型

| 選項 | 優點 | 缺點 |
| --- | --- | --- |
| **OpenAI Whisper API** | 簡單、支援多語 | 付費 |
| **本地 whisper.cpp** | 免費 | 要模型檔（~1.5GB）|
| **推薦 OpenAI API**（**首選**）| 不用裝模型 | — |

### 3.4 工具鏈

| 工具 | 用途 | 安裝 |
| --- | --- | --- |
| `pandoc` | DOCX/PPTX → Markdown | `brew install pandoc` |
| `pdfimages` | PDF 圖片提取 | `brew install poppler` |
| `ffmpeg` | 影片抽 frame + 音訊提取 | `brew install ffmpeg` |
| `pdf2text` | PDF 文字提取 | `brew install poppler` |
| `python-pptx` | PPTX 解析 | `pip install python-pptx` |

## 4. SKILL.md 7 步擴充

```
[1] 來源識別（既有）
[2] 內容處理（擴充）→ [2a] 文字處理 / [2b] 媒體提取 / [2c] 媒體理解 / [2d] 組合 Markdown
[3] Category 確認（既有）
[4] Tag + Keywords（既有）
[5] 交叉引用（既有 + 多模組索引）
[6] 概念提取（既有）
[7] 寫入 + README（擴充 → 多模組 assets/）
```

## 5. 預期風險

| 風險 | 影響 | 緩解 |
| --- | --- | --- |
| 大檔（>500MB 影片）拖慢處理 | 體驗差 | 用 ffmpeg 先 re-encode 到中等品質 |
| Vision API 成本過高 | $ | 加 `--no-vision` 旗標跳過 |
| Whisper 字幕品質差（中英混雜） | 知識庫品質 | 用 `whisper large-v3` + 後處理 |
| PPTX 內含影片但未編碼 | 提取失敗 | fallback：只取文字 + 截圖 slide |

## 6. 成功指標

- Sprint 結束時：
  - FR-2.1.1 ~ FR-2.6.3 全完成（或合理切割部分）
  - bats tests 增加 ≥ 10 個邊緣案例
  - SKILL.md 仍 ≤ 150 行（必要時拆附件）
  - 新工具 `wiki-extract-media.sh` + `wiki-media-describe.sh` 實作完成
  - 4 Gate 全綠

## 7. 用戶決策紀錄

- 2026-01-15：用戶選擇 **C 完整理解**（Vision + Whisper + 章節切分 + 概念提取）
- 推薦用 GPT-4V（圖）+ OpenAI Whisper API（音）
- 規劃模式：dav-planner（單輪決策 → 拆 17 子任務）

---

> **下一步**：Sprint 08 開工。先做 FR-2.1.1 PDF 資產提取（最大宗）+ FR-2.2 圖片處理（驗證完整流程），再做其他類型。
