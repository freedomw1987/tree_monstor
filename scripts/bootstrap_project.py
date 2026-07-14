#!/usr/bin/env python3
"""Bootstrap the Tree Monstor documentation baseline into a downstream project.

Generates the red-line-10 baseline skeleton (8 required docs + ADR +
QA-TRACKER + REGRESSION-GUARD + optional project CLAUDE.md) so a new
project can pass `docs_consistency_check.py --project-docs` from day one.
Existing files are never overwritten — they are reported and skipped.

Usage:
  python3 scripts/bootstrap_project.py --root ~/www/my-project [--name "My Project"] [--no-claude-md]
"""

from __future__ import annotations

import argparse
import datetime
import sys
from pathlib import Path


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Bootstrap Tree Monstor project documentation baseline.")
    parser.add_argument("--root", type=Path, required=True, help="Downstream project root.")
    parser.add_argument("--name", help="Project display name (default: root directory name).")
    parser.add_argument("--no-claude-md", action="store_true", help="Skip generating the project CLAUDE.md bridge.")
    return parser.parse_args(argv)


def templates(name: str, today: str) -> dict[str, str]:
    return {
        "docs/PROJECT-OVERVIEW.md": f"""# {name} — Project Overview

## 一句話
[這個 project 做什麼，用一句非技術語言解釋]

## 目標用戶
- 主要: [誰會用]
- 次要: [誰會間接受影響]

## 核心價值主張
- [用戶用這個 project 解決什麼問題？]

## 成功標準
- KPI 1: [具體可量度]

## 範圍 (Scope)
- ✅ In scope: [做什麼]
- ❌ Out of scope: [不做什麼，防 scope creep]

## 主要 Risk
- Risk 1: [風險] → Mitigation: [應對]

## 變更歷史
| 日期 | 變更 | 原因 |
|------|------|------|
| {today} | 初版 baseline (bootstrap) | 專案啟動 |
""",
        "docs/PRD.md": f"""# {name} — PRD

## User Stories

### US-001 — [一句話標題]
**As** [誰] **I want** [做什麼] **so that** [為什麼]

**優先級**: P0
**驗收標準**:
- [ ] Given [前置條件], when [動作], then [預期結果]
**Out of scope**: [這個 story 不做什麼]
**依賴**: 無

## Non-Functional Requirements
- 效能: [TBD]
- 安全: [TBD]

## 假設與風險
- 假設: [TBD]

## 變更紀錄
| 日期 | US ID | 變更 | 原因 |
|------|-------|------|------|
| {today} | US-001 | 初版 baseline | bootstrap |
""",
        "docs/DESIGN.md": f"""# Design Spec — {name}

## Overview
[設計理念與目標用戶畫像；無 UI 的 project 在此標 N/A + reason]

## Design Tokens
[TBD — 定稿時補；參照 Tree Monstor project documentation standard 文件 3]

## Components
[TBD]

## Changelog
| 日期 | 變更 | 原因 |
|------|------|------|
| {today} | 初版 baseline | bootstrap |
""",
        "docs/architecture/0001-initial-architecture.md": f"""# ADR-0001 — Initial architecture baseline

## Status
Proposed

## Context
[面對什麼問題？有什麼 constraints？]

## Decision
[選了什麼 stack / 架構？TBD 於 Plan 定案時填寫。]

## Consequences
### Positive
- [TBD]
### Negative
- [TBD]

## Alternatives Considered
### 方案 A — [名]
- 不選原因: [TBD]

## References
- ({today} bootstrap baseline)
""",
        "docs/API.md": f"""# API Reference — {name}

> Base URL: [TBD]
> Auth: [TBD]

## Endpoints

[無 API 的 project 在此標 N/A + reason。有 API 時每個 endpoint 一段：
request / response / 錯誤碼 / 對應 US。]

## QA / Regression Endpoints

尚未建立。新增 QA regression endpoint 時，參照 Tree Monstor
project documentation standard 文件 5 的模板（production 不可 mount、
auth / test tenant / audit / idempotency 欄位必填）。

## 變更歷史
| 日期 | 變更 | 原因 |
|------|------|------|
| {today} | 初版 baseline | bootstrap |
""",
        "docs/QA-TRACKER.md": f"""# QA Tracker — {name}

> 規則：PRD 每個 US 必須有 row；改 US 標 PARTIAL，刪 US 標 DEPRECATED（紅線 11）。

## User Story → Test Task 對照

| US | 描述 | 優先級 | Test tasks | Regression Hook | 狀態 |
|----|------|--------|-----------|-----------------|------|
| US-001 | [一句話標題] | P0 | [TBD] | [TBD] | PENDING |

## 變更歷史
| 日期 | 變更 | 原因 |
|------|------|------|
| {today} | 初版 baseline | bootstrap |
""",
        "docs/TEST-COVERAGE.md": f"""# Test Coverage — {name}

> 最後更新: {today}
> 總體覆蓋率: TBD

## User Story → Test Case 對照

| US | 描述 | Unit | Integration | E2E | 狀態 | 備註 |
|----|------|------|-------------|-----|------|------|
| US-001 | [一句話標題] | ❌ 0 | ❌ 0 | ❌ 0 | PENDING | baseline |

## Regression Mode / Hooks

尚未建立。Regression hooks 只可在 dev/test/staging 啟用；production
必須 not mounted / hard reject（紅線 53）。有 bug fix 或 P0 flow 時
在此建 matrix（欄位見 Tree Monstor testing strategy）。

## 已知未覆蓋區域
- [ ] 全部（baseline 階段）

## 變更歷史
| 日期 | 變更 | 原因 |
|------|------|------|
| {today} | 初版 baseline | bootstrap |
""",
        "docs/TECH-DEBT.md": f"""# Tech Debt Register — {name}

| ID | 描述 | 優先級 | 成本估算 | 業務影響 | 狀態 | 記錄日期 |
|----|------|--------|----------|----------|------|----------|
| TD-001 | [範例：暫用 in-memory cache，量大後要換] | P2 | [TBD] | [TBD] | OPEN | {today} |

## 變更歷史
| 日期 | 變更 | 原因 |
|------|------|------|
| {today} | 初版 baseline | bootstrap |
""",
        "docs/VERIFY.md": f"""# Verify — {name}

> 最後核對: {today}（命令與 package.json / tooling 一致）

## Verification commands

| Gate | Command | N/A + reason |
|------|---------|--------------|
| Lint | [TBD，例 `bun run lint`] | |
| Typecheck | [TBD，例 `bun run typecheck`] | |
| Test | [TBD，例 `bun test`] | |
| Build | [TBD，例 `bun run build`] | |
| Smoke (deploy 後) | [TBD] | |

## Regression suite

- Full regression: N/A + reason（baseline 階段尚未建立）

## 規則

- 每個 gate 必須有 command 或明確 N/A + reason，不可留空。
- 代碼改動交付前，跑最小相關 gates 並回報真實輸出（紅線 55）。
- 驗證命令變更時，本檔必須同 commit 更新。
""",
        "docs/REGRESSION-GUARD.md": f"""# Regression Guard — {name}

> 規則：每個 bug fix 必須有 RG entry（root cause + prevention，紅線 13/14）。
> QA Regression Mode 只可在 dev/test/staging 啟用；production 必須
> not mounted / hard reject（紅線 53）。

## Entries

尚無 entry。首個 bug fix 時按以下模板建立：

### RG-XXX — [bug 一句話]
- **Symptom**: [觀察到的錯誤行為與重現步驟（紅線 54）]
- **Root cause**: [為什麼會壞]
- **Fix**: [改了什麼]
- **Prevention**: [防再壞的 test / invariant]
- **QA Regression Mode**: [Frontend hook / Backend hook / QA enablement /
  Seed-reset data / Test command / Expected result / Safety boundary /
  Production exposure check]

## 變更歷史
| 日期 | 變更 | 原因 |
|------|------|------|
| {today} | 初版 skeleton | bootstrap |
""",
    }


def claude_md_template(name: str) -> str:
    return f"""# {name} — Project Instructions

本專案採用 Tree Monstor 文檔基線（紅線 10）。

## 驗證（最高優先）

- 任何代碼改動，交付前跑 `docs/VERIFY.md` 定義的最小相關 gates，回報真實輸出。
- Bug fix 先重現（紅線 54）；每個 fix 寫 `docs/REGRESSION-GUARD.md` entry（紅線 13/14）。

## 文檔同步

- 改 PRD 必同步 `docs/QA-TRACKER.md`（紅線 11）。
- 需求 / API / 設計 / 架構變更，同 commit 更新受影響 docs。
- Baseline 一致性檢查：`python3 <tree_monstor-root>/scripts/docs_consistency_check.py --root . --project-docs`

## 專案慣例

- [TBD：stack、目錄結構、環境變數等專案特有規則]
"""


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    root = args.root.expanduser().resolve()
    if not root.exists() or not root.is_dir():
        print(f"invalid project root: {root}", file=sys.stderr)
        return 2
    name = args.name or root.name
    today = datetime.date.today().isoformat()

    files = dict(templates(name, today))
    if not args.no_claude_md:
        files["CLAUDE.md"] = claude_md_template(name)

    created: list[str] = []
    skipped: list[str] = []
    for rel_path, content in files.items():
        target = root / rel_path
        if target.exists():
            skipped.append(rel_path)
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
        created.append(rel_path)
    (root / "docs" / "retros").mkdir(parents=True, exist_ok=True)

    for rel_path in created:
        print(f"created  {rel_path}")
    for rel_path in skipped:
        print(f"skipped  {rel_path} (already exists — not overwritten)")

    try:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        from docs_consistency_check import report, run

        issues = run(root, project_docs=True)
        print()
        report(issues, json_output=False, quiet=False)
        return 1 if issues else 0
    except ImportError:
        print(
            "\nnext: python3 scripts/docs_consistency_check.py "
            f"--root {root} --project-docs",
        )
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
