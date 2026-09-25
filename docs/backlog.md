# Backlog — tree_monstor 5 條優化（Trust Mode）

> 來源：2026-09-23 用戶對話「in tree_monstor 現在你覺得什麼地方可以優化？」→「全部 #1 至 #5 都做」
> 模式：Trust Mode（deadline 2026-09-23 10:03）

---

## Backlog 清單

| ID | 主題 | 優先級 | 點數 | 狀態 | 依賴 |
|----|------|--------|------|------|------|
| TMO-001 | 清 .gitignore RSI 殘留 + 刪 .agents/tree_monstor/ 髒副本 | P0 | 1 | pending | — |
| TMO-002 | install.sh 拆 lib/install/*.sh 子模組 | P1 | 5 | pending | TMO-001 |
| TMO-003 | 補缺 wiki bats + 修 README badge 數字 | P2 | 3 | pending | TMO-002 |
| TMO-004 | AGENTS.md §2.0/§2.6 重構 + Reviewer 二審 | P0 | 5 | pending | TMO-001 |
| TMO-005 | tools/ 統一 logging（修正版：trap + 共用 log_*） | P2 | 3 | done | TMO-001 | ✅ 2026-09-25 完成（v1.7 翻轉決策拆 `skills/dav-wiki/scripts/`；v1.7.1 順手修 wiki-cleanup.sh 中文 log 變數解析 bug）。原始決策紀錄保留（trust-log 2026-09-23 + v1.7 changelog）。 |

---

## TMO-001 詳細

**問題**：
1. `.gitignore` 還殘留 5 行 sop-evolver RSI 規則（commit 5db8c2e 移除 RSI 但 .gitignore 漏改）
2. `.agents/tree_monstor/` 是開發機跑 install.sh 留下的髒副本，雖然被 gitignore 但污染 IDE/Obsidian

**完成標準**：
- `.gitignore` 移除所有 sop-evolver 規則
- `.agents/` 維持整個被 gitignore 排除
- 跑 `git status` 確認 working tree clean
- regression-guard 確認安裝流程沒壞

---

## TMO-002 詳細

**問題**：993 行 install.sh 拆成主程式 + lib 子模組

**完成標準**：
- install.sh < 200 行只負責 args + dispatch
- lib/install/logging.sh / paths.sh / symlink.sh / agents.sh / sop.sh / agents_dir.sh / uninstall.sh
- 所有現有 bats 測試 100% 通過
- install --global / --local / --uninstall 行為不變

---

## TMO-003 詳細

**問題**：
1. 補上缺 bats 的工具（wiki-index / wiki-media-describe / wiki-extract-audio）
2. 合併 wiki-cross-ref-multimodal.bats → wiki-cross-ref.bats（內容重疊）
3. 修 README.md badge 從 105 → 實際 208

**完成標準**：
- 全部 @test 個數對得上 badge 數字
- 所有 bats 跑過
- 合併後的 wiki-cross-ref.bats 覆蓋兩邊的測試情境

---

## TMO-004 詳細

**問題**：AGENTS.md §2.0 與 §2.6 角色混淆，新人不知走哪條

**完成標準**：
- §2.6 升格為「一般任務 SOP（輕量版）」獨立入口
- §2.0 表格改為明確二分
- §2.6 內的「灰色地帶判斷表」改成「升級觸發器」
- Reviewer subagent 給「沒找到更多問題」
- changelog v1.5 同步更新

---

## TMO-005 詳細

**問題**：原方案「加 set -e」已驗證是錯的（已用 set -uo pipefail 故意設計）

**完成標準**：
- 從 install.sh 抽出共用 lib/log.sh
- tools/wiki-*.sh 改 source lib/log.sh
- 加 trap 統一錯誤處理
- 把 tools/ 拆成 tools/wiki/ 子目錄
- 行為向後相容（不破壞現有 bats）
- file header 一致