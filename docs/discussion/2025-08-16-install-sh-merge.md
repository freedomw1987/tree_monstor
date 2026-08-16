# 討論記錄：installer 與既有 `~/.claude/skills` 衝突

**對應 Backlog**：DE-001
**日期**：2025-08-16
**作者**：Agent（依 SOP 2.1）
**觸發**：用戶執行 `./install.sh`（全域安裝）時，installer 在 `~/.claude/skills` 已有 69 個用戶自裝 skills 的情況下安全拒絕覆寫。

---

## 1. 觸發情境

```
$ ./install.sh
[i] Source : /Users/davidchu/Sites/localhost/tree_monstor
[i] Mode   : global
[i] Target : /Users/davidchu
[i] Agents : claude pi
[i] Action : install
[i] Plan:
    → mode=global  target=/Users/davidchu  source=/Users/davidchu/Sites/localhost/tree_monstor
    → agents: claude pi
    → /Users/davidchu/.claude/CLAUDE.md (wrapper with @references)
    → /Users/davidchu/.claude/skills -> /Users/davidchu/Sites/localhost/tree_monstor/skills
    → /Users/davidchu/.pi/AGENTS.md -> /Users/davidchu/Sites/localhost/tree_monstor/AGENTS.md
    → /Users/davidchu/.pi/SOUL.md   -> /Users/davidchu/Sites/localhost/tree_monstor/SOUL.md
    → /Users/davidchu/.pi/skills    -> /Users/davidchu/Sites/localhost/tree_monstor/skills
    → /Users/davidchu/.agents/tree_monstor/ (copy)
[?] Proceed? [y/N] y
[i] Installing for Claude Code...
[✗] Path exists but is not a symlink: /Users/davidchu/.claude/skills
[✗] Refusing to overwrite. Move it aside and re-run.
```

**環境偵察**：
- `~/.claude/skills/` 是真實目錄，含 69 個用戶自裝 skills（`autoplan`、`benchmark`、`codex`、`design-consultation`、`design-html`、`design-review`、`design-shotgun` 等）
- `~/.claude/CLAUDE.md` 已是 symlink → `/Users/davidchu/www/tree_monstor/CLAUDE.md`（指到舊路徑，不是現源）
- `~/.pi/` 完全不存在
- `~/.agents/` 已存在但被 Claude Code 自己的機制使用

**根因**：`install.sh` 的 `ensure_symlink()` 對「存在但不是 symlink」的目標直接拒絕，沒有提供「合併」選項。這個設計在「全新環境」是對的，但在「已有 skills 生態」的環境下會產生阻塞。

---

## 2. 與用戶的 3 個決策問答

### Q1：如何處理已存在的 `~/.claude/skills`？

**候選**：
- A. 合併策略（保留用戶 skills，把 tree_monstor skills 合併進去）
- B. 備份後覆蓋（把現有 skills 改名備份，installer 建 symlink）
- C. 只安裝 Pi Agent（跳過 Claude 安裝）

**用戶回答**：**A（合併策略）**
> "1"

**理由**：用戶已投資 69 個 skills，直接覆蓋是高風險；tree_monstor 是專為 Pi Agent 設計的 workflow，Claude 走 symlink 反而會打亂原本結構。

---

### Q2：合併時用什麼形式？

**候選**：
- A1. 整個 symlink（`~/.claude/skills/tree_monstor/...`）
- A2. 逐個 symlink（`~/.claude/skills/dav-planner -> .../...`）
- A3. 整個 copy

**用戶回答**：**A2（逐個 symlink）**
> "A2"

**理由**：扁平路徑乾淨，符合 Claude Code 慣例；保持 symlink 可即時同步。

---

### Q3：`~/.claude/CLAUDE.md` 怎麼處理？

**候選**：
- A. 寫 wrapper（覆蓋現有 symlink）
- B. 不動（保留現狀）
- C. 重新指向新版 tree_monstor 源（用 `@` 引用 `~/Sites/localhost/tree_monstor/AGENTS.md`）

**用戶回答**：**C（重寫）**
> "C"

**理由**：現有 symlink 指到 `www/tree_monstor/` 那是凍結的舊快照，未來編輯新源 Claude 收不到；改用 `@references` 引用新源才是 live 同步，也符合 `install.sh` 設計原意。

---

## 3. 真實需求確認（給用戶的回讀）

> **DE-001** 的真實需求是：
>
> 1. installer 必須能在 `~/.claude/skills` 不是 symlink 的情況下**自動合併**，不報錯
> 2. 合併預設是**逐個 symlink**（per-skill 級別），保留用戶原有 skills
> 3. 對於命名衝突的 skill，**跳過並警告**，絕不覆蓋用戶自己的
> 4. 對 `~/.claude/CLAUDE.md`，無論是 symlink 還是普通檔，都重寫為標準 wrapper（用 `@` 引用新 path）
> 5. 對 `~/.pi/`（全新）+ `.agents/` 維持原計劃
> 6. 提供覆寫旗標（如 `--claude-skills-mode`）讓用戶選擇 replace / skip
> 7. 全部新邏輯需有對應 bats 測試

請用戶看完確認 → 進入 SOP 2.3 執行階段。
