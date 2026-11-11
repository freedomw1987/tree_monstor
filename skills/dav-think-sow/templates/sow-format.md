---
name: dav-think-sow-template
description: dav-think-sow 的「SOW markdown 產出模板」附件。含工作版與交付版骨架，規則語意見同套 `reference.md`。
---

# Dav Think SOW — 產出模板

> 本檔只放「可直接填嘅骨架」；規則語意（維度、成熟度、Item 寫法、Assumption）留喺同套 `reference.md`。
> 用法：工作版填齊所有 `<>` 括號位；交付版刪走「待確認」段同所有內部註記。
> ⚠️ 括號位寫法已用書面語示例 → 填入內容要保持同一語體（禁用字眼對照 `reference.md` §8）。

## 工作版骨架：docs/sow/<client>-<project>-<year>-sow.md

```markdown
# <客戶> — <項目名稱> Statement of Work

## 背景與目的

- <一句話說明項目目的>
- <服務對象／受益人>
- <期望達成的效果>

## 交付範圍

### Item 1 — <產品或服務名稱>

- **Description**：
  - <職責說明：一句話說明本項的職責範圍>
  - **A. <能力範疇 1 標題>**
    - <功能名> — <一句話說明>
    - <功能名> — <一句話說明>
  - **B. <能力範疇 2 標題>**
    - <功能名> — <一句話說明>
  - <數量或限制：包含 N 個／上限 N 個／支援 N 台>
- **交付物**：<實物／報告／設定>（服務型必填）
- **工作量**：<N> mandays（服務型必填）

### Item 2 — <產品或服務名稱>

- **Description**：<同上結構>
- **交付物**：<同上>
- **工作量**：<同上>

## Assumption

- **環境與資源**：<部署位置、機器／GPU／授權的提供方、外部系統依賴>
- **範圍與計算基準**：<mandays 的計算基準、超出範圍的計費方式、文件與問答數是否設有上限>
- **商業假設**：<授權年期、續約安排、變更處理方式>
- **未列明事項**：任何未於本文件列明之服務均不包含於本次交付範圍（Any services not specified above are excluded.）

## Out of scope

- <明確不包含的項目 1>
- <明確不包含的項目 2>
- <明確不包含的項目 3>

## 待確認（內部用，交付版刪走）

- <待確認問題 1> — 負責方：<角色>　期限：<日期>
```

## 自家產品拆分骨架（授權 ＋ 部署與調試；兩個 Item）

> 公司自家產品一律拆兩個 Item，對應報價表兩條獨立行項（License line／Service line）。SOW 內唔寫金額。

```markdown
### Item <N> — <產品名稱> 授權（Software License）

- **Description**：
  - <職責說明：本項為軟件授權，涵蓋以下授權範圍>
  - **A. 授權範圍**
    - 授權模組 — <涵蓋的功能模組>
    - 授權對象與角色 — <授權予邊類使用者及角色>
  - **B. 授權數量與年期**
    - 授權數量 — <N> 台／用戶／並發
    - 授權年期 — <N> 年，自驗收日起計算
    - 升級與續約 — <升級政策與續約安排>
- **數量**：<授權上限>
- **費用**：授權費用於報價表以獨立 License 行項列示（本項不列金額）

### Item <N+1> — <產品名稱> 部署與調試（Deployment & Setup）

- **Description**：
  - <職責說明：本項為安裝部署、參數調校與驗收交接服務>
  - **A. 部署**
    - 環境安裝 — <安裝範圍與作業環境>
    - 服務與資料庫初始化 — <初始化項目與設定規則>
  - **B. 調試與驗收**
    - 情境測試與參數調校 — <測試場景與調校項目>
    - 驗收與交接 — <驗收方式與交接內容>
- **交付物**：<部署紀錄、調校報告、驗收報告>（必填）
- **工作量**：<N> mandays（必填）
```

## 交付版骨架：docs/sow/<client>-<project>-<year>-sow-delivery.md

- 同工作版**同一結構**，只差三樣：
  - 刪走「待確認」整段
  - 刪走所有 `<>` 括號位同括號內註記
  - 保留 Assumption 同 Out of scope（呢兩段係保護自己嘅部分，唔好因為「淨係對客」就剪走）
- 語言跟目標客戶／報價文件（見 `reference.md` §7）；中文內文一律書面語（見 `reference.md` §8）

## Excel 版（如用戶要求）

- 由工作版逐格對應到 `SOW Details`／`SOW Details CN`：欄位只有 `#`｜`Item`｜`Description`｜`Mandays`；
  一個 Item 一行；模組資訊以 `A.`／`B.`／`C.`／`D.` 分塊寫入 `Description`；
  **徹底刪除 `Module` 欄**（唔係留空）；`Mandays` 留空畀用戶自評；`Quotation` 結構跟 template 保留
- 自家產品 → 授權與部署調試分兩行（兩個 Item 編號）；Item 名保留「（Software License）」／「（Deployment & Setup）」標註
- `Description` 寫入 cell 時用換行 ＋ `- 功能名 — 說明` 列舉，唔用 markdown 表格
- 寫入步驟同安全規則見 `reference.md` §6
