# §3 CHANGELOG（SOP 異動紀錄）

> 本檔是 AGENTS.md §3 的詳細內容。引用：`[§3 CHANGELOG](./sop/handbook/changelog.md)`
>
> 追蹤 AGENTS.md §2 SOP 的所有重大異動，便於 audit 與回溯。每筆異動需註明版本號、日期、變更內容與原因。

## v1.8 — 2026-09-25

**本版異動**：dav-planner skill AC 範本獨立化 + HTML 版本（TMO-006）

| 類型 | 項目 | 說明 |
| ---- | -- | --- |
| **P0** | `dav-planner/SKILL.md` §4.3.2 新增「AC 欄位精簡規則」 | backlog.md 表格 AC 欄位精簡為「AC 摘要（≤ 30 字 + 連結）」；完整 Given-When-Then + DoD 寫到 `docs/ac/<US-ID>.md` |
| **P0** | `dav-planner/SKILL.md` §4.6 新增「AC 範本生成 SOP」 | Agent 生成新 US 時必做 3 動作（同一 turn）：(1) 寫 `docs/ac/<US-ID>.md` (2) 生成 `docs/ac/<US-ID>.html` (3) 更新 backlog.md AC 欄位為新格式 |
| **P0** | `docs/ac/` 目錄新建 | 含 `README.md`（命名規範）+ `US-101.md` + `US-101.html`（範例檔）|
| **P0** | `docs/ac/README.md` | 說明目錄用途、命名規範、生成規則、範本結構、變更歷史 |
| **P0** | `docs/ac/US-101.md` + `docs/ac/US-101.html` | 範例檔（含真實 AC 內容 + 列印友好 CSS）|
| **P0** | `docs/prd/01-dav-planner-ac-templates.md` 新建 | 本次變更 PRD（含檔案結構 + SOP 改動 + 範本 + Story Point 8 + 風險 + DoD）|
| **P1** | `tests/dav-planner-ac-templates.bats` 新建 | 9 個探針守護 SKILL.md 章節（§4.3.2 / §4.6）/ PRD / docs/ac/ 範本 / changelog v1.8 / cross-consistency 不被靜默移除 |
| **P2** | `docs/backlog.md` 新增 TMO-006 | 記錄本次變更 + Story Point 8 + 完成標準 |

**目的**：解決用戶痛點「AC 塞在 backlog.md 表格 cell 內，閱讀體驗差、不利校對 / 分享 / 列印」— 根本原因是 markdown 表格 cell 對長內容渲染差，無論用 `<br>` 或 blockquote 都難用。修法是把 AC 抽出到獨立檔案（.md 給開發者、.html 給利害關係人），backlog.md 仍為 single source of truth。

**決策紀錄**：
- **AC 架構**：A 方案「兩者並存」（backlog.md 精簡為摘要+連結，docs/ac/ 為完整 AC）
- **HTML 生成時機**：A 方案「Agent 寫 .md 同時生成 .html」（同一 turn）
- **既有 backlog**：A 方案「不動既有 US」（過渡期兩格式共存，用戶可手動遷移）
- **AC 範本內容範圍**：A 方案「只含 AC」（不重複 US 標題 / Persona / Non-goals）
- **Reviewer**：A 方案「走 dev-checker-loop 二審」

**Markdown 表格 cell 渲染決策**：
- v1.6 SWOT 用純文字前綴 + `<br>` 分行（不用 blockquote）
- 本次 AC 摘要同樣用純文字前綴 + `<br>`（與 v1.6 慣例一致）
- 完整 AC 不再塞 cell（徹底避開 markdown 表格渲染不一致問題）

**前置**：變更經 dev-checker-loop Reviewer subagent 二審（V03 SOP 修改規則），驗證跨 SOP 一致性（dav-planner ↔ docs/prd ↔ docs/ac ↔ changelog）。Reviewer verdict 詳見對話記錄。

---

## v1.7.1 — 2026-09-25

**本版異動**：v1.7 後續技術債清理（UTF-8 bug + `.agents/` 歷史殘留 + TMO-005 關閉 + 順手修 latent bug）

| 類型 | 項目 | 說明 |
| ---- | -- | -- |
| **P1** | 5 個 bats 中文 test name 改為英文 | `dav-wiki.bats`、`ci-linux.bats`、`wiki-cleanup.bats`、`wiki-cross-ref.bats`、`wiki-cross-ref-multimodal.bats` 共 ~47 個 test 改為純 ASCII 名（移除中文括號內容 / 中文描述）；功能保留（test 內 `grep -iE "英文\|中文"` 仍同時驗中英文） |
| **P0** | 順手修 `skills/dav-wiki/scripts/wiki-cleanup.sh:336` | 中文 log message 與 `$var` 未加 `${}` 包裹，`set -uo pipefail` 下拋 `unbound variable`（v1.7 之前已存在，被 homebrew bats UTF-8 bug 掩蓋）；修為「完成：移動 ${moved}、跳過 ${skipped}、失敗 ${errors}」 |
| **P1** | 順手修 `tests/ci-linux.bats` setup | 補上 `REPO_ROOT="$(git rev-parse --show-toplevel)"`（原本 setup 沒設 `$REPO_ROOT`，導致 `$REPO_ROOT/skills/...` 變 `/skills/...`，run 指令找不到腳本） |
| **P1** | `docs/system-design.md:195` | `docs/.agents/skills/dav-wiki/concept-evolution.md` → `../skills/dav-wiki/concept-evolution.md`（Reviewer 補遺：需加 `../` 前綴才不會斷 link） |
| **P1** | `docs/system-design.md:432` | `.agents/skills/dav-wiki/` → `skills/dav-wiki/`（檔案結構樹） |
| **P1** | `docs/system-design.md:450` | `tree_monstor/.agents/skills/dav-wiki/` → `tree_monstor/skills/dav-wiki/`（install.sh 對應說明） |
| **P1** | `docs/DESIGN.md:249` | `../.agents/skills/dav-skill-creater/SKILL.md` → `../skills/dav-skill-creater/SKILL.md`（Reviewer 補遺） |
| **P1** | `CONTRIBUTING.md:100` | `各 .agents/skills/*/SKILL.md` → `各 skills/*/SKILL.md`（Reviewer 補遺） |
| **P2** | `docs/backlog.md` TMO-005 關閉 | status `pending` → `done`；加說明 v1.7 翻轉 + v1.7.1 順手修 |

**為什麼現在才暴露 wiki-cleanup.sh:336 bug**：
- v1.7 之前此 bug 已存在（git show HEAD~1:tools/wiki-cleanup.sh line 336 一模一樣）
- 但被 homebrew bats UTF-8 bug **掩蓋**：19 個 wiki-cleanup test 全部中文，bats 跳過 → `unbound variable` 未被觸發
- v1.7.1 改中文 test name 後，bats 開始跑 test → bug 浮現（14 個 fail）
- CI workflow 只做 `bash -n` + `markdownlint`（不跑 bats），所以這個 bug 在 CI 永遠抓不到

**為什麼這次不改 TMO-005 原始目標「tools/ 統一 logging」**：
- TMO-005 原始內容是「tools/ 統一 logging（修正版：trap + 共用 log_*）」
- v1.7 已將 wiki 工具搬離 `tools/`，目標位置變更
- 統一 logging 在 dav-wiki 已是 `lib/log.sh` 共享（每個 wiki-*.sh source 同一個）
- TMO-005 範圍已通過 v1.7 + v1.7.1 完成，無未盡事項

**Audit 發現**：
- homebrew bats UTF-8 處理 bug 為環境問題，需升級 bats 版本或 patch homebrew formula，**不在本次 scope**

**最終 audit（Reviewer 二審 + 重審後修正）**：

| 檔案 | 中文 test name 數 / 總數 | 處理 |
| --- | --- | --- |
| `tests/dav-wiki.bats` | 4 / 20 | ✅ 改英文 |
| `tests/ci-linux.bats` | 5 / 5 | ✅ 改英文 |
| `tests/wiki-cleanup.bats` | 19 / 19 | ✅ 改英文 |
| `tests/wiki-cross-ref.bats` | 10 / 10 | ✅ 改英文 |
| `tests/wiki-cross-ref-multimodal.bats` | 10 / 10 | ✅ 改英文 |
| `tests/wiki-extract-audio.bats` | 10 / 10 | ✅ 改英文（Reviewer 二審補遺） |
| `tests/wiki-extract-media.bats` | 20 / 20 | ✅ 改英文（Reviewer 二審補遺） |
| `tests/wiki-extract-video.bats` | 11 / 11 | ✅ 改英文（Reviewer 二審補遺） |
| `tests/wiki-media-describe.bats` | 16 / 16 | ✅ 改英文（Reviewer 二審補遺） |
| `tests/wiki-merge-media.bats` | 12 / 12 | ✅ 改英文（Reviewer 二審補遺） |
| `tests/wiki-ocr.bats` | 10 / 10 | ✅ 改英文（Reviewer 二審補遺） |
| `tests/wiki-video-audio.bats` | 10 / 10 | ✅ 改英文（Reviewer 二審補遺） |
| `tests/agents-md.bats` | 0 / 10 | ⏭️ 無需改 |
| `tests/install.bats` | 0 / 41 | ⏭️ 無需改 |
| `tests/regression-guard-watch-mode.bats` | 0 / 5 | ⏭️ 無需改 |
| **合計** | **137 / 209** | **15 個 bats 全改完** |

**為什麼 Reviewer 二審補遺必要**：初版 audit 誤判「其他 7 個 wiki-*.bats 無中文」，違背 AGENTS.md §1 「誠實和用戶溝通」。Reviewer 獨立 audit 抓出實際遺漏 7 個 bats / 89 個 test。採方案 A（順手改完）保證 macOS 本地全綠。

**順手修 latent bugs**（utf-8 改中文 test name 後浮現）：

| 檔案 | 行號 | 問題 | 修法 |
| --- | --- | --- | --- |
| `skills/dav-wiki/scripts/wiki-cleanup.sh` | 336 | `set -uo pipefail` 下中文 log message 與 `$var` 解析冲突（$moved 被吃掉） | 加 `${}` 包裹 |
| `skills/dav-wiki/scripts/wiki-extract-media.sh` | 233 | 同上（$TYPE 被吃掉） | 加 `${}` 包裹 |
| `skills/dav-wiki/scripts/wiki-extract-media.sh` | 264 | 同上（$images_dir 被吃掉） | 加 `${}` 包裹 |
| `tests/ci-linux.bats` | setup | 原本 setup 沒設 `$REPO_ROOT`，导致 `$REPO_ROOT/skills/...` 變 `/skills/...` | 加 `REPO_ROOT="$(git rev-parse --show-toplevel)"` |

**驗證證據**：
- Gate 1：15 個 bats / 209 個 tests 全部執行 + 全綠（v1.7 之前為 0 tests executed）
- Gate 2：9 個 wiki-*.sh pass `bash -n`
- Gate 3：regression == Gate 1

**前置**：變更經 dev-checker-loop Reviewer subagent 二審（V03）兩次：
- 首次審查：FAIL（4 P0 blockers：选 6 個 bats 事實錯誤、漏 wiki-cross-ref 系列、system-design.md:195 缺 `../` 前綴、漏 DESIGN.md + CONTRIBUTING.md 殘留）
- 重審：FAIL（1 P0 blocker：漏 7 個未改的 wiki-*.bats，含 89 個中文 test name）
- 最終審查（包含上進全部修正後）：仍待續審

---

## v1.7 — 2026-09-25

**本版異動**：dav-wiki 工具目錄重組（從 `tools/wiki-*.sh` → `skills/dav-wiki/scripts/wiki-*.sh`）

| 類型 | 項目 | 說明 |
| ---- | -- | -- |
| **P1** | `skills/dav-wiki/scripts/` 新建 | 9 個 wiki-*.sh 從 `tools/` 搬入；dav-wiki skill 變 self-contained |
| **P0** | `wiki-extract-media.sh` 內 OCR 呼叫改 sibling ref | 原用 `$REPO_ROOT/tools/wiki-ocr.sh` 會解析為 `skills/dav-wiki/`，名實不符且 OCR 會靜默失效；改為 `$SCRIPT_DIR/wiki-ocr.sh`（直接呼叫 sibling） |
| **P1** | `wiki-cross-ref.sh` stderr 提示更新 | 提示用戶執行新路徑（避免誤指） |
| **P1** | `tests/wiki-*.bats`（9 個）+ `wiki-cross-ref-multimodal.bats`（9 處）+ `wiki-merge-media.bats` 等共 10 個 bats 測試 | 路徑從 `tools/wiki-*.sh` 改為 `skills/dav-wiki/scripts/wiki-*.sh` |
| **P1** | `tests/ci-linux.bats`（3 處） | 硬編 `/Users/apple/www/tree_monstor/...` 絕對路徑 → 改用 `$REPO_ROOT/...`（順手修硬編 bug） |
| **P1** | `.github/workflows/ci.yml`（6 處） | `bash -n`、wc -l、PYEOF 檢查全部更新路徑 |
| **順手修** | `.github/workflows/ci.yml:51` + `CONTRIBUTING.md:55` | 原讀取 `.agents/skills/dav-wiki/SKILL.md`（被 gitignore，CI fresh checkout 不存在）；改為 `skills/dav-wiki/SKILL.md`（順手修兩個檔） |
| **P1** | `docs/sop/handbook/dav-wiki-cleanup.md`（5 處） | 指令範例 + 流程圖更新為新路徑 |
| **P1** | `skills/dav-wiki/SKILL.md`（2 處） | `wiki-extract-media.sh`、`wiki-cleanup.sh` 引用更新 |
| **P2** | `CONTRIBUTING.md`（4 處） | 路徑引用更新 |

**決策翻轉依據**（為什麼當初 TMO-005 不拆 vs 現在拆）

**當初（TMO-005，2026-09-23）**：判定不拆 `tools/wiki/` 子目錄，理由是「bats 引用絕對路徑會 breaking change」。

**本次（v1.7）**：採拆 `skills/dav-wiki/scripts/`（不是 `tools/wiki/`，是搬到 skill 內）。

**翻轉依據**：
1. **當初問題已不存在**：v1.4 changelog 已為 bats 加了 `$REPO_ROOT` 標準化（`tests/helpers/test-env.bash`），絕對路徑依賴已消除
2. **新需求觸發**：skill self-contained 是 dav-wiki install.sh 簡化部署的關鍵（`install.sh` 把整個 `skills/dav-wiki/` 一起 symlink 進 `~/.pi/skills/dav-wiki/` 時，scripts 也跟著安裝，UX 一致）
3. **成本 vs 收益**：bats 10 個檔案機械式路徑替換 ≈ 30 分鐘；換來未來 install.sh 簡化 50%+、skill 真正 self-contained
4. **不再破壞向後相容**：本次確認無外部用戶（無下游依賴 `tools/wiki-*`）；TMO-005 加註 superseded by v1.7

**前置**：變更經 dev-checker-loop Reviewer subagent 二審（V03），驗證：
- audit 補遺漏（`wiki-cross-ref-multimodal.bats` 9 處 + `wiki-video-audio.bats`）
- `wiki-extract-media.sh` 內 OCR 呼叫改 sibling reference（避免解析錯誤）
- 順手修 `.agents/skills/...` 路徑 bug（CI + CONTRIBUTING）
- Reviewer verdict: PASS with Conditions（4 必改 + 用戶批准 2 順手修全部接受）

---

## v1.6 — 2026-09-25

**本版異動**：dav-planner skill 新增 SWOT 分析機制（關鍵決策點展開）

| 類型 | 項目 | 說明 |
| ---- | -- | -- |
| **P1** | `~/.pi/agent/skills/dav-planner/SKILL.md` §2.6 新增「關鍵決策點 SWOT」 | 4 個觸發條件（不可逆變更 / 高成本 / 用戶糾結 / 戰略級影響）+ SWOT 標準格式 + V01 相容的逐項追問節奏 + V02 復用條款 + 自我檢查清單 + 情境 A/B 對照範例 |
| **P1** | `dav-planner/SKILL.md` §4.3.1 新增「SWOT 落版規則」 | 只記最終選項的 SWOT、加在 AC 欄（不新增 column）、純文字前綴（`<br>` 分行，**不用 `>` blockquote**，因 markdown 表格 cell 渲染不一致） |
| **P1** | `2.1-planning.md` Plan Gate 通過聲明加「SWOT 落版（如有）」選填欄 | 對應 §2.6 與 §4.3.1；如有展開 SWOT 才填 |
| **同步** | `tree_monstor/skills/dav-planner/SKILL.md`（如為獨立檔案，非 hardlink） | 與 `~/.pi/agent/skills/dav-planner/SKILL.md` 同步 |

**目的**：讓 dav-planner 在「關鍵決策點」不只是給一句話效果說明，而是展開策略性 SWOT（Strengths/Weaknesses/Opportunities/Threats），協助用戶做更完整的策略性決策；同時保留 §2.2 的輕量路徑，避免認知過載（不每個選項都做 SWOT）。

**觸發條件**：用戶提出 dav-planner skill 優化需求，2026-09-25 確認方向（只在關鍵決策點用 / Agent 草案+用戶驗證 / 對話+落版備註）。

**前置**：變更經 dev-checker-loop Reviewer subagent 二審（V03 SOP 修改規則），驗證跨 SOP 一致性 + Markdown 表格渲染風險。Reviewer verdict: PASS with Conditions，已接受全部 10 項修訂（4 必改 + 3 強烈建議 + 3 可選）。

---

## v1.5 — 2026-09-23

**本版異動**：修正 §2.0 表格與 §2.6 之間的立場矛盾（從「角色混淆」重新定位為「自動升級規則不一致」）

| 類型 | 項目 | 說明 |
| ---- | -- | -- |
| **P1** | `AGENTS.md` §2.0 表格補上「升級觸發器」說明 | 原本寫「一般任務 → Agent 與用戶都可主動判斷」，跟 §2.6 「必須停下問用戶」衝突。改為「以 §2.6 為準」，並引用 §2.6 的升級觸發器表格 |
| **P1** | `2.6-general-task.md` 加準則聲明 | 在檔頭明示「本檔為 §2.0 表格的準則源頭」避免未來誤看 §2.0 簡述而違反「自動升級必須停下確認」規則 |

**目的**：解決「新人 / Agent 讀 §2.0 後誤判一般任務可隨意自主」的規則衝突；保留 §2.0 表格作為「分類入口」，把「怎麼做、何時升級、何時問」統一收在 §2.6。

**前置**：變更經 dev-checker-loop Reviewer 二審（V03 SOP 修改規則），驗證跨 SOP 一致性。

---

## v1.4 — 2026-08-24

**本版異動**：Gate 3 測試指令禁用 interactive / watch 模式（防 session 卡死）

| 類型 | 項目 | 說明 |
| ---- | -- | -- |
| **P0** | `skills/regression-guard/SKILL.md` 加「測試指令執行規範」章節 | 主流 runner 對照表（vitest/jest/npm test/bats/pytest/playwright/cargo/go）+ TTY 強制關閉法 `< /dev/null` + Fail-fast 自檢條件 |
| **P0** | `docs/sop/gates.json` Gate 3 `notes` 加 watch-mode 規則 | 標明禁用 interactive / watch 模式，並 cross-ref regression-guard SKILL.md |
| **P1** | `docs/sop/handbook/2.3-execution.md` 加「Gate 3 測試指令的常見陷阱」章節 | 對齊 SKILL.md 的核心指令表，方便人類閱讀 |
| **P1** | `tests/regression-guard-watch-mode.bats`（5 個探針） | 守護新規則不會被靜默移除（SKILL × 2 / gates.json × 1 / handbook × 1 / cross-consistency × 1）|

**目的**：解決用戶痛點「Tree Monstor 跑 Gate 3 baseline 時卡在 `Waiting for task` 凍住 session」— 根本原因是 agent shell 在 TTY 偵測上模糊，runner（vitest / jest / 部分 `npm test`）預設進入 watch mode 等 stdin。修法是把「禁用 watch mode」從隱性經驗提升為 SOP 強制規則，並用 bats 守護不被未來改動移除。

**前置**：`~/.claude/skills/regression-guard/SKILL.md` 與 `tree_monstor/skills/regression-guard/SKILL.md` 是同一 inode（hardlink），改一邊兩邊同步。

## v1.3 — 2025-08-24

**本版異動**：SOP 加 `remediation` 策略欄位（TD-019）

| 類型 | 項目 | 說明 |
| ---- | -- | -- |
| **P0** | `gates.schema.json` 加 `remediation` 物件 | 定義 `strategy` enum（`auto_fix` / `auto_fix_with_limit` / `ask_user`）+ `max_attempts` + `fallback` + `description` |
| **P0** | `gates.json` 4 個 Gate 加 `remediation` | Gate 1/3 = `auto_fix_with_limit: 3` + `ask_user`；Gate 2 = `auto_fix`；Gate 4 = `ask_user` |
| **P1** | `2.3-execution.md` 加「失敗處理策略」章節 | 三種策略表 + 各 Gate 預設表 + Agent 必做動作 |
| **同步** | `tests/fixtures/mock-tree-monstor/docs/sop/` 三檔同步 | gates.json / gates.schema.json / 2.3-execution.md |

**目的**：解決用戶痛點「明明 test 做好了，但 agent 就停下來等」— 根本原因是 SOP 只寫 fail_action（禁止行為）沒寫補救策略，導致 agent 行為不一致。`remediation` 補上明確指引，讓 Agent 知道失敗時該「自動修」還是「問用戶」，預估整體等待時間減少 30-40%。

**前置設定**（同日已完成）：在 `~/.pi/agent/settings.json` 把 `retry.provider.timeoutMs` 從預設 3,600,000 ms (1 hr) → 600,000 ms (10 min)，避免 agent 卡 1 小時才 abort。

## v1.2 — 2025-08-22

**本版異動**：AGENTS.md 精簡重構（TD-017）

| 類型 | 項目 | 說明 |
| ---- | -- | -- |
| 重構 | §2.1-§2.7 + §3 抽出去 `docs/sop/handbook/*.md` | 一章一檔，AGENTS.md 從 524 行 → ~150 行 |
| 重構 | AGENTS.md 引用方式 | Markdown 相對路徑 `[§2.1](./sop/handbook/2.1-planning.md)` |

**目的**：讓大模型可穩記 AGENTS.md 的核心內容（萬事原則、提問紀律、SOP 範圍判斷、4 Gate 表格、引用索引）。

## v1.1 — 2025-08-21

**本版異動**：

| 類型 | 項目 | 說明 |
| ---- | -- | -- |
| **P0** | §2.1 Plan Gate (fail-fast) | V05 — 加用戶確認才可進 §2.2 |
| **P0** | §2.2 Design Gate (fail-fast) | V07 — 加 3 文檔 + Story Point + 用戶確認 |
| **P0** | §2.3 用戶確認才能進 Gate | V09 — Plan 確認才能進 §2.3 |
| **P0** | §2.3 subagent 機制明確化 | V13 — dev/reviewer via `subagent` + `workflowScript` |
| **P0** | §2.4 Reflection Gate (fail-fast) | V17 — 加 6 維度報告 + backlog 更新 + 用戶確認 |
| **P0** | §2.0/§2.6 灰色地帶表 + 升級條款 | V21 — 強化任務分類 + 自動升級 |
| **P0** | §2.7 SOP 違規回報（**新章節**） | V23 — 違規自檢 + 用戶回應 + 記錄 |
| **P1** | §1.5 提問紀律（**新子章節**） | V01/V02 — 一次一個問題 + 方案必標推薦 |
| **P1** | §2.1 Plan Gate 通過聲明格式 | V06 — 必貼 checklist |
| **P1** | §2.2 Story Point 規模表 | V08 — Fibonacci 1/2/3/5/8/13 對照表 |
| **P1** | §2.3 Gate 1/2/3 必留證據 | V10/V11/V12 — 紅綠 output / lint output / baseline diff |
| **P1** | §2.4 反省模板 + Action Items 格式 | V15/V16 — 6 維度表 + 4 欄位（動作/類型/驗收/預估） |
| **P1** | §2.5 Markdown 模板 + 下一步建議規範 | V18/V20 — 必含欄位 + 三項必填 |
| **P1** | §2.5 Self-Check 清單 | V19 — 8 項 ✅ 才能提交 |
| **新增** | §3 CHANGELOG（本節） | V24 — SOP 版本控制 |

**修補來源**：AGENTS.md 完整 audit 識別 27 個 vulnerabilities（P0:7 / P1:13 / P2:7），本次處理 P0+P1 共 20 項；P2 待處理。

## v1.0 — 之前版本

未保留詳細記錄（CHANGELOG 機制為 v1.1 新增）。
