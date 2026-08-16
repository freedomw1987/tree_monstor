# 交付摘要 — install.sh (US-001)

> **交付日期**: 2025-08-16
> **對應 Backlog**: US-001
> **Sprint / Module**: SP0 / M1 — Installer & Distribution
> **交付狀態**: ✅ 完成

## 1. 這次完成什麼

為 `tree_monstor` 加入 `install.sh` 安裝腳本，讓 **Claude Code** 和 **Pi Agent** 等 AI agent 能在全域或專案層讀取到 `AGENTS.md`、`SOUL.md` 和 `skills/`，且改源檔能即時生效（透過軟連結）。

**關鍵成果**：

- ✅ `install.sh`（488 行純 Bash）— 完全冪等、可卸載、跨平台
- ✅ 19 個 bats 自動化測試（100% 通過）
- ✅ 完整 README.md（213 行，含 Quick Start、Examples、疑難排解）
- ✅ 支援 6 種安裝模式：`--global`、`--local`、`--target`、單一 agent、`--no-agents-dir`、`--dry-run`
- ✅ 安全卸載：用 marker 識別自己建的檔案，不碰使用者檔案

## 2. 做了什麼改動

### 2.1 新增檔案

| 檔案路徑 | 用途 |
|---------|------|
| `install.sh` | 主腳本，488 行純 Bash |
| `README.md` | 用戶文件，213 行 |
| `tests/install.bats` | 19 個 bats 測試，227 行 |
| `tests/helpers/test-env.bash` | 測試環境 helper，94 行 |
| `tests/fixtures/mock-tree-monstor/AGENTS.md` | Fixture |
| `tests/fixtures/mock-tree-monstor/SOUL.md` | Fixture |
| `tests/fixtures/mock-tree-monstor/skills/dav-planner/SKILL.md` | Fixture |
| `tests/fixtures/mock-tree-monstor/skills/dav-designer/SKILL.md` | Fixture |
| `docs/discussion/2025-08-16-install-sh-design.md` | 設計討論記錄 |
| `docs/plan/2025-08-16-install-sh-design.md` | 設計計劃（含架構圖、模組劃分） |
| `docs/backlog.md` | 專案 backlog（首次建立） |
| `docs/reflection/us-001-reflection.md` | User Story 反省報告 |
| `docs/deliverable/2025-08-16-install-sh.md` | 本檔（Markdown 詳錄） |
| `docs/deliverable/2025-08-16-install-sh.html` | 視覺化版 |

### 2.2 修改檔案

| 檔案路徑 | 改動內容 |
|---------|---------|
| `docs/backlog.md` | 加入 US-001（含 16 條 AC、13 個子任務）+ Technical Debt 區塊 |

### 2.3 刪除檔案

無

## 3. 驗收標準對應

對應 Backlog 中 US-001 的 16 條 AC，全部 ✅ 通過：

| AC | 描述 | 結果 | 證據 |
|----|------|------|------|
| AC-1 | 預設全域安裝，skills 軟連結到 `~/.claude/skills` 和 `~/.pi/skills` | ✅ | `tests/install.bats:21` |
| AC-2 | Claude Code 建立 `CLAUDE.md` wrapper，內含 `@` 引用 | ✅ | `tests/install.bats:30` |
| AC-3 | Pi Agent symlink AGENTS.md、SOUL.md、skills | ✅ | `tests/install.bats:41` |
| AC-4 | 同時安裝到本機 `.agents/tree_monstor/` | ✅ | `tests/install.bats:50, 61` |
| AC-5 | `--local` 裝到當前目錄 | ✅ | `tests/install.bats:68` |
| AC-6 | `--target <path>` 裝到指定路徑 | ✅ | `tests/install.bats:80` |
| AC-7 | `--agent claude\|pi` 篩選 | ✅ | `tests/install.bats:90, 98` |
| AC-8 | `--uninstall` 只刪自己建的 | ✅ | `tests/install.bats:108` |
| AC-9 | `--dry-run` 不實際執行 | ✅ | `tests/install.bats:129` |
| AC-10 | `--help` 顯示完整用法 | ✅ | `tests/install.bats:143` |
| AC-11 | 完全冪等 + 修復斷掉 symlink | ✅ | `tests/install.bats:153, 167` |
| AC-12 | 排除 `.obsidian/.git/.DS_Store`（含巢狀） | ✅ | `tests/install.bats:185` |
| AC-13 | 彩色輸出 + NO_COLOR 相容 | ✅ | `tests/install.bats:197` |
| AC-14 | 純 Bash，相容 macOS / Linux | ✅ | `tests/install.bats:205` |
| AC-15 | README 文件 | ✅ | `tests/install.bats:210` |
| AC-16 | 自動化測試覆蓋所有 AC | ✅ | `tests/install.bats:218` |

## 4. 測試結果

| 測試類型 | 通過 / 總數 | 通過率 | 備註 |
|---------|-------------|--------|------|
| Bats 黑盒測試 | **19 / 19** | **100%** | 含 16 條 AC + 3 個子測試 |

執行方式：

```bash
brew install bats-core   # 安裝測試框架（macOS）
bats tests/              # 跑全部測試
```

每個測試用 `mktemp -d` + `env -i` 隔離環境，**不污染真實 `~/`**。

## 5. 已知問題 / 限制

> 從反省報告 [`docs/reflection/us-001-reflection.md`](../reflection/us-001-reflection.md) 整理

| ID | 問題 | 嚴重性 | 已記錄 |
|----|------|--------|--------|
| TD-005 | AC-11a 冪等測試用 hash 比對，跨平台可能不一致 | P2 | `docs/backlog.md` |
| TD-006 | 沒做 CI（GitHub Actions macOS + Linux） | P2 | `docs/backlog.md` |
| TD-008 | Magic strings 散落（`.claude`、`.pi`、marker），未集中 | P3 | `docs/backlog.md` |
| Limit-1 | 不支援 Windows 原生（WSL 可） | By design | 文件已說明 |
| Limit-2 | 沒做備份用戶原檔（卸載時衝突會警告） | By design | 文件已說明 |

## 6. 下一步建議

### 6.1 立即可做（建議優先）

1. **第一次實際安裝驗證** — 在你常用的 shell 跑：
   ```bash
   ./install.sh --dry-run --global     # 先預覽
   ./install.sh --global               # 確認 OK 才執行
   ```
   確認 Claude Code 和 Pi Agent 都能讀到 `AGENTS.md` / `SOUL.md` / `skills/`。

2. **驗證卸載** — 測試不會誤刪你的檔案：
   ```bash
   ./install.sh --uninstall --global
   ```
   確認你原本的 `~/.claude/*` 和 `~/.pi/*` 中**非 install.sh 建的**檔案都還在。

### 6.2 下一個 Sprint 考慮

- [ ] **TD-006**：加 GitHub Actions CI（`macos-latest` + `ubuntu-latest`，跑 `bats tests/`）
- [ ] **TD-005**：把 AC-11a 改成具體檔案比對（更精準的冪等驗證）
- [ ] **TD-008**：把 `.claude`、`.pi`、`.agents`、marker 字串集中成常數（讓未來加新 agent 更簡單）
- [ ] **擴充支援**：加 `--agent cursor` / `--agent aider` 等（按你需求）

### 6.3 長期方向（Think Big）

- **跨專案 skills 分享**：把 `tree_monstor` 的 skills 設計成可分享的 library，未來任何專案用 `--local` 就能載入
- **install.sh → install**：未來可考慮用 Go/Rust 重寫並編譯成單一 binary（但目前 Bash 已足夠）
- **版本管理**：支援 `tree_monstor` 多版本並存（例如用 `--version v0.2.0` 指定源）

## 7. 相關文檔連結

- [Backlog US-001](../backlog.md#us-001為-tree_monstor-加入-installsh)
- [設計討論記錄](../discussion/2025-08-16-install-sh-design.md)
- [設計計劃](../plan/2025-08-16-install-sh-design.md)
- [反省報告](../reflection/us-001-reflection.md)
- [README](../../README.md)
- [HTML 視覺化版](./2025-08-16-install-sh.html)

## 8. SOP 流程記錄

| SOP 步� | 狀態 |
|---|---|
| 2.1 溝通 & 思考（一題一題） | ✅ 完成（6 題） |
| 2.2 計劃（dav-designer） | ✅ 完成 |
| 2.3 執行（TDD + dev-checker-loop + regression-guard） | ✅ 完成（5 階段） |
| 2.4 自我反省（dav-reflection） | ✅ 完成 |
| 2.5 提交成果（dav-submitter） | ✅ 完成（本檔） |

---

**產生者**: Agent (透過 dav-submitter skill)
**產生時間**: 2025-08-16
