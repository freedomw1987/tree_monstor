# QA Tracker（持續測試追蹤）

> **為什麼需要這份文件** — David 在 2026-06-06 kanban task 明確指出:
> 「QA 也要持續按用戶的需求去更新測試任務,把測試任務也寫下,之後可以作全面且詳盡的測試。」
>
> 之前 `docs/qa-gate.md` 只有**一次性交付清單**。問題在於:
> - 需求改 → test cases 改了沒?**沒地方記**
> - 改完 sprint planning,QA 任務狀態如何?**沒地方追蹤**
> - 為什麼某個 US 沒有 E2E 測試?**沒地方解釋**
>
> **這份文件就是把 QA 從「一次性 gate」變成「持續追蹤系統」**。

---

## 🎯 核心概念

```
PRD.md (US-XXX 列表)
    ↓ 每個 US 必須有對應 test tasks
QA-TRACKER.md (持續追蹤)
    ↓ 每個 sprint review
TEST-COVERAGE.md (累積覆蓋率)
    ↓ 跟 code 一齊 commit
回報到用戶
```

**不再有「交付前才測試」這回事** — QA 跟開發並行,需求變更即時同步測試任務。

---

## 📋 QA Tracker 模板

每個 project 在 `docs/QA-TRACKER.md` 用以下結構:

```markdown
# QA Tracker — <Project Name>

> 最後更新: YYYY-MM-DD
> 對應 PRD 版本: vX.Y
> 對應 Test Coverage: [link to TEST-COVERAGE.md]

## Sprint 概覽
- 當前 Sprint: Sprint N (YYYY-MM-DD ~ YYYY-MM-DD)
- Sprint Goal: [...]
- 本 Sprint 完成的 US: [...]
- 本 Sprint 新增的測試: [...]

## User Story → Test Task 對照

| US | 描述 | 優先級 | Unit | Integration | E2E | Status | 負責人 | 最後更新 | 備註 |
|----|------|--------|------|-------------|-----|--------|--------|---------|------|
| US-001 | 登入 | P0 | ✅ 3 ✅ | ✅ 1 ✅ | ✅ 1 ✅ | PASS | @QA-Alice | 2026-06-06 | |
| US-002 | 註冊 | P0 | ✅ 5 ✅ | ✅ 2 ✅ | 🟡 1 | PARTIAL | @QA-Alice | 2026-06-05 | E2E 1 個 case 卡喺 email verification step |
| US-003 | 忘記密碼 | P1 | ✅ 2 ✅ | ✅ 1 ✅ | ✅ 1 ✅ | PASS | @QA-Alice | 2026-06-04 | |
| US-005 | 修改個人資料 | P2 | 🟡 0 | ❌ 0 | ❌ 0 | NOT_STARTED | TBD | - | 新 US,sprint planning 後啟動 |
| US-007 | 圖片上傳 | P1 | ❌ 0 | ❌ 0 | ❌ 0 | NOT_STARTED | TBD | - | Backend 改緊,Sprint N+1 啟動 |

**Status 定義**:
- `NOT_STARTED`: 還沒開始寫 test
- `IN_PROGRESS`: 正在寫
- `PARTIAL`: 有 test 但不全,標 🟡 嘅表示部分 sub-case 缺失
- `PASS`: 全部 test 通過
- `FAIL`: 有 test 失敗,需要修
- `BLOCKED`: 等待其他 dependency(例:backend API 未 ready)

## 需求變更影響評估

| 變更日期 | 變更內容 | 影響的 US | 影響的測試 | 動作 | 狀態 |
|---------|---------|----------|----------|------|------|
| 2026-06-05 | US-002 加咗「電話號碼驗證」 | US-002 | 2 個 unit test + 1 個 E2E | Alice 加 3 個 test cases | ✅ DONE |
| 2026-06-06 | US-007 改用 S3 上傳 (原 plan 用本地) | US-007 | 全部重寫 | 待 TBD | 🟡 PENDING |

## 持續測試任務 (Backlog)

| Task ID | 描述 | 對應 US | 預估 | 優先級 | 來源 |
|---------|------|---------|------|--------|------|
| QA-001 | 寫 US-005 unit tests | US-005 | M | P2 | Sprint N planning |
| QA-002 | 補 US-002 E2E email verification case | US-002 | S | P0 | US-002 PARTIAL |
| QA-003 | 加 US-007 嘅 S3 mock tests | US-007 | M | P1 | 需求變更 2026-06-06 |
| QA-004 | Performance test: 1000 concurrent logins | US-001 | L | P2 | Retro 2026-06-01 |
| QA-005 | A11y test: 全站 keyboard nav | ALL | XL | P2 | Retro 2026-06-01 |

## 自動觸發規則

- [ ] **需求變更時**(US 新增/修改/刪除) → 自動加 QA 任務 + 標記 影響評估
- [ ] **Sprint 結束時** → 自動 review 全部 US 嘅 status
- [ ] **Bug 報告時** → 自動加 regression test task
- [ ] **每次 code 改 `~/www/<project>/src/<feature>/`** → 自動 grep 對應 US,提示「呢個改動影響 US-XXX 嘅 N 個 test」

## 已完成 / Archived Tasks
[把已完成嘅 task 搬呢度,保持 active backlog 簡潔]

## Changelog
| 日期 | 變更 | 原因 |
|------|------|------|
| 2026-06-06 | 初版 | 從 kanban task t_c658eba4 開始 |
```

---

## 🔄 工作流程

### 1. 需求變更時(David 改要求)

```
David 提出新需求
    ↓
Developer 跟 David 對齊(updated US 列表)
    ↓
更新 PRD.md(改 US、加 US、刪 US 都記)
    ↓
更新 QA-TRACKER.md:
    - 新 US → 加 row 喺「User Story → Test Task 對照」表
    - 改 US → 標記 🟡 PARTIAL + 加 task 喺 backlog
    - 刪 US → 標 DEPRECATED,保留歷史
    - 加 row 喺「需求變更影響評估」表
    ↓
通知 QA owner 接手
    ↓
QA owner 寫/改 test
    ↓
Status 從 NOT_STARTED → IN_PROGRESS → PASS
```

**紅線**:**改了 PRD 但沒更新 QA-TRACKER = 偷懶**,等同改了代碼但沒 commit。

### 2. Sprint Planning 時

```
讀取 QA-TRACKER.md
    ↓
睇「持續測試任務 (Backlog)」section
    ↓
Sprint capacity 內可以做的 task → 加到 sprint backlog
    ↓
標 owner + due date
    ↓
Sprint 結束時,review PARTIAL / FAIL 嘅 status
```

### 3. Bug 報告時

```
用戶報 bug
    ↓
Developer reproduce + fix
    ↓
更新 QA-TRACKER.md:
    - 加 regression test task 喺 backlog
    - 喺對應 US 嘅 row 加備註
    ↓
QA owner 寫 regression test
    ↓
Test 必須 pass 之後先可以算 fix
    ↓
記低喺 `skills/regression-guard/`(見另一份文件)
```

### 4. 自動觸發

可以設定:
- **GitHub Action**: 每次 PR 開,自動 check 改動嘅 file 對應邊啲 US(透過檔名 convention 或 comment 標記),自動喺 PR 開個 comment 提「你改咗 US-XXX 嘅 code,記得 update QA-TRACKER.md」
- **Pre-commit hook**: 改 `docs/PRD.md` 嘅時候,要求同時改 `docs/QA-TRACKER.md`

---

## 📐 測試覆蓋率指標

每個 US 必須有最少覆蓋:

| 優先級 | Unit | Integration | E2E | 性能 | A11y | Security |
|--------|------|-------------|-----|------|------|----------|
| P0 | ≥3 | ≥1 | ≥1 | 1 | 1 | 1 |
| P1 | ≥2 | ≥1 | ≥1 | - | 1 | - |
| P2 | ≥1 | ≥1 | - | - | - | - |
| P3 | ≥1 | - | - | - | - | - |

**規則**:
- 數字係下限,唔係上限
- 0 個 test 嘅 US **唔可以 ship**
- PARTIAL 嘅 US 可以 ship,**但要喺 QA-TRACKER.md 列明遺留 test + 預計完成 sprint**

---

## 🎬 David 嘅實戰情境

情境:David 改咗 US-002,由「email 註冊」變成「email OR 電話號碼註冊」。

**正確流程**:
1. Developer 喺 PRD.md 改 US-002(加 acceptance criteria)
2. Developer 喺 QA-TRACKER.md:
   - 改 US-002 row 嘅 Status: PASS → PARTIAL
   - 加 row 喺「需求變更影響評估」表
   - 加 task `QA-006: US-002 加電話號碼註冊嘅 unit test` 喺 backlog
3. 派 subagent QA-Engineer 寫 test
4. Test 跑完 PASS → Status PARTIAL → PASS
5. 更新 TEST-COVERAGE.md

**錯誤流程**(會被 David 鬧):
- 只改 PRD 唔改 QA-TRACKER → 「改了什麼我自己都搞不清」
- 加 test 但沒記低 → 「下次再改我又係唔知有冇 test」
- 改完唔通知 → 「我等到 bug 出咗先知」

---

## 🚨 紅線 (新增)

加入 `SOUL.md` 嘅紅線清單:

> **紅線 11**:改 PRD 嘅同時必須更新 `docs/QA-TRACKER.md`(新 US 加 row,改 US 標 PARTIAL,刪 US 標 DEPRECATED)。**改了 PRD 沒更新 tracker = 任務沒做**。

> **紅線 12**:每個 P0/P1 US 必須有對應的 test tasks,Status = PARTIAL / PASS 才算完成。**0 test 嘅 US 唔可以 ship**。

---

## 📚 跟其他文件的關係

- `docs/qa-gate.md` 嘅一次性清單 → 從 QA-TRACKER.md 抽取最新狀態
- `docs/project-documentation-standard.md` §TEST-COVERAGE.md → 由 QA-TRACKER.md 自動 generate
- `skills/regression-guard/` → 處理 bug 修復後嘅 regression test
- `docs/feedback-loop.md` 的罰則套用到「沒更新 tracker」

---

## 🛠️ 工具建議

- **小 project**:人手維護 `docs/QA-TRACKER.md`(呢份模板)
- **中 project**:Kanban 卡片化(每個 QA task 一張卡)
- **大 project**:用 TestRail / Zephyr Scale / qase.io 等專門工具,**但**仍然要 export `docs/QA-TRACKER.md` 俾 git history(避免「為什麼當初決定跳過呢個 test」嘅考古問題)
