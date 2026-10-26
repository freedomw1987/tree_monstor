# TMO-082 需求對帳表

> 對帳者: 獨立 Reviewer subagent（V03 二審，**未參與實作**）| 對帳時間: 2026-10-26
> 錨點: docs/req/TMO-082-requirement.md
> 覆蓋率: **2/2**
> 對帳者獨立性: 非降級路徑（未參與本次實作）
> 對帳狀態: **第一輪判 R1／R2 = ⚠️ 部分實作 → 已按發現修正 → 第二輪覆核：R1／R2 全部子句 = ✅ 已實作**（第一輪修正清單見交付摘要 §7.1、第二輪清單見 §7.2）

## 對帳表

| 需求 ID | 需求句（摘要） | 狀態 | 實作位置 | 證據 | 備註 |
|---------|---------------|------|---------|------|------|
| R1 | 必須先量測現況再減磅；目標係 agent 每次觸發 skill 嘅 context 成本（唔係 repo 總行數）；不得犧牲任何被探針錨定嘅內容契約 | ✅ 已實作 | `scripts/ci/check-framework-weight.py`（量度同守門）、`docs/ac/TMO-082.md`（AC02/AC03）、`docs/deliverable/2026-10-26-context-slim-framework-weight.md` §2.2／§5.2 | **量測（同一把尺、前後兩個版本）**：context 總量（SKILL.md + 支援 .md，唔含 CHANGELOG）**9,619 → 7,413 行（−2,207，−22.9%）**；支援檔 7,950 → 5,743（−27.8%）；框架／產品比 3.0063 → 2.9203（−3.1%）。**契約零損失**：14 條被錨定嘅字串／段落結構／檔案存在性清單見交付摘要 §5.2，逐條由對應探針守住 | ⚠️ 第一輪二審指出「headline 數字用咗兩套口徑（前含 CHANGELOG、後唔含）→ 推導唔出」→ **已修正為同一口徑**。⚠️ 已知邊界：「context」用**行數**做代理（token 更準但唔可審核）；且係**上界**（agent 實際只讀主檔 + 被指標指向嘅子檔）。⚠️ 未錨定嘅教學內容**有被刪**（Jev Oracle 四種輸出嘅樣本正文）→ 已於交付摘要 §6 如實記錄 |
| R2 | 必須同時交付瘦身同防回潮；減磅後要有可量度嘅守門並接入 CI；守門必須自己都有探針證明會紅（超預算／死指標／子檔被掏空／枚舉壞咗／ratio 超標）；且唔准假綠（不得 `\|\| true` / `continue-on-error`） | ✅ 已實作 | `scripts/ci/check-framework-weight.py`、`docs/ci/framework-weight.json`、`tests/framework-weight.bats`（FW-1..016）、`.github/workflows/ci.yml`、`CONTRIBUTING.md` | **守門三層**：①context 預算（per-skill cap ＋ 總量 cap）②指標完整性（明確指標 `./xxx.md` ＋ **庫存檢查**：skill 目錄內任何 .md 被掏空／被刪除都報）③框架／產品行數比 ratchet（baseline 2.9203 ＋ tolerance 0.05）。**16 支探針**逐個壞情境實測會紅：FW-3 超預算／FW-4 死指標／FW-5 子檔掏空／FW-6 枚舉壞咗（防空過）／FW-7 ratio 超標／FW-8 冇 `skills/` rc=2／FW-9 CI 接線與假綠／FW-10 自我證明 context 檢查真係有做／FW-11 怪路徑唔會量成 0／FW-12 裸名引用嘅子檔被掏空／FW-13 子檔被刪除／FW-14 支援檔之間嘅死指標／FW-15 cap 被設成 0（fail-closed）／FW-16 產品層 0 行（ratio 冇分母）。CI step **無** `\|\| true`、**無** `continue-on-error` | ⚠️ 第一輪二審判 **P0**：ratio baseline 喺「新檔未入 git index」嘅視角量出 → 落檔後守門會紅、CI 會擋住所有 PR → **已修**（先 `git add -A` 再量，出處寫入 `_baseline_說明`）。⚠️ 第一輪二審另指出「指標完整性只捉 `./` 形式」＋「cap/baseline 被設成 0 會靜靜哋失效」＋「product=0 時 ratio 恆真」→ **已修**並各加一支探針。⚠️ 殘留邊界（已誠實記錄）：改 `docs/ci/framework-weight.json` 嘅 cap／baseline **可以改成一個更大嘅合法值**（屬規範改動、應走 V03，但無機械證明）→ 見交付摘要 §7.4 |

## 結論

- 2 項已實作、0 項部分實作、0 項未實作。覆蓋率 **2/2**（100%）。
- **第一輪曾判 ⚠️ 部分實作**（硬門檻：唔可以宣告「完成」）→ 依 15 項發現修正後，第二輪覆核 = ✅ 已實作。
- **門檻一個都冇放寬**：`SKILL.md ≤ 150 行` 未動、mutant 表 **58 支未動**（本票冇改任何既有探針）、
  `.bats` 檔數地板未動；本次**只新增**上限（per-skill cap / 總量 cap / ratio baseline）。
- ⚠️ **一項要誠實記低嘅例外**：ratio baseline 本身**更新過一次**
  （由「未落檔視角」嘅 2.8127 改成「落檔後」嘅 2.9203）——
  原因同出處寫在 `docs/ci/framework-weight.json` 嘅 `_baseline_說明`；
  呢個係一次性基線設定，之後只可下不可上。
- 本票嘅實質產出除咗 context 瘦身（−22.9%）同三層守門，仲有**三條被記錄落嚟嘅知識**：
  ① 「framework／產品比」**唔可以直接做硬上限** —— 加探針（安全網）會推高比值 → 必須用 baseline + tolerance 嘅 ratchet；
  ② 量度工具自己都會有「掃唔到就當 0」嘅病 —— 本次實測踩到並加咗 FW-11 鎖住；
  ③ **量基線必須喺「檔案已落盤（staged / committed）」嘅狀態量** —— 否則量到嘅係舊視角，守門會喺交付一刻轉紅（本次 P0 實例）。
- 範圍外（用戶明確唔選，本票唔做）：治理文件收斂（B）、衍生膨脹上限（C）、token 化 context 預算 → 見交付摘要 §7.4。
