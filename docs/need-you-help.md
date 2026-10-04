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
（trust 底線規則）。其中 TMO-044 / TMO-042 / TMO-041 動到 `.github/workflows/ci.yml`（CI 行為），
本輪只能做「本地等價驗證」，**無法在真 CI 驗證**。

**最推薦 A：push 這條分支讓 CI 真跑一次** — 原因：這是本輪唯一「本地證明不了」的部分
（bats 釘版後 git clone 安裝、ffmpeg step 雙平台、lint job 真擋）；代價：分支會上遠端（可事後刪）。
- **B：先不 push，等你把 verdict／P 項修完再一次 push** — 少一次 CI 噪音，但驗證時點延後。
- **C：不 push，改成你自己在本機 merge** — 零遠端風險，但 CI 語意永遠沒被真實驗證。

## NYH-4

**待決（TMO-035，文實矛盾）**：`skills/dav-wiki/SKILL.md:94-95` 寫「未安裝時降級為純文字模式」，
但三支腳本（`wiki-extract-media.sh` / `wiki-extract-video.sh` / `wiki-ocr.sh`）的 `require_tool()`
是硬 `exit 4`，**沒有降級路徑**。

**最推薦 A：改文件對齊現實（只動 SKILL.md 文字，不動行為）** — 原因：零行為風險、矛盾立即消失；
代價：拿掉「降級」這個承諾（若你其實想要降級，就得選 B）。此案要走 V03 二審。
- **B：實作降級模式**（缺工具 → 只出文字層 + 警告、exit 0）— 功能變更，要新探針＋新測試，工作量 M。
- **C：維持現狀** — 不推薦：下次 reviewer 會再抓一次同一條。

**保守默認（trust 期間照此辦理）**：**不修改任何檔案**，只記錄在此（改 skill 語意需你點頭）。

## NYH-5

**待決（TMO-040，護欄邊界）**：`setup-venv.sh` 的 `POC_VENV_DIR` guard 只擋 `/`、`/tmp/` 這類；
指到合法但危險的目錄（例：`$HOME`、`/private/tmp`，≥2 層絕對路徑）＋ `--force` 仍會 `rm -rf`。

**最推薦 A：危險清單（`$HOME` 本體、`/private/tmp`、`/usr`…）＋ `--force` 需輸入目錄名二次確認** —
原因：保留自訂目錄能力，同時擋掉最常見手滑；代價：`--force` 互動語意改變（CI 用 `--yes` 需一併豁免）。
- **B：只允許「不存在」或「看起來像 venv（有 `pyvenv.cfg`／`bin/python`）」的目錄** — 更嚴，
  但會擋掉「先給一個空目錄」這種合法用法。
- **C：不動程式，只在 README 加警告** — 最便宜，但護欄等於沒有。

**保守默認（trust 期間照此辦理）**：**不修改**（破壞性路徑語意屬你的決策），只記錄在此。
