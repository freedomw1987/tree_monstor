# QA Gate 交付清單

## 必須全部完成才可交付

```
□ SA Code Review: APPROVED
□ UI/UX Design Review: APPROVED
□ 單元測試通過（項目有單元測試時）
□ Integration 測試通過
□ E2E 測試通過（使用 dogfood skill）
□ User Simulation 測試通過
□ 主要 User Flow 跑通
□ Console 無 JS Error
□ 截圖/測試報告已保存
□ 部署驗證（curl health check 成功）
□ Feedback Loop 完成記錄
□ 交付狀態: ✅ 可交付 / ❌ 存在問題
```

---

## 未通過嚴禁交付

未通過 QA Gate 的代碼嚴禁交付。如果用戶堅持要，必須明確告知風險並記錄在案。

---

## QA 責任定義

**Developer 的職責是最後一道防線：**
- 每次交付前，必須完成 QA Gate 檢查清單
- 發現的 bug → 記錄在案 → 修復後重新驗證
- 無法驗證的功能 → 明確告知用戶風險
- **未經驗證就交付 → 等同 P1 過**

---

## 交付後記錄

每次交付後，在 checkpoint 或交付記錄中注明：

```
QA Gate — [功能]
├── 驗證日期: YYYY-MM-DD
├── 驗證結果: ✅ 通過 / ❌ 未通過
├── 遺留問題: [如有]
└── QA 負責人: Developer Profile
```

如果用戶發現 bug → 追加記錄：
```
Bug 反饋 — P1 — [描述]
└── 責任歸屬: QA 未發現 → +1 過
```
