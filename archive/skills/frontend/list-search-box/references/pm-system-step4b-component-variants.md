# PM-System — Step 4b: 兩個 component variant

> 來源: pm-system, 2026-06-09 (Sprint 11, WikiTab / AttachmentsTab)。由 `skills/frontend/list-search-box/SKILL.md` Step 4b 移出。

### Step 4b: 兩個 component variant (PM-System 2026-06-09 撞過)

**唔係所有 list page 嘅 header 都係 single row**。兩個常見變體:

#### Variant A: 兩欄 layout — search 喺 list sidebar header (WikiTab pattern)

`WikiTab` 嘅 layout 係 `flex gap-6`(左 list sidebar + 右 content pane)。Search 應該喺 list header **下面**, 唔喺 right content header — 因為搜尋結果影響 list 唔影響 content,layout 直覺:

```tsx
{/* Left list sidebar */}
<div className="w-72 flex flex-col">
  {/* List header — title + 新增 button */}
  <div className="flex items-center justify-between mb-3">
    <h3 className="font-semibold text-gray-900">頁面列表</h3>
    <button onClick={openCreate} className="p-1.5 text-primary-600 hover:bg-primary-50 rounded-lg">
      <Plus size={18} />
    </button>
  </div>
  {/* Search box — own row, 唔同 title 並排 */}
  <div className="relative mb-3">
    <Search size={14} className="absolute left-2.5 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
    <input
      type="text"
      value={searchX}
      onChange={(e) => setSearchX(e.target.value)}
      placeholder="搜尋頁面..."
      aria-label="搜尋 Wiki 頁面"
      className="w-full pl-8 pr-3 py-1.5 bg-white border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary-500"
    />
  </div>
  {/* List body — uses filteredX */}
</div>
```

**Why 唔同行 `justify-between`**: list header 嘅 title + create button 已經 `justify-between`, 加 search 入去會變 3 個 item,squeeze 唔落。Search 自己一行, 視覺 hierarchy 清楚。

#### Variant B: Upload bar 旁 — search 喺右側, RWD 兩行 (AttachmentsTab pattern)

`AttachmentsTab` 嘅 top section 係 upload button + helper text。Search 應該喺 upload bar 旁邊, **desktop 並排, mobile 兩行**:

```tsx
<div className="mb-6 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
  {canUpload && (
    <div className="flex items-center gap-4">
      <label htmlFor="upload" className="btn-primary flex items-center gap-2 cursor-pointer">
        <Upload size={18} />{uploading ? '上傳中...' : '上傳附件'}
      </label>
      <span className="text-sm text-gray-500">支援圖片、文檔、壓縮包等格式</span>
    </div>
  )}
  <div className="relative w-full sm:w-72 sm:ml-auto">
    <Search size={14} className="absolute left-2.5 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
    <input
      type="text"
      value={searchX}
      onChange={(e) => setSearchX(e.target.value)}
      placeholder="搜尋附件..."
      aria-label="搜尋附件"
      className="w-full pl-8 pr-3 py-1.5 bg-white border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary-500"
    />
  </div>
</div>
```

**Key differences from default (single column) page**:
- **`sm:ml-auto`** 推 search 喺 desktop 右邊, 即使 canUpload 係 false 都 keep right-aligned
- **`py-1.5` 唔係 `py-2`**: 附件 list 高度密啲, search 縮細一格 match
- **`Search size={14}` 唔係 `{16}`**: 同 attachment card 嘅 icon size (16) 對齊, visual harmony

**搜尋 `filename` 唔係 `mimeType`**: 用戶揾 file 通常記得「嗰份 spec PDF」(filename), mimeType 過濾無意思(e.g.「揀 image」係 filter button 唔係 search)。
