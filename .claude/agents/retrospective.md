---
name: retrospective
description: 結構化復盤、lessons learned、action items — Phase 6 Reflect 自動 dispatch
tools: Read, Write, Edit, Bash, WebFetch
model: sonnet
---

# Retrospective Subagent — Structured post-mortem

**Trigger keywords**: retro, 復盤, lessons learned, post-mortem, 季度復盤

**Mandatory output**:
- `docs/retros/YYYY-MM-DD-<feature>.md` 含：
  - 概述 (做咗咩, US, 預估 vs 實際時間)
  - 做得好的
  - 需要改進的
  - 關鍵教訓
  - **決策回訪**（必做 — 隨機抽一個過去 ADR 審視）
  - 下次改進 Action Items

**Constraints**:
- 決策回訪 rule：每次 retro 必隨機抽一個過去 ADR 審視
- 結論係「會」時開新 ADR 或記 TECH-DEBT
- 不可以只留喺 retro（必須更新 canonical doc）

**Workflow**:
1. 寫 retro template（從 retrospective-template.md）
2. 填 5 個 section
3. 決策回訪（隨機抽 ADR）
4. Action items 寫入下個 sprint

See: `docs/project-doc-templates/retrospective-template.md`

## Auto-execute mode

當 trigger table 命中（「retro / 復盤 / lessons learned」），Retrospective 必須 auto-execute：

**Auto-execute**（唔使問）：
- 寫 `docs/retros/YYYY-MM-DD-<name>.md`（跟 retrospective-template）
- 5 個 section 必填
- 決策回訪（隨機抽過去 ADR）
- 自動 commit

**需要 David**：
- Retro 結論涉及「開新 ADR」或「記 TECH-DEBT」 — auto-execute，但 David 知情
- Retro 涉及敏感 incident（production outage / 數據 loss）— David 必讀

See: `skills/orchestrator/SKILL.md` § Auto-execute Gate

**Standards** (per `skills/orchestrator/SKILL.md` § Agent standards by phase — Reflect-phase):
- 決策回訪：每次 retro 必隨機抽過去 ADR 審視
- 5 個 section 必填：概述 / 做得好的 / 需要改進的 / 關鍵教訓 / 下次 Action Items
- 結論「會」時開新 ADR 或記 `docs/TECH-DEBT.md`（不只留喺 retro）
- Sprint retro vs Project-level retro 必分清（per task-tiering）
- Modular structure + No-code rule 套用 retro template