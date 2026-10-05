# Backlog — tree_monstor 5 條優化（Trust Mode）

> 來源：2026-09-23 用戶對話「in tree_monstor 現在你覺得什麼地方可以優化？」→「全部 #1 至 #5 都做」
> 模式：Trust Mode（deadline 2026-09-23 10:03）

---

## Backlog 清單

| ID | 主題 | 優先級 | 點數 | 狀態 | 依賴 |
|----|------|--------|------|------|------|
| TMO-001 | 清 .gitignore RSI 殘留 + 刪 .agents/tree_monstor/ 髒副本 | P0 | 1 | done (2026-09-23) | — |
| TMO-002 | install.sh 拆 lib/install/*.sh 子模組 | P1 | 5 | done (2026-09-23) | TMO-001 |
| TMO-003 | 補缺 wiki bats + 修 README badge 數字 | P2 | 3 | done (2026-09-23) | TMO-002 |
| TMO-004 | AGENTS.md §2.0/§2.6 重構 + Reviewer 二審 | P0 | 5 | done (2026-09-23) | TMO-001 |
| TMO-005 | tools/ 統一 logging（修正版：trap + 共用 log_*） | P2 | 3 | done | TMO-001 |
| TMO-006 | dav-planner AC 範本獨立化 + HTML 版本 | P1 | 8 | done | TMO-001 |
| TMO-007 | dav-planner 用戶背景收集機制（§2.7） | P1 | 8 | done | TMO-006 |
| TMO-008 | 減法：文件產出物精簡（v2.0） | P1 | 5 | done | TMO-007 |
| TMO-009 | 重結構：9 skill + AGENTS.md 任務導航 + 純文字引用 | P1 | 25 | done | TMO-008 |
| TMO-010 | docs/ 批量減法：5 檔、53KB（孤立檔 + 存量 HTML + 存量反思）| P1 | 3 | done (2026-09-26) | — |
| TMO-011 | regression-guard skill 升級：Jev Oracle PoC（M1-M4 feat-jev-regression）| P1 | 8 | done (2026-09-28) | — |
| TMO-012 | M5 PoC 去 hardcode 化：fixture config + stale 限 AC + CLI 重構 + bats 探針 | P1 | 8 | done | TMO-011 |
| TMO-013 | M3.1 Playwright Chrome driver 整合 | P2 | 5 | done | TMO-012 |
| TMO-014 | SKILL.md 整合：user-journey-as-test-spec 規範 | P1 | 3 | done | TMO-013 |
| TMO-015 | CI 整合：GitHub Actions + return code gate + branch protection SOP | P1 | 5 | done | TMO-013 |
| TMO-016 | M6 修正循環：Jev fix proposal CLI + SKILL.md Step 4 整合 | P1 | 3 | done | TMO-015 |
| TMO-017 | M6.1 LLM Relay：skill 本身 LLM 接力寫 fix 文字 | P1 | 5 | done | TMO-016 |
| TMO-018 | docs/cleanup 盤點腳本 + 套用减法 | P1 | 3 | done | TMO-017 |
| TMO-019 | M6.2 patch + re-validate 自動閉環 | P1 | 8 | done (2026-09-28) | TMO-017 |
| TMO-020 | M6.3 互動式 sandbox + flaky 驗證 + cleanup CI 定期 | P1 | 13 | done (2026-09-28) | TMO-019 |
| TMO-021 | M7 flaky→batch_report 整合 + gh pr comment | P1 | 5 | done (2026-09-28) | TMO-020 |
| TMO-022 | M8 CI matrix pipeline (多 story_id 並行) | P1 | 5 | done (2026-09-28) | TMO-021 |
| TMO-023 | 修 v2.1-jev-poc C 類探針 bug（8 紅：sandbox baseline fixture / flaky batch fixture / 缺 `run` / `ls` dotfile 假斷言）| P0 | 5 | done (2026-10-04) | — |
| TMO-024 | README 精簡（288→90 行）+ 導向 AGENTS.md / skills + 新增 docs/install-reference.md | P2 | 3 | done (2026-10-04) | — |
| TMO-025 | 修 B 類 12 紅：pptx 文字改用 python-pptx（修靜默假成功）+ 裝 poppler + 新探針 AC-E21/E22 + CI 依賴 | P1 | 5 | done (2026-10-04) | TMO-023 |
| TMO-026 | 修 A 類 12 紅：探針 retarget 到 skill 拆檔後的新家（+3 條 CJK 靜默假綠探針復活）| P1 | 5 | done (2026-10-04) | TMO-025 |
| TMO-027 | 廢棄守門：dav-planner §2.7 用戶背景收集（用戶已決策廢除）5 條探針轉負向斷言 | P2 | 3 | done (2026-10-04) | TMO-026 |
| TMO-028 | `skills/dav-wiki/SKILL.md` 151 → **129 行**（V03.5 強制 ≤130）：輸出結構/軟刪除細節移子檔 + 指標存在探針 + 版本漂移鎖 | P2 | 3 | done (2026-10-04) | TMO-026 |
| TMO-029 | venv bootstrap：`PoC/requirements.txt` + setup 腳本 + CI trigger `[main, master]` + 探針「缺 venv 就大聲紅、靜態測試不誤紅」；驗收=本機 506/506（CI 首跑全綠待 TMO-039）| P1 | 3 | done (2026-10-04) | TMO-026 |
| TMO-030 | 廢除麵包屑補齊：`docs/prd/02` 頂部加「已廢棄」狀態塊 + `docs/prd/03:104` **移除**已廢除的 §2.7 引用（該檔與 §2.7 無關，**不加**麵包屑）+ backlog TMO-007 詳細段加註 | P2 | 2 | done (2026-10-05) | TMO-027 |
| TMO-031 | `skills/dav-planner/SKILL.md:73` 殘留舊步驟名（「背景收集 / 最終目的」→ 現行 Step 1/2）| P2 | 1 | done (2026-10-05) | TMO-027 |
| TMO-032 | 探針精準化：`refute_file_contains` 加檔案存在檢查（根除假綠）+ 負向斷言排除變動歷史列 + v1.9 條目改列級錨定 + BACKLOG-005 大寫 `PENDING` 漏抓 | P2 | 3 | done (2026-10-05) | TMO-027 |
| TMO-033 | dav-wiki 子檔內容錨點：`output-structure.md` 需含 `_index.json`/`_tags.json`/`_concepts.json`/`transcript.md`；`soft-delete.md` 需含 `deprecated_at`/`--older-than`/`--purge`（現僅 existence 鎖，子檔被掏空仍綠）| P2 | 2 | done (2026-10-05) | TMO-028 |
| TMO-034 | 清同源死引用（指向已刪的 `docs/sop/handbook/dav-wiki-cleanup.md`）：`wiki-cleanup.sh:3`/`:39`、`CONTRIBUTING.md:48`（原 4 處，其中 `ci.yml:50` 已由 TMO-029 移除該 step）| P2 | 1 | done (2026-10-05) | TMO-028 |
| TMO-035 | 文實矛盾對齊：`SKILL.md:97`「未裝時降級為純文字模式」vs 三支腳本 `require_tool()` 硬 `exit 4`（無降級路徑）→ **已決策改文對齊現實**（2026-10-05）：①`SKILL.md` 限制表改寫為「未裝就停（`exit 4` + 安裝提示），不降級成純文字」＋標明 OCR mock 為唯一例外；②順帶修掉第二個同源矛盾：`wiki-ocr.sh` usage 原寫「4 必要工具缺失」但全檔無 `exit 4` 路徑（缺 tesseract 走 mock）→ usage 改 0/1/2 ＋移除無呼叫點的 `EXIT_TOOLMISSING` 死常數；③新探針 `tests/wiki-toolmissing-contract.bats`（WTM-1~9：隔離 PATH 實跑 rc=4＋安裝提示；audio 不留任何痕跡、media 會留空目錄但不留部分產出（pdf/docx/pptx 三條安裝提示都鎖）＋SKILL.md 限制表與 OCR usage 的靜態鎖）；④文件不再把 Whisper/Vision 歸成「缺工具」——它 real 模式未實作且失敗回 rc 0（假成功），另開 TMO-058 追蹤 | P2 | 3 | done (2026-10-05) | TMO-028 |
| TMO-036 | 跨目錄探針覆蓋缺口：`restruct-zero-cross-read.bats` 動詞表不含 `grep`＋清單硬編 9 檔（漏 `ask-me`，新增 skill 靜默漏掃）| P2 | 2 | done (2026-10-05) | TMO-028 |
| TMO-037 | 清 markdownlint 債（2026-10-05 實測 **270 錯 / 127 檔**；主類 MD013 201、MD047 20、MD056 9、MD038 8、MD031 7…）——**已清到 0**，並移除 lint job 的 `continue-on-error`（恢復阻擋）；新增守門探針 `tests/markdownlint-guard.bats`（MLG-1..9：job 存在 / 不得假綠 / glob 不得縮小 / MD013 上限鎖 120 / fixture 在範圍內 / lint job 不得有 `if:`）；手法＝`--fix` 機械修 52 + 折行 247 行 + 手改 MD056/MD036/MD025/MD028 共 16 處（12 檔） + 順手清 3 筆 shellcheck info 級 | P2 | 8 | done (2026-10-05) | TMO-029 |
| TMO-038 | 探針強化：`poc-bootstrap.bats` ① 掃描範圍放寬到縮排（函式內 optional import）與子目錄 `.py`、加 module→dist 映射；④ 靜態不變式的 helper 清單目前硬編 3 個（新增 helper → 漏抓）；⑤ CI 契約由字串改 PyYAML 語意斷言（含 `workflow_dispatch` 鎖、step 需排在 `bats tests/` 前）**→ 已修（2026-10-05）**：①改 AST 遞迴掃描＋`PoC-OPTIONAL-DEP` 行內標記制（含反向鎖）、④helper 自動列舉、⑤新增 1 條 PyYAML 語意斷言（trigger／矩陣／步驟次序／不得吞錯；缺 PyYAML 大聲紅不 skip）| P2 | 3 | done (2026-10-05) | TMO-029 |
| TMO-039 | 首次真實 GitHub Actions 驗證（首跑 `37213235272` 全 job 紅 → 6 類真因；第二輪 `37215560458` **34 紅收斂到 4 紅** → 再揭露 2 類：①oracle 依賴假綠 3 條 ②macOS ffmpeg 8 移除 `-vsync`；第三輪修法見 §TMO-039 詳細；**第三輪 run `37218446930` ubuntu+macos test job 全綠**，僅 lint-only 紅＝TMO-037；**reviewer round-3 `approve-with-comments`（0 P0 / 0 P1 / 6 P2）**，前輪 5 P2 全數收尾，本輪 P2 已修 3 條／切票 TMO-044、TMO-045；**用戶決策「收在此」→ 結案**，收尾 run `37219489118` 亦綠）| P1 | 3 | done (2026-10-04) | TMO-029 |
| TMO-041 | 環境等價／「本機假綠」殘餘防線：①macOS 預設 bash 3.2 對「已宣告空陣列」做長度展開不報錯、CI bash 5.2 在 `set -u` 下會 unbound（今日靠 `brew bash` 手動重現，未自動化）→ 需 bash 5.x 變體 Gate 3；②`bats` 未釘版（ubuntu apt 1.10 vs brew 1.14，`@test` 名稱/旗標行為有差）；③其他狀態依賴尚未掃完——reviewer round-3 具體點名：真網路未封鎖、`PoC/.env`（`__file__` 旁，非 `HOME`）、固定 `/tmp` 檔名跨 run 殘留、`bats`/`bash` 版本、`gh`/`brew` 工具未 stub（①已涵蓋版本項） **→ 已修（2026-10-05）**：新增 `tests/env-equivalence.bats`（ENV-EQ-1..7：bash 5.x 必需、「每個本機 bash 版本」都跑 `wiki-cleanup` 套件、shim 有效性、空陣列×`set -u` 逐版本量測、固定 `/tmp` 殘留鎖、`gh`/`brew` 執行鎖、網路黑洞＋canary）；②CI 兩平台把 bats-core 釘在 `v1.14.0`（git clone tag 取代 apt/brew 未釘版）＋契約探針加釘版斷言；③reviewer 點名的 4 個狀態依賴全部落地（真網路＝ENV-EQ-7、`PoC/.env`＝TMO-045 既有 seam、固定 `/tmp`＝鎖 1＋56 處改 `$BATS_TEST_TMPDIR`、`gh`/`brew`＝鎖 2） | P2 | 3 | done (2026-10-05) | TMO-039 |
| TMO-042 | 媒體探針未鎖 ffmpeg 版本 → **已修（2026-10-05）**：新增 `scripts/ci/check-ffmpeg-version.sh`（①版本底線 ≥5.1 ②用本 repo 真的在用的旗標組合 `-vf select/showinfo` + `-fps_mode vfr` + `-f null -` 實測能力③缺 ffmpeg/ffprobe 即紅；`FFMPEG_BIN`/`FFPROBE_BIN` 可覆寫供測試）；ci.yml test job 兩平台都跑（bats 之前）；CONTRIBUTING 寫明底線、CI 實測版本與「移除/改名清單」（`-vsync` → `-fps_mode`）；新探針 `tests/ffmpeg-version.bats` FV-1..FV-7（含假殼舊版 4.4.2 / 5.0 / 旗標失效 / 缺工具 / CI 靜態鎖 / 文件鎖） | P2 | 2 | done (2026-10-05) | TMO-039 |
| TMO-043 | 死碼清理（原：`probe_metadata()` SC2329）——擴大為系統性掃描後共 3 處：①`wiki-extract-video.sh` `probe_metadata()` 刪除；②`wiki-media-describe.sh` `ext_pattern` **算完未用＝真 bug**（批次未依 mode 過濾，describe 會誤吃 .wav、transcript 會誤吃 .png）→ 修正 + 新探針 AC-D17/D18；③`wiki-ocr.sh` `EXIT_TOOLMISSING` 保留並註記（exit 4 契約屬 TMO-035 決策——**TMO-035 後續決策：該常數改為移除**，因 OCR 根本沒有 exit 4 路徑，見 `wiki-ocr.sh` v2.2.1 註解）；`wiki-media-describe.sh` 則自帶同名常數（`:37`，未受影響；**TMO-058 已刪除該常數**）。新探針 `tests/wiki-dead-code.bats`（WDC-1 靜態鎖 + WDC-2 掃描器自測） | P2 | 1 | done (2026-10-05) | TMO-039 |
| TMO-044 | `ci.yml` `Verify Python heredoc syntax` 恆綠假檢查 → **已換成真檢查**：新增 `scripts/ci/check-python-heredocs.sh`（抽 python3 heredoc → `ast.parse` 驗語法；未結束/語法錯/抽不到都會 rc=1），ci.yml step 改為呼叫它（全 ci.yml 已無 `\|\| true`）。順帶修好覆蓋缺口：原檢查只涵蓋 5/9 個 heredoc（漏 wiki-extract-media ×2 / wiki-merge-media / wiki-index），現為 9/9。新探針`tests/ci-heredoc-check.bats` H1-H5（含 3 種突變證明咬得住） | P2 | 2 | done (2026-10-05) | TMO-039 |
| TMO-045 | oracle 假綠的殘餘護欄（reviewer P2-B/C/D）→ **已修（2026-10-05）**：①`jev_oracle.py` 新增 `JEV_ENV_FILE` seam（覆寫即取代整份 `.env` 候選清單，涵蓋 `PoC/.env` 與 `~/.claude/.../PoC/.env`）；②`M6-g`/`M6.1-c` 自身加 `JEV_ENV_FILE=/dev/null`；③`CLEAN-POC-f` 由定點鎖（3 條）一般化為「動態挑出所有 oracle 測試檔 → 整檔離線重跑」（實測 `v2.1-jev-poc.bats` 100 條全綠，故未另做 CI 等價腳本）；④新增 `CLEAN-POC-h`（`PoC/.env`/`cache/` 不得被追蹤 + `.gitignore`/`.env.example` 正對照）與 `CLEAN-POC-i`（反向驗證 seam）；⑤CONTRIBUTING + cache-fixtures/README 精確化。敏感度證明：清 fixture→f 紅、`git add -f .env`→h 紅、半套 seam 突變→i 紅 | P2 | 3 | done (2026-10-05) | TMO-039 |
| TMO-040 | 護欄設計邊界（Round-4 P2-2）：`POC_VENV_DIR` 指向合法的 ≥2 層絕對目錄（如 `$HOME`、`/private/tmp`）＋ `--force` 仍會 `rm -rf`；屬使用者明示操作、無法與真 venv 目錄區分，需決策（加 `$HOME` 排除？或改為只允許 `$POC_DIR` 之外的自訂目錄並加確認提示）| P2 | 2 | done (2026-10-05) | TMO-029 |
| TMO-056 | **危險清單的「容器本體直接子項」缺口**（TMO-040 Round-2 二審 P3-a 延伸）：現行清單列了 `/Users`、`/Volumes` 本體，但 `/Users/<他人>`、`/Volumes/<外接碟>` 這種**一層子項**不在清單內，而 `rm -rf /Volumes/Backup` 會整顆碟清空；目前只靠二次確認＋`--yes` 豁免擋（自訂 `POC_VENV_DIR` 才觸發）。**建議**：清單加「容器直接子項」規則（`/Users/*`、`/Volumes/*`、`/home/*` 且層數 == 2 才拒，更深的 `/Users/me/projects/x` 仍放行）；**未做原因**：allow 側（深層路徑仍可寫 venv）在 CI（Linux）無可寫入的同構路徑可驗，會產生未受測分支；待有真實 PENDING US 再排 | P3 | 1 | ⏸️ 跳過 (2026-10-05 ask-me) | TMO-040 |
| TMO-046 | `skills/tdd-test-writer/SKILL.md` 已 **149/150 行**（餘 1 行）；主檔行數上限見 `dav-skill-creater/editor-guide.md`。CI 的尺寸檢查過去只盯 `dav-wiki/SKILL.md`（1/11 檔），本輪已改為自動列舉（SSG-1..3）→ 現在這檔已受鎖，但仍無餘裕：下一次修改極可能撞上限，需先瘦身（走 V03）。**實作（2026-10-05）**：已瘦身 **149 → 105 行**（觸發時機／流程 6 步壓成表格、移除重複的「測試結構模板」段），規則面零刪減（`RESTRUCT-TDD-TEST-WRITER` 13 條全綠）；現行最長主檔改為 `dav-skill-creater/SKILL.md`（148 行）。 | P3 | 1 | done (2026-10-05) | TMO-041 |
| TMO-047 | **skill 自帶探針從未被 CI 執行**（round F P3-5）：`skills/dav-skill-creater/tests/check-examples-version-baseline.bats`（1 條）、`restruct-no-cross-dir-path.bats`（2 條）目前 3/3 綠，但 `.github/workflows/ci.yml` 只跑 `bats tests/` → 這兩檔永遠不會被執行（改了也不會擋）。兩把靜態鎖（`lint-probe-*.py`）的 `targets()` 反而會掃它們。**實作（2026-10-05）**：①兩支探針加 `SKILLS_DIR_OVERRIDE`（預設仍掃 `~/.pi/agent/skills`）＋**fail-closed**（root 不存在／掃不到檔 → 紅，不再 skip）；②`ci.yml` 加一步 `SKILLS_DIR_OVERRIDE="$PWD/skills" bats skills/*/tests/*.bats`；③新增 `ENV-EQ-11` 鎖「自動列舉 ≥2 檔 + 逐檔實跑綠 + 不得 skip + 每檔認 override + ci.yml 恰好一步且寫法相符」。**量測發現（為何不是天真版）**：這兩支原本掃 `~/.pi/agent/skills`，在 CI 上掃不到檔 → 一支 `skip`、另一支 0 violations＝**假綠**；故若只加 CI 步驟會製造新的假綠。**未擴 `ENV-EQ-9` 普查**：`bats tests/` 的條數不含 skill 自帶探針，skill-local 集合改由 `ENV-EQ-11` 獨立鎖（避免把兩套不同執行路徑混進同一個計數）。 | P2 | 1 | done (2026-10-05) | TMO-041 |
| TMO-048 | **Gate 2 的 shellcheck 掃描面有洞**（L5 量測）：原指令只列 `lib/log.sh`＋`skills/dav-wiki/scripts/*.sh`＋`scripts/ci/*.sh`（14 檔），漏掉 `install.sh`、`lib/install/*.sh`（6 檔）、`skills/*/PoC/*.sh`、`tests/helpers/*.bash`，即**安裝器核心從未被 lint**（實測：8 個 SC2148 error＋2 個 SC2034 warning＋2 個 SC2086 info）。**已修（2026-10-05）**：改為自我列舉 `shellcheck -x -S style $(git ls-files '*.sh' '*.bash')`（23 檔、rc=0）；6 支 `lib/install/*.sh` 補 `# shellcheck shell=bash`、`install.sh` 兩個未用常數加 `disable=SC2034` 附理由、`run_pipeline.sh` 兩處補引號；新增 `ENV-EQ-13`（每個 shell 檔須宣告 shell ＋ CONTRIBUTING 的 Gate 2 指令須自我列舉 ＋ 下限 ≥20）；`CONTRIBUTING.md` 同步換成自我列舉指令。突變 M33/M34/M35 全咬 ✓ | P2 | 2 | done (2026-10-05) | TMO-029 |
| TMO-049 | **CI 沒有跑 shellcheck**（Gate 2 只在開發者本機跑）：`ci.yml` 目前只有 bats／markdownlint／ffmpeg／heredoc／SKILL 大小，所以「本機 Gate 2 全綠」不等於 CI 會擋 shellcheck 類問題（ENV-EQ-13 只鎖本機指令的掃描面完整）。**建議（待用戶裁決）**：在 `test` job 加一步 `shellcheck -x -S style $(git ls-files '*.sh' '*.bash')`；風險：macOS runner 是否預裝 shellcheck 未能本機驗證（信任模式禁 push，看不到 CI 結果），若要零風險可只在 ubuntu leg 跑並在文件揭露「macOS 未涵蓋」 | P2 | 2 | done (2026-10-05) | TMO-029 |
| TMO-050 | **空過測試＋檔尾換行**（L7/L8 量測）：①`tests/ci-linux.bats` 的 `ci-linux: OS LinuxCI` 是 `if Linux then skip else [ true ]`——任何平台都不可能紅（純裝飾綠燈）；②**35 個被追蹤文字檔**（13 支 `.bats`、`install.sh`、`lib/**`、`scripts/ci/*.sh`、3 支 `.json`…）檔尾缺換行，實際害到本輪 mutation M39/M40 **靜默沒套上**。**已修（2026-10-05）**：①改成真斷言（BSD `date -v-90d`／GNU `date -d '90 days ago'` 與 Python 算出的日期相等）；②逐檔等價驗證（去尾端換行後內容不變）後補換行，binary fixture 以 NUL 嗅探排除。新增 `ENV-EQ-15`（禁空過斷言，下限 ≥40）與 `ENV-EQ-16`（文字檔須以換行結尾，下限 ≥100）；M39–M46 全咬 ✓；**ENV-EQ-16 第一版因 bash `$'\x00'` 變空字串而假綠，是 M43 沒咬才抓到** | P2 | 2 | done (2026-10-05) | TMO-029 |
| TMO-051 | **docs 相對連結沒有鎖**（L9 量測）：naive 掃描 121 條相對連結，31 條解析不到，但逐條看多為 **code span 內的引用範例**（handbook 檔頭的 `` `[§2.1](./sop/handbook/2.1-planning.md)` ``）、`tests/fixtures/mock-tree-monstor/**` 的縮減樹、以及 submitter 樣板／dav-wiki 範例的 placeholder（`path`、`../backlog.md#<backlog-id>`）。**真壞的只有 3 條**：①`docs/sop/handbook/2.3-execution.md` 的 `../../skills/regression-guard/SKILL.md`（少一層，應為 `../../../`）——**修它要走 V03（handbook 修改）**，故僅記錄不逕改；②`docs/deliverable/2026-09-26-reduce-deliverables.md` 的 `./2.4-reflection.md`／`./2.5-submission.md`（歷史交付物，append-only 慣例不動）。已順手修好 `docs/DESIGN.md` 的 2 條（`skills/dav-wiki/frontmatter-schema.md` → `../skills/...`、`../sop/handbook/changelog.md` → `sop/handbook/changelog.md`）。**建議**：先定 scope（排除 code span／fixtures／樣板）再上連結鎖，否則誤報率 >90% | P3 | 1 | done (2026-10-05) | TMO-029 |
| TMO-052 | **CI 的 `Verify bash syntax` 步驟只 glob 硬編子集**：`ci.yml` 的該步只跑 `for f in skills/dav-wiki/scripts/*.sh; do bash -n "$f"; done`，漏掉 `install.sh`、`lib/**`、`scripts/ci/*.sh`、`skills/*/PoC/*.sh`、`tests/helpers/*.bash`（與 TMO-048 同一個「硬編清單」病根，只是換成 CI 端）。緩解：ENV-EQ-13（所有 shell 檔前 5 行須宣告 shell，跑在 CI 內）＋ `tests/install.bats` 真的會執行 `install.sh`，所以不是完全裸奔。**建議（待用戶裁決，與 TMO-049 二選一或合併）**：改成自我列舉 `git ls-files '*.sh' '*.bash'` 後逐一 `bash -n`，或直接由 TMO-049 的 shellcheck 取代此步（shellcheck 已含語法檢查） | P3 | 1 | done (2026-10-05) | TMO-029 |
| TMO-053 | **secret 遮罩通則**（NYH-2，2026-10-05 開票 → 2026-10-05 完成）：①`mask_secrets()` 上移共用 `tests/helpers/test-env.bash`（探針檔不得自己再定義一份）；②新靜態鎖 `scripts/ci/lint-probe-secrets.py`（鎖 4，R1 真 `sk-or-v1-` 前綴／R2 碰 `_load_api_key` 的檔必須有**遮蔽呼叫**（去註解後才算，光寫在註解裡不算）／R3 FAIL 訊息展開 `$output`／`${output}` 未過遮罩／R4 只有 `tests/helpers/test-env.bash` 可以定義 `mask_secrets`／R5 `SECRET-OK` 必須附理由且只能標在洩漏樣本行＋防空過下限）；③新探針 `tests/secret-masking.bats`（SM-1~5，含**反向實測**：真的讓 CLEAN-POC-i 失敗→輸出不得含密鑰）。**來源**：NYH-1 的實際外洩——探針 FAIL 訊息把本機 `OPENROUTER_API_KEY` 印進 session log。走 V03 二審 | P2 | 2 | done (2026-10-05) | TMO-045 |
| TMO-057 | **六支 dav-wiki 腳本的死引用**：`wiki-extract-{audio,video}.sh`、`wiki-media-describe.sh`、`wiki-ocr.sh`、`wiki-merge-media.sh`、`wiki-index.sh` 的**第 3 行**各指向**兩個不存在的檔**：①`docs/prd/03-knowledge-extraction.md`（`docs/prd/` 現有 01/02/03-reduce-deliverables、04-restructure，無 knowledge-extraction）②`docs/plan/2026-01-15-dav-wiki-sprint-08.md`／`-09.md`（`docs/` 下無 `plan/` 目錄）。屬 TMO-034「同源死引用」家族的漏網（TMO-034 只修了 `wiki-extract-media.sh` 那處）。**同一批死引用還有一半在 `usage()` 裡**：同 6 支腳本的 `對應手冊: docs/prd/03-knowledge-extraction.md` 各一處（`wiki-index.sh:50`、`wiki-merge-media.sh:45`、`wiki-ocr.sh:69`、`wiki-media-describe.sh:77`、`wiki-extract-audio.sh:50`、`wiki-extract-video.sh:53`），共 12 處。**未做原因**：本輪（TMO-035/053）範圍是「缺工具行為契約」，且修法需決策（刪行／改指 `docs/system-design.md`／改指 skill 子檔），不順手改；`docs/prd/` 是否要重建知識提取 PRD 亦待用戶決定 | P3 | 1 | done (2026-10-05) | — |
| TMO-058 | **`wiki-media-describe.sh` real 模式假成功**（TMO-035 Round-1 二審 P1-1 揭露）→ **已修（2026-10-05）**：①real 未實作改用新碼 **`EXIT_NOTIMPL=5`**（原本借用的 4＝「必要工具缺失」語意錯：本檔根本沒工具檢查 → 一併刪除死常數）；②單檔 `process_single … \|\| exit $?`（原本 `set -uo pipefail` 無 `-e`，回傳值被 `exit 0` 蓋掉）；③批次改聚合計數（`ok`／`fail`／`truncated`，任一失敗→非零 rc，**不得**再印「✅ 批次完成」）；④順修（已揭露）：`echo > "$output"` 與 `mkdir -p "$outdir"` 原本不看 rc（寫不進去也印 `✓ wrote` ＋ ✅）→ 改用新碼 **`EXIT_WRITE=6`**；⑤探針 **AC-D19~D30**（Round-1 後補 D29＝非法 `--max-concurrency`、D30＝合法值不得誤擋）（real 單檔 rc=5 無產物／real 批次 rc≠0 且無 ✅／mock 批次仍 ✅ 回歸鎖／dry-run 不變／usage 有 5 無死 4／SKILL.md 靜態鎖／截斷 WARN／部分失敗可達 rc=6／單檔寫入失敗／output-dir 建不出來）＋突變 M1~M9 全咬住；⑥`SKILL.md` 限制表對齊（v2.2.2；Round-1 P1 處置：刪 v2.1 列回 134 行，符合「只留最近 3 條＋v2.0 錨點」）；⑦Round-1 P2-2 順修：`--max-concurrency` 限正整數（探針 AC-D29）；⑧文件數字同步（`install-reference.md` 612／615／569+43；Round-2 後每加一條探針再同步一次）。**未做**：`--max-concurrency` 被當「總處理上限」的語意 bug（另開 TMO-060，本票只把靜默丟檔變誠實 WARN）。原文：real `real_describe()`／`real_transcribe()` 印 `ERROR: real … not implemented yet` 後 `return 4`，單檔 `process_single` 回傳值沒接→最終 `exit 0`；批次 `continue` 後照樣印「✅ 批次完成」→ 零產出卻回報成功 | P2 | 2 | done (2026-10-05) | TMO-035 |
| TMO-054 | **OpenRouter API key 輪替（人工項，僅用戶可執行）**（NYH-1，2026-10-05 開票）：到 OpenRouter 撤銷舊 key、產生新 key 並更新 `skills/regression-guard/PoC/.env`；完成後由 Agent 複驗 sha256 已變＋新值未出現在任何被追蹤檔／本輪 diff。**Agent 無法代為撤銷**（見 NYH-1） | P1 | 1 | todo | — |
| TMO-055 | **README 缺「本機開發前置」區塊**（2026-10-05 Gate 3 紅燈事故）：新 clone 未 `brew install bash`（5.x）＋未跑 `bash skills/regression-guard/PoC/setup-venv.sh` 時，本機 `bats tests/` 會 **47 紅**＋**31 條 CJK 測試名被 bash 3.2 靜默丟棄**（`Executed 545 instead of expected 576`），而 CI 全綠 → 新 clone 必踩。現況指令只散落在 `CONTRIBUTING.md:52` 與 `docs/install-reference.md 的「開發 / 測試」段（原引用行號 277 已位移失效，2026-10-05 改為段名）`，README 完全沒提。**建議**：README 開頭加 2 行指令的前置區塊並指向 `docs/install-reference.md`。**已實作**（`debcda9`）：README 新增「本機開發前置（想在這個 repo 跑測試才需要）」區塊，含 `brew install bash`（5.x）＋`setup-venv.sh`、兩個症狀（缺 venv ⇒ 43 條紅；bash 3.2 ⇒ `Executed N instead of expected M` 静默丟棄）、bats 鋇版 v1.14.0 提醒，並連結 install-reference 的「開發 / 測試」段。**未做**：把本機 bash 3.2 降到「不可能踩」，仍靠 `ENV-EQ-1/19` 在踩到時大聲報 | P3 | 1 | done (2026-10-05) | — |
| TMO-059 | **README CI badge owner 寫錯**（`apple/tree_monstor`）：TMO-025 時期已列為 P2（report-only）但一直沒修，實測 `https://github.com/apple/tree_monstor` = **404**、`freedomw1987/tree_monstor` = 200。**已修**（`e4180f7`）：badge 與連結兩處改 `freedomw1987`。附帶確認：`.github/workflows/ci.yml` 的 `branches: [main, master]` 早已修好，故 badge 現為真連結 | P3 | 1 | done (2026-10-05) | — |
| TMO-060 | **`--max-concurrency` 被當「總處理上限」用**（TMO-058 收尾揭露）：`process_batch` 原為 `if [[ $ok -ge $MAX_CONCURRENCY ]]; then break; fi`，語意應是「同時處理幾個」（平行度），實際卻變成「最多處理 N 個檔案」→ 第 N+1 個以後**靜默不處理**。TMO-058 已先把靜默丟檔改成誠實的 `⚠ 已達 --max-concurrency 上限（N），尚有 K 個未處理`（rc 仍 0）＋探針 AC-D25，但語意仍錯。**建議**：①若不做平行，就改名／改說明為「單次處理上限」並預設 0＝無限制；②或真的實作背景並發（`wait -n`，bash 4.3+）並把上限套在「同時運行數」。**§2.1 決策（2026-10-05，用戶選 A）**：正名為「單次批次上限」——新增 `--batch-limit <N>`（`--max-concurrency` 保留為**相容別名**），語意＝「一次最多**嘗試**處理 N 檔」，`0`＝無限制且**改為預設**（原預設 4＝任何 >4 檔批次都丟檔，是真 bug）；失敗檔亦計入額度；附帶①②③一併修（截斷額度改計嘗試數、dry-run 改印 `[DRY-RUN] 批次完成：…`、白名單略過要計數 WARN）。**不做**真並發（real API 未接上、無收益、bash 3.2 相容風險）。**本票已先補的**：`--max-concurrency 0`／非數字（`2x`）原本會「每檔都算截斷→零產出卻印 ✅ 回 0」或「`[[ ]]` 算術報錯後默默不限制」，TMO-058 已收緊為**限正整數**（否則 `exit 1`）＋探針 AC-D29。**附帶（同批次訊息家族，已於本票一併修）**：①截斷上限計的是**成功數**，失敗檔不佔額度（`--max-concurrency 1` 遇 1 失敗時實際會處理 2 檔）；②批次 `--dry-run`／空目錄仍印 `✅ 批次完成：N 個檔案`（rc 0），建議改 `[DRY-RUN] 批次完成：N 個檔案`；③批次靜默略過不符 mode 白名單的檔（單檔模式會 WARN），建議一併計數並 WARN。**注意**：AC-D11 只測單檔 | P3 | 3 | done (2026-10-05) | TMO-058 |
| TMO-061 | **`install-reference.md` 的探針總數靠人工同步（同一票內就改過多次）**(TMO-058／TMO-060 收尾揭露）：每加／改一條探針，就要人工改 `docs/install-reference.md` 的 `bats tests/` 條數、CI 條數、clean clone 的 `N ok / 43 not ok`；TMO-058 內漂 4 次（600→611→612 等，backlog 列漏改 1 次）、TMO-060 內漂 2 次（612→615→622；615→618→625；569→572→579）。**建議**：①讓 `install-reference.md` 只寫「以 `bats --count tests/` 為準」並移除硬編數字；或②寫一條探針／CI 步驟自動校驗該檔的數字與實測一致（後者較重、但能保住「文件有數字」的可讀性）。**注意**：TMO-060 一票之內又同步 **2** 次（612→615→622；615→618→625；569→572→579），可見人工同步的成本。 | P3 | 1 | done (2026-10-05) | TMO-060 |
| TMO-062 | **七支 dav-wiki 腳本第 2 行自述路徑過時**（TMO-057 V03 二審 P2-3 揭露）：`wiki-cross-ref.sh`、`wiki-extract-audio.sh`、`wiki-extract-video.sh`、`wiki-index.sh`、`wiki-media-describe.sh`、`wiki-merge-media.sh`、`wiki-ocr.sh` 第 2 行仍寫 `# tools/<name>.sh`，但 repo 根已無 `tools/` 目錄（實際在 `skills/dav-wiki/scripts/`）；sibling `wiki-extract-media.sh` 已在 TMO-025 修過。**修法**：`# tools/<name>.sh` → `# skills/dav-wiki/scripts/<name>.sh`，對齊 sibling。 | P3 | 1 | done (2026-10-05) | TMO-057 |

> 📝 2026-10-05 ask-me：**TMO-035** 決策＝**改文件對齊現實**（`SKILL.md` 限制表該列改為
> 「缺工具即停並提示安裝（`exit 4`）」），**不實作降級模式**；純文字修正、走 V03 二審後施工。

<!-- ask-me 註腳分隔（TMO-040） -->

> 📝 2026-10-05 ask-me：**TMO-040** 決策＝**危險清單＋二次確認**（危險路徑即使 `--force` 也拒；
> 其他自訂目錄 `--force` 需輸入目錄名，CI 以 `--yes` 豁免），待實作＋新探針。

<!-- ask-me 註腳分隔（TMO-056） -->

> ⏸️ 2026-10-05 ask-me：**TMO-056** 決策＝**跳過**（票面原文已說明：allow 側深層路徑在 Linux CI 無同構可寫入路徑可驗，會生未受測分支；**等真實 PENDING US
> 出現時再排隊**）。
> 抉擇理由：零成本、零風險、與原作者意圖一致；backlog 仍保留票面描述供日後引用。

<!-- ask-me 註腳分隔（TMO-057） -->

> 📝 2026-10-05 ask-me：**TMO-057** 決策＝**改指對齊文件**（12 處死引用改指現存 `docs/system-design.md`；屬 skill 子檔變動，**待 V03 Reviewer
> 二審後開工**，ask-me 階段不逕動 skill 程式碼）。
> 抉擇理由：改指現存檔比刪行/重建 PRD 都實用；同類 dead-link 家族 TMO-034 已有先例。
>
> **✅ 2026-10-05 施工完成**：12 處死引用全改為 `docs/system-design.md §3.2（FR-3 資料流）`（對齊 sibling `wiki-extract-media.sh`）。V03
> Reviewer 二審 verdict＝changes-requested（P1：原保留的 FR-3.5/3.7/3.9 在目標檔不存在、音訊實為 FR-3.8 → 改為去編號的 §3.2 描述），修正後用戶批准。驗證：
> `bash -n` 6 檔 OK；相關 bats 110 ok / 0 fail；`skills/dav-wiki/scripts/` 已無 `03-knowledge-extraction`／`dav-wiki-sprint`
> 字串。

<!-- ask-me 註腳分隔（TMO-061） -->

> ✅ 2026-10-05 ask-me：**TMO-061** 決策＝**繼續做（方案①）**（`docs/install-reference.md` 改為「以 `bats --count tests/` 為準」並移除硬編數字；
> **文件潤稿類，不動 SOP / gates / skill / 探針，不走 V03**，ask-me 開工）。
> 抉擇理由：代價低、不增加探針複雜度；唯一不可逆點是「數字不再可即讀」，但讀者可以跑 `bats --count tests/` 拿最新數字。
>
> **狀態欄修正（2026-10-05）**：本票 ask-me 時狀態欄誤標為 `📝 改設計`，實際應為 `✅ 已確認`（用戶選繼續做）— 本次 ask-me 同步修主表狀態欄為 `✅ 已確認 (2026-10-05 ask-me)`。
>
> **✅ 2026-10-05 施工完成**：`docs/install-reference.md` 已依方案①移除全部硬編探針總數（`bats tests/` 條數、clean clone `N ok / N not ok`、CI
> 條數等），改為「以 `bats --count tests/` 為準」；`## 開發 / 測試` 頂部加總數免責註。受鎖探針 `ENV-EQ-10`、`ZERO-CROSS-READ` 全綠；該檔 markdownlint 0
> issue。

<!-- ask-me 註腳分隔（TMO-049／TMO-052） -->

> 📝 2026-10-05 ask-me：**TMO-049＋TMO-052** 決策＝**方案 A（合併）**：CI `test` job 加一步
> `shellcheck -x -S style $(git ls-files '*.sh' '*.bash')`，並把 `Verify bash syntax` 改為自我列舉
> （或刪除，交給 shellcheck）；macOS runner 若無 shellcheck 則只跑 ubuntu leg 並在文件揭露。

<!-- ask-me 註腳分隔（TMO-051） -->

> 📝 2026-10-05 ask-me：**TMO-051** 決策＝**只修 handbook 那條**（`2.3-execution.md` 的
> `../../skills/regression-guard/SKILL.md` → `../../../skills/...`），走 V03 二審；
> 歷史交付物 `2026-09-26-reduce-deliverables.md` 的 2 條壞連結**不動**（append-only）。

<!-- CI 複驗註腳（TMO-049／TMO-052） -->

> 📝 2026-10-05 CI 複驗（結案證據）：master HEAD `507b6d5` 的 GitHub Actions run
> [`37248578384`](https://github.com/freedomw1987/tree_monstor/actions/runs/37248578384) 三 job 全 `success`，且
> **step 10「ShellCheck every tracked shell file」在 `ubuntu-latest` 與 `macos-latest` 兩腿皆 `success`**
> （step 11「Verify bash syntax」自我列舉版亦綠）。TMO-049／TMO-052 的「待 CI 複驗」條件成立 → 結案。（原記錄：run `37247515182` @ `6f44dcc`）

<!-- ask-me 註腳與狀態定義分隔 -->

> **狀態定義**（單一來源）：`todo` = 已描述、尚未開工（TMO-026 之後的新票，**非** trust mode 未結項）；`doing (日期)` = 進行中；`done (日期)` =
> 已交付；`blocked (原因)` = 被外部條件卡住；`待決（NYH-n）` = 決策已上呈 `docs/need-you-help.md` 第 n 項，等用戶裁決（round F P2-5 補定義）。
> 注：`tests/backlog-trust-mode-completion.bats:48`（BACKLOG-005）禁止 trust mode 期間的票停在 `pending`；本表新票一律用 `todo`，不修改該探針。

---

## TMO-020 詳細
> ✅ 2026-09-28 完成 — M6.3 互動式 sandbox + flaky 驗證 + cleanup 進 CI 定期一次到位；regression-guard 升級為「完整閉環 + 自動 sandbox + 穩定性量測 +
> 文件自動審查」四合一；探針 63→80 全綠。
> 抉擇：3 個收尾選項不分拆（互相依賴、一起交付最簡）。
> Evidence：`skills/regression-guard/PoC/sandbox_runner.py`（379 行） + `flaky_check.py`（187 行） +
> `docs/ac/US-M63.{md,html}` + `SKILL.md v2.6` + `examples.md`。

---

## TMO-019 詳細
> ✅ 2026-09-28 完成 — M6.2 patch + re-validate：LLM 接力文字 → `patch_parser.py` 抽 diff → `playwright_patcher.py` 真的 patch →
> `re_validate.py` 重跑分類 improvement/regression/no_change；regression 時建議 rollback。regression-guard 從「給建議」升級為「建議 → 真的
> patch → 自動驗證」閉環。
> 抉擇：不全自動 apply（CI 不能無人工 commit + LLM 文字可能錯）；reviewer 需人 3 步。
> Evidence：`skills/regression-guard/PoC/patch_parser.py`（258 行） + `playwright_patcher.py`（213 行） + `re_validate.py`
> （194 行） + `docs/ac/US-M62.{md,html}` + `SKILL.md v2.5`。

---

## TMO-001 詳細
> ✅ 2026-09-23 完成 — `.gitignore` 28→17 行（移除 5 行 sop-evolver RSI 殘規則，commit `5db8c2e` 移除 RSI 時漏改）、刪
> `.agents/tree_monstor/` 開發機髒副本 132 檔。`git status` clean + regression-guard 確認安裝流程沒壞。
> 補登：狀態完成但 backlog 欄漏改，2026-09-26 補上。
> Evidence：`docs/trust-log.md` 2026-09-23 08:08。

---

## TMO-002 詳細
> ✅ 2026-09-23 完成 — `install.sh` 993→569 行；抽 19 個函數到 6 個 `lib/install/*.sh` 子模組。
> 抉擇：args + dispatch 留主程式，其餘下沉到 lib（行為 100% 維持）。
> Evidence：`docs/trust-log.md` 2026-09-23 08:25。

---

## TMO-003 詳細
> ✅ 2026-09-23 完成 — 範圍收縮到「只修 README badge 105→208」；不另建新 bats、不合併 cross-ref。
> 抉擇：原計畫 3 項中後 2 項延伸過遠、回歸主票。
> Evidence：`docs/trust-log.md` 2026-09-23 08:38。

---

## TMO-004 詳細
> ✅ 2026-09-23 完成 — AGENTS.md §2.0/§2.6 重構（§2.6 升格輕量 SOP + §2.0 改以 §2.6 為準）；AGENTS.md 頂版 v1.3→v1.5；Reviewer APPROVE。
> 抉擇：v1.3 兩節角色混淆、新人不知走哪條；§2.6 改為「升級觸發器」取代「灰色地帶判斷表」。
> Evidence：`docs/trust-log.md` 2026-09-23 08:55 + `docs/sop/handbook/changelog.md` v1.5。

---

## TMO-005 詳細
> ✅ 2026-09-25 完成（v1.7 翻轉拆 `skills/dav-wiki/scripts/`；v1.7.1 順手修 wiki-cleanup.sh 中文 log 變數解析 bug）。
> 抉擇：原方案「加 set -e」已驗證是錯的（v1.7 故意設計 `set -uo pipefail`），改用共用 `lib/log.sh` + trap 統一錯誤處理。
> Evidence：`docs/trust-log.md` 2026-09-23 + `docs/sop/handbook/changelog.md` v1.7/v1.7.1。

---

## TMO-006 詳細（dav-planner AC 範本獨立化 + HTML 版本）
> ✅ 2026-09-26 完成（v1.8 落地） — AC（Given-When-Then + DoD）從 `docs/backlog.md` 表格 cell 抽出到 `docs/ac/<US-ID>.md` + `.html`；
> `dav-planner` SKILL.md §4.3/§4.6 改寫；新增 `tests/dav-planner-ac-templates.bats` 守門。
> 抉擇：AC 整段塞 backlog cell 閱讀差、不利利害關係人單獨校對/分享/列印；HTML 版本服務非 Markdown 讀者。
> Reviewer verdict：PASS（首次 FAIL 抓到 2 P0 blocker，修正後 PASS）。
> Evidence：`docs/deliverable/2026-09-26-dav-planner-ac-templates.md` / `.html` +
> `docs/reflection/v1.8-dav-planner-ac-templates-reflection.md`。

---

## TMO-007 詳細（dav-planner 用戶背景收集機制）
> 🚫 **已廢棄（2026-09-26；v2.1 撤銷）** — §2.7「用戶背景收集」整套廢除；本票詳細段保留作歷史紀錄。
> 守門＝負向斷言（`tests/dav-planner-user-background.bats`：不得回流）；權威來源＝`skills/dav-planner/CHANGELOG.md`。
> 當時（v1.9）做法：SKILL.md 新增 §2.7（5 角色對應表 + 跳過規則 + 與 §3 Persona 區分）＋7 個 bats 探針守門 ＋ changelog v1.9 條目；Story Point 8。
> 廢除原因：2026-09-26 ask-me 決策「撤銷」（見 TMO-027）；票面原文見 git history。

## TMO-008 詳細（減法：文件產出物精簡 v2.0）
> ✅ 2026-09-26 完成 — v1.8/v1.9 每 sprint 寫 6+ 檔 → 精簡為**必寫 2 檔**（changelog + deliverable.md 含反思末段）；不寫 deliverable.html /
> 獨立 reflection.md / 小任務 PRD。改 AGENTS.md §2.4/§2.5 + dav-submitter（三層→兩層）+ §2.4/§2.5 handbook + changelog v2.0 條目 +
> `tests/v2-reduce-deliverables.bats` 6 探針。
> 抉擇：只動未來 sprint 規則、存量 6+ 檔全部保留（Non-goals）；SOP 路徑走完整 §2.1–§2.5（V03 紀律）。
> Reviewer：首次 FAIL（2 P0）+ 順手修 2 P1 → PASS。
> Evidence：`tests/v2-reduce-deliverables.bats` 6/6 PASS + changelog v2.0。

## TMO-011 詳細
> ✅ 2026-09-28 完成（branch `feat-jev-regression`、5 commit、+2148 行）— `regression-guard` PoC：Jev Oracle (
> `typesafe/jev-1.13`) + Journey Gen + Dry-Run Loop + Batch Report；`run_pipeline.sh` 一鍵串接 M2→M3→M4；skill 本體零改動不污染生產規範；
> US-101 4 條 AC 驗證、pipeline cost $0.000390 live。
> 抉擇：用 OpenRouter Jev（中文理解佳）而不自己做語意判斷；cost < $0.001 門檻讓 PoC 可常跑。
> Evidence：`docs/deliverable/2026-09-28-feat-jev-regression-poc.md`（含反思末段） + `skills/regression-guard/PoC/` 11 source
> code + 1 pipeline shell。

---

## TMO-012 詳細
> ✅ 2026-09-28 完成（commit `4ac566d`） — M5 PoC 去 hardcode 化：`AC_AWARE_FIXTURES` → `fixtures/<story_id>.yaml`
> （config-driven）；stale detection 限「同一 AC 連續」+ `current_ac_id` 狀態機；`--stale-test` 重構進 `runner.run_dry`；bats 探針 16/16
> 全綠、零迴歸（M3 行為完全一致）。PoC 對新 US 是 plug-in 模式：只加 `fixtures/<story_id>.yaml` 就能跑。
> 抉擇：不在本票整合 skill 本體（SKILL.md / examples.md）的 user-journey-as-test-spec 規範 — 順延至真實 PENDING US 出現（V02 用戶決策）。
> Evidence：`docs/deliverable/2026-09-28-feat-jev-regression-m5.md`（含反思末段）。

---

## TMO-013 詳細
> ✅ 2026-09-28 完成（commit `83336eb`） — M3.1 PoC 換真的 Chrome driver：`playwright_observer.py` 294 行（lazy import + 6 action
> handler + DOM snapshot）+ `journey_runner.py` dispatcher（依 `OBSERVER_BACKEND` 選 ac_aware/mock/playwright）；不裝
> playwright 仍能跑（lazy import）。5 個 M3.1 探針全綠。
> 抉擇：真實 driver 跑 example.com 順延到「真實 PENDING US 出現時」 — lazy import 保證 PoC 不被外部依賴拖連。
> Evidence：`docs/deliverable/2026-09-28-feat-jev-regression-m31-skill.md`（同 TMO-014 合併）。

---

## TMO-014 詳細
> ✅ 2026-09-28 完成（commit `83336eb`） — SKILL.md 整合：M1-M5 PoC 成果提升為正式 skill 規範。SKILL.md v2.2 新增「Jev Oracle 補充（進階）」章節（+62
> 行，原 Steps 1-4 不動）+ examples.md 新增 4 個範例（+111 行）；25/25 探針全綠；regression-guard 升級為「Steps 1-4 規範 + 可選進階 Jev Oracle 章節」。
> 抉擇：原 Steps 1-4 不動保證相容；跳過上語意提只加進階章節（採納者看 SKILL + examples 評估實作成本）。
> Evidence：`docs/deliverable/2026-09-28-feat-jev-regression-m31-skill.md`（同 TMO-013 合併） + `SKILL.md` v2.2 +
> `examples.md` v2.2。

---

## TMO-015 詳細
> ✅ 2026-09-28 完成（commit `f0f6543`） — CI 整合：`.github/workflows/regression-guard-jev-poc.yml`（2 jobs / 14 steps / 3
> triggers / paths filter）+ Return code gate（0=green / 2=yellow / 1=red blocks merge） + artifact upload 30天 + PR
> comment + `secrets.OPENROUTER_API_KEY` 不 hardcode；探針 25→37；branch protection SOP（`gh api` + UI 雙路徑）。regression-guard
> 從「local-only PoC」升級為「CI-ready PoC」。
> 抉擇：實際 GH branch protection 接入順延到「真實 PENDING US 需被該接下來擋下時」— 文件化 SOP 足夠。
> Evidence：`docs/ci/regression-guard-jev-poc.md`（155 行） + `.github/workflows/regression-guard-jev-poc.yml`（149 行）。

---

## TMO-016 詳細
> ✅ 2026-09-28 完成（commit `f0f6543`） — M6 修正循環：`fix_proposal.py`（311 行）改為「信心度報告」模式 — 3 維度 noul 概率 + 整體信心度 + 失敗走跡截錄 200
> 字（Jev v1.13 不支援 free_response）；`FixProposal` dataclass 評級高/中/低/不可判定 + `to_markdown()`；`run_pipeline.sh` 加
> `JEV_FIX_PROPOSAL=1` + `M4_RC` capture（避免 set -e 中斷）；SKILL.md v2.3 +55 行 + examples.md 範例；探針 36/36。
> 抉擇：Jev 不給文字回應 → 改成信心度報告意外更務實（reviewer 接手起點明確、不需 LLM 接力）；M6.1+ 自動接 LLM 寫 fix 顯然升級路徑。
> Evidence：`skills/regression-guard/PoC/fix_proposal.py`（311 行） + `SKILL.md` v2.3 + `examples.md`。

---

## TMO-017 詳細
> ✅ 2026-09-28 完成（commit `224297c`） — M6.1 LLM Relay：`prompts/fix_relay.md` 95 行（檔案型 prompt template）+
> `fix_proposal_v2.py`（260 行、LLMRelayBundle + RELAY_GATING_THRESHOLD=0.5）；`JEV_FIX_PROPOSAL_V2=1` 開啟 M6.1；SKILL.md
> v2.4 + examples.md；探針 50 綠。不再依賴外部 Claude/GPT/OpenAI API；prompt 邏輯統一在 skill 內。
> 抉擇：讓召喚 skill 的 LLM 接力（不是另接 Claude/GPT）— skill 被召喚時本身就有 LLM（pi / subagent），維護單一 prompt 來源。
> Evidence：`skills/regression-guard/PoC/prompts/fix_relay.md` + `fix_proposal_v2.py` + `SKILL.md` v2.4。

---

## TMO-018 詳細
> ✅ 2026-09-28 完成（commit `224297c`） — docs/cleanup 盤點腳本：`cleanup-scan.py`（246 行）4 分類（KEEP≥2 link / REVIEW=1 / DELETE=0
> / MERGE 待實作）+ skill 保護 + `--json` + `--apply`；掃描結果 KEEP 63 / REVIEW 4 / DELETE 0（4 個 REVIEW 為 v2.0 audit trail 保留）；7
> 個 CLEAN 探針全綠。
> 抉擇：保留 4 個 REVIEW 為 v2.0 audit trail（不論今 view 是 audit trail 、PRD、反思歷史），驗證 TMO-008 / TMO-010 v2.0 規則未違反。
> Evidence：`docs/cleanup/cleanup-scan.py`（246 行） + `tests/cleanup-scan.bats`（7 探針）。

---

## TMO-021 詳細（M7 flaky 整合 + gh pr comment）
> ✅ 2026-09-28 完成（trust mode） — M7 解鎖 review 流程：`flaky_integration.py`（207 行）跑 N 次 journey 聚合 + 寫回
> `batch_report.flaky_measured` + 高度 flaky 降級 overall_health（red→yellow）；`gh_pr_comment.py`（174 行）構造 4 段 PR
> comment（journey / 信心度 / 問題摘要 / sandbox 建議）+ `gh pr comment` 推送（best-effort 不中斷）；M7-flaky 移到 M4 後；探針 80→92。
> 抉擇：M7-flaky 原本放 M3 後 → batch_report 那時還未產出 → 移到 M4 後；gh pr comment 設 best-effort（不中斷 pipeline）。
> Evidence：`skills/regression-guard/PoC/flaky_integration.py` + `gh_pr_comment.py` + `SKILL.md` v2.7 +
> `docs/ac/US-M71.md`。

---

## TMO-022 詳細（M8 CI matrix pipeline）
> ✅ 2026-09-28 完成（trust mode） — M8 多 US 並行：workflow 加 `strategy.fail-fast: false` +
> `matrix.story_id: [US-101, US-M62, US-M63]` + `aggregate-matrix` job（download-artifact merge + matrix-summary.md）；
> SKILL.md v2.8；探針 92→98。regression-guard CI 從「1 US / 1 run」升級為「3 US / 3 runs 並行 + 自動聚合」。
> 抉擇：M8 只在 workflow_dispatch 觸發（push/PR 跑 3 matrix 浪費 CI minutes）+ fail-fast: false（reviewer 一次看 3 結果比「1 fail cancel
> 全部」有用）。
> Evidence：`.github/workflows/regression-guard-jev-poc.yml` + `SKILL.md` v2.8 + `docs/ac/US-M81.md`。

---

## TMO-023 詳細（v2.1-jev-poc C 類探針修復）
> ✅ 2026-10-04 完成 — 只改測試層修 8 個自壊探針：M6.3-b/c/d/e/f（5 個需 `--before /tmp/US-M63-before.json` 但 repo 沒產生步驟） +
> flaky-int-b（少 `run` 前綴） + flaky-int-c / M7-gating-a（缺 batch_report fixture）+ M6.3-e 額外發現假斷言（`ls` 不列 dotfile、結構上永不可能
> fail）。新增 2 個 helper（`make_us_m63_before` 真跑 baseline + `make_m62_batch_report`）+ `ls -a` + `.gitignore /tmp/`；探針
> 38→30 紅。
> 抉擇：用「突變測試」（故意破壞 `_cleanup` 證明探針真會紅）驗證 AC4，不只「補 fixture 讓綠」否則 =「放寬門檻」。
> Reviewer：V03.6 二審 2 輪，首輪抓 M6.3-e 假斷言 P1。
> Evidence：`tests/v2.1-jev-poc.bats` helper 增兩支 + `.gitignore /tmp/` + `bats tests/` 30 紅 / 463 ok。

---

## TMO-024 詳細（README 精簡 + install-reference）
> ✅ 2026-10-04 完成 — `README.md` 288 → 90 行（badges / Quick Start / 精簡 Usage 表 + 「工作流程：看 AGENTS.md」 + 11 skill 列表 + 進階指向
> install-reference）；新增 `docs/install-reference.md`（296 行：完整 flag 表 / 檔案結構 / 設計理由 / 環境變數 / 6 題 troubleshooting）；修正不實描述
> `REGRESSION_MODE=true bash install.sh` → `bash -x install.sh --dry-run --global`。
> 抉擇：保留 `Usage`、`--global`、`--uninstall` 三字串在 README（`tests/install.bats` AC-15 依賴）。
> Evidence：`README.md` + `docs/install-reference.md` + `tests/install.bats` AC-15 綠 + `markdownlint` 0 問題。
> 已知問題：`bats 209/209` badge 已過期（實際 463/493）、CI badge 指向未跑 workflow → 待用戶決定（見 TMO-061）。

---

## TMO-025 詳細（B 類 12 紅修復：pptx 假成功 + poppler）
> ✅ 2026-10-04 完成 — 修 B 類 12 紅。
> 抉擇：AC-E21 用 `status -eq 5` 釘死（區分「工具缺 exit 4」vs「提取失敗 exit 5」）；AC-E22 加 fixture 漂移守衛。
> Reviewer：2 輪 approve-with-comments / risk low。
> Evidence：`docs/deliverable/2026-10-04-tmo-025-b-class-probe-fix.md` + commit `5ed097e`。

## TMO-026 詳細（A 類 12 紅 retarget + 3 條 CJK 假綠探針復活）
> ✅ 2026-10-04 完成 — A 類 12 紅 retarget + 3 條 CJK 假綠探針復活：v2.1–v2.9 各 skill 把內文從 `SKILL.md` 搬進子檔（`backlog-rules.md` /
> `runner-cheatsheet.md` / `jev-oracle.md` / `CHANGELOG.md`），探針盯舊址 → retarget 到新家 + 主檔指標斷言；`bats` 1.14.0 對 `@test` 名含
> CJK 靜默不執行（宣告 498 / 實跑 495）→ 改名 ASCII。`bats tests/` 18→6 紅（實跑 495→498）。
> 抉擇：**retarget 探針而非把內文搬回迎合探針**；界線在「有沒有同時鎖住主檔→子檔指標」（無指標＝放寬門檻）。
> Reviewer：V03.6 二審 2 輪均 approve-with-comments / risk low / 0 P0-P1（第 2 輪判「真強化、非化妝」）。
> 教訓：紅燈有三種病（探針過期／守廢棄功能／產品缺陷），本輪只治第一種；最安靜的債是沒在跑的探針（假綠不會叫人）。
> Evidence：7 次突變測試 + `bats tests/` 6 紅 / 492 ok。

---

## TMO-027 詳細（dav-planner §2.7 廢棄守門）
> ✅ 2026-10-04 完成 — v2.1 廢除 dav-planner §2.7「用戶背景收集」後，5 條存在型探針恆紅；改寫成 4 條「廢棄守門」＝**負向斷言**（功能不得回流）+ **定位句必須留著** +
> **廢除紀錄必須留著**；新增 helper `refute_file_contains()`。`bats tests/` 剩 1 紅（TMO-028）。
> 抉擇：用「負向斷言 + 廢除紀錄錨定」把守門人升級成「防回流」，而非刪紅燈；守門標的用「主題」而非編號（`§2.7` 編號必被合法重用會誤紅）。
> Reviewer：V03.6 二審 2 輪 approve-with-comments / risk low / 0 P0（首輪抓 refute 假綠 P2-1）；11 次突變測試全還原後回綠。
> 教訓：廢棄守門要能咬人必須三件套（功能不回流／定位句留著／廢除紀錄留著）；負向斷言天生有假綠風險（grep 對不存在檔 rc=2 → PASS），必須配正向錨定。
> 已知問題：已切票 TMO-030/031/032（探針精準化）；自首 TMO-026 commit `3639d00` 用 `pending` 撞 BACKLOG-005 新紅，本輪修掉不改探針。

## TMO-028 詳細（dav-wiki 主檔瘦身 + 版本漂移鎖）
> ✅ 2026-10-04 完成 — `dav-wiki/SKILL.md` 151 → **129 行**（依 V03.5「主檔 ≥150 必先瘦身至 ≤130」做**內容無損外移**：輸出結構樹 →
> `output-structure.md`、軟刪除規則 → `soft-delete.md`、主檔留導航指針）；`tests/restruct-dav-wiki.bats` +1 指標存在探針 + 版本漂移鎖。
> `bats tests/` 0 紅 / 498 ok。
> 抉擇：不是「151→150 剛好過關」，只砍重複 `---` 過關下個小改動又撞牆；細節外移才是結構性降注意力成本。搬移要能被證明是搬移（`git show HEAD` 舊樹 vs 新子檔 fence `diff` 得空輸出）。
> Reviewer：V03 + V03.6 二審 2 輪 approve-with-comments / risk low / 0 P0 / 0 P1（判「真瘦身」「加嚴非放寬」），第 2 輪明示不需第三輪；4 次突變全還原後回綠。
> 教訓：負向與空值都有假綠（`found >= 4` 擋擷取失效、`[ -n "$v" ]` 擋抽空）；最安靜的債是缺鎖。
> 已知問題：已切票 TMO-033/034/035/036；P2-2 漂移鎖訊息不可診斷折入 TMO-032。

## TMO-029 詳細（venv bootstrap：CI 真的會跑 + 一行建環境 + 缺環境大聲紅）
> ✅ 2026-10-04 完成 — 修三大病：①**CI 從未真正執行**（`ci.yml` 只寫 `branches: [main]` vs repo 預設 `master`）②clean clone 無法自己站起來（無
> requirements / setup 腳本）③缺環境時 38 條測試以 127 噪音各自失敗。新增 `PoC/requirements.txt`（httpx + PyYAML，上下界鎖）+ `PoC/setup-venv.sh`
> （uv 優先 / `python3 -m venv` 退路 / `POC_VENV_DIR` 縫 / 危險值護欄）+ `.markdownlint-cli2.jsonc`；`ci.yml` triggers 加
> `[main, master]` + `workflow_dispatch` + Build PoC venv 步驟；`v2.1-jev-poc.bats` venv-dependent 測試加 `need_poc_venv()`；
> 新增 `tests/poc-bootstrap.bats` **8 條探針**（各附反空過設計：AST 遞迴掃描、真跑退路、自動列舉名單、`git check-ignore` 行為驗證、壞值矩陣、行號護欄、PyYAML 語意斷言）。
> `bats tests/` 0 紅 / 506 ok / 0 skip。
> 抉擇：「測試很多 ≠ 測試會跑」— 一個字設定讓 209 條測試整年沒跑；缺環境要大聲紅不要噪音；假綠有兩種（`skip` 永不跑／空過斷言），用「本檔 skip 數必須 0」+ 不變式等號鎖住。
> Reviewer：V03.6 二審 **4 輪**（R1 0P0/1P1/11P2 → R4 approve-with-comments / risk low / 0 P0 / 0 P1），R3 抓出 `/tmp/`
> 繞過護欄（同義寫法矩陣）。
> 教訓：安全性檢查要拿「同義寫法矩陣」來測；自傷（假突變、`git checkout` 誤刪未 commit 整批編輯）全部寫進證據包。
> 已知問題：已切票 TMO-037 lint 債 246 處 / TMO-039 首次真實 Actions 驗證 / TMO-040 護欄設計邊界。

## TMO-039 詳細（首次真實 Actions 驗證：34 紅的真因與修復）
> ✅ 2026-10-04~05 完成 — 首次真實 CI run `37213235272` ubuntu 34 紅（本機 506 全綠 = **假綠**）。修六類真因：①journey 寫死 `/Users/<作者>/` 絕對路徑
> → 改相對 ②`US-M62.yaml` 被 gitignore 且無產生器 → 解除忽略版控 ②b **`sandbox_runner.py` 真 bug**（`sandbox_dir / 絕對路徑` 右邊覆寫左邊 →
> `SameFileError`）→ 用 `.resolve().relative_to(REPO_ROOT)` ③runner 缺 `ffmpeg` ④`wiki-cleanup.sh` 空陣列展開（bash 5.2+
> `set -u` unbound）→ 改 `CLEAN_COUNT` ⑤`python-version: '3.x'` 浮動 → 釘 `'3.12'` ⑥lint 債 246 處（→ TMO-037）。第二輪 34→4 紅：⑦3
> 條探針依賴本機 `OPENROUTER_API_KEY` + 8233 筆暖快取（**假綠第 5 型**）→ 注入 stub / 版控 `cache-fixtures/` + `JEV_CACHE_DIR` seam ⑧macOS
> brew ffmpeg 8 移除 `-vsync` → `-fps_mode vfr`（同旗標在**產品腳本** `wiki-extract-video.sh:141` = 真 bug）。新增
> `tests/poc-clean-clone.bats`（5 條）+ 多條鎖探針（M6.3-k/l、AC-V11、CLEAN-POC-f/g）。`bats tests/` 516 ok / 0 紅 / 0 skip。
> 抉擇：「本機全綠是假綠」— 真正驗證是「在別人機器、從零開始」；假綠有五型（skip／空過斷言／依賴本機狀態／路徑寫法差異／本機環境）。
> Reviewer：二審 P2 一併收尾（P2-1 `..` 逃出 sandbox 實測外洩 → 補洞 + `M6.3-l`）。
> 教訓：錯誤歸因也是債（clean clone 4 紅誤判「缺 fixture」實為 `src == dst` 真 bug）；產品 bug 會躲在探針紅燈裡（`-vsync`）。
> 已知問題：已切票 TMO-042 ffmpeg 版本漂移 / TMO-043 `probe_metadata()` 死碼。

## TMO-038 詳細（探針強化：AST 掃描／標記制／自動列舉／CI 語意斷言）
> ✅ 2026-10-05 完成 — 修 `tests/poc-bootstrap.bats` 三處「看起來有守、其實漏守」：①依賴掃描改 **AST 遞迴**（`rglob('*.py')`）＋ module→dist 映射表，
> optional 依賴改**行內標記** `# PoC-OPTIONAL-DEP` 自我說明 ④helper 名單**自動列舉**（`awk` 抽「body 用到 `$PY` 的函式」）⑤新增 **PyYAML
> 語意斷言**（trigger 三件套、`matrix.os` 雙平台、venv 步驟早於 `bats tests/`、禁 `continue-on-error`）。`bats tests/` 553 ok / 0 紅 / 0
> skip。
> 抉擇：探針⑤讓 CI 契約從純靜態變成需要 PyYAML（clean clone 未建 venv 會紅但附修復指令）— 理由：字串比對看不到步驟先後與矩陣，而 CI 執行次序保證拿得到 PyYAML。反空過設計：映射表自我測試、
> 標記只能落 import 行、抽取器自我測試。
> Reviewer：V03.6 二審（見 `docs/trust-log.md` round E）；11 組突變全咬（M6b 對照組證新規則 41/40 咬、舊硬編 40/40 不咬）。
> 已知殘餘：「helper 用 `$PY`」判定仍靜態字串（間接形式會漏抓）；`PoC/tmp/**` runtime `.py` 在掃描範圍內（未來可能誤紅）。

## TMO-041 詳細（環境等價／「本機假綠」殘餘防線）
> ✅ 2026-10-05 完成 — 三件事：**版本等價**（新增 `tests/env-equivalence.bats` ENV-EQ-1..10：bash 5.x 必需不 skip、每個本機可用 bash 都跑
> `wiki-cleanup.bats` 防空過、shim 有效性、空陣列×`set -u` 逐版本量測、`/tmp` 殘留鎖、`gh`/`brew` 執行鎖、網路黑洞 canary）＋追加 ENV-EQ-8/9/10（CI
> 護欄腳本自動列舉、宣告 `@test` 數 == `bats --count`＋CJK canary、文件教釘版 bats）；**釘版**（CI 兩平台 `git clone --branch v1.14.0 bats-core`，
> 移除 apt/brew distro bats，契約探針鎖同 tag）；**狀態依賴清掃**（`v2.1-jev-poc.bats` **56 處** `/tmp/` → `$BATS_TEST_TMPDIR`，抽
> `make_gh_pr_batch`，純資料 4 行標 `TMP-OK`）。另加 `tests/skill-size-guard.bats` SSG-1..3。`bats tests/` 567 ok / 0 紅 / 0 skip。
> 抉擇：**不斷言「bash X 必須 unbound」**（本機實測與票面相反：`/bin/bash` 3.2 反而報 unbound）→ 改成「逐版本實際跑套件」，不寫無法驗證的預測。兩鎖抽成
> `scripts/ci/lint-probe-*.py`（放探針檔內會掃到自己）；`TMP-OK` 加反向鎖（只能落真有 `/tmp/` 的行）；`CLEAN-POC-f` 排除 `env-equivalence.bats`
> （V03.6 條件式放寬②，補償＝ENV-EQ-5 + 釘 bats）。
> Reviewer：V03.6 二審 round E `f8f35524` = OK with notes（0 P0 / 1 P1 / 10 P2）P 項全修；round F 對 delta 另審；11 條突變全咬。
> 已知殘餘：CI ubuntu bash 5.2 本機無法驗證（只有 3.2/5.3）；CI 釘版走 `git clone` 需網路；本機 `python3` 3.14 vs CI 3.12 尚未納入等價探針。
