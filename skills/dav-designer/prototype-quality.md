---
name: dav-designer-prototype-quality
description: dav-designer 的「原型品質」子檔。含 DoD 深度模式、5 種狀態（Happy／Loading／Empty／Error／Edge）、設計自審 6 維度、自審報告模板、追溯矩陣模板。
---

# Prototype Quality Sub-spec

> 本檔為 `dav-designer` 的子檔：原型品質（狀態 + 自審）。demo app 規格（Surface／stack／demo 路線）→ 同套 `system-prototype.md`。

## 0. DoD 深度模式

- **DoD-Lite** — 必做：Happy path（§1.1）；略過：Loading／Empty／Error／Edge；⭐ 預設
- **DoD-Full** — 必做：五狀態全做（§1.1-§1.5）；選用（Step 1 逐 Surface 選定）

## 1. 原型 DoD（Definition of Done）

### 1.1 Happy path（主流程）— **必做**

- **主流程完整**：由入口到出口每步都點得完，冇死路
- **表單驗證**：必填未填要擋 ＋ 有提示訊息
- **成功回饋**：完成後有明確成功狀態（toast／跳頁／訊息）

### 1.2 Loading 狀態

- **至少 1 個 spinner／skeleton** ＋ **CTA 期間 disable**（防重複點擊）＋ **最短顯示 ≥ 300ms**（唔好閃一閃就冇）

### 1.3 Empty state（空狀態）

- **至少 1 個零資料畫面**（冇待辦／冇訂單）＋ **圖示 + 文字**（唔好淨係空白）＋ **引導動作**（「建立第一個 X」CTA）

### 1.4 Error state（錯誤狀態）

- **表單錯誤**（密碼錯／Email 格式錯）＋ **系統錯誤**（網絡斷線／伺服器錯）＋ **訊息要具體**（講點樣修正，唔好淨係「發生錯誤」）

### 1.5 Edge case（邊界輸入）

- **超長字串**（貼 1000 字元唔爆版）＋ **特殊字元**（Emoji／`<script>`／注入字串）＋ **邊界數值**（0／999999／-1）

## 2. 設計自審 6 維度（Step 4.5）

- **一致性** — 相同操作跨 Module／Surface 統一（刪除確認位置、命名、錯誤訊息形式）；❌ → 統一風格後重生 Step 4
- **可達性** — 冇孤島畫面；深層路徑 ≤ 3 層；必經節點有 breadcrumb／返回鍵；❌ → 加導航或刪孤島畫面
- **錯誤處理** — 每個表單有對應錯誤狀態；失敗有 fallback；邊界輸入唔崩；❌ → 補錯誤狀態（納入 Step 5 DoD）
- **空狀態** — 零資料畫面、零搜尋結果畫面、首登 onboarding 都有設計；❌ → 補空狀態畫面
- **效能預感** — 大資料量有分頁／虛擬捲動；重操作有進度條；即時操作有 debounce；❌ → 補 loading 或回 Step 3 調架構
- **整合性**（v2.6 新增） — 跨 Module／跨 Surface 流程可達；demo 路線行得通；資料真串連；跨端視覺同一套 tokens；❌ → 修 store 接線／補 route／統一 tokens

## 3. 自審報告模板（Agent 產出格式）

```markdown
# 設計自審報告 — <Surface / 批次>

- 一致性：✅ 綠 / ⚠️ 待修 / ❌ 不通過 — <備註>
- 可達性：✅ / ⚠️ / ❌ — <備註>
- 錯誤處理：✅ / ⚠️ / ❌ — <備註>
- 空狀態：✅ / ⚠️ / ❌ — <備註>
- 效能預感：✅ / ⚠️ / ❌ — <備註>
- 整合性：✅ / ⚠️ / ❌ — <備註>

**結論**：全綠 → 進 Step 5 / 有 ⚠️❌ → 用戶決定「退回修改」或「帶條件進 Step 5」

請用戶簽核：「✅ 簽核」或「🔙 退回修改：...」
```

## 4. 追溯矩陣模板

PRD.md 必含（缺欄視為不完整）：`FR / User Story / Surface / 畫面路由 / Demo 步驟 / 狀態`

```markdown
| FR | User Story | Surface | 畫面路由 | Demo 步驟 | 狀態 |
| --- | --- | --- | --- | --- | --- |
| FR-01 登入 | TMO-012 | web-admin | /w/login | step-1 | ✅ 已原型 |
| FR-02 註冊 | TMO-013 | web-admin | /w/register | — | ⏳ 待原型 |
| FR-03 落單 | TMO-015 | mobile-app | /m/orders/new | step-2 | ✅ 已原型 |
```

- 「User Story」欄填 backlog ID；「畫面路由」填 demo app 內 hash route；「Demo 步驟」填 `step-N` 或 `—`（唔喺 demo 路線內）。
- 矩陣表頭必須出現「User Story」字樣（下游漂移檢查靠佢定位 US 欄）。
