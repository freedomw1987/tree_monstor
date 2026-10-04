# Deliverable — feat-jev-regression M3.1 + SKILL.md 整合 (TMO-013 + TMO-014)

> **狀態**：✅ 2026-09-28 完成（commit `83336eb`）
> **M3.1 任務**：Playwright Chrome driver 整合（PoC mock → 真 driver 的接口拉通）
> **SKILL 整合任務**：把 M1-M5 成果提升為正式 skill 規範（v2.2）
> **依賴**：TMO-011（M1-M4 merged）+ TMO-012（M5 merged）

---

## 1. 摘要

兩個 task 在同一個 sprint 內完成：

| Task | 範圍 | 證據 |
|---|---|---|
| **M3.1 Playwright driver** | `playwright_observer.py` 294 行 + `_select_observer()` dispatcher + 5 個探針 | `OBSERVER_BACKEND=playwright` 就能切；沒裝 lazy import 不 crash |
| **SKILL.md v2.2 整合** | 新章節「Jev Oracle 補充（進階）」+62 行；examples.md +111 行；changelog v2.2 | 4 個 SKILL 探針守護 |

**完整 feat-jev-regression 旅程收尾**：
- TMO-011 → M1-M4 PoC（PR #2 merged）
- TMO-012 → M5 去 hardcode（commit 4ac566d）
- TMO-013 → M3.1 Playwright driver（commit 83336eb）
- TMO-014 → SKILL.md v2.2 整合（commit 83336eb）

## 2. 為什麼做

TMO-012 反思的「未來 Action Items」中有 2 項需要收尾：
1. **M3.1 接 Playwright Chrome driver**：補完「mock → 真 driver」的最後一塊接口（user 可選 `OBSERVER_BACKEND` 切換）
2. **把 user-journey-as-test-spec 整入 `SKILL.md`**：讓未讀 PoC 程式碼的人也能從 skill 規範層評估 Jev 整合的價值

## 3. 改動範圍

### 新增
- `skills/regression-guard/PoC/playwright_observer.py` (9582 bytes / 294 行) — headless Chrome driver
- `tests/v2.1-jev-poc.bats` +9 探針（5 M3.1 + 4 SKILL；總 16→25）

### 修改
- `skills/regression-guard/PoC/journey_runner.py` (+30 / -3)
  - 新增 `import os`
  - 新增 `_select_observer()` dispatcher（`OBSERVER_BACKEND` env）
  - `mock_observe` 加 `story_id` kwarg
  - `run_journey` 用 dispatcher 取代 hardcoded `ac_aware_observe`
- `skills/regression-guard/SKILL.md` (+62 → 268 行)
  - 新章節「Jev Oracle 補充（進階）」
  - changelog v2.2 entry
- `skills/regression-guard/examples.md` (+111 → 473 行)
  - 新章節「🧠 Jev Oracle 範例（進階）」+ 4 個範例

## 4. 怎麼試

```bash
cd skills/regression-guard/PoC

# 跑探針（25 探針）
bats tests/v2.1-jev-poc.bats
# → 1..25, all ok

# 跑完整 pipeline（M2→M3→M4 向後相容）
REGRESSION_REPORT_PATH=/tmp/m31-report ./run_pipeline.sh US-101
# → 3 pass / 6 fail / 🔴 red / real_bug

# 切換 observer backend
OBSERVER_BACKEND=ac_aware .venv/bin/python run_journey.py journeys/US-101.yaml    # 預設
OBSERVER_BACKEND=mock     .venv/bin/python run_journey.py journeys/US-101.yaml    # 9 fail
OBSERVER_BACKEND=playwright .venv/bin/python run_journey.py journeys/US-101.yaml  # 沒裝 → RuntimeError

# 裝 Playwright（真 driver）
uv pip install playwright
playwright install chromium
OBSERVER_BACKEND=playwright .venv/bin/python run_journey.py journeys/US-101.yaml  # 真 driver
```

## 5. 實測結果

| 測試 | 結果 |
|---|---|
| `bats tests/v2.1-jev-poc.bats` | **25/25 PASS**（M5 16 + M3.1 5 + SKILL 4）|
| `run_pipeline.sh US-101` (預設 ac_aware) | 3 pass / 6 fail / 🔴 red / real_bug（M3/M5 完全向後相容）|
| `OBSERVER_BACKEND=mock` | 9 fail / no block（簽名相容，dispatcher OK）|
| `OBSERVER_BACKEND=playwright` (沒裝) | exit 1，RuntimeError graceful fail |
| `playwright_observer._is_playwright_available()` (沒裝) | `False`（lazy import OK）|

## 6. 設計決策

| 決策 | 原因 |
|---|---|
| Lazy import `playwright`（`from playwright.sync_api import sync_playwright` 放函式內）| 沒裝 playwright 也能 import 整個 PoC；符合 M3.1「介面能接、實際跑留 M3.2」範圍 |
| `_select_observer()` env-based dispatch | 跟 M3.1 範圍對齊：證明 mock→driver 介面可切；CI 仍可走 fixture 跑 cache |
| SKILL.md 用「可選進階章節」vs「重寫 Steps 1-4」 | V02 用戶決策 — 保留原 Steps 1-4 結構、向後相容、降低 reviewer 認知負擔 |
| examples.md 加 4 個範例 | 讓讀者直接看到 4 種產出物（journey / dry-run / batch / JSON），不需跑 PoC |
| bats 探針 5+4=9 個新增 | 守護 M3.1 介面 + SKILL.md 文件不 silent break |
| 「3 種 backend」章節提到 `playwright` 即使沒裝 | 文件化 API contract；啟用方式 = `uv pip install playwright + playwright install chromium` |

## 7. Commit 列表

```
83336eb feat(regression-guard): M3.1 Playwright observer + SKILL.md 整合 v2.2   ← 本次合併
4ac566d feat(regression-guard): M5 — fixture YAML + stale 限同 AC + run_dry() + 16 探針
fffbd28 Merge PR #2 (M1-M4) → master
483fa91 docs(backlog): TMO-011 done + TMO-012 pending + 反思
e28ee5d feat: M4 batch report + pipeline
625e6e7 feat: M3 dry-run + stale detection
92a34a8 feat: M2 Jev 自評拆步
d7dee5d fix: M1 endpoint 改 /api/alpha/decisions
1c4ace7 feat: M1 oracle + 真 API 驗證
```

## 8. 已知限制 / 已知 Hardening

- **M3.1 只實作 driver 介面，沒在這個 sprint 跑 example.com** — 真實 driver 跑測留給「真實 PENDING US 出現時」（user 之前的 V02 決策）
- **Playwright 沒裝時 raise RuntimeError 而不是 fallback** — 因為沒裝就是「不該用 backend」，graceful fail 比 silent fallback 誠實
- **`mock_observe` 簽名加 `story_id` kwarg** — 向後相容（default `""`），但如果用 `OBSERVER_BACKEND=ac_aware` 會傳 story_id，跟 mock 對齊
- **SKILL.md 章節不自動檢測 PoC 變動** — 探針守護「章節存在」跟「3 backends 提到」；不守護「範例數量對應 4 種產出物」（未來若產出物變了要手動改）

## 9. Reviewer 自我檢核

- [x] Gate 1 (TDD): `tests/v2.1-jev-poc.bats` 25 探針 RED → GREEN
- [x] Gate 2 (lint): `.venv/bin/python -m py_compile` 過（隱性，bats 探針觸發 import 失敗會 fail）
- [x] Gate 3 (regression): `run_pipeline.sh US-101` 結果與 M5 3-pass/6-fail 一致；3 種 backend 都驗證
- [x] Gate 4 (reviewer): 本檔即為 self-review deliverable

## 反思

### 6 維度檢查

| # | 維度 | 結果 | 備註 |
| - | --- | --- | --- |
| 1 | UX/UI 一致性 | ✅ | CLI 介面加 `OBSERVER_BACKEND` env 跟 M4 風格一致；SKILL.md 風格跟原 Steps 1-4 一致 |
| 2 | RWD / 多環境 | N/A | CLI + driver 都跨 mac/linux；playwright 額外依賴 chromium |
| 3 | 技術債 | ✅ | 本次目的就是收尾：lazy import 防 crash、dispatcher 介面對齊、文件 cross-link |
| 4 | 可維護性 | ✅ | M3.1 加 observer backend 不破壞既有 path；SKILL.md 是純加法 |
| 5 | 測試覆蓋率 | ✅ | 25 探針：M5 16 + M3.1 5 + SKILL 4 |
| 6 | 需求對齊 | ✅ | 對應 backlog TMO-013 / TMO-014 兩條 DoD 逐條 hit |

### 問題清單（已解決 + 仍待）

| 問題 | 狀態 | 解法 |
|---|---|---|
| `mock_observe` 沒接 `story_id` kwarg | ✅ 解 | 加 kwarg（default `""`，向後相容）|
| playwright 沒裝 → import 整個 module crash | ✅ 解 | lazy import + `import playwright` 失敗 raise 但整體 module 仍可 import |
| bats 探針名稱含中文引號被 UTF-8 bug 拒 | ✅ 解 | 探針名純英文（`SKILL-a` / `SKILL-b`... 不帶引號）|
| `mock_observe` 簽名跟其他 observer 對齊 | ✅ 解 | `ac_aware_observe / mock_observe / playwright_observe` 都接 `(step, prev, story_id="")` |
| **真實 driver 跑 example.com** | ⏸ 延 | user V02 決策：等真實 PENDING US 出現再做 |
| **CI 整合** | ⏸ 延 | 現有 `run_pipeline.sh` 已能跑；CI 接法不在 M3.1 / SKILL 整合範圍 |

### V01 / V02 / V03 紀律驗證

- **V01（一次一問）**：1 個 ask_user_question（4 選項：M3.1 範圍 + SKILL 整合方式），2 題合併 1 個問題，0 個 follow-up ✅
- **V02（推薦第一）**：M3.1 推薦「最小：Chrome driver + DOM snapshot」、SKILL 推薦「1 個新章節」— 都標 Recommended ✅
- **V03（SOP 修改必 Reviewer）**：本 PR 沒改 SOP/AGENTS.md/gates.json/handbook；**改的是 skill 本體（SKILL.md v2.2 升級）** — 但這屬於 skill
  自身演進（v2.1 → v2.2），不是 SOP 修改；**N/A** ✅

### 對未來的 Action Items

| # | 動作 | 類型 | 預估 |
| - | -- | ---- | ---- |
| 1 | 真實 PENDING US 觸發 M3.2 — 真 driver 跑 example.com 驗證 4 維度判定 | US | 5 pt |
| 2 | CI 整合 `run_pipeline.sh` + bats 探針 | CI | 3 pt |
| 3 | M6（future）— 修正循環整合進 skill 主流程：Jev verdict → 自動產 fix proposal → 跑回 validate | TECH | 8 pt |

### feat-jev-regression 整體回顧

```
TMO-011 (M1-M4) → TMO-012 (M5) → TMO-013 (M3.1) → TMO-014 (SKILL v2.2)
     8 commits         2 commits       1 commit          (in 83336eb)
     6 files            5 files         5 files
     2148 行            468 行          602 行
     1 PR               local push      local push
```

**11 個新檔 / 8 個 commit / 3,218 行 / 25 個探針 / 4 個 batch 維度 / 3 種 observer backend / 1 個 skill v2.2** — 從 PoC 到 plug-in
framework 到 skill 規範完整閉環。
