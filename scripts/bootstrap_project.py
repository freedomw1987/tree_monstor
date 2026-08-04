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

> **Status:** Living document. US index references per-US files in `docs/US/`.
> 每個 US 一個獨立檔（per-US modular），方便 agent 為單一 feature 工作時只讀該檔。

## Scope

[與 `docs/PROJECT-OVERVIEW.md` § 範圍 一致。scope 變更兩邊同步。]

## User Story Index

| US | 標題 | 優先級 | 狀態 | Spec |
|----|------|--------|------|------|
| US-001 | [一句話標題] | P0 | DRAFT | [docs/US/US-001-example.md](US/US-001-example.md) |

狀態: `DRAFT` / `IN_PROGRESS` / `DONE` / `DEPRECATED`

## Non-Functional Requirements
- 效能: [TBD]
- 安全: [TBD]
- 兼容性: [TBD]

## 假設與風險
- 假設: [TBD]
- 風險: [TBD]

## 變更紀錄
| 日期 | US ID | 變更 | 原因 |
|------|-------|------|------|
| {today} | US-001 | 初版 baseline | bootstrap |
""",
        "docs/US/US-001-example.md": f"""# US-001 — [一句話標題]

**狀態**: DRAFT
**優先級**: P0
**對應 master**: [docs/PRD.md § User Story Index](../PRD.md)
**對應 QA tracker row**: US-001
**對應 regression test**: (尚未建立)
**最後更新**: {today} by bootstrap

## 描述
**As** [誰] **I want** [做什麼] **so that** [為什麼]

## 驗收標準
- [ ] Given [前置條件], when [動作], then [預期結果]
- [ ] ...

## 邊界情況
- ...

## Out of scope
- ...

## 依賴
- 無

## 變更紀錄
| 日期 | 變更 | 原因 |
|------|------|------|
| {today} | 初版 | bootstrap |
""",
        "docs/DESIGN.md": f"""# Design Spec — {name}

> **Status:** Living document. Tokens here are single source of truth;
> per-component specs in `docs/components/`, per-page specs in `docs/pages/`.
> **No-code rule**: 不含 source 語言 snippet（TS/JS/Python 等）；
> component 用 props table / events / a11y / states 描述。

## Overview
[設計理念、品牌定位、目標用戶畫像、設計參考連結]

## Design Tokens

### Colors
| Token | HEX | 用途 |
|-------|-----|------|
| --color-primary | [TBD] | CTA, 強調 |
| --color-bg | [TBD] | 背景 |
| ... | ... | ... |

### Typography
| Token | Font | Size / Line-height | Weight | 用途 |
|-------|------|-------------------|--------|------|
| --text-h1 | [TBD] | [TBD] | [TBD] | 頁面標題 |
| --text-body | [TBD] | [TBD] | [TBD] | 內文 |

### Spacing
[4px / 8px grid system; --space-1..5 tokens]

### Elevation
| Token | 用途 |
|-------|------|
| --elevation-1 | Card |
| --elevation-2 | Modal |

### Shapes
[Border radius tokens]

## Component Index

| Component | 規格 | 對應 US |
|-----------|------|---------|
| Button | [docs/components/Button.md](components/Button.md) | US-001 |
| Input | [docs/components/Input.md](components/Input.md) | US-001 |

## Page Index

| Page | 規格 | 對應 US |
|------|------|---------|
| Login | [docs/pages/Login.md](pages/Login.md) | US-001 |

## Do's and Don'ts
- ✅ Do: [TBD]
- ❌ Don't: [TBD]

## Changelog
| 日期 | 變更 | 原因 |
|------|------|------|
| {today} | 初版 baseline | bootstrap |
""",
        "docs/components/Button.md": f"""# Component: Button

**對應 US**: US-001
**對應實作**: (尚未建立)

## Purpose
Primary action affordance。

## Props
| Prop | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| variant | `primary` \| `secondary` \| `ghost` | no | `primary` | Visual variant |
| size | `sm` \| `md` \| `lg` | no | `md` | Size token |
| label | string | yes | — | Button text |
| onClick | `() => void` | yes | — | Click handler |
| disabled | boolean | no | `false` | Disabled state |
| loading | boolean | no | `false` | Loading spinner replaces label |

## Events
- `click` → calls `onClick`
- Keyboard: `Enter` / `Space` triggers click

## States
default / hover / active / disabled / loading

## Accessibility
- Min hit-area: 44×44px
- `role="button"`
- `aria-disabled` when disabled
- Visible focus ring per `--focus-ring` token

## Token usage
- background → `--color-primary` (or variant-specific)
- text → `--color-on-primary`
- padding → `--space-2` `--space-3`

## Do's and Don'ts
- ✅ Do: 文字按鈕至少 44x44px
- ❌ Don't: 嵌套 button

## Changelog
| 日期 | 變更 | 原因 |
|------|------|------|
| {today} | 初版 | bootstrap |
""",
        "docs/components/Input.md": f"""# Component: Input

**對應 US**: US-001
**對應實作**: (尚未建立)

## Purpose
Text input field。

## Props
| Prop | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| type | `text` \| `email` \| `password` | no | `text` | Input type |
| value | string | yes | — | Controlled value |
| onChange | `(v: string) => void` | yes | — | Change handler |
| placeholder | string | no | — | Placeholder text |
| error | string \| null | no | `null` | Error message |
| disabled | boolean | no | `false` | Disabled state |

## Events
- `change` → calls `onChange`

## States
default / focus / error / disabled

## Accessibility
- Label association via `<label>` or `aria-label`
- Error message via `aria-describedby` + `role="alert"`

## Changelog
| 日期 | 變更 | 原因 |
|------|------|------|
| {today} | 初版 | bootstrap |
""",
        "docs/pages/Login.md": f"""# Page: Login

**對應 US**: US-001
**URL**: `/login`
**對應實作**: (尚未建立)

## Purpose
用戶輸入認證資訊。

## Wireframe
```
[待畫 — ASCII wireframe]
```

## Components used
- Input (email, password)
- Button (primary, md)

## Interaction spec
1. 用戶輸入 → 表單 state 更新
2. submit 按鈕：所有欄位 valid 前 disabled
3. submit 後：顯示 loading state
4. 成功 → 跳轉 dashboard
5. 失敗 → 顯示錯誤訊息

## States
idle / submitting / error

## Accessibility
- Form labels 明確
- 鍵盤 navigation
- 錯誤訊息 `aria-live="polite"`

## Changelog
| 日期 | 變更 | 原因 |
|------|------|------|
| {today} | 初版 | bootstrap |
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

> **Status:** Living document. Conventions here are cross-cutting;
> per-resource contracts in `docs/endpoints/`.
> **No-code rule**: JSON schema 保留（interface 規格）；
> 不寫 TS/JS/Python 等 source 語言 client-side example。

> Base URL: [TBD]
> Auth: [TBD]
> Content-Type: `application/json`

## Conventions

### Request format
- All request bodies are JSON
- Timestamps: ISO 8601 UTC
- IDs: UUID v4 unless otherwise noted

### Response format
- Success: `2xx` with JSON body
- Error: `4xx`/`5xx` with `{{ error: {{ code, message, details? }} }}` body

### Error code convention
| Status | Meaning |
|--------|---------|
| 400 | INVALID_* (client-side validation) |
| 401 | UNAUTHENTICATED |
| 403 | UNAUTHORIZED / FORBIDDEN |
| 404 | NOT_FOUND |
| 409 | CONFLICT_* |
| 429 | RATE_LIMIT |
| 5xx | INTERNAL — server-side, never leaks stack |

### Auth
- [TBD]

## Endpoint Index

> Per-resource contracts 喺 `docs/endpoints/<resource>.md`；master 只列 index。

| Resource | 規格 | Endpoints |
|----------|------|-----------|
| example | [endpoints/example.md](endpoints/example.md) | POST /example, GET /example/{{id}} |

## Endpoints

> 完整 request / response / error code 細節見 `docs/endpoints/<resource>.md`。
> 下方列出 endpoint 索引供跨資源查閱。

| Method | Path | Resource | Spec | 對應 US |
|--------|------|----------|------|---------|
| POST | /example | example | [endpoints/example.md](endpoints/example.md) | US-001 |
| GET | /example/{id} | example | [endpoints/example.md](endpoints/example.md) | US-001 |

## QA / Regression Endpoints

尚未建立。新增 QA regression endpoint 時，參照 Tree Monstor
project documentation standard 文件 5 的模板（production 不可 mount、
auth / test tenant / audit / idempotency 欄位必填）。

## Changelog
| 日期 | 變更 | 原因 |
|------|------|------|
| {today} | 初版 baseline | bootstrap |
""",
        "docs/endpoints/example.md": f"""# Endpoints: example

**對應 US**: US-001
**對應實作**: (尚未建立)

## POST /example

**描述**: [一句話]

**對應 US**: US-001

**Request Body**:
```json
{{
  "field": "value"
}}
```

**Response 200**:
```json
{{
  "id": "uuid",
  "field": "value"
}}
```

**錯誤碼**:
| Status | Code | 說明 |
|--------|------|------|
| 400 | INVALID_FIELD | [TBD] |

**對應 Test**: (尚未建立)

## GET /example/{{id}}

**描述**: [一句話]

**對應 US**: US-001

**Response 200**:
```json
{{
  "id": "uuid",
  "field": "value"
}}
```

**錯誤碼**:
| Status | Code | 說明 |
|--------|------|------|
| 404 | NOT_FOUND | [TBD] |

## Changelog
| 日期 | 變更 | 原因 |
|------|------|------|
| {today} | 初版 | bootstrap |
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

> **Status:** Living document. Master summary here; per-US detail in `docs/coverage/`.
> **orchestrator inner loop 整合**：Work Item 直接 reference `coverage/<US-id>.md`。

> 最後更新: {today}
> 總體覆蓋率: TBD

## User Story → Test Case 對照

> 完整 test inventory 喺 `docs/coverage/<US-id>.md`；master 只列 summary。
> Per-US coverage 詳情見對應 coverage 檔。

| US | 標題 | 規格 | Unit | Integration | E2E | 狀態 | 備註 |
|----|------|------|------|-------------|-----|------|------|
| US-001 | [一句話標題] | [coverage/US-001.md](coverage/US-001.md) | ❌ 0 | ❌ 0 | ❌ 0 | PENDING | baseline |

狀態: `PASS` / `PARTIAL` / `NONE` / `FLAKY`

## 測試金字塔分佈
- Unit tests: 0
- Integration tests: 0
- E2E tests: 0
- Manual smoke tests: 0

## Regression Mode / Hooks（RT/RG master index）

| ID | Type | US | Spec | Test command | Status |
|----|------|----|------|--------------|--------|
| (尚未建立) | | | | | |

Regression hooks 只可在 dev/test/staging 啟用；production 必須
not mounted / hard reject（紅線 53）。

## 已知未覆蓋區域
- [ ] 全部（baseline 階段）

## Changelog
| 日期 | 變更 | 原因 |
|------|------|------|
| {today} | 初版 baseline | bootstrap |
""",
        "docs/coverage/US-001.md": f"""# Coverage: US-001 — [一句話標題]

**對應 US**: [docs/US/US-001-example.md](../US/US-001-example.md)
**對應 RT**: (尚未建立)
**最後更新**: {today} by bootstrap

## Test inventory

### Unit tests
| Test file | 覆蓋範圍 | 狀態 |
|-----------|----------|------|
| (尚未建立) | | |

### Integration tests
| Test file | 覆蓋範圍 | 狀態 |
|-----------|----------|------|
| (尚未建立) | | |

### E2E tests
| Test file | 覆蓋範圍 | 狀態 |
|-----------|----------|------|
| (尚未建立) | | |

## RT-XXX (regression test)
- (尚未建立)

## 已知 gap
- 全部（baseline 階段）

## Changelog
| 日期 | 變更 | 原因 |
|------|------|------|
| {today} | 初版 | bootstrap |
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
- 驗證輸出必須落地：`docs/verify-log/YYYY-MM-DD-<task>.txt`
  （命令原文 + 真實輸出摘要 + exit code），與 code 改動同 commit。
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
    (root / "docs" / "verify-log").mkdir(parents=True, exist_ok=True)

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
