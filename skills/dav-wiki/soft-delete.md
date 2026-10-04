# Soft Delete — dav-wiki

> 本檔定義 dav-wiki 的**軟刪除**（不真刪除）規則：frontmatter 標記、90 天清理、可追溯性。
> 配合 [SKILL.md](SKILL.md) 使用（SKILL.md 主檔只留導航與指針）。

---

## 1. 核心規則：不真刪除檔案

用 frontmatter 標記：

- **文件**：`deprecated: true` 或 `superseded_by: "<path>"`
- **概念**：`deprecated: true` + `status: deprecated` + `superseded_by: "<slug>"` + 從 `_concepts.json` 移除

## 2. 為什麼

- **可追溯**：讀者能從舊文件追到新文件，不會遇到死連結
- **避免 index 傾斜**：擋掉 read-modify-write，一旦移除就無法回推來源

## 3. 磁碟清理

deprecated 超過 90 天的檔案可用同套本 skill 的 `scripts/wiki-cleanup.sh` 移到
`docs/wiki/_deprecated/{YYYY-Qn}/`，從主索引移除但保留可追溯。

| 參數 | 作用 |
|------|------|
| `--target <docs>` | 目標 `docs/` 目錄 |
| `--older-than 90` | 天數門檻（依 frontmatter `deprecated_at`；無此欄位則用檔案 mtime）|
| `--dry-run` | 只列出將搬移的檔案，不動磁碟 |
| `--yes` / `-y` | 跳過互動確認 |
| `--purge` | 真刪除（危險，預設禁用）|

## 4. 邊界

- 清理**只搬移**，不刪除；`_deprecated/` 不進 `_index.json`
- 概念被 deprecate 時，必須同步從 `_concepts.json` 移除，否則會出現「索引有、檔案已封存」的不一致
