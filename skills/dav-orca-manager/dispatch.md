# Dispatch — 啟動審查 ＋ 切工 ＋ Worktree 策略 ＋ 派工

> 主檔 Step 1–2 嘅細節。命令係常用形；實際旗標以 `orca --help` 同版本對齊嘅指南為準。

## §1 啟動審查（缺一即拒絕啟動）
逐項驗；缺任何一項 → 明講缺咩 ＋ 拒絕啟動（唯一例外：用戶覆核 → trust-log 記低）：
- **大目標**：一句講得出「項目要變成點」
- **Deadline**：具體時間點；冇 → 問一次（唯一允許嘅啟動前提問）
- **Backlog**：`docs/backlog.md` 有 PENDING US，而且每條 US 有可驗收嘅 AC
- **設計覆蓋**：`docs/DESIGN.md`／`docs/system-design.md`／PRD 覆蓋到 PENDING US
- **Orca 可用**：`orca status --json` 通；唔通 → `orca open --json` 再試；`runtime_access_denied` → 提權重跑，唔重啟 Orca
- **時間錨點**：`date` 取 `START_TS`／`DEADLINE_TS`（錨點紀律見同套 `dav-trust` skill）
  → 寫入 `docs/trust-log.md` 檔頭（必含 `> Deadline:`，否則 sleep 守門／fuse 審核／報時全部失效）

通過 → `orca orchestration run-create --objective "<大目標>" --json` → Run id 寫入 `docs/orca-run.md`。

## §2 切工（一個 US 一個 Task）
- **粒度**：一個 PENDING US → 一個 Task；跨模組／跨檔嘅 US 先再拆，但同一 Task 內唔好混兩個 US 嘅 AC
- **Task spec 必含**：US id ＋ 目標 ＋ AC（逐條抄，唔改寫）＋ 檔案／模組範圍 ＋ 禁區 ＋ 完成定義（要交咩證據）
- **切工帳**：US id ↔ Task id 對照寫入 `docs/orca-run.md`
- 建 Task：`orca orchestration task-create --spec "<spec>" --task-title "<US id 標題>" --json`

## §3 Worktree 策略（衝突迴避 ＋ 數額上限 6）
### 數額
- **上限 6 計咩**：同時運行中嘅 worktree 總數 = dev ＋ reviewer ＋ resolver ＋ merge ＋ orca-manager 自己開嘅任何 worktree
- **開之前必數**：`orca worktree ps --json` 數一次；≥ 6 → 唔准開新，排隊（pending 列寫入 `docs/orca-run.md`）
- **留位**：唔好開到 6 就滿 —— 至少留 1 格做 reviewer／resolver（review 同解衝突都要 worktree）；建議 dev 常態 ≤ 4
- **滿額出路（依序）**：① 收已 merged 嘅 ② 收 review pass 待合併嘅 ③ 停最低價值 worker（`worker-stop` ＋ 記 log）④ 等
- **一 Task 一 worktree，完成即收**：唔好留死 worktree 佔額（收法見 `./coordinate.md` §5）

### 衝突迴避（派工之前做，唔係等合併時才做）
- **按檔案擁有權切，唔按功能切**：一個 Task = 一組互斥嘅檔案／模組；同一時間一個檔案只可以由一個 worktree 改
- **派工前盤點**：列出新 Task 預期會改嘅檔案／模組 → 同 in-flight Task 清單比對 → 有交集 → 唔派（縮範圍／改序列／併成一個 Task）
- **共用面特別處理**：API 契約／共用元件／schema／migration／lockfile／config → 同一時間只准一個 worktree 改
- **共用面做法**：先派「介面 owner」Task → review pass → 合併 → 其他 consumer Task 排下一波
- **分波（wave）派工**：同一波內 Task 嘅檔案集合兩兩互斥；有相依 → 下一波；每波數量受 6 格限制（含留位）
- **同波同 base**：同一波嘅 worktree 由同一個 base ref 開（先 `orca repo set-base-ref`），減少漂移
- **失控訊號**：worker 中途要動禁區／共用面 → 佢應該發 `escalation`；收到 → 停同波相關 Task，重排波次（見 `./coordinate.md` §3）

## §4 開 worktree ＋ 派 worker
- **一個 Task 一個 child worktree**：`--worktree new-child --name <kebab-name> --setup run`（Orca 準備好 worktree 才派工）
- **一 worktree 一 writer**：同一 worktree 同時只准一個 agent 寫；要並行就開多個 worktree（避免互相覆蓋）
- **派工**：一個 Task 一個 `worker-start`（命令見下）；`--agent` 揀 codex／claude／…；唔好幾個 Task 塞同一個 worktree
- **起點正確**：先 `orca repo set-base-ref`，令新 worktree 由正確分支開出（唔好幾個 worktree 由唔同起點開）
- **記帳**：start receipt 內嘅 taskId／dispatchId／worktree id 即刻寫入 `docs/orca-run.md`
- **並行上限**：同時 in-flight 嘅 worker 數以「能逐個 review ＋ 序列化合併」為準；寧少莫多

```text
orca orchestration worker-start --task <taskId> --worktree new-child --name <name> \
  --agent <codex|claude|...> --setup run --json
```

## §5 Task brief 模板（寫入 spec 嘅內容）
- **目標**：一句（US 標題 ＋ 為何要做）
- **AC**：逐條抄自 backlog
- **範圍**：可以改嘅檔案／模組；**禁區**：唔准動嘅檔案
- **測試要求**：TDD（先寫測試見紅）＋ 改動範圍內回歸（見同套 `dav-developer` skill）
- **完成訊號**：worker 交貨時自己發（命令見下）；收唔到就當未完成
- **提問**：有阻塞 → `orca orchestration ask --to <coordinator> --question "..." --options "..."`，唔好自己猜
- **禁止**：唔准自己 merge／push 到共用分支；合併權只在 orca-manager

```text
orca orchestration send --type worker_done --task-id <id> --dispatch-id <id> \
  --outcome succeeded --files-modified "<paths>" --json
```

## §6 派工前自檢
- Task spec 有 AC 嗎？冇 AC → 唔派（做唔到 review）
- 呢個 Task 同 in-flight Task 有檔案重疊嗎？有 → 縮範圍或改序列
- 呢個 Task 同 in-flight Task 會爭共用面嗎？會 → 排下一波
- 數過 worktree 未？≥ 6 → 先排隊（唔准硬開）
- worktree 係新開（唔係重用未收嘅）嗎？
- 有冇一個 Task 已經 in-flight 但冇 Task id／dispatch id 紀錄？有 → 先補帳再派下一個
