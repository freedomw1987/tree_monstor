# Sprint 06 計劃 — TD-006 GitHub Actions CI（2026-01-15）

> **Sprint 主題**：把技術債推到 0 — 從 US-001 留下的 P2 技術債，3 年後終於補上
> **總 SP**：2 SP
> **前置**：Sprint 05 ✅ DONE

## 1. Sprint 目標

建立 GitHub Actions CI workflow，在每個 PR / push 自動跑：
- bats 全套測試（macOS + Linux）
- markdownlint
- bash -n 兩個 CLI 腳本
- SKILL.md 行數檢查（≤ 150）
- 驗證 Python 在 macOS / Linux 行為一致

## 2. Sprint Backlog

| ID | 標題 | SP | 優先級 |
| --- | --- | --- | --- |
| **TD-006.1** | GitHub Actions workflow（`.github/workflows/ci.yml`）| 1 | P2 |
| **TD-006.2** | 在 README.md 加 CI badge | 0.25 | P3 |
| **TD-006.3** | 文件：貢獻者指南（CONTRIBUTING.md）含 CI 說明 | 0.5 | P3 |
| **TD-006.4** | 補一個 Linux-specific test fixture | 0.25 | P2 |

## 3. Workflow 設計

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4

      - name: 跑 bats 全套
        run: |
          if ! command -v bats >/dev/null; then
            sudo apt-get install -y bats || brew install bats-core
          fi
          bats tests/

      - name: 跑 markdownlint
        run: |
          npm install -g markdownlint-cli2
          markdownlint-cli2 "skills/**/*.md" "docs/**/*.md" "tests/**/*.md"

      - name: 驗證 bash 語法
        run: bash -n tools/wiki-cleanup.sh && bash -n tools/wiki-cross-ref.sh

      - name: 驗證 SKILL.md ≤ 150 行
        run: |
          LINES=$(wc -l < .agents/skills/dav-wiki/SKILL.md)
          if [ "$LINES" -gt 150 ]; then
            echo "❌ SKILL.md 過長：$LINES 行（限制 150）"
            exit 1
          fi
```

## 4. 預期效益

- 每次 push 自動跑全套測試，避免「本地過、CI 沒過」
- macOS + Linux 雙平台驗證
- 揭露跨平台 bug（如 `date` 行為、`find` 路徑）

## 5. 風險

| 風險 | 影響 | 緩解 |
| --- | --- | --- |
| bats 在 GitHub Actions runner 上預設不安裝 | 測試不會跑 | workflow 內自動安裝 |
| markdownlint-cli2 需 Node.js | 額外 30 秒 | 預裝 |
| Python 跨平台行為差異 | 跨平台 bug | 跑測試時隔離環境 |

## 6. 成功指標

- `.github/workflows/ci.yml` 創建且語法正確
- workflow 在本地能乾跑（`act` 或 dry-run 模式驗證）
- README.md 有 CI badge（placeholder OK，實際 URL 等 repo push 後補）
- CONTRIBUTING.md 含 CI 章節
- 本地跑 bash -n 確認 workflow YAML 合法

## 7. 對話記錄

- 用戶決策：2026-01-15 選擇「A 跑 TD-006」
- 規劃模式：dav-planner（單輪決策）