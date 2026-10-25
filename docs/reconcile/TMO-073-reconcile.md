# TMO-073 需求對帳表

> 對帳者: `evidence-auditor` subagent（Gate 4.5 獨立對帳者，**未參與實作**）| 對帳時間: 2026-10-26
> 錨點: docs/req/TMO-073-requirement.md
> 覆蓋率: **2/2**
> 對帳輪次: 第 6 輪（Round 6）；第 5 輪殘餘（「D4 數字區間分支待以可執行證據複核」）本輪已閉合
> 對帳者獨立性: 非降級路徑（未參與本次實作）；對帳者環境**無 shell 執行能力** → 其「指令實際輸出」欄位由
> supervisor 補跑並附於各列「證據」欄（已標明誰取得）

## 對帳表

| 需求 ID | 需求句（摘要） | 狀態 | 實作位置 | 證據 | 備註 |
|---------|---------------|------|---------|------|------|
| R1 | 同一件事在多份文件間的**字面不一致**必須能被機械化抓出，不靠 AI 自省 | ✅ 已實作 | `skills/dav-reconciler/scripts/check-doc-drift.py`（D1..D8 全部實作於 `Checker` 各方法；`main()` 依序呼叫 `check_ac_files` / `check_prd` / `check_reconcile` / `check_deliverable_reconcile` / `check_deliverable_window`（fail-closed：窗內 0 件或 D8 零檢查件 → rc=1；須在 reconcile 之後呼叫）/ `check_deliverables`；rc 契約 0/1/2）；wrapper `scripts/ci/check-doc-drift.sh`；CI 步驟 `.github/workflows/ci.yml`「Verify no document drift (D1-D8)」 | D1=DOC-DRIFT-011｜D2=012｜D3=013｜D4=014/015/023/032/033/035/036/037｜D5=016｜D6=017｜D7=024/025/026｜D8=027/028/029/030/031；rc 契約=008/009/010；白名單 fail-closed=018/019/020；CI 不得假綠=022 + 034（反向自測）；探針總數=**47**（DOC-DRIFT-001..037 + 039..048 逐支點名核對；038 為未使用空號）；mutant=DD-M1/DD-M2/DD-M3/DR-M1（`scripts/ci/mutants.tsv`，CI 步驟「Verify probes still kill mutants」跑全表且 MMD-5 禁止 `--only`/`--list`/`--no-baseline`/`\|\| true`）｜**supervisor 實跑**：`bats tests/doc-drift.bats` → **47/47 綠**；`bash scripts/ci/check-doc-drift.sh --from-date 2026-10-26` → rc=0（15 項檢查、7 項豁免） | 「不靠 AI 自省」成立：8 類全部是**字面/結構比對**（表列比對、編號連續性、ID 集合包含、檔案存在性、狀態字串、R-ID 集合、內嵌 vs 權威表多重集），無任何語意判斷。CI 步驟實讀：`run: bash scripts/ci/check-doc-drift.sh --from-date 2026-10-26`，**無** `continue-on-error` / `\|\| true` / `if:`（DOC-DRIFT-022/034 雙向鎖）。**殘餘（已揭露的設計邊界，非本句條件缺口）**：D5 只比 md/html 的**狀態**、不比內文 → 同檔內「5 類 vs 8 類」這類內文漂移抓不到（本輪實際發生：`docs/ac/TMO-073.html:22` 寫「本 US 做 5 類字面對帳」，同檔 :19 / :24 寫 8 類 → **同一檔自相矛盾**；已直接修正）。補 D9（md↔html 內文關鍵數字同步）屬**新增 scope**，非本句條件缺口 |
| R2 | 探針涵蓋 8 類字面對帳 D1..D8（AC 狀態同步 / AC 編號連續唯一 / 追溯矩陣無幽靈 ID / 交付摘要檔案存在 / md 與 html 狀態一致 / AC 範本 ↔ 需求錨點對應 / 對帳表 R-ID 覆蓋 / 交付摘要對帳段與狀態一致）；存量已知不一致以**帶理由的白名單**豁免，不得誤紅 | ✅ 已實作 | 8 類實作：`check-doc-drift.py` `check_ac_files()`（D1/D2/D5/D6）、`check_prd()`（D3）、`check_reconcile()`（D7）、`check_deliverable_reconcile()`（D8）、`check_deliverables()`（D4）；白名單：`load_whitelist()`（理由空 → rc=2；`<類>#*` → rc=2）＋ `docs/ci/drift-whitelist.txt`（7 筆，每筆帶理由）；防誤紅：`expand_paths()`（`X.md/.html` 與 `X-069~071.md` 兩種簡寫展開）＋ `DEFAULT_FROM_DATE=2026-10-26` | 8 類**逐一對號**（錨點列舉 ↔ 實作方法 ↔ 探針）：①AC 狀態同步=D1/011｜②AC 編號連續唯一=D2/012｜③追溯矩陣無幽靈 ID=D3/013｜④交付摘要檔案存在=D4/014｜⑤md↔html 狀態一致=D5/016｜⑥AC↔需求錨點=D6/017｜⑦對帳表 R-ID 覆蓋=D7/024（+025 狀態值合法、026 已交付必對帳）｜⑧交付摘要對帳段↔權威表=D8/027~031。白名單：018（缺理由 rc=2）、019（全類豁免 rc=2）、020（命中須輸出 `WHITELIST D6 DEMO-001: 存量未回補`）；真實白名單每一筆都帶理由（現 7 筆：D6×5 + D1×1 + D4×1）。防誤紅：009（乾淨 fixture rc=0）、021（本 repo rc=0）、032（副檔名簡寫不誤紅）、035（數字區間簡寫不誤紅）、023/015（from-date 雙向）｜**第 5 輪殘餘已閉合（supervisor 實跑）**：`bats tests/doc-drift.bats -f "DOC-DRIFT-035"` → ok；且 `bats tests/doc-drift.bats` → **47/47 綠**，DOC-DRIFT-035 存在且綠 | **第 5 輪殘餘「D4 數字區間分支本輪才補探針（DOC-DRIFT-035），待對帳者以可執行證據複核」本輪已閉合**：探針存在、邏輯正確、實測綠。**本輪另修掉兩個使本 US 的「不得誤紅／不得假綠」失效的真實缺陷**：①`--from-date` 未驗證格式（比對用**字串**比較 → 傳入 `"bad-date"` 會讓**所有**交付摘要被跳過 → 檢查範圍靜默縮成空集 → **D8 硬門檻被一個 typo 關掉** → 假綠；已實測 `bad-date` → rc=0「OK: 12 項檢查」vs 有效值 rc=0「14 項檢查」）→ 改 `datetime.strptime` 驗證 + **rc=2 fail-closed**，補 DOC-DRIFT-036/037；②探針 RECON-007（`tests/restruct-dav-reconciler.bats`）的解析器在 **BSD grep 2.6** 上只認 2 個交替分支 → 探針本身紅 → `mutant-must-die.py` 的 baseline 迴圈 `die()` → **整個 mutant 表中止** → DD-M1..M3 / DR-M1 四支守護長期處於**失效狀態** → 已改 python3 解析 + 探針註解記錄實測機制（見 changelog v2.12）。**本輪第三個缺陷亦已修**（V03 Reviewer 第 2 輪 P2-3）：RECON-007 原只認 **4 個已知 emoji** → 全新 emoji 的第 5 種狀態值不被擋（**舊實作同樣漏，非本輪引入**）；已依 Reviewer 建議改為**結構式 + 集合等值 + 跨檔守護**（以「表頭第一欄 == 狀態」定位 §4 狀態表 → 集合等值比對 → 並守住 `check-doc-drift.py` 的 `VALID_STATUS` 與規格檔 §4 一致），另新增**反向自測 RECON-016** 與 **mutant DR-M2**（整格變成 `✅ 已實作 🟡 暫緩` → v1.1 會漏、v1.2 會死）。**殘餘（已揭露的設計邊界，僅剩一項）**：D5 只比狀態不比內文（見 R1 備註） |

## 結論

- 2 項已實作、0 項部分實作、0 項未實作。覆蓋率 **2/2**（100%）。
- 錨點列舉的 8 類與實作的 D1..D8 **逐一對號無缺**；白名單 fail-closed（缺理由 / 全類豁免 → rc=2）；
  三個已知誤紅來源（D8 R-ID 全域鍵、D4 路徑簡寫、emoji 位元組）已修且各有反向探針（030 唯一性、032/035 簡寫、022/034 假綠自測）。
- **第 5 輪殘餘已閉合**：DOC-DRIFT-035 存在且**實測綠**（47/47）。
- 對帳者備註: 本輪對帳者沒有 shell 執行能力，判定以實作原始碼 + 探針斷言 + 真實資料檔逐項比對為據；
  指令實際輸出由 supervisor 補跑並與其推演一致。本輪實測另抓出兩個**工具層**缺陷（`--from-date` fail-open、
  RECON-007 解析器壞掉導致 mutant 守護失效）——兩者都讓「本機制真的在跑」這件事**失效**，
  是本 US 條件的實質風險，已閉合并補了反向探針。
- 依 `reconcile-format.md` §7 硬門檻：本 US 全部 ✅ → 本 US 無阻擋項。
