# TMO-054 需求錨點

> US: TMO-054 | 建立: 2026-10-28（票 2026-10-05 開票，錨點補建）| 來源: NYH-1
> （`docs/need-you-help.md` 已結案索引；原文保留在 git history：`git log -p -- docs/need-you-help.md`）

## 用戶原話（唯讀）

- R1: 「撤銷並輪替 key」（2026-10-05 ask-me 抉擇：撤銷舊 key、產生新 key、更新本機 key 來源；人工操作，Agent 無法代為撤銷）
- R2: 「接受風險、不輪替、保留現狀」（2026-10-05 結案決策：舊 key 續用，`.env` 與 `~/.zshrc` 兩處並存）

## 澄清後驗收句

- R1: 用戶到 OpenRouter 撤銷舊 key、產生新 key，並更新本機 key 來源（PoC `.env` 檔，gitignore 內；或 `~/.zshrc` 環境變數）；
  完成後由 Agent 複驗 sha256 已變 ＋ 新值未出現在任何被追蹤檔／本輪 diff。
- R2: 若用戶決定接受風險，則本票以 ⏸️ 跳過結案：舊 key 續用、兩處並存，不再輪替（本 repo 現況：2026-10-05 起維持此狀態）。

## 背景（非用戶原話；係實測記錄）

| 事實 | 來源 |
|---|---|
| 2026-10-05 做 TMO-045「反向驗證」時，探針 FAIL 訊息把本機真實 `OPENROUTER_API_KEY` 印進 session log（前綴已遮罩，完整值在對話記錄中）| NYH-1 |
| key 沒有入 git（`.env` 被 gitignore、該輪無 push）| NYH-1 |
| 2026-10-05 用戶改以系統環境變數（`~/.zshrc`）提供 key；Agent 比對該值 sha256 與 `.env` 完全相同 ＝ 仍為原洩漏舊 key、未輪替 | NYH-1 結案記錄 |

## 執行約束（repo 既有規則，唔屬驗收句）

- 改 skill／SOP → 依 `AGENTS.md` §1.5 **V03 走獨立 Reviewer 二審**
- 本票為人工項：Agent 只可複驗，不可代為撤銷／發新 key

## 變更歷史

| 日期 | 變更 | 原因 |
|------|------|------|
| 2026-10-28 | 補建錨點 | `docs/ac/` 減磅後唯一未完成 US 需要可對帳嘅 AC 範本 ＋ 錨點（守 DOC-DRIFT-007 空集合 fail-closed ＋ D6 對應關係）|
