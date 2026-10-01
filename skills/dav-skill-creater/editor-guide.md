# Editor Guide — SKILL.md 編寫準則

> 本檔為 dav-skill-creater 的「SKILL.md 編寫準則」章節（v2.1-v2.2 累積）抽出。
> 引用：`SKILL.md` 的「SKILL.md 編寫準則」章節
>
> 從 SKILL.md v2.5 起，本檔獨立。理由：原本 60 行的編寫準則屬於「寫 skill 時才需要看」，不在「用 skill」的主流程上。

## 5 段推薦結構（任務導航）

| 段落 | 目的 | 寫法 |
|------|------|------|
| **TL;DR** | 第一眼看到 | 5 個重點條列：做什麼 / 何時觸發 / SOP 路徑 / 關鍵紀律 / 必產出物 |
| **觸發時機** | 何時該用 / 不該用 | 表格：情境 + ✅/❌ |
| **流程** | 怎麼做 | N 步，每步 動作/為什麼/產出/證據 |
| **規則** | 邊界 / 例外 / 限制 | 表格：規則 / 例外 / 限制 |
| **變動歷史** | 版本演進 | 表格：版本 / 日期 / 變動 / 為什麼 |

## 可讀性原則

- **TL;DR 必須第一**：讓 LLM 第一秒就抓到核心
- **emoji 限縮**：只在「觸發時機」表用 ✅🟡❌，不在流程 / 規則濫用
- **表格只放結論**：長說明放流程步驟內、不放表格
- **流程明步**：每步必含 動作 / 為什麼 / 產出 / 證據 四元素
- **規則表格**：規則 / 例外 / 限制 三欄

## 反模式（避免）

| ❌ 反模式 | ✅ 改為 |
|----------|--------|
| ASCII box-drawing 流程圖 | 文字描述 + 表格 |
| 一大段散文 | 5 條列 |
| 不明步驟（只有標題） | 每步 4 元素（動作 / 為什麼 / 產出 / 證據）|
| 沒 frontmatter | 必含 `name` + `description` |
| `description` 太長（> 200 字）| 一句話聚焦 + 何時用 + 何時不用 |
| 跨 dir 連結（相對路徑指 docs/ 或 Obsidian wiki link 指其他 dir）| 純文字「見 monorepo 對應的 PRD 文件」|

## 純文字引用規範（v2.1 + v2.2）

**v2.1 — markdown 跨 dir 連結零容忍**：
- **不放 markdown 跨 dir 連結**：禁止任何用相對路徑指向 SKILL.md 所在 dir 之外的 markdown 連結
- **不放 Obsidian 跨 dir 連結**：禁止用 Obsidian wiki link 指向其他 dir 的檔案
- **skill 子檔可用 markdown**：因為子檔和 SKILL.md 在同 dir，可正常使用相對連結

**v2.2 — 跨目錄讀檔引用零容忍**（更嚴格）：
- **不放跨目錄讀檔引用**：禁止任何「讀 + path」「見 + path」「詳見 + path」這類指向 skill 自己目錄以外檔案的引用（自然語言描述）
- **不放跨 skill 引用**：禁止任何指向其他 skill 頂層 SKILL.md 的引用
- **不放指向 docs/ 內具體檔案**：禁止任何指名 docs/ 子目錄內具體檔案的引用
- **替代寫法**：抽象詞「見 monorepo 對應的 PRD 文件」、「見 SOP 全域變動歷史」、「見同套 other-skill 子檔」（由 monorepo 約定或同套安裝關係取得）

**為什麼更嚴**：
- skill 搬動到任何位置仍可運作，不依賴 monorepo 內的 docs/ 或其他 skill 結構
- 產出目的地（寫到 docs/）仍保留 — docs/ 是 project 約定、屬於「寫到哪」語意
- 讀檔引用（從 docs/ 讀）破壞獨立性、寫到 docs/ 不破壞獨立性（LLM 仍可決定寫入路徑）

**Obsidian `[[xxx]]` 教學標記（v2.2）**：
- dav-wiki 等 skill 提到 Obsidian 雙向連結教學時，必加「`<教學範例>`」標記
- 例如：「產出：教學範例：markdown 內 `[[xxx]]` 標記 — 實際 wiki 產出由 dav-wiki 處理」
- 避免讀者誤判 `[[xxx]]` 為跨檔連結

**例外**（仍可用 markdown 連結 / 路徑引用）：
- skill 自己的 `CHANGELOG.md` 內的版本歷史連結
- `AGENTS.md`（全域索引、非 skill）內的 handbook / gates.json 連結
- skill 寫到 docs/（project 約定的寫入目的地）

## 變動歷史外移規範（v2.4 新增）

**規則**：所有 skill 的變動歷史超過 3 條時，必外移至 `<skill>/CHANGELOG.md`，主檔 `SKILL.md` 只保留：
1. 一行 Markdown 連結：`完整變動歷史見 [`CHANGELOG.md`](./CHANGELOG.md)`
2. 表格（保留表頭 + 最近 3 條）

**為什麼要外移**（LLM 注意力優化）：
- 變動歷史是 skill 演進的「歷史軌跡」，但對當前執行任務無直接幫助
- 歷史過長（如 regression-guard 23 行）會稀釋主檔的「流程 / 規則」注意力
- 完整歷史保留在 CHANGELOG.md，需要時可查；不需要時不佔主檔 token

**外移 vs 不外移決策**：

| 變動歷史條數 | 處理 |
|-------------|------|
| ≤ 3 條 | 留在主檔即可 |
| > 3 條 | 一律外移至 `CHANGELOG.md` |

**CHANGELOG.md 格式規範**：
- 檔頭：`# <Skill 名稱> — CHANGELOG`
- 引用塊：「本檔為 <skill> 的完整變動歷史。引用：`SKILL.md` 變動歷史章節」
- 表格：與主檔一致（4 欄：版本 / 日期 / 變動 / 為什麼）
- 最新版本排在最上面（與主檔慣例一致）

**為什麼不是 5 條而是 3 條**：
- 3 條足以讓 LLM 抓到「最近 3 次演進方向」
- 超過 3 條 LLM 開始分心（注意力門檻約 3-5 個項目）
- 完整歷史隨時可從 CHANGELOG.md 取得，不會真的「看不到」
