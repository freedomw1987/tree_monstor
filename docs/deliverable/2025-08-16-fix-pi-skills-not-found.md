# Deliverable: 修復 pi agent 在「另一個項目」找不到 tree_monstor skills

**日期**：2025-08-16
**類型**：Bug Fix / Environment Setup + install.sh Patch
**對應 Backlog**：無（前次 install.sh 執行的後遺症）

---

## 🎯 用戶回報

> 「我行完 bash install.sh 之後，在另一個項目中用 pi agent 時，用不到 skills」

## 🔍 根因

`install.sh --global`（預設行為）把 symlink 放到了 **`~/.pi/skills/`**，但 pi 的 skill discovery 規範路徑是 **`~/.pi/agent/skills/`**（參考 `docs/skills.md` 的 Locations 章節）。

所以原本的安裝結果：

```
~/.pi/skills      → tree_monstor/skills   ← 錯位置！pi 完全不讀
~/.pi/AGENTS.md   → tree_monstor/AGENTS.md
~/.pi/SOUL.md     → tree_monstor/SOUL.md
~/.pi/agent/skills/                              ← 根本不存在
```

外加 `~/.claude/skills/dav-*` 殘留 5 個 symlink（`--uninstall` 的 merge 模式不會清掉）。

## ✅ 解決方案（用戶選 B：所有 8 個 skills 全局化，逐個 symlink）

### 執行步驟

1. **`./install.sh --uninstall -y`**
   移除錯位的 `~/.pi/skills`、`~/.pi/AGENTS.md`、`~/.pi/SOUL.md`、`~/.claude/CLAUDE.md`、`~/.agents/tree_monstor/`

2. **手動清掉 `~/.claude/skills/dav-*` 殘留**（5 個 symlink）

3. **逐個 skill symlink 到 `~/.pi/agent/skills/` 和 `~/.agents/skills/`**：
   - dav-designer
   - dav-planner
   - dav-reflection
   - dav-skill-creater
   - dav-submitter
   - dev-checker-loop
   - regression-guard
   - tdd-test-writer

4. ~~**`~/.pi/AGENTS.md` 和 `~/.pi/SOUL.md`** symlink 到 tree_monstor~~ ❌ **這一步是錯的，已修正**（見下方修正記錄）

5. **不建** `~/.agents/AGENTS.md` / `SOUL.md`（無 agent 讀，避免垃圾文件）

## 📋 最終狀態（修正後）

```
~/.pi/
└── agent/
    ├── AGENTS.md                            → tree_monstor/AGENTS.md   ← pi 啟動讀這
    └── skills/                              (8 個 symlink，全部指向 tree_monstor/skills/*)

~/.agents/skills/                            (19 個 entries：11 原本 + 8 新增 symlink)

~/.claude/skills/                            (原本的 skills 不變；5 個 dav-* 殘留已清)
```

> **注意**：原本誤建了 `~/.pi/AGENTS.md` 和 `~/.pi/SOUL.md`，已刪除（pi 不讀這兩個位置；AGENTS.md 的正確全局位置是 `~/.pi/agent/AGENTS.md`）。

---

## 🛠 修正記錄（用戶提醒後發現的 Bug）

第一次安裝時參考了 `install.sh` 本身的行為，把 `AGENTS.md` 和 `SOUL.md` symlink 到 `~/.pi/` 根目錄。
但根據 `docs/usage.md:100` 和 `docs/quickstart.md:100`：

> Pi loads `AGENTS.md` or `CLAUDE.md` at startup from:
> - `~/.pi/agent/AGENTS.md` for global instructions
> - `AGENTS.md` or `CLAUDE.md` from parent directories and the current directory

**`~/.pi/AGENTS.md` pi 根本不讀**。原本的安裝會導致：tree_monstor 的 SOP 全局指引**完全不會被 pi 載入**，用戶在任何項目跑 pi 都看不到 SOP 規則——這正是「在另一個項目用 pi 沒感覺到跟 tree_monstor 關聯」的原因之一。

### 修正動作
1. 建立 `~/.pi/agent/AGENTS.md` → `tree_monstor/AGENTS.md`
2. 刪除 `~/.pi/AGENTS.md`（錯位）
3. 刪除 `~/.pi/SOUL.md`（pi 不讀 SOUL.md，且 tree_monstor/AGENTS.md 透過 `[[SOUL]]` 相對引用讀 tree_monstor/SOUL.md）
4. 順帶刪除 `~/.pi/skills`（被不明操作重建，是 install.sh 的錯位行為）

### 教訓
- **不要照搬 `install.sh` 的行為而不查官方文檔**——`install.sh` 自己也有這個 bug（把 AGENTS.md 放 `~/.pi/` 而非 `~/.pi/agent/`）。
- ~~未來若要徹底修，可以 patch `install.sh` 的 symlink 目標路徑。~~ ✅ **已完成 patch**

---

## 🛠 install.sh Patch（已套用）

### 修改檔案
- `install.sh` — 3 處修改
- `tests/install.bats` — 3 處 AC 更新

### install.sh 的核心改動

**1. `install_pi()`（line ~528）**
```bash
# 舊（錯）：建在 ~/.pi/
ensure_symlink "$pi_root/AGENTS.md" "$SOURCE_DIR/AGENTS.md"
ensure_symlink "$pi_root/SOUL.md"   "$SOURCE_DIR/SOUL.md"
ensure_symlink "$pi_root/skills"    "$SOURCE_DIR/skills"

# 新（對）：建在 ~/.pi/agent/
ensure_symlink "$agent_root/AGENTS.md" "$SOURCE_DIR/AGENTS.md"
[[ -d "$agent_root/skills" ]] || run mkdir -p "$agent_root/skills"
ensure_merged_skills_into "$SOURCE_DIR/skills" "$agent_root/skills"
# SOUL.md 不裝全局：pi 不讀，且 tree_monstor/AGENTS.md 透過 [[SOUL]] 引用同目錄
```

**2. `uninstall_pi()`（line ~514）**
- 改成清理 `$pi_root/agent/AGENTS.md` 和 `$pi_root/agent/skills/` 的 merged entries
- 新增 `remove_merged_skills()` helper，只刪自己建的 per-skill symlink，保留用戶其他 skill

**3. plan 輸出** — 同步更新 plan 訊息，反映新路徑

### 測試結果

```
1..26
ok 1 AC-1:  default install symlinks skills to ~/.claude/skills and ~/.pi/agent/skills/
ok 2 AC-2:  Claude wrapper with @ references
ok 3 AC-3:  creates ~/.pi/agent/AGENTS.md symlink (NOT ~/.pi/AGENTS.md)
... (全部 26 個 PASS)
```

### 設計決策記錄

| 決策 | 理由 |
|------|------|
| skills 用 **merge 模式**（per-skill symlink），不建 tree-level symlink | 用戶可能在 `~/.pi/agent/skills/` 放其他 skill（如 gsap-*），tree-level 會遮蔽它們 |
| 預建 `~/.pi/agent/skills/` 空目錄 | 確保 `ensure_merged_skills_into()` 走 merge 分支，否則會 fallback 到 tree-level |
| uninstall 後保留空的 `~/.pi/agent/skills/` 目錄 | 該目錄位置由 pi 文件規範，用戶可能想保留作爲全局 skill 容器 |
| **不安裝 SOUL.md 到全局** | pi 完全不讀 SOUL.md；tree_monstor/AGENTS.md 用 `[[SOUL]]` 同目錄引用即可 |

### 未順手修的事項（明確記下，避免遺忘）

1. **Claude Code 端有對稱 bug**：`install_claude` 在 `~/.claude/skills` 不存在時會建 tree-level symlink，可能遮蔽用戶其他 skill。但這不在本次任務範圍（用戶只要求修 Pi 端）。
2. **沒有給 `install.sh` 加 self-test 確認 AGENTS.md 真的被 pi 載入**。下次可加一個 smoke test（啟動 pi 一次，看 banner 有沒有列出 dav-* skill description）。

## 🧪 驗證結果

- ✅ `~/.pi/agent/skills/` 內 8 個 SKILL.md 全部可讀到 description
- ✅ `~/.agents/skills/` 內 8 個 SKILL.md 全部可讀到 description
- ✅ 模擬 pi 啟動的 `<available_skills>` XML payload 包含全部 8 個

## 📝 用戶確認事項（重要！）

> 1. **backlog 不存在不是問題**：dav-planner 會自己新增 `docs/backlog.md`，不需要預先存在。
> 2. **dav-skill-creater 可以給其他項目生成 skills**：用戶明確允許 dav-skill-creater 在任何項目運作時把新 skill 寫進 `tree_monstor/skills/`。
>
> 這兩點確認代表：**目前安裝結果即為最終狀態，不需要額外修改 skill 源碼**。

## ⚠️ 已知副作用（保留給用戶參考）

- 在「另一個項目」跑 pi 並說「幫我規劃」時，dav-planner 會去 `tree_monstor/docs/` 操作 backlog 文件，不是當前項目的 `docs/`。用戶已知悉。
- dav-skill-creater 在其他項目生成的 skill 統一寫入 `tree_monstor/skills/`。用戶已知悉。

## 🚀 下一步建議

- 在另一個項目跑一次 `pi`，確認 `/skill:dav-planner` 可用
- 如果發現某些 skill 在特定項目表現不如預期，再用 `dav-reflection` 做一次反省，更新 docs/backlog.md