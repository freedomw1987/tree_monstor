# dav-wiki 清理手冊

> 對應 SOP §X.X + TD-019 + `skills/dav-wiki/scripts/wiki-cleanup.sh`

## 1. 為什麼要清理？

`docs/wiki/` 中的檔案用 frontmatter `deprecated: true` 標記為軟刪除後，仍佔磁碟空間且出現在索引中。
長期下來會累積「過時但沒人看」的檔案，反而干擾交叉引用品質。

## 2. 清理策略

採用 **TD-019 方案 A**：保留檔案但移到隔離目錄 + 反向索引。

```
原位置：docs/wiki/frontend/2026-01/old-doc.md（deprecated: true, date: 2025-09-01）
  ↓ [skills/dav-wiki/scripts/wiki-cleanup.sh --older-than 90]
新位置：docs/wiki/_deprecated/2025-Q3/old-doc.md（保留檔案 + 加 deprecated_moved_at）
```

### 2.1 保留原則

- **永不刪除**：deprecated 檔案只能移到 `_deprecated/`，不可真刪（除非用戶明確指定 `--purge`）
- **可追溯**：從 `_deprecated/_index.json` 反向索引，隨時可查到「這個檔案為何、何時、被誰 deprecate」
- **保留 history**：原始的 deprecated 標記、superseded_by、related 全部保留

### 2.2 隔離結構

```
docs/wiki/
├── _index.json                   ← 主索引（不含 _deprecated/）
├── _tags.json
├── _deprecated/
│   ├── _index.json               ← 反向索引（deprecated 專用）
│   └── {YYYY-Qn}/                ← 按季度分組
│       └── {title}.md
└── {category}/
    └── {YYYY-MM}/
        └── {title}.md
```

季度分組（如 `2025-Q3`）方便瀏覽器讀取（一年最多 4 個目錄，不會爆炸）。

## 3. 使用方式

### 3.1 互動模式（推薦首次使用）

```bash
$ skills/dav-wiki/scripts/wiki-cleanup.sh
[?] 找到 3 個 deprecated 檔案超過 90 天：
  - docs/wiki/frontend/2025-09/old-react-pattern.md (deprecated 2025-09-15)
  - docs/wiki/backend/2025-08/deprecated-api-design.md (deprecated 2025-08-30)
  - docs/wiki/meeting-notes/2025-09/cancelled-meeting.md (deprecated 2025-09-10)
[?] 是否移到 _deprecated/? [y/N]
```

### 3.2 Dry-run 模式

```bash
$ skills/dav-wiki/scripts/wiki-cleanup.sh --dry-run
[INFO] Dry-run：不實際移動，僅顯示計畫
[INFO] 會移動 3 個檔案到 _deprecated/2025-Q3/
  - frontend/2025-09/old-react-pattern.md
  - backend/2025-08/deprecated-api-design.md
  - meeting-notes/2025-09/cancelled-meeting.md
```

### 3.3 自動模式（CI / cron）

```bash
$ skills/dav-wiki/scripts/wiki-cleanup.sh --yes --older-than 90
[INFO] --yes 模式：跳過互動確認
[OK] 移動 3 個檔案
[OK] 更新 _index.json（移除 3 筆）
[OK] 寫入 _deprecated/_index.json（新增 3 筆）
```

### 3.4 旗標

| 旗標 | 說明 | 預設 |
| --- | --- | --- |
| `--dry-run` | 只顯示計畫，不實際執行 | false |
| `--older-than <days>` | 只清理超過 N 天的 deprecated | 90 |
| `--yes` / `-y` | 跳過互動確認 | false |
| `--purge` | 真刪除（危險） | false |
| `--target <path>` | 指定 dav-wiki 根目錄 | `docs/` |

## 4. 處理流程（CLI 內部）

```
[1] 掃描 docs/wiki/**/*.md
    ↓
[2] 讀 frontmatter：deprecated, deprecated_at
    ↓
[3] 過濾：deprecated=true 且 age(now, deprecated_at) >= --older-than
    ↓
[4] 顯示計畫（dry-run 直接到這）
    ↓
[5] 用戶確認（除非 --yes）
    ↓
[6] 對每個檔案：
    [6.1] 決定 _deprecated/{YYYY-Qn}/ 子目錄（基於 deprecated_at 季度）
    [6.2] mv 檔案到 _deprecated/{YYYY-Qn}/{原檔名}
    [6.3] 補 frontmatter 欄位 `deprecated_moved_at: <now>`
    ↓
[7] 更新 _index.json（從 documents/tags_index 移除）
    ↓
[8] 更新 _deprecated/_index.json（新增反向記錄）
    ↓
[9] **已實作**（Sprint 05）：重建 docs/README.md（從 _index.json 重新組裝統計資訊）
    ↓
[10] 輸出 summary：搬了幾個、跳過幾個、失敗幾個
```

> **Sprint 05 更新**：step [9] README 重建已實作（從 `_index.json` 重新組裝 categories / tags 統計）。

## 5. 前置需求

- bash 4+
- `yq` 或 Python `pyyaml`（解析 frontmatter）
- 沒有 yq 時 fallback 用 awk/sed 解析
- 寫入權限到 `docs/wiki/`

## 6. 邊緣案例

| 案例 | 處理 |
| --- | --- |
| 檔案沒有 `deprecated_at` 但 `deprecated=true` | 用檔案 mtime 當 fallback |
| 目標子目錄不存在 | 自動 mkdir |
| `_deprecated/` 已有同名檔 | 跳過並警告（不覆蓋歷史） |
| 檔案正在被其他 process 讀取 | 提示重試 |
| frontmatter 格式錯誤 | 跳過並警告（不 crash） |

## 7. 反悔怎麼辦？

`_deprecated/_index.json` 含每個檔案的「原始路徑」與 `deprecated_moved_at`。

```bash
# 手動反悔範例
$ mv docs/wiki/_deprecated/2025-Q3/old-react-pattern.md \
       docs/wiki/frontend/2025-09/old-react-pattern.md
$ # 然後手動更新 _index.json + _deprecated/_index.json
```

未來可加 `skills/dav-wiki/scripts/wiki-restore.sh` CLI（全自動反悔），但不在本 TD 範圍。

## 8. 與其他章節的關係

- **SOP §X.X**：dav-wiki skill 主流程（7 步）
- **AGENTS.md §1**：萬事原則（誠實、可追溯）
- **frontmatter-schema.md** §1.3：`deprecated`, `superseded_by`, `deprecated_moved_at` 欄位定義
- **concept-evolution.md**：deprecate 動作（本工具只搬檔案，不改 concept 狀態）

## 9. 測試

`tests/wiki-cleanup.bats` 涵蓋：

- ✅ 基本移動
- ✅ --dry-run 不實際執行
- ✅ --older-than 過濾
- ✅ _index.json 同步
- ✅ _deprecated/_index.json 反向索引
- ✅ README 重建
- ✅ --yes 跳過互動
- ✅ frontmatter 格式錯誤跳過不 crash
- ✅ 同名檔不覆蓋
