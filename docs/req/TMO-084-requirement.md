# TMO-084 需求錨點

> US: TMO-084 | 建立: 2026-10-27 | 來源: 用戶決策（CI 定位 ＋ 本機閘）

## 用戶原話（唯讀）

- R1: 「CI 降級為『偵測器』＋ 落地本機等價閘」（2026-10-27 用戶決策，見 `docs/backlog.md` TMO-084 列）
- R2: 同一決策嘅第二要素：本機閘必須 **fail-closed**（任何一步失敗 → 整體非 0；禁止 `|| true` / `set +e`）
- R3: 同一決策嘅第三要素：閘要有**守門探針**，而且**雙向**對齊 ci.yml ↔ 本機 runner
- R4: 同一決策嘅第四要素：放寬閘屬規範改動 → 依 `AGENTS.md` §1.5 **V03 必須走獨立 Reviewer 二審**
- R5: 同一決策嘅第五要素：必須**誠實記錄代價**（CI 原本捉到而本機捉唔到嘅跨 OS／跨版本差異，改由「通知」而非「阻擋」）
- R6: 「regression-guard 的 ci 在本地跑都得，不用在 github 上跑」（2026-10-27 用戶補充決策）—— 即 **regression-guard 專屬嘅 CI 連「偵測器」都唔做**，完全搬返本機

> ⚠️ 本票嘅用戶原話係**決策摘要**（由執行者按用戶指示整理），非逐字引錄。
> 決策三要素：① 本 repo 係**平時自用嘅技能庫** → CI **唔再係完成條件**；
> ② **刻意唔開** branch protection（CI 紅都 merge 得，係**有意識**嘅選擇而唔係「未設定」）；
> ③ 閘改為**本機**：探針全綠 ＋ lint 0 issue ＋ mutant 全死 ＋ Reviewer 二審。

## 澄清後驗收句

- R1: 必須有一條**一條指令**跑齊本機閘（步驟同 CI 一致），而且**唔會同 CI 漂移**
  （ci.yml 嘅 step 名、markdownlint glob、doc-drift `--from-date` 全部**執行時從 ci.yml 抽**，唔硬編）。
- R2: 本機閘必須 **fail-closed**：任何一步失敗 → 整體非 0；**禁止** `|| true` / `set +e` 類 fail-open。
- R3: 必須有**守門探針**證明本機閘唔會假綠，並且**雙向**對齊 ci.yml ↔ 本機 runner
  （CI 有嘅 step 本機冇 → 紅；本機有嘅 CI 冇 → 紅）。
- R4: 閘嘅放寬（CI 由閘變偵測器）屬**規範改動** → 依 `AGENTS.md` §1.5 **V03 必須走獨立 Reviewer 二審**。
- R5: 必須**誠實記錄代價**：CI 原本捉到而本機捉唔到嘅跨 OS／跨版本差異，改由「通知」而非「阻擋」。
- R6: regression-guard 嘅 CI 必須**完全喺本機跑**：
  ① 有一條**本機**指令承擔原本 workflow 嘅全部 job（探針／pipeline／多 story 矩陣／cleanup-scan）；
  ② **return code gate 語義不變**（綠 0／黃 2／紅 1）→ 紅燈真係要擋；
  ③ 原本嘅 GitHub Actions workflow **必須刪除**（唔准「兩邊都留」→ 兩邊都會漂移）；
  ④ 目標專案想自己用 GitHub Actions 嘅教學要保留（連 secrets／branch protection 設定）。

## 背景（非用戶原話；係 TMO-084 開票時嘅實測）

| 事實 | 來源 |
|---|---|
| CI 係 clean clone（攞唔到未版控檔）| TMO-039 CI 首跑實測 |
| shellcheck apt 0.9 vs 本機 0.11 嘅 SC2002 差異 | TMO-039 |
| macOS runner bash 3.2 令 31 條測試被**靜默丟棄** | TMO-074 |
| clean clone 缺未版控 fixture 令 34 條紅 | TMO-039 |
| 本 repo 冇開 branch protection（CI 紅都 merge 得）| 實測 GitHub 設定 |

⇒ 呢啲係**你部機結構上捉唔到**嘅環境差異 → CI 仍有價值，但唔應該再係「完成條件」。

## 執行約束（repo 既有規則，唔屬驗收句）

- 新增／修改 `tests/**/*.bats`（探針）→ 依 `AGENTS.md` §1.5 **V03 走獨立 Reviewer 二審**（本次**明確放寬咗閘**，必須二審）。
- 新增 shell 腳本必過 `scripts/ci/lint-shell-var-nonascii.py`（`$var` 緊接非 ASCII → bash 3.2 吞字節）。
- 新增守門機制必補 mutant（閘本身要受保護）。
- 探針名全 ASCII（PNA-1）；fail-fast 慣例（PNA-4）。

## 變更歷史

| 日期 | 變更 | 原因 |
|------|------|------|
| 2026-10-27 | 初版 | 用戶決策（CI 降級為偵測器 ＋ 本機等價閘）整理成錨點；背景含 TMO-039／074 嘅實測事實 |
| 2026-10-27 | 加 R6 | 用戶補充決策：「regression-guard 的 ci 在本地跑都得，不用在 github 上跑」→ 本票範圍由「repo 通用 CI」擴到「regression-guard 專屬 CI」 |
