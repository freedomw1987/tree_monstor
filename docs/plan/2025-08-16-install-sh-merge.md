# 設計計劃：installer 在 `~/.claude/skills` 已存在時的合併策略

**對應 Backlog**：DE-001
**日期**：2025-08-16
**狀態**：待用戶審核
**作者**：Agent（依 SOP 2.2）
**討論來源**：[`docs/discussion/2025-08-16-install-sh-merge.md`](../discussion/2025-08-16-install-sh-merge.md)

---

## 1. 目標

讓 `install.sh` 在 `~/.claude/skills` 已經是真實目錄（用戶有自裝 skills）時，**不報錯、自動合併**——把 `tree_monstor/skills/` 中的每個 skill 逐個 symlink 進去，保護用戶原有 skills 不被破壞。

---

## 2. 系統架構

### 2.1 新增 CLI 旗標

| 旗標 | 說明 | 預設 |
|---|---|---|
| `--claude-skills-mode <mode>` | 處理 `~/.claude/skills` 已存在時的策略 | `merge` |
|  | `merge` — 逐個 symlink，命名衝突跳過警告 | |
|  | `replace` — 改名備份後建 symlink（破壞式） | |
|  | `skip` — 跳過 Claude skills，只裝 wrapper + `.pi` + `.agents` | |

### 2.2 安裝流程變更（`install_claude`）

```
install_claude:
  1. 確保 ~/.claude/ 目錄存在
  2. 處理 CLAUDE.md（持續行為不變：symlink 解除，普通檔覆蓋，內容寫 wrapper）
  3. 處理 skills/ ← 新邏輯 ↓
  4. 印摘要

處理 skills/ 流程：
  ┌────────────────────────────────────────────────────────┐
  │  case: $CLAUDE_SKILLS_MODE in                          │
  │  merge:                                                │
  │    if 不是 symlink 且 是目錄:                           │
  │      for skill in $SOURCE_DIR/skills/*:                │
  │        target = ~/.claude/skills/<skill-name>          │
  │        if target 不存在:                                │
  │          ln -s $SOURCE_DIR/skills/<skill> $target      │
  │          log_ok "merged: .../"                         │
  │        else:                                            │
  │          log_warn "conflict: <skill> 已存在，略過"      │
  │      done                                               │
  │    elif 不是 symlink 且 不是目錄:                       │
  │      log_err "~/.claude/skills 是檔案，無法合併"       │
  │      exit 1                                             │
  │    elif 是 symlink:                                      │
  │      原 ensure_symlink 邏輯（指向正確就跳過，否則修）  │
  │  replace:                                               │
  │    if 不是 symlink:                                      │
  │      mv ~/.claude/skills ~/.claude/skills.bak.$(date)   │
  │      log_warn "備份原 skills 為 ~/.claude/skills.bak..." │
  │    然後 ensure_symlink                                  │
  │  skip:                                                   │
  │    log_info "skipping ~/.claude/skills (per --claude-skills-mode=skip)" │
  └────────────────────────────────────────────────────────┘
```

### 2.3 模組劃分（沿用 US-001 M1）

| 子模組 | 變動 |
|---|---|
| M1.1 旗標解析 | ➕ 新增 `--claude-skills-mode` 解析 |
| M1.4 Claude 安裝 | 🔧 重構 `install_claude` 的 skills 處理 |
| M1.3 冪等連結 | ➕ 新增 `ensure_merged_skill()` / `ensure_merged_skills()` |
| M1.9 輸出 | 不變 |

### 2.4 函數設計

```bash
# 處理 ~/.claude/skills 的單一 skill 合併
ensure_merged_skill() {
  local link="$1"          # ~/.claude/skills/dav-planner
  local target="$2"        # /Users/.../tree_monstor/skills/dav-planner

  if [[ -L "$link" ]]; then
    local current; current="$(readlink "$link")"
    local target_abs; target_abs="$(abs_path "$target")"
    if [[ "$current" == "$target_abs" ]]; then
      log_ok "merge OK: $link -> $target_abs"
      return 0
    fi
    log_warn "merge: symlink 指向錯誤，修復: $link ($current -> $target_abs)"
    run rm "$link"
    run ln -s "$target_abs" "$link"
    return 0
  fi

  if [[ -e "$link" ]]; then
    log_warn "merge: 目標已存在（非 symlink），略過: $link"
    return 0
  fi

  run ln -s "$target" "$link"
  log_ok "merged: $link -> $target"
}

# 處理整個 skills 目錄的合併
ensure_merged_skills_into() {
  local src_skills="$1"     # /Users/.../tree_monstor/skills
  local dst_skills="$2"     # ~/.claude/skills

  if [[ -L "$dst_skills" ]]; then
    # 已是 symlink，走原 ensure_symlink
    ensure_symlink "$dst_skills" "$src_skills"
    return 0
  fi

  if [[ ! -e "$dst_skills" ]]; then
    # 不存在，直接 symlink
    ensure_symlink "$dst_skills" "$src_skills"
    return 0
  fi

  if [[ ! -d "$dst_skills" ]]; then
    log_err "merge: $dst_skills 存在但不是目錄，無法合併"
    return 1
  fi

  log_info "merge: 合併 $src_skills/* 到 $dst_skills/"
  shopt -s nullglob
  local skill_path skill_name
  for skill_path in "$src_skills"/*; do
    skill_name="$(basename "$skill_path")"
    ensure_merged_skill "$dst_skills/$skill_name" "$skill_path"
  done
  shopt -u nullglob
}
```

---

## 3. 測試策略

### 3.1 新增 bats 測試案例（≥ 5 個）

| 測試 ID | 場景 | 對應 AC |
|---|---|---|
| `test_merge_skills_into_existing_dir` | 預設 merge 模式，~已有 skills/，逐個 symlink 進去 | AC-1, AC-2 |
| `test_merge_skips_naming_conflicts` | 已有同名 skill 時略過並警告 | AC-3 |
| `test_merge_repairs_wrong_symlinks` | 已有同名 symlink 但指向錯誤，自動修復 | AC-3 |
| `test_claude_skills_mode_replace_backup` | `--claude-skills-mode=replace` 備份原 skills 並建 symlink | AC-4 |
| `test_claude_skills_mode_skip` | `--claude-skills-mode=skip` 完全跳過 | AC-4 |
| `test_claude_wrapper_overwrites_old_symlink` | 現有 symlink 指到舊源，自動重寫指向新源 | AC-5 |
| `test_dry_run_shows_merge_actions` | dry-run 正確顯示 merge 行為 | AC-10 |

### 3.2 測試輔助

- 擴充 `tests/helpers/test-env.bash`：新增 `create_existing_skills_dir()` helper
- `tests/fixtures/mock-tree-monstor/`：維持現狀（已有 skill-a / skill-b）
- 新增 `tests/fixtures/mock-tree-monstor/skills/conflict-skill/`：模擬命名衝突案例

### 3.3 完整測試預期

舊 19 個 + 新 7 個 = **26 個** 測試 → 全部通過

---

## 4. 開發流程（TDD + 循環）

### 階段 A：TDD 骨架（`tdd-test-writer`）
1. 寫 7 個新 bats 測試 → 全部紅燈
2. 提交 red

### 階段 B：實作迴圈（`dev-checker-loop`）
1. 先實作 `ensure_merged_skill()` + `ensure_merged_skills_into()` 兩個 helper
2. 改 `install_claude()` 改用新 helper
3. 加入 `--claude-skills-mode` 旗標解析
4. 對每個 AC → 寫最小實作讓對應測試綠燈
5. 重構
6. 跑全部 26 個測試，確認沒破壞

### 階段 C：探針（`regression-guard`）
在 `install_claude` / `ensure_merged_skills_into` / `ensure_merged_skill` 加 `__PROBE__` 標記。

### 階段 D：User Story 級反省（`dav-reflection`）
DE-001 是 Defect，等同小 US，做 US 級反省。

### 階段 E：提交（`dav-submitter`）
產出 3 層交付物。

---

## 5. UX 設計

預設 merge 模式的輸出：

```
[i] Installing for Claude Code...
[!] ~/.claude/skills 已存在為真實目錄，進入 merge 模式
[✓] merged: /Users/davidchu/.claude/skills/dav-planner -> /Users/.../tree_monstor/skills/dav-planner
[✓] merged: /Users/davidchu/.claude/skills/dav-designer -> /Users/.../tree_monstor/skills/dav-designer
[!] merge: 略過衝突 (現有非同名校 skill): /Users/davidchu/.claude/skills/<既有同名 skill>
[i] 共合併 8 個、略過 0 個、衝突 0 個
[✓] file written: /Users/davidchu/.claude/CLAUDE.md (overwrite old symlink)
```

注意：原 `[✗] Refusing to overwrite.` 錯誤訊息改為 `[!] 已切換到 merge 模式`。

---

## 6. 風險與緩解

| 風險 | 緩解 |
|---|---|
| 用戶不小心選 merge，skills 氾濫 | 輸出明確列出「合併了哪些、跳過了哪些」 |
| 命名衝突被略過，用戶沒注意到 | 印 `[!]` 警告；建議用 `--claude-skills-mode=replace` 確認 |
| `shopt -s nullglob` 影響其他函數 | 在 for 結束後 `shopt -u nullglob` 還原 |
| 空 source skills 目錄讓 merge 變 no-op | 計入「合併 0 個」並 log info |

---

## 7. 交付物清單

- [ ] `install.sh` 新增 ~80 行（`ensure_merged_*` + 旗標解析 + 改 `install_claude`）
- [ ] `tests/install.bats` 新增 7 個測試案例
- [ ] `tests/fixtures/mock-tree-monstor/skills/conflict-skill/`
- [ ] `docs/deliverable/2025-08-16-install-sh-merge.md`
- [ ] `docs/deliverable/2025-08-16-install-sh-merge.html`
- [ ] `docs/reflection/2025-08-16-install-sh-merge-reflection.md`（DE 級反省）

---

## 8. 待用戶確認

請你看完整份計劃後告訴我：

1. **計劃 OK，可以進入 SOP 2.3 開始寫新的測試（red）？**
2. 或者你想改某個部分（例如：merge 預設行為、旗標命名、測試案例）？

確認後我就會：
1. 進入 SOP 2.3：用 `tdd-test-writer` 寫 7 個新測試（先紅）
2. 然後 `dev-checker-loop` 實作 → 綠燈 → 重構
3. 中間穿插 `regression-guard` 加探針
4. 跨 `~/.claude/skills`→tree_monstor/skills 衝突時自動 merge
5. 完成後 `dav-reflection` + `dav-submitter`
