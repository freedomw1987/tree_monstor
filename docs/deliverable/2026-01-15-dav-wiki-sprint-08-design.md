# Sprint 08 設計階段交付 — dav-wiki 多模組擴充（2026-01-15）

> 對應 SOP §2.2 dav-designer 階段
> 範圍：FR-2 / FR-3 多模組擴充設計稿
> 下一步：Sprint 08 執行階段（Gate 1 TDD → Gate 4 reviewer）

## 1. 改了什麼

### Skill 附件

| 檔案 | 變更 |
| --- | --- |
| `skills/dav-wiki/SKILL.md` | 7 步流程擴充 `[2] 內容處理` 為 FR-2 多模組；加 FR-2 旗標說明 |
| `skills/dav-wiki/frontmatter-schema.md` | 新增 `images` / `videos` / `audio` 3 個物件 schema + 完整範例 |
| `skills/dav-wiki/example.md` | 加範例 6（PDF 含圖+影） + 範例 7（PPTX 含影片）|

### 設計文件

| 檔案 | 變更 |
| --- | --- |
| `docs/prd/03-knowledge-extraction.md` | 加 FR-3 章節：10 個子功能、輸出結構、降級策略、成本估算 |
| `docs/DESIGN.md` | §4.1 加 FR-3 多模組資產結構 |
| `docs/system-design.md` | §3.1 加 Sprint 08 工具（wiki-extract-media.sh / wiki-media-describe.sh）；§3.2 加多模組資料流 |

## 2. 核心設計決策

### D-08.1：資產存放路徑

```
docs/wiki/{category}/{YYYY-MM}/
├── {title}.md
└── assets/
    ├── images/{n}.png
    ├── videos/{n}.mp4
    ├── videos/{n}.transcript.md
    └── audio/{n}.mp3
```

**為什麼**：
- Obsidian `![[assets/images/n.png]]` 自動解析
- 與 wiki 文件同目錄，便於 `git mv` / 移動整個 wiki 條目
- 不汙染 `docs/wiki/` 根目錄

### D-08.2：frontmatter 欄位

文件 frontmatter 加 3 個選填欄位（不破壞既有文件）：

| 欄位 | 型別 | 何時填 |
| --- | --- | --- |
| `images` | object[] | 文件有圖片 |
| `videos` | object[] | 文件有影片 |
| `audio` | object[] | 文件有音訊 |

各物件 schema 見 `frontmatter-schema.md` §1.4-1.6。

### D-08.3：Vision + Whisper 選擇

| 用途 | 推薦 | 替代 |
| --- | --- | --- |
| 圖描述 | **GPT-4V**（最準）| Claude 3.5 Sonnet / 本地 LLaVA |
| 字幕轉錄 | **OpenAI Whisper API**（簡單）| 本地 whisper.cpp |

### D-08.4：降級策略

| 缺失工具 | 影響 | 行為 |
| --- | --- | --- |
| 無 pdfimages | FR-3.1 PDF 圖提取失敗 | 警告，只處理文字 |
| 無 ffmpeg | FR-3.6 影片章節切分失敗 | 警告，跳過影片 |
| 無 Vision API key | FR-3.4 圖描述失敗 | 警告，圖仍存檔但無 caption |
| 無 Whisper API | FR-3.7/3.8 字幕失敗 | 警告，跳過字幕 |

### D-08.5：成本估算

單份 PDF（含 10 圖 + 1 段 5 分鐘影片）：**~$0.15**

## 3. SKILL.md 行數

| 檔案 | 行數 | 限制 | 狀態 |
| --- | --- | --- | --- |
| `SKILL.md` | 143 | ≤ 150 | ✅ |
| `frontmatter-schema.md` | 293 | 無（附件）| ✅ |
| `example.md` | 610 | 無（附件）| ✅ |
| `concept-evolution.md` | 239 | 無（附件）| ✅ |

## 4. 4 Gate 預期

| Gate | 預期 | 證據 |
| --- | --- | --- |
| Gate 1 (TDD) | ✅ | 紅 → 綠 10+ 測試（PDF 提取、影片章節、字幕、圖描述）|
| Gate 2 (lint) | ✅ | markdownlint 0 + bash -n OK |
| Gate 3 (regression) | ✅ | baseline 110 → after 120+ |
| Gate 4 (reviewer) | ⏳ 待執行 | — |

## 5. 風險與監控項

| 風險 | 緩解 |
| --- | --- |
| Vision API 成本失控 | 加 `--max-images N` 旗標限制處理數量 |
| 大影片（>500MB）拖慢 | ffmpeg re-encode 到 720p |
| Whisper 中英混雜品質差 | 用 `large-v3` + 後處理 |
| PPTX 影片格式特殊 | python-pptx fallback：截圖 + 文字 |

## 6. 下一步

進入 Sprint 08 執行階段：

1. FR-2.1.1（PDF 資產提取）+ FR-2.6.1（wiki-extract-media.sh 工具）— **最大宗優先**
2. FR-2.2（圖片處理 + Vision 描述）— **驗證完整流程**
3. FR-2.3 / FR-2.4（影片 / 音訊）— **次優先**
4. FR-2.5（交叉引用擴充）— **最後**

## 7. 相關文件

- 計劃：[`docs/plan/2026-01-15-dav-wiki-sprint-08.md`](../plan/2026-01-15-dav-wiki-sprint-08.md)
- PRD：[`docs/prd/03-knowledge-extraction.md`](../prd/03-knowledge-extraction.md)
- DESIGN：[`docs/DESIGN.md`](../DESIGN.md)
- system-design：[`docs/system-design.md`](../system-design.md)
- 既有 SKILL：[`skills/dav-wiki/SKILL.md`](../../skills/dav-wiki/SKILL.md)
