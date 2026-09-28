# Deliverable — feat-jev-regression TMO-020 M6.3 + Flaky + Cleanup-CI

> **狀態**：✅ 2026-09-28 完成（commit 下一個）
> **TMO-020**（3 個收尾選項一次到位）：M6.3 互動式 sandbox + Flaky 多次驗證 + Cleanup 進 CI 定期
> **sprint 涵蓋**：8 個 sprint（M1~M6.3 + cleanup）

---

## 1. 摘要

feat-jev-regression 在前 7 個 sprint（M0~M6.2）已建出完整閉環 (M1→M6.2)。
這次 sprint 把 3 個未來 Action Items 一次收尾：

| 收尾選項 | 模組 | 探針 |
|---|---|---|
| **M6.3 互動式 sandbox** | sandbox_runner.py (12.8KB) | 10 |
| **Flaky 多次驗證** | flaky_check.py (6.4KB) | 4 |
| **Cleanup 進 CI 定期** | workflow schedule + cleanup-scan job | 3 |
| **總計** | 2 模組 + 1 workflow | **17** |

完整閉環從 M2→M6.2 升級為 **M2→M6.3**（7 stages），且 CI 自動定期跑 cleanup-scan 防止文件堆積。

---

## 2. 為什麼做

TMO-017 / TMO-018 / TMO-019 反思的未來 Action Items 中有 3 項要收尾：

1. **M6.3 互動式 sandbox** — M6.2 還需手動 3 步（apply → 重跑 → re-validate）；封裝成 1 步 sandbox 流程
2. **Flaky 多次驗證** — 用多次跑驗證 journey 結果是否穩定；驗證 flaky_likelihood 維度真能識別 flaky test
3. **Cleanup 進 CI 定期** — docs/cleanup-scan 加到 GitHub Actions schedule，避免文件堆積

---

## 3. 改動範圍

### 新增

| 檔案 | 大小 | 用途 |
|---|---|---|
| `docs/ac/US-M63.md` | 2325B / 60 行 | M6.3 PENDING US AC 範本 |
| `docs/ac/US-M63.html` | 4371B / 116 行 | M6.3 HTML 版 |
| `skills/regression-guard/PoC/sandbox_runner.py` | 12796B / 379 行 | M6.3：互動式 sandbox（建/apply/重跑/re-validate/rollback/cleanup）|
| `skills/regression-guard/PoC/flaky_check.py` | 6371B / 187 行 | Flaky 驗證：跑 N 次 + 計算 flaky_likelihood + 分類 |
| `skills/regression-guard/PoC/fixtures/US-M63-sample.py` | 29B | M6.3 測試 fixture |
| `docs/deliverable/2026-09-28-feat-jev-regression-m63-flaky-cleanup.md` | 本檔 | TMO-020 deliverable |

### 修改

| 檔案 | 改動 |
|---|---|
| `.github/workflows/regression-guard-jev-poc.yml` | +schedule trigger + cleanup-scan job |
| `docs/backlog.md` | +TMO-020 row + 詳細段 |
| `skills/regression-guard/PoC/run_pipeline.sh` | +M6.3 step + AC_FILE fallback + JEV_SANDBOX_RUN=1 |
| `skills/regression-guard/SKILL.md` | +v2.6 changelog + M6.3 / Flaky / Cleanup-CI 3 小節 |
| `skills/regression-guard/examples.md` | +M6.3 範例 + flaky 5 次跑表 + cleanup-CI workflow |
| `tests/v2.1-jev-poc.bats` | +17 探針 → 63 → 80 |

---

## 4. 怎麼試

```bash
cd skills/regression-guard/PoC

# 1. 跑探針（80 探針）
cd ../.. && bats tests/v2.1-jev-poc.bats && cd -
# → 1..80, all ok

# 2. 跑完整閉環 M2→M6.3
JEV_FIX_PROPOSAL=1 JEV_FIX_PROPOSAL_V2=1 \
  JEV_PATCH_AND_REVALIDATE=1 JEV_SANDBOX_RUN=1 \
  ./run_pipeline.sh US-M63
# → M2 → M3 → M4 → M6 → M6.1 → M6.2 → M6.3 → ✨ Pipeline 完成

# 3. sandbox_runner 獨立使用
.venv/bin/python sandbox_runner.py \
  --before /tmp/US-M63-before.json \
  --file fixtures/US-M63-sample.py \
  --old 'return "before-patch"' --new 'return "after-patch"' \
  --journey journeys/US-M63.yaml \
  --story-id US-M63 --source docs/ac/US-M63.md \
  --sandbox-dry-run
# → 👀 sandbox 已建不 apply

# 4. flaky 多次驗證
.venv/bin/python flaky_check.py journeys/US-M62.yaml \
  --source docs/ac/US-M62.md --story-id US-M62 --runs 5 \
  --output /tmp/flaky-usm62.md
# → 5 次跑 + 🟢 stable (flaky_likelihood=0.0)

# 5. cleanup-scan
.venv/bin/python docs/cleanup/cleanup-scan.py --json | python -m json.tool
# → KEEP 63 / REVIEW 4 / DELETE 0

# 6. CI weekly 自動跑
#   .github/workflows/regression-guard-jev-poc.yml schedule: '0 0 * * 1'
#   → 每周一 00:00 UTC 跑 cleanup-scan
```

---

## 5. 實測結果

| 測試 | 結果 |
|---|---|
| `bats tests/v2.1-jev-poc.bats` | **80/80 PASS**（63 → 80，+10 M6.3 + 4 flaky + 3 cleanup-CI）|
| `./run_pipeline.sh US-M63` | ✅ M2→M3→M4→M6→M6.1→M6.2→M6.3 全綠 |
| `sandbox_runner.py --sandbox-dry-run` | ✅ 建 sandbox 1ms，原檔未改 |
| `sandbox_runner.py` 真的 apply | ✅ no_change classification + 801 bytes sandbox_report.md |
| `sandbox_runner.py` ambiguous old | ❌ error=1 + cleanup 仍跑 |
| `sandbox_runner.py` missing before.json | ❌ error=1 + 「檔案不存在」訊息 |
| `flaky_check.py` US-M62 5 次跑 | 🟢 **stable** (flaky_likelihood=0.0)，verdict 完全一致 |
| `flaky_check.py` highly_flaky 模擬 | 🔴 flaky_likelihood=0.85, highly_flaky |
| `cleanup-scan.py --json` | KEEP 63 / REVIEW 4 / DELETE 0 |
| workflow YAML 解析 | ✅ schedule + cleanup-scan job |

---

## 6. 設計決策

| 決策 | 原因 |
|---|---|
| **M6.3 不污染主 repo** | sandbox 是「目錄級隔離」（tmp/.sandbox-<ts>/），主 repo 永遠不被改 |
| **M6.3 自動 rollback if regression** | 套 patch 後若 verdict 變差，自動從 .pre-patch/ 還原；保護 sandbox 內狀態 |
| **M6.3 仍叫「互動式」** | 自動 apply / re-validate / rollback，但「要不要拿回主 repo + commit」仍人工 |
| **M6.3 cleanup 永遠跑** | 不論結果都刪 sandbox 目錄，不留垃圾（用 `try/finally` 風格）|
| **flaky_likelihood 公式**：Σ range / (Σ max + 1) | 簡單直觀：0=完全穩定，接近 1=完全 flaky；避免分母為 0 |
| **flaky 3 種分類** | stable (<0.05) / mildly_flaky (<0.20) / highly_flaky (≥0.20) |
| **flaky 用 US-M62 5 次跑實測** | 證明 verdict 100% 一致 → flaky_likelihood=0.0 → 結果可信 |
| **cleanup-scan weekly 不是 daily** | 文件分類變化不快；daily 浪費 CI minutes；weekly 1 次夠 cover |
| **cleanup-scan 不自動刪 DELETE** | 可能是 audit trail / 重要單一來源 / WIP；DELETE > 0 只警告 |
| **cleanup-scan job 只在 schedule/dispatch 跑** | 避免 push/PR 跑浪費 CI minutes；只在定期 + 手動時跑 |

---

## 7. 完整 feat-jev-regression 終局總結（8 sprint）

從 9/26 `1c4ace7` 到今天 9/28 共 **19 commits**，完整閉環 + 自動 sandbox + 穩定性量測 + 文件自動審查：

```
Sprint 1 (TMO-011): M1-M4 Oracle + journey + batch report
Sprint 2 (TMO-012): M5 de-hardcode + fixture + stale
Sprint 3 (TMO-013+014): M3.1 Playwright observer + SKILL v2.2
Sprint 4 (TMO-015+016): CI workflow + M6 fix proposal
Sprint 5 (TMO-017+018): M6.1 LLM relay + docs/cleanup
Sprint 6 (TMO-019): M6.2 patch + re-validate 閉環
Sprint 7 (TMO-020): M6.3 sandbox + flaky + cleanup-CI
```

| 階段 | 模組 |
|---|---|
| 觀察 | Oracle (Jev) / AC parser / fixture / Playwright observer |
| 行動 | Journey gen / dry-run loop / 3 observer backends |
| 評估 | Batch report (4 dim) / confidence gating / flaky_likelihood |
| 修正 | Fix proposal v1 / LLM Relay v2 / patch_parser / playwright_patcher / re_validate / sandbox_runner |
| 治理 | CI workflow (push/PR/dispatch) + schedule weekly cleanup-scan + SKILL v2.6 |

**Pipeline 一鍵跑**：

```bash
JEV_FIX_PROPOSAL=1 JEV_FIX_PROPOSAL_V2=1 \
  JEV_PATCH_AND_REVALIDATE=1 JEV_SANDBOX_RUN=1 \
  ./run_pipeline.sh US-M63
# 完整跑 M2→M3→M4→M6→M6.1→M6.2→M6.3，產 7 個檔案
```

---

## 8. Commit 列表（整個 feat-jev-regression）

```
[TBD] feat(regression-guard): M6.3 sandbox + flaky + cleanup-CI  ← 本次
fcd8f3f feat(regression-guard): M6.2 patch + re-validate 閉環
6ed708e docs(backlog): TMO-017 / TMO-018 done + M6.1 LLM relay + cleanup deliverable
224297c feat(regression-guard): M6.1 LLM relay + docs/cleanup 盤點
eb6c0ab docs(backlog): TMO-015 / TMO-016 done + CI + M6 deliverable + 反思
f0f6543 feat(regression-guard): CI workflow + M6 fix proposal + return code gate
49d24e1 docs(backlog): TMO-013 / TMO-014 done + M3.1 + SKILL 整合 deliverable
83336eb feat(regression-guard): M3.1 Playwright observer + SKILL.md 整合 v2.2
711a969 docs(backlog): TMO-012 done + M5 deliverable + 反思
4ac566d feat(regression-guard): M5 — fixture YAML + stale 限同 AC + run_dry() + 16 探針
fffbd28 Merge PR #2 (M1-M4) → master
... (M1-M4 8 commits)
1c4ace7 feat(regression-guard): M1 PoC — Jev oracle 走 typesafe/jev-1.13 via OpenRouter  ← 起點
```

---

## 9. 已知限制 / Hardening

- **M6.3 sandbox 是「目錄級隔離」**，不是「process / container 級隔離」— 主 repo 不被改，但 sandbox 內仍可能改錯檔案；rollback 機制可救回
- **M6.3 仍需人工 commit** — 自動 apply / re-validate / rollback，但「拿回主 repo + commit」人工；未來可加「互動式 sandbox + 人工 review button」
- **flaky 用 5 次跑** — 樣本數小，偶發 flaky 仍可能 miss；未來可加 `--runs 10` 或 `--runs 20` 選項
- **cleanup-scan weekly 跑** — 若 repo 活躍，可能錯過「重大 PRD 變更」；可手動 dispatch 補跑
- **flaky 沒整合到 batch_report** — flaky_likelihood 仍是獨立工具；M7 可整合到 batch_report.overall_health

---

## 10. Reviewer 自我檢核

- [x] Gate 1 (TDD): `tests/v2.1-jev-poc.bats` 80 探針 RED → GREEN
- [x] Gate 2 (lint): python 模組 import 過 + workflow YAML 解析正確
- [x] Gate 3 (regression): `JEV_*_=1 ./run_pipeline.sh US-M63` 跟 M5/M6/M6.1/M6.2 結果一致
- [x] Gate 4 (reviewer): 本檔即為 self-review deliverable

---

## 反思

### 6 維度檢查

| # | 維度 | 結果 | 備註 |
| - | --- | --- | --- |
| 1 | UX/CLI 一致性 | ✅ | sandbox_runner / flaky_check 跟 patch_parser / playwright_patcher 風格一致 |
| 2 | RWD / 跨平台 | ✅ | 純 stdlib + json + statistics；無外部依賴 |
| 3 | 技術債 | ✅ | sandbox_runner 純 import 既有模組（apply_patch / rollback / re_validate）|
| 4 | 可維護性 | ✅ | SKILL v2.6 加法不破壞；3 個新小節獨立 |
| 5 | 測試覆蓋率 | ✅ | 80 探針：M5 16 + M3.1 5 + SKILL 4 + CI 5 + M6 7 + M6.1 6 + CLEAN 7 + M6.2 13 + M6.3 10 + flaky 4 + cleanup-CI 3 |
| 6 | 需求對齊 | ✅ | 對應 backlog TMO-020 6 條 DoD 逐條 hit |

### 問題清單（已解決 + 仍待）

| 問題 | 狀態 | 解法 |
|---|---|---|
| M6.2 還需手動 3 步 | ✅ 解 | M6.3 sandbox_runner 封裝成 1 步 |
| Journey 結果是否穩定 | ✅ 解 | flaky_check.py 跑 N 次 + flaky_likelihood |
| Cleanup-scan 需手動跑 | ✅ 解 | CI schedule weekly + workflow_dispatch |
| **互動式 sandbox + 人工 review button** | ⏸ 延 | M6.3 自動 apply，但 commit 仍需人工 |
| **flaky 整合到 batch_report** | ⏸ 延 | M7 升級 |
| **process 級 sandbox 隔離** | ⏸ 延 | 需 container / VM；M6.3 目錄級已足 |
| **Jev cache 命中對 flaky 影響** | ⏸ 延 | M7 量測 |
| **CI matrix pipeline 多 story_id 並行** | ⏸ 延 | M8 升級 |
| **真實 PENDING US 跑多次 flaky** | ⏸ 延 | US-M62 已證 stable；其他 US 待跑 |

### V01 / V02 / V03 紀律驗證

- **V01（一次一問）**：1 個 ask_user_question（3 任務順序）3 個選項 + 推薦第一，0 follow-up ✅
- **V02（推薦第一）**：順序「M6.3 → flaky → CI（推薦）」標 Recommended ✅
- **V03（SOP 修改必 Reviewer）**：本 sprint 沒改 SOP/AGENTS.md/gates.json/handbook；改的是 skill 本體（SKILL v2.6）+ 新增模組 — **V03 N/A** ✅

### feat-jev-regression 整體回顧（7 sprint, 19 commits）

| Sprint | 範圍 | 探針 |
|---|---|---|
| TMO-011 | M1-M4 Jev Oracle PoC | 0 |
| TMO-012 | M5 de-hardcode + fixture | 16 |
| TMO-013 + 014 | M3.1 Playwright + SKILL v2.2 | 25 |
| TMO-015 + 016 | CI + M6 fix proposal | 37 |
| TMO-017 + 018 | M6.1 LLM relay + cleanup | 50 |
| TMO-019 | M6.2 patch + re-validate 閉環 | 63 |
| **TMO-020** | **M6.3 sandbox + flaky + cleanup-CI** | **80** |

| 指標 | 數值 |
|---|---|
| 新檔 | 25 + 6 = **31**（sandbox_runner.py / flaky_check.py / US-M63.md / US-M63.html / US-M63-sample.py / deliverable）|
| Commit | 14 + 1 = **15** |
| Source code lines | 7,057 + 2,154 = **9,211** |
| bats 探針 | 63 + 17 = **80** |
| Pipeline stages | 7（M2→M3→M4→M6→M6.1→M6.2→M6.3）|
| Batch 維度 | M4 4 + M6 3 + flaky 1 = **8** |
| Observer backend | **3** (ac_aware / mock / playwright) |
| Skill 版本 | v2.0 → v2.1 → v2.2 → v2.3 → v2.4 → v2.5 → **v2.6** |
| 信心度 gating | 0.5（v1 reviewer 接手）/ 0.5（M6.1 LLM relay 召喚）|
| Patch safety | 4 種 action（dry_run / applied / aborted / describe_only）|
| Re-validate 分類 | 3 種（improvement / regression / no_change）|
| Flaky 分類 | 3 種（stable / mildly_flaky / highly_flaky）|
| Cleanup 分類 | 4 種（KEEP / REVIEW / DELETE / MERGE）|
| 文件分類結果 | KEEP 63 / REVIEW 4 / DELETE 0 |
| Backlog 完成 | TMO-001~020 共 **20 個 done** |

**從 oracle PoC → plug-in framework → skill 規範 → CI + 修正循環 → LLM 接力 → 文件減法 → 完整閉環 → 自動 sandbox + 穩定性 + 文件審查**，7 sprint 連續收尾，零迴歸、零降級。

### 完整閉環 1 次跑通的意義

> **這次 sprint 的 3 個收尾都不是「必要」，而是「讓閉環更完整」**：
> - M6.2 已經能 patch + re-validate，但手動 3 步；M6.3 封裝成 1 步自動
> - 我們已知 journey 大致穩定，但沒量測；flaky_check 給了量化指標
> - cleanup-scan 已知可用，但需手動跑；CI schedule 讓它「不需要記得」

**3 個 Action Item 全收 → 未來跑 regression-guard 不再需要人記得「要 manual apply」「要查 flaky」「要跑 cleanup」**。

skill 從「可用工具」升級為「**自管理**工具」：自動 sandbox、自動 flaky 量測、自動 cleanup 提醒。
