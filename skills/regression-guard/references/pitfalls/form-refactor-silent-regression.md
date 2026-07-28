# ⚠️ Pitfall — Form refactor 破壞原本 working code 嘅 silent regression

**場景**(2026-06-08 crm-system 統一 `ManDayEditor` refactor):

我抽 `ManDayEditor` 共享 component 嚟取代 `service-detail.tsx` 同 `QuickCreateServiceDialog` 兩處獨立嘅 form。**Tsc pass ✅ + Docker build pass ✅ + 推到 origin/main ✅**。**但 UI 完全壞咗**:
- `ManDayEditor` 個 `value: ServiceManDay[]` props 從未 sync 入 parent state
- 5 個 `Input` share 同一個 `row.roleName` global,唔係 per-row
- Submit 出去嘅 wire payload 全部 5 個空 row → backend `TypeError: Cannot read 'properties' of undefined`
- User 開個 service form 睇唔到 man-day role section,save 失敗 500

**冇任何人 catch 到**,因為:
- ❌ 我冇跑 browser smoke 喺 push 之前
- ❌ tsc pass 嘅錯覺以為 type-safe = runtime-safe
- ❌ 我 patch 嗰陣 replace 咗成個 file,**冇保留原本 working 嘅 state shape** 嘅完整 list
- ❌ 冇任何 test 阻擋(紅線 16 違規)

**真正嘅教訓 — Form refactor 必須遵守嘅 4 條紀律**:

1. **抄原本 working file 嘅完整 state list 先**:
   ```bash
   # 步驟 0: 攞原本 working file 入 /tmp
   git show dcae100:apps/web/src/components/quick-create-service-dialog.tsx > /tmp/ORIG-dialog.tsx
   # 然後清點所有 useState 嘅 setter + 全部 controlled input 嘅 value/onChange
   ```
2. **refactor 唔可以 overwrite 整個 file** — 用 patch 增量改,逐段 verify
3. **refactor 完必須跑 form 嘅 happy path**:
   - Browser navigate 去個 page
   - 填 form
   - Submit
   - 撳返 detail page 確認 DB round-trip 啱
4. **P0 form feature 必須有 happy-path E2E test** — 冇 test = silent regression risk

**檢測信號**(出現以下就要 audit form 改動):
- 任何 `useState` 個 setter `setFoo` 喺 parent 但個 form 用緊 prop 唔 trigger sync
- 任何 `<Input value={x} onChange={...}>` 但 onChange 唔更新 x
- 任何 controlled input 數量 > 5 個 per row
- 任何 form 嘅 wire payload 喺 submit 時 `JSON.stringify(form)` 個 keys 唔等於 expected schema

**預防 checklist**(form refactor 必跑):
- [ ] 攞原本 working file 嘅完整 state list 入 `/tmp/ORIG-*.tsx`
- [ ] 清點所有 `useState` setter
- [ ] 驗證每個 controlled input 嘅 `value` / `onChange` 對應到邊個 state
- [ ] 用 patch 增量改,唔好 overwrite 整個 file
- [ ] 改完跑 form happy path 喺 browser
- [ ] 確認 wire payload 嘅 keys / shape 同 backend expected 一致
- [ ] 確認 DB round-trip 啱(GET 返個 entity 睇 fields 都齊)
- [ ] (P0 form) 加 happy-path E2E test

**Lesson**:`tsc pass` 永遠唔等於 `feature work`。Frontend form refactor 嘅黃金標準係**原本 working code path 一個字都唔可以掉**。
