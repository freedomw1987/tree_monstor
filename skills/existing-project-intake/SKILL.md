---
name: existing-project-intake
description: |
  Intake workflow for existing projects before continuing development. Analyze current source state,
  derive a truthful docs baseline, identify QA/regression gaps, and create a safe continuation plan.
trigger: |
  "existing project", "inherited project", "continue development", "analyze current state",
  "project lacks docs", "no complete docs", "docs missing", "docs incomplete",
  "project intake", "baseline audit", "take over this project", "補 docs then continue",
  "regression endpoints missing", "QA hooks missing"
version: 1
category: software-development
---

# Existing Project Intake — Source-first baseline before Build

> **Status:** Operational workflow. Use before modifying an existing project whose docs, tests, QA tracker, or regression endpoints are incomplete, stale, or unknown.

Existing projects are not greenfield projects. Conversation history may be missing, docs may be stale, tests may not map to user stories, and QA / regression hooks may not exist. Current source, tests, config, and git history are the evidence base.

---

## Core rule

For an existing project with incomplete or unverified docs, do not begin feature / bug development until a source-first intake has produced a task-appropriate documentation baseline.

- Do not block every small task on full ideal documentation if a task-scoped baseline is enough.
- Do not ignore missing docs either.
- Create the minimum truthful baseline required for the requested change.
- Record broader missing docs as `docs/TECH-DEBT.md`, intake report follow-up, or explicit backlog.
- Unknowns must be marked `TBD`, `Unknown`, or `N/A + reason`; never invent product/API/design facts.

---

## Scope options

When David has not specified depth, offer these options:

1. **Intake report only** — read-only source inventory and gap report; no docs/code changes.
2. **Docs baseline then stop** — source-first docs baseline and verification; no feature code changes.
3. **Full intake plus first development plan** — docs baseline, QA/regression gap matrix, and safe implementation plan.
4. **User-selected subset** — David chooses exact areas to inspect or document.

Default recommendation: option 3 for active development work; option 1 for quick due diligence.

---

## Phase 0 — Pre-work state capture

Before changing project docs or code, capture:

- current branch and `git status --short`
- recent commits and bug/fix-related commit messages
- existing docs inventory (`README`, `docs/`, ADRs, changelog, wiki exports)
- package/dependency files (`package.json`, `pyproject.toml`, `go.mod`, etc.)
- app entrypoints and runtime scripts
- routes/controllers/API handlers
- frontend pages/components, if applicable
- database schema/migrations/ORM models
- tests, test configs, CI/deploy files
- env/config examples and deployment manifests

If existing docs contradict source, source wins. Mark the doc stale and update from evidence.

---

## Phase 1 — Source inventory

Derive current state from source before writing docs.

| Area | What to derive |
|---|---|
| Project shape | stack, app type, package manager, runtime, deploy style |
| Product surface | routes, pages, commands, jobs, workers, scripts |
| API surface | endpoints, request/response shapes, auth requirements, error behavior |
| UI/UX | pages, forms, critical flows, components, states |
| Data model | schemas, migrations, ORM models, storage |
| Auth/security | auth middleware, RBAC, permissions, tenant boundaries, rate limits, audit |
| Tests | unit/integration/E2E inventory, commands, gaps, smoke checks |
| Regression readiness | `RG-`, `/__qa`, `REGRESSION_MODE`, seed/reset hooks, fake mailbox, test clock, queue drain, QA panels, `data-testid` |
| Deployment | Docker, CI, infra files, env vars, release scripts |
| Known debt | TODO/FIXME, bug/fix commits, existing tech-debt docs |

---

## Phase 2 — Documentation baseline

Use canonical templates from `docs/project-documentation-standard.md` and source-first derivation from `skills/structural-doc-batch/SKILL.md`.

Required baseline before Build, or explicit `N/A + reason` where applicable:

- `docs/PROJECT-OVERVIEW.md`
- `docs/PRD.md`
- `docs/DESIGN.md` or explicit N/A
- `docs/architecture/0001-*.md`
- `docs/API.md` or explicit N/A
- `docs/QA-TRACKER.md`
- `docs/TEST-COVERAGE.md`
- `docs/TECH-DEBT.md`
- `docs/REGRESSION-GUARD.md` only when bug/RG history exists, `RG-*` appears, or the requested task is a bug fix

Minimum task-scoped baseline is acceptable when David wants a targeted change. Example: API-only change can defer full design docs with N/A reason, but must baseline API behavior, affected requirements, tests, QA tracker, and tech debt if relevant.

---

## Phase 3 — Regression and QA endpoint readiness audit

Classify each regression / QA signal:

| Classification | Meaning |
|---|---|
| Existing and safe | Hook/endpoint exists, documented, guarded, scoped, and production-blocked |
| Missing but needed | Deterministic verification requires state/time/queue/mailbox/external control not currently available |
| Unsafe | Hook exists but may bypass security, mutate unscoped data, or be production-exposed |
| N/A with reason | No hook needed because unit/integration fixture or existing test setup is deterministic enough |

Scan for:

- `RG-`
- `REGRESSION_MODE`
- `/__qa`
- `qa:seed` / `qa:reset`
- `seedRegression`
- fake mailbox / notification inbox
- test clock / time travel
- queue drain / job controls
- frontend QA panel
- `data-testid`
- ad-hoc `/debug`, `/dev`, `/test`, `/seed`, `/reset`, `/mock`, `/fixture` endpoints

Missing `/__qa/*` is not automatically a blocker. Add or propose `/__qa/*` only when deterministic QA/E2E verification needs controllable state, time, queue, external services, mailbox, or per-`RG-XXX` setup.

Unsafe endpoints are blockers until guarded or documented as not for use.

---

## Phase 4 — Continue-development gate

End intake with one of these states:

1. **Blocked**
   - baseline missing for affected area
   - source behavior unknown
   - PRD / QA tracker drift unresolved
   - no safe test path for intended P0/P1 or bug-fix work
   - unsafe QA/regression endpoint found

2. **Ready for planning**
   - baseline exists or task-scoped baseline is proposed
   - gaps are documented
   - next scope can be planned with David

3. **Ready for Build**
   - baseline passes
   - scope approved
   - test / regression path defined
   - doc sync expectations clear

Verification commands:

```bash
python3 scripts/docs_consistency_check.py --project-docs
python3 scripts/docs_consistency_check.py --project-docs --base-ref origin/main --doc-code-sync
```

Use the project’s default base ref if it is not `origin/main`.

---

## Required output — Existing Project Intake Report

```markdown
## Existing Project Intake Report

### 1. Current State Summary
- Project type:
- Main stack:
- App entrypoints:
- Data layer:
- API surface:
- UI surface:
- Deployment/runtime:
- Current git state:

### 2. Documentation Baseline Status
| Required doc | Exists | Source-derived/current? | Action |
|---|---:|---:|---|
| PROJECT-OVERVIEW.md | Yes/No | Yes/No/Unknown | Create/update/keep |
| PRD.md | Yes/No | Yes/No/Unknown | Create/update/keep |
| DESIGN.md | Yes/No/N/A | Yes/No/Unknown | Create/update/N/A |
| ADR | Yes/No | Yes/No/Unknown | Create/update |
| API.md | Yes/No/N/A | Yes/No/Unknown | Create/update/N/A |
| QA-TRACKER.md | Yes/No | Yes/No/Unknown | Create/update |
| TEST-COVERAGE.md | Yes/No | Yes/No/Unknown | Create/update |
| TECH-DEBT.md | Yes/No | Yes/No/Unknown | Create/update |
| REGRESSION-GUARD.md | Yes/No/N/A | Yes/No/Unknown | Create/update/N/A |

### 3. Test and QA Inventory
- Unit tests:
- Integration tests:
- E2E tests:
- Smoke commands:
- Coverage known/unknown:
- P0/P1 flows without tests:

### 4. Regression Readiness
| Area | Current hook | Gap | Production safety concern | Recommendation |
|---|---|---|---|---|

### 5. QA Endpoint Readiness
- `/__qa/*` found:
- Debug/dev/test endpoints found:
- Auth/secret/allowlist:
- Tenant/data scope:
- Production exposure:
- Safety risk:

### 6. Blockers Before Build
- [ ] Missing docs baseline:
- [ ] PRD ↔ QA tracker drift:
- [ ] Missing test plan:
- [ ] Unsafe/missing regression mode:
- [ ] Unknown source behavior:

### 7. Minimum Baseline Needed For This Task
- Must add before coding:
- Can defer:
- N/A with reason:

### 8. Recommended Next Step
- Option A:
- Option B:
- Option C:
```

---

## Pitfalls

- **Hallucinated docs**: never invent PRD/API/design facts. Derive from source or mark Unknown.
- **Stale docs as truth**: existing docs may be wrong; verify against source.
- **Build before baseline**: existing projects still need task-scoped baseline before behavior changes.
- **`/__qa/*` as bypass**: QA endpoints are deterministic fixture/observability/orchestration, not auth/security bypass.
- **Unsafe production exposure**: QA panels, fake mailboxes, test clocks, seed/reset endpoints must be guarded and production-blocked.
- **Scope creep**: intake may reveal many gaps; summarize and ask David to choose the first development slice.
- **Wholesale overwrite**: patch/source-derive large docs; do not regenerate and erase existing context without evidence.

---

## Related docs

- [Structural doc batch](../structural-doc-batch/SKILL.md)
- [Regression guard](../regression-guard/SKILL.md)
- [Project documentation standard](../../docs/project-documentation-standard.md)
- [QA Gate](../../docs/qa-gate.md)
- [Testing strategy](../../docs/testing-strategy.md)
- [QA tracker](../../docs/qa-tracker.md)
