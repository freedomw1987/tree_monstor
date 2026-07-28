# ⚠️ Pitfall — Reproduce 撞 500 嘅 root cause 之前唔好寫 fix(2026-06-08 pm-system TD-011)

**場景**:E2E 撞 `fake UUID token 收 500`,我 Round 1 即刻寫 fix:**`derive hook` 加 `if (!dbUser) return null`**。睇 source code 先 catch 真實 bug — `derive hook` 已經有 try-catch(我以為冇),真實 root cause 係 **`prisma.user.findUnique` 對 fake UUID return null(唔 throw),fall through RBAC check,落到 `prisma.project.create({ createdById: user.id })` 撞 FK constraint**。

**2 round miss-and-catch 嘅 cost**:
- Round 1 fix 寫錯位置
- Round 2 睇 `backend/src/index.ts:80-115` 先 catch
- Time 損失:~10 分鐘(re-read source、識破自己嘅假設)
- 更危險:**如果 Round 1 嘅 fix 過咗 review 而冇再睇 source code,bug 仍然喺度**(可能 silence pass test 但真實攻擊面未封)

**Prevention 紀律**(寫 fix 之前):

```
E2E 撞 failure
    ↓
Step 0: **Reproduce** 喺 dev(local curl / minimal script)
    ↓
Step 1: **睇 server log / stack trace**(唔係睇自己嘅 mental model)
    ↓
Step 2: **Trace 個 stack 入真實 code path** — 用 grep / read_file 搵真實嗰行
    ↓
Step 3: 確認 root cause 喺邊個 line / 邊個 function
    ↓
Step 4: 寫 fix(對應真實 root cause,唔係對應 mental model)
    ↓
Step 5: **睇 source code 一眼** — 順手檢查附近有冇其他 invariants 違反
    ↓
Step 6: Fix + regression test + RG entry
```

**Detection signal**(出現以下就要停一停,re-diagnose):
- 寫 fix 之前冇 reproduce 過 — 純靠 mental model
- 寫 fix 之前冇睇 server log / stack trace
- 寫 fix 之前冇 `grep` / `read_file` 個真實 file
- Fix 嘅位置同你估嘅唔同(尤其 hook / middleware 類 — `try/catch` 可能已經有,只係內部 logic 漏)
- 一個 fix 同時想 cover 太多嘢(代表你可能未完全理解 bug 嘅 scope)

**Lesson**:**Reproduce → log → source code → fix**。跳過任何一步都係賭。Mental model 同 source code 衝突嘅時候,**永遠 source code 啱**。

**Reference**: 完整 reproduce 見 `references/pm-system-2026-06-08-sprint-1-td-011-fix-and-regression-test.md` 第 2 節「Diagnosis(我嘅 2 round miss-and-catch)」

---
