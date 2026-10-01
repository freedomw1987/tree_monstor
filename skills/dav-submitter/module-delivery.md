# Module 級交付（v2.2 新增）

> 本檔為 dav-submitter 的 Module 級交付細節。
> 引用：`SKILL.md`「v2.2 Module 級交付」章節
>
> 從 SKILL.md v2.2 起，本檔獨立。理由：Module 級交付與 US 級交付差異多（Backlog ID 格式 / 探針綁定 / §9 總結），屬於「進階場景」。

## 適用情境

- **整個 Module 完成**：Module 內所有 US 都驗收完、Module 級整合測試通過
- **Module 級里程碑**：Module 內 US 不全部交付、但達到某個「可發佈」的狀態
- **Module 重構完成**：Module 內部技術債清理 + 探針重寫

## Module 級交付的差異

### 1. Backlog ID 格式

- **US 級**：`US-101` / `DE-201` / `TECH-03` / `SPIKE-04`
- **Module 級**：`<MODULE_CODE>-<US_ID>`（如 `M01-US-101`）
- **多 US 同 Module 交付**：在 §2.1-2.3 用 `M01 多 US 集合` 代表，避免重複列每個 US 的改動

### 2. Module 邊界即測試邊界

- Module 內所有探針必含 Module prefix（如 `M01-user-login-returns-correct-data`，v2.8 regression-guard 規則）
- 跨 Module integration test 用 `INT-<M01>-<M02>-<description>` 標記
- 交付時必列 Module 內探針清單 + Module 級整合測試結果

### 3. deliverable.md 命名

| 場景 | 命名 |
| --- | ---- |
| **US 級** | `docs/deliverable/<YYYY-MM-DD>-<task-slug>.md` |
| **Module 級** | `docs/deliverable/<YYYY-MM-DD>-<module>-<slug>.md` |

範例：

- US 級：`docs/deliverable/2026-09-26-m01-us-101-login.md`
- Module 級：`docs/deliverable/2026-09-26-m01-auth-module.md`

### 4. Module 交付有「第 9 段」

US 級 deliverable 是 8 段（§1-§8）；Module 級多加 §9「Module 級總結」：

**§9 Module 級總結（Module 級必含）**：

| 子段 | 內容 |
| --- | --- |
| **9.1 多 US 間關聯** | Module 內 US 的依賴關係圖（哪些 US 互相依賴、哪些可獨立交付）|
| **9.2 跨 Module 遺留問題** | 跨 Module 邊界的問題清單（如 `INT-M01-M02-checkout-flow` 整合測試未跑）|
| **9.3 Module 級技術債** | Module 內累積的技術債（含本次未修的 + 跨 sprint 的）|
| **9.4 Module 級指標** | 探針總數 / 覆蓋率 / Module 大小（LOC） / 變動歷史 |
| **9.5 Module 級下一步** | Module 級優先行動（vs US 級的小行動）|

## Module 級 vs US 級交付對照表

| 面向 | US 級 | Module 級 |
| --- | --- | --- |
| **對應 Backlog** | 1 個 US | Module 內多 US |
| **deliverable 段數** | 8 段 | 8 + 1 段（§9 Module 級總結）|
| **檔案命名** | `<date>-<slug>.md` | `<date>-<module>-<slug>.md` |
| **對話摘要** | ≤ 90 秒 | 可至 200 秒（多 US 需說明關聯）|
| **反思層級** | US 級 6 維度 | US 級 6 維度 + Module 級 6 維度（重複 12 項）|
| **下一步** | US 級優先 | Module 級優先 + US 級優先 |

## Module 級反思（§8 內嵌）

Module 級反思在 US 級反思之上再加 Module 級 6 維度：

| # | 維度 | Module 級聚焦 |
| - | --- | ------------ |
| 1 | UX/UI 一致性 | Module 邊界的一致性（內部 API 統一、錯誤碼統一）|
| 2 | RWD 響應式設計 | （不適用 Module 級，除非 Module 含 UI）|
| 3 | 技術債 | Module 內部技術債 + 跨 Module 依賴的技術債 |
| 4 | 可維護性 | Module 內聚度（dav-designer 5 條原則驗證）|
| 5 | 測試覆蓋率 | Module 級覆蓋率（vs US 級單檔覆蓋率）|
| 6 | 需求對齊 | Module 職責對齊 system-design.md 定義 |
