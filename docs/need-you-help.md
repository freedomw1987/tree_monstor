# 需要你決定的事（trust mode 期間累積）

> trust mode run：2026-10-05 01:21–08:00（本地分支 `trust/2026-10-05-tmo-cleanup`）
> 規則：不中斷、不 push；遇爭議採保守預設並寫在這裡。

## NYH-1（⚠️ 建議你行動）

**事件**：02:41 做 TMO-045 的「反向驗證」時（故意把 `JEV_ENV_FILE` seam 改成半套實作，
確認探針咬得住），探針的 FAIL 訊息把**本機真實的 `OPENROUTER_API_KEY`** 印進了本次 session log
（開頭 `sk-or-v1-7472…`，完整值在對話記錄中）。

**影響**：
- 沒有進 git（`.env` 被 gitignore、本輪也不 push）；洩漏面僅限「本次對話／session log」。
- 但 session log 可能被同步或保存 → 保守估計應視為已洩漏。

**最推薦**：到 OpenRouter 撤銷並重新產生該 key，再更新 `PoC/.env`。
（我沒有動 `.env` 內容；輪替前後 sha256 一致。）
**替代**：若該 key 本來就只在本機、你接受風險，可選擇不輪替。

## NYH-2

**待決（P3 建議，未實作）**：是否把「探針 FAIL 訊息不得印出密鑰」做成通則
（例：`_load_api_key()` 回傳值在測試輸出前遮罩）。目前只有 CLEAN-POC-i 的失敗訊息會印值。
未實作原因：屬新規範、需 V03 二審，且與本輪 5 張票無關。

## NYH-3

**待決（push）**：本輪所有 commits 都在本地分支 `trust/2026-10-05-tmo-cleanup`，**沒有 push**
（trust 底線規則）。其中 TMO-044 動到 `.github/workflows/ci.yml`（CI 行為），
本輪只能做「本地等價驗證」，**無法在真 CI 驗證**。交付後要不要 push 讓 CI 跑，由你決定。
