# Skills Catalog

> **Status:** Catalog. Local skills index; each skill's source of truth is its own `SKILL.md`.

**10 core skills** kept under `skills/`. No archive directory — retired / stack-specific / niche patterns live in git history only (`git log --all -- '*<skill-name>*'` or `git log -S '<name>'`).

This catalog lists **local Tree Monstor skills** at two levels:

1. **Top-level skills** — immediate child directories of `skills/` with a `SKILL.md` file, hand-curated in the tables below.
2. **Nested skills** — `skills/<category>/<skill>/SKILL.md` entries, auto-generated into the「Nested skills by category」section by `scripts/generate_skills_catalog.py`.

Each skill’s canonical source is its own `SKILL.md`. This catalog is a navigation aid, not a replacement for reading the skill itself.

---

## Maintenance rule

When adding, removing, or renaming a local skill:

1. Top-level skill → update the hand-curated tables in the same change. Nested skill → run `python3 scripts/generate_skills_catalog.py` to regenerate the nested section（不要手改生成段）。
2. Do **not** add skill counts to `README.md`, `SOUL.md`, `MEMORY.md`, `AGENTS.md`, or `docs/00-index.md`.
3. If a count is needed for release notes or verification, compute it from `skills/**/SKILL.md` at verification time.
4. Keep descriptions short enough to scan; detailed instructions belong in each skill’s own `SKILL.md`.
5. After catalog changes, run `python3 scripts/docs_consistency_check.py` from the repository root（it verifies both levels' coverage）.
6. **Content freshness（advisory，唔係 gate）**：`docs_consistency_check.py` 只驗導航結構，唔驗 skill 內容係咪仍然成立。定期（建議每季，或引用 version-pinned skill 之前）跑 `python3 scripts/skills_freshness_audit.py` 排 review 優先次序 — 佢按最後 review 日期列出過期 skills，有 pin 住具體版本（如 Elysia / Prisma / CDK 版號）嘅排最前。Review 完一個 skill 而內容唔使改時，喺該 `SKILL.md` 頂部加/更新一行 `Last-verified: YYYY-MM-DD`（audit 會優先讀呢個標記）；內容有改就唔使，git commit 日期自動更新。發現內容已過時 → 更新或 archive 該 skill。呢個 audit 刻意設計為 advisory（預設 exit 0），**唔好**加入 pre-commit / CI。
7. **Skill lifecycle — case-history vs reusable**：每個 `SKILL.md` 喺 frontmatter 加 `applicability: operational | generic-pattern`(`operational` = profile-level workflow / orchestration / methodology;`generic-pattern` = 可重用於任何用緊個 stack 嘅 project)。**新 case-history / post-mortem skill 唔再 promote 上 `skills/`,亦唔再 archive** —— 留喺 git history(`git log --all -- '*<skill-name>*'` 或 `git log -S '<skill-name>'`)。**只有 reusable insight 先 promote 上 `skills/`**。咁 routing surface 唔再被 case-history 撈污,真係 reusable 嘅 pattern 先留喺 working tree。

---

## Claude Code routing note

These are local Tree Monstor markdown skills. They are not automatically Claude Code slash commands unless separately registered in the active Claude Code runtime. Currently registered: `regression-guard`, `existing-project-intake`, `dev-checker-loop`, `patch-corruption-recovery`, `docs-sync`, `orchestrator` — via wrappers in `adapters/claude-code/skills/` symlinked from `~/.claude/skills/`; the canonical source remains each skill's `SKILL.md` here.

**2026-08-02 merge**: `dev-checker-loop` skill merged into `orchestrator`. The `/dev-loop` adapter remains (redirects to orchestrator canonical) so the slash command still works.

In Claude Code:

1. Use this catalog to choose the matching local skill.
2. Read `skills/<name>/SKILL.md` before acting.
3. If Claude Code exposes a matching runtime slash / harness skill, prefer invoking that runtime skill and use the local skill docs as Tree Monstor-specific supplement.
4. Keep this catalog as navigation only; each `SKILL.md` remains canonical.

---

## Core skills (10 keepers)

### Orchestration & multi-agent

| Skill | Purpose | When to use |
|-------|---------|-------------|
| [`orchestrator`](orchestrator/SKILL.md) | Multi-subagent coordination (outer: task board, dependencies, multi-role dispatch) with per-work-item dev+checker verification loop (inner: STATE.md, regression test, fresh checker). | Multi-phase tasks; multi-item feature dev with built-in quality gate; "dev-loop" / "checker agent" / 雙 agent 開發 requests. |

### Documentation / QA / project hygiene

| Skill | Purpose | When to use |
|-------|---------|-------------|
| [`doc-html-preview`](doc-html-preview/SKILL.md) | Syncs `docs/*.md` into standalone HTML previews for engineering and decision review. | After docs updates that need David/user confirmation. |
| [`docs-sync`](docs-sync/SKILL.md) | Synchronizes review feedback, QA findings, and code-review suggestions into durable project docs. | After Review/Test/QA/user feedback changes requirements, design, API, architecture, tests, regression behavior, or tech debt. |
| [`existing-project-intake`](existing-project-intake/SKILL.md) | Intake workflow for existing projects before continuing development. | Existing/inherited projects with incomplete docs, unknown current state, or missing QA/regression hooks. |
| [`plan-author`](plan-author/SKILL.md) | Converts Think / Plan conversation into modular plan docs (PRD master + per-US + DESIGN + components/pages + ADRs + QA-TRACKER baseline + VERIFY). | New project / new major feature / greenfield — Plan phase start with no source code yet. |
| [`spec-driven-development`](spec-driven-development/SKILL.md) | Foreground BA gate: turns every new feature / user-story request into docs/specs/REQ-XXX/spec.md (Given/When/Then AC) + tests.md (AC→RT traceability) before implementation. dev-checker-loop cannot close until every AC has passing real evidence. | Every T2/T3 new feature / user-story request; "新功能" / "REQ-XXX" / "驗收標準". |
| [`regression-guard`](regression-guard/SKILL.md) | Records regression guards for bug fixes. | Every bug fix or regression-prone change. |
| [`structural-doc-batch`](structural-doc-batch/SKILL.md) | Batch documentation organization and structural cleanup. | Large documentation cleanup or re-indexing work. |
| [`tech-debt-register`](tech-debt-register/SKILL.md) | Tracks technical debt with priority, cost, and business impact. | Known debt, refactor tradeoffs, deferred cleanup. |
| [`patch-corruption-recovery`](patch-corruption-recovery/SKILL.md) | Prevents replace-all/regex edit corruption and recovers from corrupted patch/edit states by restoring and re-patching cleanly. | Bulk replace-all on code, syntax corruption, mismatched braces, broken patch attempts. |

### DevOps / security gate

| Skill | Purpose | When to use |
|-------|---------|-------------|
| [`devops/dependency-cve-audit`](devops/dependency-cve-audit/SKILL.md) | Audit project dependencies for known CVEs (npm + bun + lockfiles) — fulfills 紅線 18 (Critical/High CVE must be 0 to merge). | Before any merge to main; periodic audit for prod systems. |

---

## Archived skills

No archive directory. Retired patterns live in git history only — recoverable via `git log --all -- '*<skill-name>*'` or `git log -S '<name>'`. See the 2026-08 compression commits for what was retired and why:

- **Stack-specific** (Prisma, Elysia/Bun, CDK, Docker, React/Vite, Tailwind, iOS, Nginx): reusable only within a specific stack; better as project-level cheatsheet than profile-level routing
- **Niche / one-shot** (e.g. `mac-apfs-case-insensitive-git-tracking`, single-deploy gotchas): not core to multi-project workflow
- **Hermes retired** (`dev-task-memory`, `interruption-recovery`): runtime automation retired 2026-07-28; Claude Code built-in resume covers
- **Claude Code built-in cover** (`ultrawork`): hard-deleted; Claude Code's Workflow tool has the patterns

---

<!-- BEGIN GENERATED: nested-skills-catalog (scripts/generate_skills_catalog.py) -->

## Nested skills by category（自動生成）

> 本段由 `scripts/generate_skills_catalog.py` 生成，**不要手改**；新增 / 刪除嵌套技能後重跑該腳本。每個技能的 canonical source 仍是其 `SKILL.md`。

### `devops/`

| Skill | Description |
|-------|-------------|
| [`dependency-cve-audit`](devops/dependency-cve-audit/SKILL.md) | Audit project dependencies for known CVEs — fulfills 紅線 18 (Critical/High CVE must be 0 to merge). Class-level skill that covers BOTH npm + bun projects, lockf… |

<!-- END GENERATED: nested-skills-catalog -->

---

## Related docs

- [Documentation index](../docs/00-index.md)
- [README](../README.md)
- [Core identity](../SOUL.md)
