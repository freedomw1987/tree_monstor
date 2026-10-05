# Deliverable — feat-jev-regression M6.1 LLM Relay + docs/cleanup (TMO-017 + TMO-018)

> **狀態**：✅ 2026-09-28 完成（commit `224297c`）
> **TMO-017 (M6.1 LLM Relay)**：讓 regression-guard skill 召喚時的 LLM（subagent / pi 本身）接力寫 fix 文字
> **TMO-018 (docs/cleanup)**：文件減法盤點腳本 + 4 類分類

---

## 1. 摘要

兩個任務在同一個 sprint 內完成：

| Task | 範圍 | 證據 |
|---|---|---|
| **M6.1 LLM Relay (TMO-017)** | prompt template + fix_proposal_v2.py + SKILL v2.4 | 50/50 bats，gating 0.41 走 fail 路徑，bundle / answer / final 三件式產出 |
| **docs/cleanup (TMO-018)** | cleanup-scan.py 246 行 + 7 個探針 | 掃描 KEEP 63 / REVIEW 4 / DELETE 0 |

**關鍵設計決策**：

> **M6.1 不接外部 Claude/GPT** — 召喚 regression-guard skill 時的 LLM（subagent / pi 本身）就是接力的 LLM。Prompt template
> 是「檔案」可版本化，不需另外維護 prompt 邏輯雙重來源。

---

## 2. 為什麼做

TMO-016 反思的 4 個未來 Action Items 中有 2 項要收尾：

1. **M6.1 接 LLM 生成 fix 文字** — 之前是「信心度報告 + 走跡 + reviewer 接手」；升級為「信心度達標 → 召喚 LLM 接力寫 fix」
2. **文件減法系統化** — TMO-008 / TMO-010 做過一次手動減法（5 檔 53KB），但沒留下「可重跑」的盤點工具

---

## 3. 改動範圍

### 新增

| 檔案 | 大小 | 用途 |
|---|---|---|
| `skills/regression-guard/PoC/prompts/fix_relay.md` | 2341B / 95 行 | M6.1 prompt template（角色 / 輸入 / 產出 / 約束 / 範例）|
| `skills/regression-guard/PoC/fix_proposal_v2.py` | 7928B / 260 行 | v1 + LLM relay 素材打包 + final report 拼裝 |
| `docs/cleanup/cleanup-scan.py` | 6659B / 246 行 | 文件減法盤點腳本 |

### 修改

| 檔案 | 改動 |
|---|---|
| `skills/regression-guard/PoC/run_pipeline.sh` | +15 行：M6.1 步驟（`JEV_FIX_PROPOSAL_V2=1` 開啟）|
| `skills/regression-guard/SKILL.md` | +57 → 380 行 → v2.4：M6.1 修正循環補充小節 |
| `skills/regression-guard/examples.md` | +64 → 575 行：M6.1 v2 範例 + 為什麼是 skill 本身 LLM 說明 |
| `tests/v2.1-jev-poc.bats` | +141 探針 → 37→50 |

---

## 4. 怎麼試

```bash
cd skills/regression-guard/PoC

# 跑探針（50 探針）
cd ../.. && bats tests/v2.1-jev-poc.bats && cd -
# → 1..50, all ok

# 跑完整 pipeline + M6 + M6.1
JEV_FIX_PROPOSAL=1 JEV_FIX_PROPOSAL_V2=1 \
  REGRESSION_REPORT_PATH=/tmp/r \
  ./run_pipeline.sh US-101
# → ▶ M2 → M3 → M4 → M6 → M6.1
# 0.41 < 0.5 → 走「跳過 LLM relay」路徑
# 產出 /tmp/r-fix-proposal.md + /tmp/r-fix-proposal-v2.md + /tmp/US-101-run.relay/

# 看 prompt bundle（信心度≥0.5 才會有）
cat /tmp/US-101-run.relay/prompt.md
# 召喚 LLM 接力 → 寫到 /tmp/US-101-run.relay/answer.md
# 再跑：
.venv/bin/python fix_proposal_v2.py /tmp/US-101-run.json \
  /tmp/r-final.md --answer-from /tmp/US-101-run.relay/answer.md

# 跑 cleanup 盤點
cd ../..
skills/regression-guard/PoC/.venv/bin/python docs/cleanup/cleanup-scan.py
# → KEEP 63 / REVIEW 4 / DELETE 0

# 或 JSON
skills/regression-guard/PoC/.venv/bin/python docs/cleanup/cleanup-scan.py --json
```

---

## 5. 實測結果

| 測試 | 結果 |
|---|---|
| `bats tests/v2.1-jev-poc.bats` | **50/50 PASS**（M5 16 + M3.1 5 + SKILL 4 + CI 5 + M6 7 + M6.1 6 + CLEAN 7）|
| `JEV_FIX_PROPOSAL=1 JEV_FIX_PROPOSAL_V2=1 ./run_pipeline.sh US-101` | ✅ M2→M3→M4→M6→M6.1 全部跑通；0.41 < 0.5 走 gating fail 路徑 |
| `fix_proposal_v2.py --answer-from` end-to-end | ✅ gating 通過時拼裝 LLM 文字 + 走跡對照 |
| `cleanup-scan.py` | ✅ KEEP 63 / REVIEW 4 / DELETE 0（掃 < 1 秒）|
| `cleanup-scan.py --json` | ✅ 67 檔 valid JSON，4 分類正確 |
| `cleanup-scan.py` 無 .venv false positive | ✅ `is_excluded` 修正後無 .venv 內 LICENSE.md 誤報 |

---

## 6. 設計決策

| 決策 | 原因 |
|---|---|
| **M6.1 用 skill 本身 LLM（不接外部 Claude/GPT）** | skill 召喚時的 LLM（subagent / pi 本身）就是接力的 LLM；不增加外部依賴、不增加 API cost、不增加 prompt 邏輯雙重來源 |
| **Prompt template 是檔案不是 hardcoded 字串** | 可由 skill 維護者迭代、可版本化、可在 changelog 註明哪一版 prompt 跑出哪版結果 |
| **RELAY_GATING_THRESHOLD=0.5** | 跟 v1 「整體信心度 ≥ 0.5 → reviewer 接手」門檻一致；M6.1 用同門檻判斷是否召喚 LLM |
| **`fix_proposal_v2.py` 純 import `fix_proposal` 模組化** | v1 / v2 共用 `_state_text` / `_parse_proposal_response` 等；不重複 code |
| **`build_final_report()` 統一拼裝** | v1 + LLM 文字 + 走跡對照 3 段組合，無論 LLM 是否接力 layout 一致 |
| **cleanup-scan.py 4 類 KEEP/REVIEW/DELETE/MERGE** | MERGE 留 hook（v2.0 規則禁止改存量所以本次不實作），未來如需可加 |
| **EXCLUDE `.venv` 用 `/.venv` in rel** | `Path.match('**/.venv/**')` 不匹配多層；簡單字串檢查更可靠 |
| **PROTECT 所有 skill/ 目錄** | 防止 cleanup 誤刪 skill 內部文件（如 dav-designer prototype-quality.md）|
| **不下 --apply 自動刪** | 本次 DELETE 類為 0，--apply 沒用到；未來如發現 DELETE 類，需人工 review 後手動跑 |

---

## 7. Commit 列表

```
224297c feat(regression-guard): M6.1 LLM relay + docs/cleanup 盤點   ← 本次
f0f6543 feat(regression-guard): CI workflow + M6 fix proposal + return code gate
83336eb feat(regression-guard): M3.1 Playwright observer + SKILL.md 整合 v2.2
4ac566d feat(regression-guard): M5 — fixture YAML + stale 限同 AC + run_dry() + 16 探針
fffbd28 Merge PR #2 (M1-M4) → master
... (M1-M4 8 commits)
```

---

## 8. 已知限制 / Hardening

- **CI 不會自動召喚 LLM relay** — subagent 需要當下對話，CI 環境無對話；M6.1 在 CI 仍走「信心度報告 + 走跡 + prompt bundle」路徑
- **Prompt template 是 markdown 不是 jinja** — 簡單可讀但不支援條件邏輯；如需 conditional 需升級到 jinja 或 programmatic prompt
- **Final report 沒 LLM 接力文字的 versioning** — 改了 prompt template 跑出來文字可能差很多；**需在 deliverable 註明用的是哪一版 prompt**
- **cleanup-scan.py MERGE 分類沒實作** — 留 hook；v2.0 規則禁止改存量所以本次不實作
- **cleanup-scan.py 沒做 fuzzy match** — cross-link 只認 exact 檔名或 stem；可能漏掉 alias / 別名引用

---

## 9. Reviewer 自我檢核

- [x] Gate 1 (TDD): `tests/v2.1-jev-poc.bats` 50 探針 RED → GREEN
- [x] Gate 2 (lint): python 模組 import 過 + workflow YAML 解析正確
- [x] Gate 3 (regression): `JEV_FIX_PROPOSAL=1 JEV_FIX_PROPOSAL_V2=1 ./run_pipeline.sh US-101` 跟 M5/M6 結果一致
- [x] Gate 4 (reviewer): 本檔即為 self-review deliverable

---

## 反思

### 6 維度檢查

| # | 維度 | 結果 | 備註 |
| - | --- | --- | --- |
| 1 | UX/CLI 一致性 | ✅ | `JEV_FIX_PROPOSAL_V2=1` 跟 v1 風格一致；`fix_proposal_v2.py` CLI 介面跟 v1 對齊 |
| 2 | RWD / 跨平台 | ✅ | cleanup-scan.py 純 stdlib；fix_proposal_v2.py 純 python + httpx |
| 3 | 技術債 | ✅ | 本次是收尾：M6.1 模組化（import v1）、cleanup 工具化（可重跑）|
| 4 | 可維護性 | ✅ | SKILL v2.4 加法不破壞、prompt template 檔案可編輯、cleanup 4 分類清楚 |
| 5 | 測試覆蓋率 | ✅ | 50 探針：M5 16 + M3.1 5 + SKILL 4 + CI 5 + M6 7 + M6.1 6 + CLEAN 7 |
| 6 | 需求對齊 | ✅ | 對應 backlog TMO-017 / TMO-018 兩條 DoD 逐條 hit |

### 問題清單（已解決 + 仍待）

| 問題 | 狀態 | 解法 |
|---|---|---|
| M6 Jev 沒文字回應 | ✅ 解 | M6.1 用 skill 本身 LLM 接力（不接外部）|
| Prompt 邏輯雙重來源風險 | ✅ 解 | prompt 寫成檔案（`prompts/fix_relay.md`），可由 skill 維護者迭代 |
| `Path.match('**/.venv/**')` 不匹配多層 | ✅ 解 | `is_excluded` 改用 `/.venv in rel` 簡單字串檢查 |
| 4 個 skill 內部 .md 被誤判孤立 | ✅ 解 | PROTECTED_PATTERNS 列出所有 skill/ |
| **CI 自動召喚 LLM relay** | ⏸ 延 | CI 環境無對話；需外部觸發（gh action with `workflow_dispatch` + subagent）|
| **M6.2 patch + re-validate 自動迴圈** | ⏸ 延 | 需 playwright driver + patch safety 邏輯；M6.1+ 升級路徑 |
| **cleanup-scan.py MERGE 分類** | ⏸ 延 | v2.0 規則禁止改存量所以本次不實作 |
| **cleanup-scan.py fuzzy match** | ⏸ 延 | 簡化版先上線；如未來 cross-link alias 變多再加 |

### V01 / V02 / V03 紀律驗證

- **V01（一次一問）**：1 個 ask_user_question（4 選項：M6.1 形式 / cleanup 範圍），2 題合併 1 個問題，0 個 follow-up ✅
- **V02（推薦第一）**：M6.1 推薦「Subagent 接力（推薦）」、cleanup 推薦「加 /docs/cleanup（推薦）」— 都標 Recommended ✅
- **V03（SOP 修改必 Reviewer）**：本 PR 沒改 SOP/AGENTS.md/gates.json/handbook；改的是 skill 本體（SKILL.md v2.3 → v2.4）+ prompt
  template + 新增 `docs/cleanup/` 模組 — **V03 N/A** ✅

### 對未來的 Action Items

| # | 動作 | 類型 | 預估 |
| - | -- | ---- | ---- |
| 1 | CI workflow 自動 `gh pr comment` 把 fix_proposal_v2 推上 PR 討論串 | CI | 1 pt |
| 2 | M6.2 — M3.1 真 driver + M6.1 LLM 串接，完整 patch + re-validate 迴圈 | US | 13 pt |
| 3 | cleanup-scan.py 加 fuzzy match（alias 解析）+ MERGE 分類實作 | TOOL | 3 pt |
| 4 | cleanup-scan.py 跑進 CI 定期檢查（`if DELETE > 0: warn`）| CI | 0.5 pt |

### feat-jev-regression 整體回顧（5 sprint, 14 commits）

```
TMO-011 (M1-M4)  → TMO-012 (M5)  → TMO-013 (M3.1) + TMO-014 (SKILL v2.2)
                                              ↓
                              TMO-015 (CI) + TMO-016 (M6)
                                              ↓
                              TMO-017 (M6.1 LLM Relay) + TMO-018 (cleanup)  ← 本 sprint
```

| 指標 | 數值 |
|---|---|
| 新檔 | 17 + 3 = **20**（fix_proposal_v2.py / fix_relay.md / cleanup-scan.py）|
| Commit | 10 + 1 + 1 = **12** |
| Source code lines | 4,099 + 876 = **4,975** |
| bats 探針 | 37 + 13 = **50** |
| Batch 維度 | M4 4 + M6 3 = **7** |
| Observer backend | **3** (ac_aware / mock / playwright) |
| Skill 版本 | v2.0 → v2.1 → v2.2 → v2.3 → **v2.4** |
| 信心度 gating | 0.5（v1 reviewer 接手）/ 0.5（M6.1 LLM relay 召喚）|
| 文件分類 | KEEP 63 / REVIEW 4 / DELETE 0 |
| Backlog 完成 | TMO-011 / 012 / 013 / 014 / 015 / 016 / 017 / 018 共 **8 個 done** |

**從 oracle PoC → plug-in framework → skill 規範 → CI + 修正循環 → skill 本身 LLM 接力 + 文件減法**，5 sprint 連續收尾，零迴歸、零降級。
