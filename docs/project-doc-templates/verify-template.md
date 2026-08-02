# VERIFY.md — Template

> **When to use:** Plan 階段（baseline）+ Build 階段（tooling 變更時）。
> **No-code rule:** 命令本身（`bun run lint` 等）保留；不寫 inline source code。

## 必填區塊

```markdown
# Verify — <Project Name>

> 最後核對: YYYY-MM-DD（命令與 package.json / tooling 一致）

## Verification commands

| Gate | Command | N/A + reason |
|------|---------|--------------|
| Lint | `bun run lint` | |
| Typecheck | `bun run typecheck` | |
| Test | `bun test` | |
| Build | `bun run build` | |
| Smoke (deploy 後) | `curl -fsS https://<host>/health` | |

## Regression suite

- Full regression: `bun run test:regression`（或 N/A + reason）

## 規則

- 每個 gate 必須有 command 或明確 N/A + reason，**不可留空**。
- 代碼改動交付前，跑最小相關 gates 並回報真實輸出（紅線 55）。
- **驗證輸出必須落地成 artifact**：每次交付前的驗證寫入
  `docs/verify-log/YYYY-MM-DD-<task>.txt`（執行的命令 + 真實輸出摘要 + exit code；
  跑唔到嘅 gate 在 log 寫 N/A + reason）。「聲稱驗證過」必須可覆核。
- `package.json` scripts / test runner / build tooling 變更時，本檔必須同 commit 更新。
```

## Verify-log artifact 規則

- **位置**：`docs/verify-log/YYYY-MM-DD-<short-task>.txt`（或 `.md`），跟 code 改動**同 commit**
- **內容三要素**：執行的命令原文、真實輸出（長輸出可截尾，保留失敗 / 總結行）、exit code
- **目的**：紅線 55 的「回報真實輸出」由自我報告升級為 git 內可覆核的證據；`--doc-code-sync` 檢查會驗「code 改咗但冇新 verify-log」
- Verify-log 係證據，唔係文檔 — **不能**用嚟滿足「code 改動必須同步更新 project docs」嘅要求

## 更新時機
- Build 前 baseline 必須存在（跟其他 baseline 文件一起 commit）
- 任何驗證命令變更 → 同 commit 更新
- 每次 Ship 前核對「最後核對」日期與實際 tooling 是否一致