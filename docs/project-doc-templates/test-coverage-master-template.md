# TEST-COVERAGE.md (master) — Template

> **When to use:** Test 階段，每個 project 都必須有 master + per-US coverage 檔。
> **No-code rule:** 不適用。
> **配套：** per-US coverage 見 `coverage-us-template.md`。

## 結構

```
docs/
├── TEST-COVERAGE.md            ← master: summary table + RT/RG index
└── coverage/
    ├── US-001.md               ← per-US: 該 US 嘅 Unit/Integration/E2E/RT 細節
    ├── US-002.md
    └── ...
```

## 必填區塊

```markdown
# Test Coverage — <Project Name>

> 最後更新: YYYY-MM-DD
> 總體覆蓋率: X% (statement / branch / function / line)

## User Story → Coverage 對照（summary）

| US | 標題 | 規格 | Unit | Integration | E2E | 整體狀態 |
|----|------|------|------|-------------|-----|---------|
| US-001 | 登入 | [coverage/US-001.md](coverage/US-001.md) | ✅ 3 | ✅ 1 | ✅ 1 | PASS |
| US-002 | 註冊 | [coverage/US-002.md](coverage/US-002.md) | ✅ 5 | ✅ 2 | ❌ 0 | PARTIAL |
| US-003 | 忘記密碼 | [coverage/US-003.md](coverage/US-003.md) | ✅ 2 | ✅ 1 | ✅ 1 | PASS |
| ... | ... | ... | ... | ... | ... | ... |

狀態: `PASS` / `PARTIAL` / `NONE` / `FLAKY`

## 測試金字塔分佈
- Unit tests: N
- Integration tests: M
- E2E tests: K
- Manual smoke tests: L

## Regression Mode / Hooks（RT/RG master index）

| ID | Type | US | Spec | Test command | Status |
|----|------|----|------|--------------|--------|
| RT-001 | Feature | US-001 | coverage/US-001.md | `test:regression:rt -- RT-001` | READY |
| RG-001 | Bug regression | US-001 | docs/REGRESSION-GUARD.md | `test:regression:rg -- RG-001` | READY |
| ... | ... | ... | ... | ... | ... |

## 已知未覆蓋區域
- [ ] US-005 edge case: empty list（spec: docs/US/US-005.md）
- [ ] US-012 性能測試未做
- [ ] US-020 a11y 測試

## Changelog
| 日期 | 變更 | 原因 |
|------|------|------|
```

## 規則
- 改 US → 同步對應 `coverage/<US-id>.md` + master summary
- Regression hook 只可在 dev/test/staging 啟用；production 必須 not mounted / hard reject（紅線 53）
- orchestrator inner loop Work Item 直接 reference `coverage/<US-id>.md`