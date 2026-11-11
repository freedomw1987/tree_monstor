# Coordinate — 監督迴圈、衝突、Review、合併、收尾

> 主檔 Step 3–6 嘅細節。

## §1 監督迴圈（收訊 → 分流 → 決定 → 記帳）
1. **等訊**：`orca orchestration check --wait --types worker_done,escalation,question --timeout-ms 900000 --json`
2. **處理完一個 Delivery 要 ack**：`orca orchestration check --ack <deliveryId> --wait ...`；`--peek` 可以睇而唔消費
3. **讀訊／查現況**：唔明 worker 狀況 → `worker-show --dispatch <id> --json` ＋ `worker-read --dispatch <id> --limit 50 --json`
4. **分流**：見 §2
5. **記帳**：每輪寫 `docs/orca-run.md`（時間／事件／Task／決定／下一步）
6. **唔准空轉**：`check --wait` 係有內容嘅等待；冇訊而又冇 in-flight worker → 去派下一個 Task，唔好 sleep
7. **數額守門**：每輪順手 `orca worktree ps --json` 數 running worktree；≥ 6 → 先收已 merged 嘅再派新工（策略見 `./dispatch.md` §3）
- **卡住偵測**：worker 長時間冇 `worker_done` 又冇 heartbeat → `worker-read` 睇最後畫面；
  真卡 → `worker-stop --dispatch <id>` 再 `worker-start --retry-of <dispatchId>`（retry 唔繼承 `--on`／worktree，要明寫）
- **釋放**：收貨後 `worker-release --dispatch <id> --json`（封存輸出再關該終端）；要除錯才 `worker-retain`。
  唔好用大範圍 `terminal close` 代替 release

## §2 分流（收到訊之後做咩）
- **`worker_done`（succeeded）** → 標 `ready-for-review` → 派**獨立 reviewer**（§4）；未 review 唔准合併
- **`worker_done`（failed）** → 睇 body 講嘅原因 → 可救就 follow-up dispatch（同 worktree 續派）；救唔到 → 重切 Task 或降級範圍
- **`question`（worker 問）** → **唔轉問用戶**（trust mode）→ 自己決定 ＋ 寫 `docs/trust-log.md`（問題／決策／理由／可推翻標記）；
  再用 `send --to dispatch:<id>` 回覆
- **`escalation`** → 影響範圍大（要改共用介面／加依賴／動禁區）→ 建 decision gate（§6），並暫停受影響 Task
- **`blocked`** → `task-update --id <id> --status blocked --result '{"reason":"..."}'` ＋ 重排序列

## §3 衝突處理（多 worktree 必做）
- **源頭迴避優先**：派工前按 `./dispatch.md` §3 分波／互斥切分；呢度係合併前嘅補救線（源頭做對就唔會行到呢度）
- **合併前偵測**（唯讀，屬 orca-manager 本份）：`orca worktree ps --json` 睇 in-flight；
  `git merge-tree`／`git log --oneline <base>..<branch>`／`git diff --stat` 比對各 branch 改動範圍
- **分類**：① 檔案重疊（同檔同區）② 介面／契約變更（A 改簽名、B 照舊叫）③ 順序相依（migration／schema／lockfile）
- **處理**：
  - ①／② → 派**專責 resolver worker**（獨立 child worktree，base = 最新整合分支）；任務 = 合併 ＋ 解衝突 ＋ 跑回歸 ＋ 交 `worker_done`。
    **唔叫原 worker 自己解**（佢唔知別人改咗咩）
  - ③ → 訂死合併順序（先 schema／migration，後 consumer），序列化執行
  - 無法解（真正設計衝突）→ decision gate ＋ 自己決定（trust）＋ 記 log
- **序列化**：任何時候**只有一個** merge 動作 in-flight；上一個合併 ＋ 回歸綠燈後才開始下一個

## §4 獨立 Review（合併前必做）
- **派工**：為 `ready-for-review` 嘅 Task 開一個**新** reviewer dispatch —— 唔同 worktree、唔同 agent 身份、
  唔可以係原作者（見同套 `dav-reviewer` skill 嘅獨立性要求）
- **Review 範圍**（Gate 4）：① 對照 US 嘅 AC 逐條驗 ② 代碼品質 ③ 測試覆蓋（新行為有探針）④ 改動範圍回歸綠燈 ⑤ 有冇偷動禁區
- **Review 指令**：reviewer 只讀 ＋ 跑測試，**唔准改代碼**；有問題 → 交 `worker_done --outcome failed` ＋ 列出具體問題
- **分流**：pass → 標 `ready-to-merge`（§5）；fail → 退回原 worktree follow-up dispatch（附問題清單）→ 修完再 review
- **唔准**：作者自我 review；reviewer 順手改 code（會令 review 失去獨立性）

## §5 合併 ＋ 收 worktree
1. 序列化取一個 `ready-to-merge` Task
2. 合併入整合分支（orca-manager 落指令；必要時派 merge worker 執行）→ 合併後**即跑回歸**
3. 回歸綠 → 更新 `docs/backlog.md` 該 US 狀態 ＋ `docs/orca-run.md`
4. **收 worktree**：`worker-release --dispatch <id> --json` → `orca worktree rm --worktree id:<id> --force --json`
   （收完即時釋放一格 → `./dispatch.md` §3）
5. 回歸紅 → 唔收 worktree，退回修（回到 §4）
- **例外**：用戶明說要留 → `worker-retain`，並喺 `docs/orca-run.md` 記低原因

## §6 Decision gate（大決定先擋住）
- 用途：影響多個 Task 嘅決定（共用介面／資料模型／依賴）→ `gate-create --task <id> --question "..." --options '["yes","no"]'`
  → 自己決定後 `gate-resolve --id <gateId> --resolution "<...>"`（trust mode：決定寫 trust-log）
- 唔用 gate 做細決定（只會拖慢）；細決定直接回覆 worker

## §7 記帳格式（`docs/orca-run.md`）
- **Run**：id／objective／START_TS／DEADLINE_TS
- **Task 帳**（列表，一個 Task 一段）：US id｜Task id｜Dispatch id｜worktree id／name｜狀態
  （dispatched／review／ready-to-merge／merged／blocked）｜備註
- **事件流**：時間戳 ＋ 事件（派工／收貨／review 結果／衝突／合併／收 worktree）
- 狀態轉移**當下**寫，唔好事後補
