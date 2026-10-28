# Frontmatter Schema — dav-wiki

> 本檔定義 dav-wiki 產出檔案的 frontmatter 欄位。
> 分兩種：**文件 frontmatter**（`docs/wiki/`）與 **概念 frontmatter**（`docs/concepts/`）。
> 完整可複製範例 → 同套本 skill 樣例檔（`./examples/frontmatter-full-examples.md`）。

---

## 1. 文件 frontmatter（docs/wiki/{title}.md）

### 1.1 完整範例

- 完整可複製範例（含選填的多模組欄位）→ 同套本 skill 樣例檔（`./examples/frontmatter-full-examples.md`）§1
- 純文字 / URL 來源**唔使**填 `images` / `videos` / `audio`；刪走嗰三段即可（其餘欄位不變）。

### 1.2 欄位規範

- **`title`** — 型別：string；必填：✅；約束：50 字內、首字大寫
- **`source.type`** — 型別：enum；必填：✅；約束：`pdf` `docx` `pptx` `txt` `md` `url` `ocr` `subtitle`
- **`source.original`** — 型別：string；必填：✅；約束：原始檔名 / URL
- **`source.url`** — 型別：string \| null；必填：❌；約束：URL 來源時填
- **`extracted_at`** — 型別：date；必填：✅；約束：ISO 8601（YYYY-MM-DD）
- **`category`** — 型別：string；必填：✅；約束：kebab-case 小寫
- **`tags`** — 型別：string[]；必填：✅；約束：3-8 個、kebab-case 小寫
- **`summary`** — 型別：string；必填：✅；約束：1-3 句
- **`keywords`** — 型別：string[]；必填：✅；約束：3-5 個關鍵詞（提升交叉引用品質）
- **`related`** — 型別：string[]；必填：✅；約束：`[[xxx]]` 雙鏈接，可空
- **`concepts`** — 型別：string[]；必填：✅；約束：`[[xxx]]` 雙鏈接，可空
- **`images`** — 型別：object[]；必填：❌；約束：見 1.3
- **`videos`** — 型別：object[]；必填：❌；約束：見 1.4
- **`audio`** — 型別：object[]；必填：❌；約束：見 1.5
- **`deprecated`** — 型別：boolean；必填：✅；約束：`true` / `false`
- **`superseded_by`** — 型別：string \| null；必填：❌；約束：deprecated 時填

### 1.3 images 物件 schema（FR-2.2）

- **`path`** — 型別：string；必填：✅；約束：相對 `assets/images/` 下的路徑
- **`caption`** — 型別：string；必填：✅；約束：Vision 模型生成的 1-3 句描述
- **`ocr_text`** — 型別：string；必填：❌；約束：OCR 提取的文字（圖含文字才填）
- **`alt_text`** — 型別：string；必填：❌；約束：無障礙用 alt 文字

### 1.4 videos 物件 schema（FR-2.3）

- **`path`** — 型別：string；必填：✅；約束：相對 `assets/videos/` 下的路徑
- **`duration`** — 型別：number；必填：✅；約束：影片秒數
- **`transcript_path`** — 型別：string；必填：❌；約束：Whisper 字幕檔路徑（`*.transcript.md`）
- **`chapters`** — 型別：object[]；必填：❌；約束：章節切分；**chapters 條目**含 `title`（✅）、`start`（✅ 秒）、`end`（✅ 秒）、`summary`（✅ 1-3 句）
- **`thumbnail`** — 型別：string；必填：❌；約束：封面圖路徑

### 1.5 audio 物件 schema（FR-2.4）

- **`path`** — 型別：string；必填：✅；約束：相對 `assets/audio/` 下的路徑
- **`duration`** — 型別：number；必填：✅；約束：音訊秒數
- **`transcript_path`** — 型別：string；必填：❌；約束：Whisper 字幕檔路徑

---

## 2. 概念 frontmatter（docs/concepts/{slug}.md）

### 2.1 完整範例

- 完整可複製範例 → 同套本 skill 樣例檔（`./examples/frontmatter-full-examples.md`）§2

### 2.2 欄位規範

- **`slug`** — 型別：string；必填：✅；約束：kebab-case、唯一
- **`title`** — 型別：string；必填：✅；約束：30 字內
- **`definition`** — 型別：string；必填：✅；約束：1-2 句話定義
- **`status`** — 型別：enum；必填：✅；約束：`active` `draft` `deprecated`
- **`deprecated`** — 型別：boolean；必填：✅；約束：`true` / `false`
- **`superseded_by`** — 型別：string \| null；必填：❌；約束：slug 或 null
- **`parents`** — 型別：string[]；必填：✅；約束：`[[xxx]]`，可空
- **`children`** — 型別：string[]；必填：✅；約束：`[[xxx]]`，可空
- **`related_docs`** — 型別：string[]；必填：✅；約束：`[[xxx]]`，可空
- **`history`** — 型別：object[]；必填：✅；約束：可空，見 2.3

### 2.3 history 條目規範

每條 history 係一個物件：`date`（✅ ISO 8601）、`action`（✅ `created` / `derived` / `revised` / `merged` / `deprecated`）、`note`（❌
一句話說明）。

---

## 3. 驗證規則

### 3.1 寫入前檢查

- ✅ 所有必填欄位都有值
- ✅ 日期是有效 ISO 8601
- ✅ category / tag / slug 都符合 kebab-case
- ✅ `[[xxx]]` 內的 slug 在 `_index.json` 或 `_concepts.json` 存在（不存在會 warn，但不擋寫入）

### 3.2 軟刪除檢查

- 標 `deprecated: true` 的檔案 → 從 `_index.json` / `_concepts.json` 移除（檔案保留）
- 標 `superseded_by` 的檔案 → 同上，但保留反向連結以便追溯
- 自動從 `docs/README.md` 隱藏

### 3.3 命名衝突

若 slug 已存在：自動加 `-2`、`-3` 後綴，並在對話中提示用戶。

---

## 4. 參考

- [Obsidian Internal Links](https://help.obsidian.md/Linking/Internal+links) — `[[xxx]]` 語法
- [JSON Schema Draft 07](https://json-schema.org/draft-07/json-schema-release-notes.html) — 索引格式
- 主流程 → 同套本 skill 主檔（`./SKILL.md`）；演進規則 → 同套本 skill 子檔（`./concept-evolution.md`）
