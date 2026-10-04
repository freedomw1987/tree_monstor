# Ask Me — 範例集

> 配合主檔見範例（指本 skill 的 SKILL.md）；本檔存放 need-you-help.md 完整範本、雙寫前後對照、實戰時間軸。

---

## 1. need-you-help.md 完整範本（上游 trust skill 創建時寫的格式）

> ⚠️ 本節是「上游 trust skill 創建待辦擔憂檔時的格式範本」，本 skill 消化時只改 ☐→☑ 和抉擇欄。

```markdown
# Need Your Help — CRM 會員系統開發

> 由 Agent 在 trust mode 期間主動記錄的擔憂。
> 用戶後續針對每條擔憂給指示：繼續做 / 改設計 / 跳過。

---

## ⚠️ US-105 匯出 CSV

**Backlog**: 客戶列表支援 CSV 匯出（10 萬筆）
**擔憂**: 同步匯出 10 萬筆可能 timeout（30s），且會 block UI thread
**影響範圍**: US-102 客戶列表的效能、用戶體驗
**建議**: 改用 streaming 匯出 或 加進度條

**抉擇**:
- [ ] 繼續做（接受風險，10 萬筆超時請改批次）
- [ ] 改設計（分批 / streaming 匯出）
- [ ] 跳過（不做這個功能）

---

## ⚠️ US-103 表單驗證

**Backlog**: 客戶新增/編輯表單加 zod schema 驗證
**擔憂**: 第三方驗證庫 zod v3 與現有 TypeScript 5.x 相容性未知
**影響範圍**: 表單提交流程
**建議**: 用原生 TypeScript 寫簡單驗證（避免依賴）

**抉擇**:
- [ ] 繼續做（試試看 zod，不行再換）
- [ ] 改設計（用原生 TS 寫）
- [ ] 跳過（不做表單驗證）
```

---

## 2. ask-me 消化前後對照

### 2.1 need-you-help.md（消化後）

```markdown
# Need Your Help — CRM 會員系統開發

---

## ⚠️ US-105 匯出 CSV

**Backlog**: 客戶列表支援 CSV 匯出（10 萬筆）
**擔憂**: 同步匯出 10 萬筆可能 timeout（30s），且會 block UI thread
**影響範圍**: US-102 客戶列表的效能、用戶體驗
**建議**: 改用 streaming 匯出 或 加進度條

**抉擇**:
- [x] 📝 改設計（分批 / streaming 匯出）— **抉擇理由（2026-01-15）**：分批 / streaming 匯出、避免 10 萬筆 timeout
- [ ] 繼續做（接受風險，10 萬筆超時請改批次）
- [ ] 跳過（不做這個功能）

---

## ⚠️ US-103 表單驗證

**Backlog**: 客戶新增/編輯表單加 zod schema 驗證
**擔憂**: 第三方驗證庫 zod v3 與現有 TypeScript 5.x 相容性未知
**影響範圍**: 表單提交流程
**建議**: 用原生 TypeScript 寫簡單驗證（避免依賴）

**抉擇**:
- [x] ✅ 繼續做（試試看 zod，不行再換）— **抉擇理由（2026-01-15）**：用戶決定試 zod、不行再換
- [ ] 改設計（用原生 TS 寫）
- [ ] 跳過（不做表單驗證）
```

### 2.2 backlog.md（同步更新後）

**原本：**

| US    | 名稱             | SP  | 優先 | 狀態       |
|-------|------------------|-----|------|-----------|
| US-103| 表單驗證（zod）  | 3pt | P1   | ⏸️ 待確認 |
| US-105| 匯出 CSV         | 5pt | P2   | ⏸️ 待確認 |

**消化後：**

| US    | 名稱             | SP  | 優先 | 狀態       |
|-------|------------------|-----|------|-----------|
| US-103| 表單驗證（zod）  | 3pt | P1   | ✅ 已確認 |
| US-105| 匯出 CSV（分批） | 5pt | P2   | 📝 改設計 |

> 📝 2026-01-15 ask-me：US-105 改設計為分批 / streaming 匯出（避免 10 萬筆 timeout）
> 📝 2026-01-15 ask-me：US-103 用戶決定試 zod（不行再換）

---

## 3. 實戰時間軸範例

```
[Trust Mode 自然結束：deadline 到 / 用戶叫停]
    ↓
Agent 輸出「🏁 Trust Mode 已結束」+ 標記有 need-you-help.md 待處理
    ↓
用戶：「ask-me，幫我處理 need-you-help」
    ↓
🤖 開始 ask-me
    ↓
📋 共 2 個未確認擔憂（US-103 表單驗證、US-105 匯出 CSV）
    ↓
⚠️ US-103 表單驗證
   擔憂：zod v3 與 TypeScript 5.x 相容性未知
   建議：用原生 TS 寫簡單驗證
   ↓
用戶：✅ 繼續做（試試看 zod，不行再換）
    ↓
✏️ 雙寫：need-you-help.md ☐→☑ + backlog.md ⏸️→✅
    ↓
⚠️ US-105 匯出 CSV
   擔憂：10 萬筆同步匯出可能 timeout
   建議：streaming 匯出 或 加進度條
    ↓
用戶：📝 改設計（分批 / streaming 匯出）
    ↓
✏️ 雙寫：need-you-help.md ☐→☑ + backlog.md ⏸️→📝 + US-105 名稱加「（分批）」
    ↓
📋 沒有更多未確認擔憂
    ↓
🏁 ask-me 結束

處理: 2/2 項
- US-103: ✅ 繼續做（用戶決定試 zod）
- US-105: 📝 改設計（分批 / streaming 匯出）

📄 docs/need-you-help.md: 全部 ☐→☑
📄 docs/backlog.md: 同步狀態更新 + 2 行註腳

下一步：
- 可重啟 trust mode（帶新狀態繼續做 US-103、US-105）
- 或用普通對話模式處理其他事
```

---

## 4. 邊角情境

### 4.1 用戶中途叫停

```
⚠️ US-103 表單驗證
   ↓
用戶：等等、我先處理其他事，ask-me 先停
    ↓
🤖 ask-me 暫停

目前進度：1/2 項已處理（US-103 ✅）、1 項待處理（US-105 ☐）

⏸️ 用戶中斷
下次說「ask-me 繼續」即可從 US-105 開始。
```

### 4.2 對應 US 在 backlog.md 找不到（orphan）

```
⚠️ ORPHAN 擔憂（無對應 US）

**Backlog**: 設計文件「暗黑模式」相關未定項目
**擔憂**: 預設偵測 vs 手動切換順序不確定
**影響範圍**: 整體 UX

Agent 動作：
- need-you-help.md: ☐→☑、加 📝 2026-01-15 ask-me：<理由>
- backlog.md: ⚠️ 無對應 US、不動
- 結束時提醒用戶：「⚠️ 1 項 orphan 已在 need-you-help 完成，但 backlog.md 無對應 US、請手動處理」
```

### 4.3 用戶自訂決定

```
⚠️ US-105 匯出 CSV
   ↓
用戶：「先做 MVP 版（只匯 1000 筆）、之後再加分批」
   ↓
🤖 視為「📝 自訂決定：MVP 版（1000 筆上限）」
    ↓
雙寫格式（符合主檔 Step 3a 自訂分支規範）：
- need-you-help.md: **追加一行** `- [x] 📝 自訂決定（MVP 版 1000 筆上限）— 抉擇理由（2026-01-15）：MVP 版只匯 1000 筆`、原 3 個 checkbox 維持 ☐
- backlog.md: US-105 狀態變 📝 自訂決定、名稱加（MVP 版）
```

---

## 5. 反模式（不要這樣做）

### ❌ 只寫 need-you-help.md、不寫 backlog.md

```markdown
# 錯誤示範
Agent: US-103 已更新為 ✅ 已確認（need-you-help.md）
Agent: 下一題...
# 結果：backlog.md 還是 ⏸️ 待確認 → 雙寫失敗 → ask-me 未完成
```

✅ **正確做法**：雙寫必齊；缺一不可。

### ❌ 批量問 5 題

```markdown
# 錯誤示範
Agent: US-103 / US-105 / US-107 / US-109 / US-111 一併決定吧？
```

✅ **正確做法**：V01 一次一個問題；一題一題問。

### ❌ ask-me 結束後又自動延伸

```markdown
# 錯誤示範
🏁 ask-me 結束
（5 秒後）
我看你 backlog US-103 狀態已 ✅、我順便幫你做掉好了 🚀
```

✅ **正確做法**：ask-me 結束後完全靜默、等用戶指示。

---

## 變動歷史

| 版本 | 日期 | 變動 | 為什麼 |
|------|------|------|------|
| v1.0 | 2026-01-15 | 初版：need-you-help 範本 + 雙寫前後對照 + 實戰時間軸 + 4 個邊角情境 + 3 個反模式 | 與 SKILL.md v1.0 同步創建 |
