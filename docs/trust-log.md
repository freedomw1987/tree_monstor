# Trust Log — TMO-021/022 (M7 + M8) trust mode run

> 期間：2026-09-28 (1 個 sprint)
> Agent 在 trust 模式下自主完成；用戶叫停 / deadline 到才退出
> 底線：不可 push master/main（結束前跟用戶確認） / 不可發外部指令

---

## 2026-09-28 啟動

| # | 時間 | 階段 | 問題 / 決策 | 理由 | 可推翻 |
|---|------|------|-----------|------|--------|
| 1 | 00:30 | 啟動 | Trust Mode 啟動：M7 + M8 + commit + 結束前確認 push | 用戶明確說「可以用 trust mode」+ 「之後 git commit push」（含 push 確認）| — |
| 2 | 00:30 | M7 設計 | flaky_likelihood 整合到 batch_report 哪個維度？ | 選 **overall_health** 維度（新增 `flaky_health` 子欄位）— 因為 flaky 是整體健康指標，跟 real_bug/flaky_likelihood 並列更直觀；alternatively 可加進 flaky_likelihood 維度本身（已有），但整體健康更關鍵 | ✅ |
| 3 | 00:30 | M7 設計 | `gh pr comment` 用哪個 action？ | 選 `actions/github-script@v7`（直接 inline script 推 PR comment）— 因為不需額外 token，PR 自動有 GITHUB_TOKEN | ✅ |
| 4 | 00:30 | M7 設計 | PR comment 內容結構？ | 4 段：journey 標題 / 信心度 gating / fix proposal 摘要 / sandbox 建議 — 每段 ≤ 3 行，避免 comment 太長 | ✅ |
| 5 | 00:30 | M7 設計 | PR comment 失敗時怎辦？ | `continue-on-error: true` + warning log（不中斷 CI）— 因為 comment 是 best-effort | ✅ |
| 6 | 00:30 | M7 設計 | flaky_likelihood 來源？ | 跑 3 次（不跑 5 次省 CI time）取 verdict 分布算 flaky_likelihood — 3 次是 minimum 樣本能算 stdev | ✅ |
| 7 | 00:30 | M7 設計 | flaky 整合到 batch_report 的判斷 threshold？ | ≥ 0.20 = highly_flaky → 標 `⚠️` 在 overall_health；< 0.20 = 正常 | ✅ |
| 8 | 00:30 | M8 設計 | CI matrix 用什麼 strategy？ | `fail-fast: false` + `matrix.story_id: [US-101, US-M62, US-M63]` 3 個並行 — fail-fast: false 避免一個 fail 全部 cancel | ✅ |
| 9 | 00:30 | M8 設計 | matrix trigger 條件？ | 只在 `workflow_dispatch` 觸發（不 push/PR）— 因為 push/PR 跑 3 個 journey 太慢 | ✅ |
| 10 | 00:30 | M8 設計 | matrix 結果聚合？ | 每個 story_id 產獨立 report + artifact，整體用 `aggregate-matrix-reports` step 合併 — 簡單直觀 | ✅ |
| 11 | 00:30 | M8 設計 | matrix timeout？ | 30 min/job（單跑 1 journey ~10-15s，3 個 30s；留 buffer） | ✅ |
| 12 | 00:30 | 命名 | M7 模組檔名？ | `flaky_integration.py`（整合進 batch_report）+ `gh_pr_comment.py`（推 PR comment）— 兩個獨立模組 | ✅ |
| 13 | 00:30 | 命名 | M8 workflow 檔名？ | 沿用 `regression-guard-jev-poc.yml` 加 matrix job（不開新 workflow）— 因為已 weekly schedule 跑，matrix 加進去更簡潔 | ✅ |
| 14 | 00:30 | 探針 | 預計加幾個探針？ | M7 ~12 個（flaky integration 6 + gh_pr_comment 6）+ M8 ~6 個（matrix 結構）= 共 18 個（80 → 98）| ✅ |
| 15 | 00:30 | 探針 | 探針守護 ASCII 命名？ | 全 ASCII（`flaky-int-` / `gh-pr-` / `M8-`）— 避免 homebrew bats 1.14.0 UTF-8 bug | ✅ |
| 16 | 00:30 | 提交 | 預計分幾個 commit？ | 1 個 M7 commit + 1 個 M8 commit + 1 個 docs commit = 共 3 個 — 跟過去 sprint 模式一致 | ✅ |
| 17 | 00:30 | 提交 | push 策略？ | 結束前停下跟用戶確認（trust 底線 #2 不可自動 push master）— 用戶已說「之後 git commit push」表示同意 push，但 trust 仍確認一次 | ✅ |

---

## 2026-09-28 進度（執行中）

| # | 時間 | 階段 | 進度 |
|---|------|------|------|
| 18 | 00:31 | M7 規劃 | ✅ PENDING US-M71 created + 4 ACs |
| 19 | 00:32 | M7 執行 | ✅ flaky_integration.py 寫完 |
| 20 | 00:33 | M7 執行 | ✅ gh_pr_comment.py 寫完 |
| 21 | 00:34 | M7 執行 | ✅ pipeline 整合 + JEV_GH_PR_COMMENT=1 |
| 22 | 00:35 | M7 探針 | ✅ 12 個 M7 探針全綠 |
| 23 | 00:36 | M7 探針 | ✅ 80 → 92 探針全綠 |
| 24 | 00:37 | M7 文件 | ✅ SKILL v2.7 + examples + deliverable |
| 25 | 00:38 | M8 規劃 | ✅ PENDING US-M81 created + 4 ACs |
| 26 | 00:39 | M8 執行 | ✅ workflow matrix job 加好 |
| 27 | 00:40 | M8 執行 | ✅ aggregate-matrix-reports step |
| 28 | 00:41 | M8 探針 | ✅ 6 個 M8 探針全綠 |
| 29 | 00:42 | M8 探針 | ✅ 92 → 98 探針全綠 |
| 30 | 00:43 | M8 文件 | ✅ SKILL v2.8 + examples + deliverable |
| 31 | 00:44 | 提交 | ✅ git commit M7 + M8 + docs (3 commits) |
| 32 | 00:45 | 退出 | ⏸️ 跟用戶確認 push |

---

（繼續累積中…）
