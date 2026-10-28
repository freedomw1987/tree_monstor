# Module 級交付 — 差異 ＋ 第 9 段模板

> 本檔為 `dav-reviewer` skill 嘅「Module 級交付差異」子檔（2026-10-28 由 `deliver.md` 搬出）。
> **點解喺模板區**：Module 級交付係「進階場景」（差異多：Backlog ID 格式／探針綁定／§9 總結）→ 唔係每次交收都要讀。
> 觸發條件同規則 → 見同 skill 子檔 `deliver.md` §3 規則表。

## 適用情境 ＋ 交付單位

- **交付單位 4 級**：單個 US（1 個 AC 套件）｜單個 Module（Module 內所有 US 集合）｜多個 Module（＋ cross-module integration）｜
  整個 repo / sprint 結束（整個交付歷史）—— 後三級用 Step 3.5 微總結
- **觸發情境**：整個 Module 完成（內所有 US 驗收完 ＋ Module 級整合測試通過）／Module 級里程碑（未全部交付但達可發佈狀態）／Module 重構完成（技術債清理 ＋ 探針重寫）

## 四個差異

- **1. Backlog ID 格式** — US 級：`US-101`／`DE-201`／`TECH-03`／`SPIKE-04`；Module 級：`<MODULE_CODE>-<US_ID>`（如 `M01-US-101`）；
  多 US 同 Module 交付：在 §2.1-2.3 用 `M01 多 US 集合` 代表，避免重複列每個 US 的改動
- **2. Module 邊界即測試邊界** — Module 內所有探針必含 Module prefix（如 `M01-user-login-returns-correct-data`，v2.8 dav-developer 規則）；
  跨 Module integration test 用 `INT-<M01>-<M02>-<description>` 標記；交付時必列 Module 內探針清單 ＋ Module 級整合測試結果
- **3. deliverable.md 命名** — US 級 `docs/deliverable/<YYYY-MM-DD>-<task-slug>.md`；Module 級
  `docs/deliverable/<YYYY-MM-DD>-<module>-<slug>.md`
  （例：US 級 `2026-09-26-m01-us-101-login.md`、Module 級 `2026-09-26-m01-auth-module.md`）
- **4. Module 交付有「第 9 段」** — US 級 deliverable 是 8 段（§1-§8）；Module 級多加 §9「Module 級總結」：
  9.1 多 US 間關聯（依賴關係：邊啲互相依賴、邊啲可獨立交付）｜9.2 跨 Module 遺留問題（如 `INT-M01-M02-checkout-flow` 未跑）｜
  9.3 Module 級技術債（本次未修 ＋ 跨 sprint 的）｜9.4 Module 級指標（探針總數／覆蓋率／LOC／變動歷史）｜9.5 Module 級下一步（vs US 級小行動）

## Module 級 vs US 級交付對照

- **對應 Backlog**：US 級 1 個 US；Module 級 Module 內多 US｜**段數**：US 級 8 段；Module 級 8 ＋ 1（§9）
- **檔案命名**：US 級 `<date>-<slug>.md`；Module 級 `<date>-<module>-<slug>.md`
- **對話摘要**：US 級 ≤ 90 秒；Module 級可至 200 秒（多 US 需說明關聯）
- **反思層級**：US 級 6 維度；Module 級 6 維度 ＋ Module 級 6 維度（重複 12 項）
- **下一步**：US 級 US 級優先；Module 級 Module 級優先 ＋ US 級優先

## Module 級反思（§8 內嵌）

Module 級反思在 US 級反思之上再加 Module 級 6 維度：① UX/UI 一致性 → Module 邊界一致性（內部 API 統一、錯誤碼統一）；
② RWD → 不適用 Module 級（除非 Module 含 UI）；③ 技術債 → Module 內部 ＋ 跨 Module 依賴的技術債；
④ 可維護性 → Module 內聚度（dav-designer 5 條原則驗證）；⑤ 測試覆蓋率 → Module 級覆蓋率（vs US 級單檔）；
⑥ 需求對齊 → Module 職責對齊 system-design.md 定義

## 第 9 段模板（抄落交付摘要）

```markdown
## 9. Module 級總結

### 9.1 多 US 間關聯
- <邊啲 US 互相依賴／邊啲可獨立交付>

### 9.2 跨 Module 遺留問題
- <如 INT-M01-M02-checkout-flow 未跑：點解、要幾時補>

### 9.3 Module 級技術債
- <本次未修 ＋ 跨 sprint 的>

### 9.4 Module 級指標
- 探針總數：<n>｜覆蓋率：<n>%｜LOC：<n>｜變動歷史：<摘要>

### 9.5 Module 級下一步
- <vs US 級小行動：模組層面要先做乜>
```
