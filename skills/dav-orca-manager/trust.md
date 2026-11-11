# Trust — orca-manager 嘅 trust 綁定

> orca-manager 預設以 trust mode 行（見同套 `dav-trust` skill）。適用於主檔 Step 1 同全程。

## §1 綁定（同 dav-trust 一致）
- **前提**：大目標 ＋ deadline ＋ backlog（US 含 AC）＋ 設計覆蓋 —— 缺一即拒絕啟動
- **錨點**：啟動時 `date` 取 `START_TS`／`DEADLINE_TS`，對話明示「Trust Mode 啟動 ＋ 兩個錨點」
- **必寫 trust-log 檔頭**：`docs/trust-log.md` 頭要寫 `> Deadline: YYYY-MM-DD HH:MM:SS ±HHMM`
  （範本 → 同套 `dav-trust` skill 嘅 `examples/trust-log-formats.md` §1）—— 機械層（sleep 守門／fuse 審核／每 30 分鐘報時）
  全部靠呢行認 trust mode，冇寫 = 全部失效
- **不問用戶**：歧義／選型／命名／合併順序／衝突取捨 → 自己決定 ＋ 寫 `docs/trust-log.md`
- **代答格式**：時間戳 ＋ 問題 ＋ 決策 ＋ 理由 ＋ 可推翻標記
- **唯一可問**：缺 deadline；危險操作（見 §4）—— 問之前先寫 log 解釋為何要問

## §2 orca-manager 特有嘅代答位
- 邊個 Task 先派／後派（優先序）
- worker agent 揀邊個（codex／claude／…）＋ 模型／effort
- 衝突取捨（邊邊讓路）＋ 合併順序
- review fail 之後：退回修 vs 降級範圍 vs 放棄該 Task
- worktree 收唔收、Task 標 blocked 嘅理由

## §3 接力（對應 dav-trust 嘅 L1–L3）
- **L1**：當前 Task 隊列做完 → 即刻由 backlog 認領下一個 PENDING US 切 Task 派工
- **L2**：全 PENDING 做完 → 重訪 ⏸️ 待確認，能用保守做法補上就切 Task（設計缺口造成嘅 ⏸️ 唔喺範圍）
- **L3**：仍剩時間 → 對齊 `docs/` 預先規劃自主擴量（backlog 標 `🆕 自主擴量` ＋ trust-log）
- **deadline 硬上限**：剩 < 10% 主動收斂，唔再開新 Task

## §4 停手底線（違反 = 退出 trust）
- 唔發外部指令（email／課金／推送／付費 API）
- 唔改不可逆文件（push main／改 production）
- 唔擅自改 deadline
- 危險操作：記 trust-log ＋ 停下等用戶

## §5 收尾 ＋ 續跑
- **收尾**：全完成或 deadline 到 → 先收齊 in-flight worker（`worker-stop` 或等佢交貨）＋ 收 worktree
  → 交付（見同套 `dav-reviewer` skill）→ 輸出 `🏁 Trust Mode 已結束`
- **續跑**：崩潰／壓縮後 → 讀 `docs/trust-log.md` ＋ `docs/orca-run.md` ＋ `orca orchestration task-list --json`
  重建「邊個 Task 喺邊個狀態」→ 先對帳（orphan worker／死 worktree）再繼續
- **暫停**：用戶叫「暫停」→ 只輸出 `⏸️ Trust Mode 已暫停（可續跑）`，唔退出身份；in-flight worker 要記低喺 orca-run.md
- **唔准等時間**：嚴禁 `sleep`／空轉；冇 in-flight → 派下一個 Task
