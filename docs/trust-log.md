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

---

# Trust Log — TMO-037/042/043/044/045（清上一輪留下的 5 張票）

> 期間：2026-10-05 01:21 → 08:00 CST（deadline 用戶指定）
> Agent 自主完成；中途不問問題（歧義自答 + 寫本 log；爭議寫 docs/need-you-help.md）
> 底線：**不 push、不動 production** → 本輪所有 commit 留在本機分支 `trust/2026-10-05-tmo-cleanup`

## 2026-10-05 啟動

| # | 時間 | 階段 | 問題 / 決策 | 理由 | 可推翻 |
|---|------|------|-----------|------|--------|
| 1 | 01:21 | 啟動 | Trust Mode 啟動：清 TMO-043 / 044 / 045 / 042 / 037 | 用戶「trust mode 清上面的 tmo」+ 指定 deadline 08:00 CST | — |
| 2 | 01:21 | 啟動 | 執行順序 043 → 044 → 045 → 042 → 037 | 先小後大；**TMO-037（markdownlint 全面改行）必排最後**，否則前面票新增的長行會被重複改寫 | ✅ |
| 3 | 01:21 | 啟動 | push 策略：不 push（底線規則 #1/#2）→ 開本機分支 `trust/2026-10-05-tmo-cleanup` | trust 禁止外部指令；代價：TMO-044（CI 語意）無法用真 CI 驗收 → 改用「CI 等價本機驗證 + 步驟可被探針直接執行」補償 | ✅ |
| 4 | 01:25 | 規劃 | TMO-037 的 273 處是否全部硬改行？ | **先量測規則分佈再定**：表中/code block 的 MD013 由 `.markdownlint-cli2.jsonc` 豁免（tables:false / code_blocks:false）→ 只處理真違規；若某類豁免是「合理約定」則維持全域豁免並在文件說明，**不以關規則取代改文** | ✅ |
| 5 | 01:25 | 規劃 | 5 張票的交付物策略 | 1 份合併 deliverable（`docs/deliverable/2026-10-05-trust-tmo-cleanup.md`）+ 5 個 commit（每票一個，含探針與文件） | ✅ |

## 2026-10-05 進度（執行中）

| # | 時間 | 階段 | 進度 |
|---|------|------|------|
| 6 | 01:38 | TMO-043 規劃 | 現場掃描（shellcheck 全 severity）：不只 `probe_metadata`，另有 `ext_pattern`（**真 bug**：批次不吃 mode 過濾）＋2 個未用常數 |
| 7 | 01:40 | TMO-043 執行 | 決策：`ext_pattern` 修正為依 mode 建 `find` 條件（行為改變＝真修 bug，附 AC-D17/D18）；`EXIT_TOOLMISSING` in ocr 保留＋註記（exit 4 契約歸 TMO-035）；media-describe 改用該常數 |
| 8 | 01:44 | TMO-043 探針 | ✅ WDC-1/WDC-2 新增（修前紅：`wiki-extract-video.sh: probe_metadata`）；AC-D17/18 修前紅、修後綠 |
| 9 | 01:46 | TMO-043 Gate 3 | ✅ 全量 521 ok / 0 not ok（原 517 + 4） |
| 10 | 02:05 | TMO-044 執行 | 新 `scripts/ci/check-python-heredocs.sh`（ast.parse，不執行）；剔除自家掃描器假陽性（註解行的 `python3` + `<<EOF` 被誤判）→ 加「略過註解行 + `<<` 前需空白」兩道界線 |
| 11 | 02:08 | TMO-044 探針 | ✅ H1-H5（含 3 突變：語法錯／未結束／只有註解假 heredoc）；H5 修前紅（ci.yml 未呼叫） |
| 12 | 02:10 | TMO-044 決策 | 為何從 `wiki-cleanup.yaml` 檢查改為「抽 heredoc」：原檢查連目標檔都不存在；且只驗 5/9 個 heredoc；改 ast.parse 後語意真檢查且零額外依賴（stdlib） |
| 13 | 02:12 | TMO-044 Gate 3 | ✅ 全量 526 ok / 0 not ok（+5） |
| 14 | 02:35 | TMO-045 執行 | `JEV_ENV_FILE` seam（取代整份候選清單）＋ M6-g/M6.1-c 自身封 `.env`；CLEAN-POC-f 一般化為「動態挑檔 × 整檔離線重跑」（v2.1 全 100 條綠）；新增 CLEAN-POC-h / CLEAN-POC-i |
| 15 | 02:41 | TMO-045 敏感度證明 | ✅ 清空 cache-fixtures → M6.1-c/M6-g 紅、外層 CLEAN-POC-f 紅（`diff -r` 還原一致）；`git add -f .env`+cache → CLEAN-POC-h 紅（`.env` sha256 前後一致）；「半套 seam」突變 → CLEAN-POC-i 紅 |
| 16 | 02:44 | ⚠️ 事件：key 洩漏到 session log | 反向驗證時 CLEAN-POC-i 的 FAIL 訊息印出了本機真 `OPENROUTER_API_KEY`（前綴 sk-or-v1-7472…）。未進 repo（只在本地 session log），但**建議輪替該 key**；已記入 need-you-help.md |
| 17 | 02:47 | TMO-045 Gate 3 | ✅ 全量 528 ok / 0 not ok（+2）；新改 .md markdownlint 0 issues |
