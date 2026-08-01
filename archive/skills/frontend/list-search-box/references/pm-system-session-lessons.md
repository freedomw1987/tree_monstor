# PM-System — list search box 過去 session 教訓

> 來源: pm-system 2026-06-09 / 2026-06-10 session (Sprint 11 / 13 / 14)。由 `skills/frontend/list-search-box/SKILL.md` 移出嘅 session narrative (commit hash、David feedback 對話、retro doc 路徑)。

## Step 6 相關: 呢個 session 嘅 push back 記錄

**我喺呢個 session 嘅 2 輪 push back** (2026-06-09 pm-system):
- 輪 1: David 揀 (1) 軟刪除 + (2) search box + (3) 先做 delete+list search。我 push back 問「(1) bugs delete 影響 4 個 frontend entry + 5 個 backend endpoint, 範圍好大, 只改 BugsPage?」+「(2) 搜尋係 client-side 定 server-side?」
- 輪 2: David 答「(1)A + (2)C 加埋 project 內 sub-list」, 但**跟住修訂**(獨立 cue):「menu 不用有」 → 拎走成個 standalone page

**Lesson**:
- **David 嘅 wording 要 parse 多次**:「menu 不用有」聽落簡單, 但其實 scope 包括 standalone page delete + back-link update
- **每收到一條 feedback 即 push back 一次**, 唔好悶頭做
- **每個 push back 帶 2-3 個 options + 自己推薦**, David 答得快(0-1 個 turn)
- **3 個 step 嘅 scope checklist 用 5-15 分鐘 grep + audit 確認**, 比悶頭做大幅省時間

## 過去 session 教訓

- **2026-06-09 pm-system**: David feedback「(1) 拎走 '全部缺陷' menu (2) 項目內頁需求/任務/缺陷 + 需求內頁任務/缺陷 加 search box」。Frontend-only, 6 files 改, 271 lines 拎走, 173 加返。Commit `048650e`。Retro doc `docs/retros/2026-06-09-remove-bugs-menu-add-list-search.md`。**Lesson**:**David 嘅 wording 要 parse 多次** — 拎走 menu 唔淨止拎走 nav item, scope 包括 standalone page delete + back-link update + E2E test 跟進。
- **2026-06-09 pm-system (同 session push back)**: 我做 2 輪 push back, 每次帶 2-3 個 options + 自己推薦。David 0-1 個 turn 答。**Lesson**: **每收到一條 feedback 即 push back 一次 + 帶選項**, David 答得快, 悶頭做嘅後果係做錯 scope 後再改。
- **2026-06-09 pm-system (C 延伸 — Wiki + Attachments 變體)**: David follow-up feedback 「(1) skip 失效 E2E test (2) 加埋 Wiki/Attachments 嘅 search」。Frontend-only, 6 files 改 (+200 / −38)。Commit `8c99f32`。Retro doc `docs/retros/2026-06-09-sprint-11-wiki-attachments-search-deprecate-bugs-page.md`。**Lesson**:
  - **唔係所有 list 都係 single column**。`WikiTab` (兩欄 layout: left list sidebar + right content pane) 同 `AttachmentsTab` (upload bar + grid) 嘅 search box layout 同 default 唔同 — 詳見 Step 4b Variant A / B
  - **過咗 default pattern, audit checklist 要 extend** (item #11, #12 加咗)
  - **`describe.skip` 整個 describe 跳過 > 逐個 `test.skip` 6 個**: 6 個 test skip 唔應該逐個 mark, group 一個 describe skip, Playwright 報告清楚 + audit trail 完整
  - **File header changelog 比 inline comment 更顯眼**: 將「2026-06-09 變更」放 file 頂部嘅 block comment, reader 一開 file 就知歷史 context
  - **E2E test entry 已廢 entry grep**: 拎走 route/feature 一定要 `grep -n` 拎出所有 reference 然後逐個 fix, 唔好假設「其他 file 冇 reference」

