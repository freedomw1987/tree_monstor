---
name: regression-guard
description: |
  防止修復過的 bug 重新出現(regression)。
  規則:每個修過的 bug 必須留下「regression test」+「root cause note」+「為何會發生」分析,
  確保日後 refactor / 改需求時唔會重新踩坑。
  David 在 2026-06-06 kanban task 明確指出「舊的 bug 又出現」嘅困擾。
trigger: |
  「bug 翻發」「regression」「舊 bug」「為什麼同樣嘅 bug 又出現」「fix 完又壞」
  或任何 bug 修復流程
version: 1
category: software-development
---

# Regression Guard — 防舊 Bug 翻發

> **為什麼需要這個 skill** — David 嘅實際困擾(2026-06-06 kanban task):
> 「因為現在我有好大體驗,覺得係啲 bug 翻發,舊的 bug 又出現的感覺」
>
> **根因分析**(根據 David 過去 session 觀察):
> 1. Bug fix 之後,只有「修咗」,冇留「點解會壞嘅解釋」+「防止再壞嘅 test」
> 2. Refactor / 改需求時,新嘅 code 違反咗原本 fix 嘅 invariant
> 3. 冇「為何會壞」嘅紀錄 → 6 個月後 debug 同樣 bug 嘅人(可能係 AI subagent)又踩同樣嘅坑
>
> **這個 skill 解決的就是:把「修 bug」從一次性事件變成「帶歷史的防護」**。

---

## 🎯 核心流程

```
Bug 發現 / 報告
    ↓
Step 1: 重現 bug(reproduce)
    ↓
Step 2: 寫 failing test(red)
    ↓
Step 3: 分析 root cause + 寫「點解會壞」紀錄
    ↓
Step 4: 修代碼 → test 變 green
    ↓
Step 5: 寫 regression test(就算原 bug test 已修好,再加邊界情況)
    ↓
Step 6: 寫 regression-guard entry 喺 `docs/REGRESSION-GUARD.md`
    ↓
Step 7: 喺 source code 加 comment 標記(防止 refactor 破壞)
    ↓
Step 8: 提交 + commit message 引用 entry ID
```

**紅線**:**冇 step 3 (root cause) 同 step 6 (guard entry) 嘅 bug fix 唔可以 merge**。

---

## 📁 文件結構

每個 project 必須有 `docs/REGRESSION-GUARD.md`,格式:

```markdown
# Regression Guard — <Project Name>

> 目的:追蹤所有修過嘅 bug,確保日後唔會重新踩坑。
> 規則:每個 bug fix 必須喺呢度留 entry,否則不算完成。

## 索引
| Entry ID | Bug 描述 | 發現日期 | 影響版本 | Root Cause | Regression Test | 狀態 |
|----------|---------|---------|---------|-----------|-----------------|------|
| RG-001 | 登入後 token 過期但 UI 唔跳 | 2026-05-12 | v1.2.0 | [see](#rg-001) | [test/auth.test.ts#expired-token-redirect](...) | FIXED |
| RG-002 | 圖片上傳 > 5MB 唔報錯 | 2026-05-20 | v1.2.1 | [see](#rg-002) | [test/upload.test.ts#size-limit](...) | FIXED |
| RG-003 | 註冊 email 重複檢查 race condition | 2026-06-01 | v1.3.0 | [see](#rg-003) | [test/auth.test.ts#concurrent-signup](...) | FIXED, MONITORING |

## 條目格式

<a id="rg-001"></a>
### RG-001 — 登入後 token 過期但 UI 唔跳轉到 login

**發現日期**: 2026-05-12
**發現者**: @David (用戶回報)
**影響版本**: v1.2.0 (released 2026-05-10)
**修復版本**: v1.2.1
**修復者**: @Backend-Bob
**Commit**: `a1b2c3d`

#### 症狀
- 用戶登入後用緊 30 分鐘
- 突然操作一個需要 auth 嘅 endpoint
- 後端回 401,但前端 UI 冇反應(冇跳轉、冇 toast)
- 用戶以為 app 壞咗,實際係 token 過期

#### Root Cause(為何會壞)
- 原本 `apiClient.ts` 有個 axios interceptor 處理 401
- 但 `interceptor` 只 refresh token,**冇** force logout
- 如果 refresh 失敗(refresh token 都過期),silently fail
- 前端冇 global error boundary 處理「auth 死咗」嘅情況

**教訓**:
1. 唔好假設 refresh token 一定 work — 要有 fallback
2. Auth state 變化要 broadcast(用 Event Bus / state machine)
3. UI 必須對「無法恢復嘅 auth 失敗」有明確用戶反饋

#### 防止再發(防護措施)
- [x] **Regression test**: `test/auth.test.ts#expired-token-redirect` 模擬 refresh 失敗 → 預期跳轉到 /login
- [x] **Code comment**: `apiClient.ts` 嘅 interceptor 加 `// RG-001: 唔好 silent fail,要 force logout if refresh fails`
- [x] **Invariant statement**: 「401 + refresh 失敗 = 強制登出」寫入 `docs/architecture/0007-auth-state-machine.md`
- [x] **Linting rule**: ESLint custom rule 禁止 `catch (err) { /* silent */ }` 在 auth-related code

#### 相關 Issue / Discussion
- [GitHub Issue #234](...)
- [Slack thread 2026-05-12](...)
```

---

## 📝 Step-by-Step 詳細執行

### Step 1: 重現 bug

**紅線:未確認能重現嘅 bug 唔可以 fix**。

```bash
# 1. 寫 reproduction script(寫到 /tmp/,唔好寫到 project)
cat > /tmp/repro_bug.py << 'EOF'
import requests
# 模擬 bug 嘅觸發條件
resp = requests.post("https://api.example.com/upload", files={"file": open("huge.jpg", "rb")})
print(f"Status: {resp.status_code}")  # 期望 413,實際 500
print(f"Body: {resp.text}")
EOF
python3 /tmp/repro_bug.py
```

**記錄**:
- 觸發條件(輸入、狀態、環境)
- 預期 vs 實際
- 重現率(100% / 偶發 / 特定條件)

### Step 2: 寫 failing test (Red)

**在正式 test suite 內加 test(唔好寫到 /tmp/!)**

```typescript
// test/upload.test.ts
describe('Image upload size limit', () => {
  it('should return 413 when file > 5MB', async () => {
    const hugeFile = new File([new ArrayBuffer(6 * 1024 * 1024)], 'huge.jpg', { type: 'image/jpeg' });
    const result = await uploadImage(hugeFile);
    expect(result.status).toBe(413);
  });
});
```

**確認**:`npm test` 跑呢個 test 係 **FAILING** (紅色)。如果 PASS,代表根本無 bug 或者 test 寫錯。

### Step 3: 分析 root cause(最關鍵!)

**要回答三條問題**:
1. **點解會壞?**(技術原因)
2. **點解之前冇人發現?**(process 原因)
3. **點解將來唔會再壞?**(prevention 設計)

```markdown
#### Root Cause

**技術原因**:
- `uploadHandler.ts:42` 用 `await file.arrayBuffer()` 之後直接 push 到 S3
- 冇 size check
- 過咗 Lambda 嘅 6MB payload limit 之後就 500

**Process 原因**:
- 之前只係用 1MB test file 做 integration test
- Production 環境啲用戶有時上傳 5-10MB 嘅相
- 冇 staging environment 用真實 size 測試

**Prevention 設計**:
- Client-side: 喺 file picker 加 size validation(防止用戶揀錯 file)
- Server-side: middleware 做 size check(防止 client-side 被 bypass)
- S3: 用 multipart upload for files > 5MB(支援大 file)
- Test: 加 regression test with 6MB file
```

**規則**:**技術原因 + process 原因都要寫**。淨寫「我加咗個 if 啦」係偷懶。

### Step 4: 修代碼

寫最少嘅 code 改動,確保 step 2 嘅 test 變 GREEN。

### Step 5: 寫 regression test

```typescript
// 加多幾個邊界 case
describe('Image upload edge cases', () => {
  it('should reject 5.1MB with 413', ...);
  it('should accept 4.9MB with 200', ...);
  it('should reject 0-byte file with 400', ...);  // 新加嘅邊界
  it('should handle concurrent uploads of large files', ...);  // 性能
  it('should not leak memory on rejected uploads', ...);  // 資源
});
```

**原則**:**預防性測試 > 反應性測試**。等個 bug 出咗先寫 test 永遠慢人一步。

### Step 6: 寫 REGRESSION-GUARD entry

按上面嘅模板,寫一個完整嘅 entry。

**重要:Entry ID 用 `RG-` + 3 位數遞增**(`RG-001`, `RG-002`...)。

### Step 7: 在 source code 加 comment

```typescript
// uploadHandler.ts
async function uploadImage(file: File) {
  // RG-002: 5MB size limit enforced client + server side
  // 修改前請睇 docs/REGRESSION-GUARD.md#rg-002 嘅 invariant
  if (file.size > 5 * 1024 * 1024) {
    throw new Error("FILE_TOO_LARGE");
  }
  // ...
}
```

**Comment 必須包含**:
- `RG-XXX` entry ID
- 一句 invariant 描述
- 連結到 REGRESSION-GUARD.md

### Step 8: 提交

```bash
git add src/uploadHandler.ts test/upload.test.ts docs/REGRESSION-GUARD.md
git commit -m "fix(upload): enforce 5MB size limit (RG-002)

- Add server-side size check
- Add regression test for 5.1MB upload
- Document root cause and prevention in REGRESSION-GUARD.md
- Add RG-002 comment marker in source code

Refs: RG-002"
```

**Commit message 必須引用 RG ID**,方便日後 `git log --grep "RG-002"` 找返所有相關 commit。

---

## 🔍 防止「同樣 bug 又出現」的具體策略

### 策略 1: Refactor 時嘅 Guard

當 refactor 涉及有 RG entry 嘅 code:

```
Refactor 開始
    ↓
git grep "RG-XXX" → 列出所有受影響位置
    ↓
逐個睇 invariant statement
    ↓
確認 refactor 冇違反任何 invariant
    ↓
跑對應嘅 regression test
    ↓
先可以 merge
```

### 策略 2: 改需求時嘅 Guard

當某個 US 改咗,可能影響之前嘅 RG entry:

```
改 US 影響分析
    ↓
檢查 REGRESSION-GUARD.md 入面,有冇 entry 嘅 invariant 同新 US 衝突
    ↓
如果有衝突:
    - 標記 RG entry 為 NEEDS_REVIEW
    - 在該 entry 加新嘅 section 講解衝突點
    - 跟用戶/PM 確認
    - 寫新 entry `RG-XXX-supersedes-RG-YYY`(保留歷史)
```

### 策略 3: 自動監控

```yaml
# .github/workflows/regression-check.yml
name: Regression Guard
on: [pull_request]
jobs:
  check-rg-references:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Check RG comment markers
        run: |
          # 改咗 src/ 但冇更新 REGRESSION-GUARD.md 嘅 PR → fail
          if git diff --name-only origin/main | grep -E "src/.*\.(ts|js|py)$"; then
            if ! git diff --name-only origin/main | grep -q "REGRESSION-GUARD.md"; then
              if ! git diff origin/main | grep -qE "RG-[0-9]{3}"; then
                echo "❌ Source code 改動冇引用任何 RG entry"
                echo "   要麼:1) 加 RG entry / 2) 確認唔影響現有 RG"
                exit 1
              fi
            fi
          fi
```

### 策略 4: 季度 RG Audit

每季做一次:
```
撈 REGRESSION-GUARD.md 全部 entry
    ↓
逐個睇:
    - regression test 仲跑唔跑?(有冇被 refactor 刪走?)
    - code comment 仲喺唔喺度?
    - invariant 仲 valid 唔 valid?(隨住 system 演進,可能已經唔適用)
    ↓
寫 audit report 喺 `docs/retros/YYYY-QX-regression-audit.md`
    ↓
發現失效嘅 entry → 標 DEPRECATED + 解釋
```

---

## 🆚 同其他文件嘅關係

| 文件 | 角色 | 互動 |
|------|------|------|
| `docs/PRD.md` | 講要做咩 | RG entry 可能引用 US(例:RG-002 違反咗 US-007) |
| `docs/architecture/*.md` | 講點樣做 | RG entry 可能引用 ADR(例:RG-003 因為 ADR-0005 嘅 trade-off 造成) |
| `docs/QA-TRACKER.md` | 持續測試追蹤 | RG 嘅 regression test 一定喺 QA-TRACKER 入面追蹤 |
| `docs/TECH-DEBT.md` | 技術債 | RG entry 升級做 tech debt 嘅情境:「個 fix 唔完美,將來要重做」 |
| `docs/feedback-loop.md` | 獎罰 | 沒寫 RG entry 嘅 bug fix 算 P1 過(已記錄喺 feedback-loop.md 嘅罰則) |

---

## 🚨 紅線 (新增)

加入 `SOUL.md` 嘅紅線清單:

> **紅線 13**:任何 bug fix 必須有對應嘅 `RG-XXX` entry 喺 `docs/REGRESSION-GUARD.md`,**冇 entry 嘅 fix 唔可以 merge**。

> **紅線 14**:Bug fix 必須有 root cause + prevention 兩部分,**淨寫 code 改動冇寫點解嘅 fix 唔可以 merge**。

> **紅線 15**:Refactor 涉及有 `RG-` 標記嘅 code 必須先確認冇違反 invariant,否則要開新 entry 講解取捨。

---

## 🎬 David 嘅實戰情境

情境:David 報 bug —「用戶密碼重設之後,登入之後個 session 仲係舊嘅,新密碼改咗但其他 device 仲可以用舊密碼登入」。

**正確流程**(用本 skill):
1. **重現**:Developer 寫 script 模擬兩 device + 重設密碼,確認 bug
2. **寫 failing test**: `test/auth.test.ts#password-reset-invalidate-sessions`
3. **Root cause 分析**:
   - 技術:`resetPassword` 只 update password hash,**冇** invalidate existing sessions
   - Process:之前 sprint planning 冇考慮「password change = security event = invalidate all sessions」呢個 invariant
   - Prevention:加 `session.invalidate_all_for_user(userId)` 喺 `resetPassword` 流程
4. **修 code**:加 invalidate logic
5. **加 regression test**: 加多 `it('should invalidate refresh tokens after password reset')`
6. **寫 RG-004 entry**:
   - ID:RG-004
   - 症狀:密碼重設後其他 device 仲用舊密碼有效
   - Root cause:密碼改動冇 trigger session invalidation
   - Prevention:所有 auth event(password change, email change, 2FA enable)都 invalidate sessions
7. **Code comment**:
   ```typescript
   // RG-004: 密碼重設必須 invalidate 全部 sessions
   // 違反呢個 invariant = 其他 device 仲可以用舊密碼
   await sessionStore.invalidateAllForUser(userId);
   ```
8. **Commit**:`fix(auth): invalidate sessions on password reset (RG-004)`

**錯誤流程**(冇用本 skill):
- 「我加咗個 invalidate call 啦,搞定」→ **冇 RG entry → 下次 refactor 又會踩**
- 「點解之前冇人 catch 到」 → 永遠唔會知道
- 「同樣嘅 bug 我一年撞 3 次」→ 唔會再撞嘅唯一方法就係**留下紀錄**

---

## 📊 衡量指標

每個 project 嘅 health check:

| 指標 | 健康 | 警告 | 不健康 |
|------|------|------|--------|
| 過去 90 日新增 RG entry 數 | < 5 | 5-15 | > 15(可能 process 有問題) |
| RG entry 標 NEEDS_REVIEW 嘅比例 | < 10% | 10-30% | > 30%(需求變更太頻繁沒管理) |
| Regression test 跟 code 一齊 commit 嘅比例 | 100% | 80-99% | < 80% |
| 季度 audit 發現失效 RG 嘅比例 | < 5% | 5-20% | > 20%(audit 太少) |

**注意**:`過去 90 日新增 RG entry 數` 健康值低,代表 codebase 穩定。**唔係「愈少 bug 愈好」**— 可能係冇發現 bug 嘅 reflection。
