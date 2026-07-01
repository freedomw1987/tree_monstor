---
name: docs-sync
description: Synchronizes review feedback, QA findings, user corrections, and code-review suggestions into durable project docs before Build, merge, or ship.
---

# Docs Sync — Review Feedback to Project Docs

> **Status:** Operational workflow. Use this skill when feedback changes project knowledge that must survive beyond chat.

Review feedback is not complete until it is either:

1. Applied in code and reflected in the affected docs; or
2. Explicitly deferred / rejected with rationale in the appropriate project doc.

Conversation-only feedback is not durable.

---

## When to use

Use this workflow after:

- user review feedback
- QA findings
- code-review suggestions
- design review comments
- architecture review comments
- bug reports or regression discoveries
- deferred cleanup or refactor suggestions
- any Build / Review / Test / Ship correction that changes lasting project knowledge

---

## Feedback classification matrix

| Feedback type | Required docs |
|---|---|
| Scope / business goal / success criteria | `docs/PROJECT-OVERVIEW.md` + `docs/PRD.md` + `docs/QA-TRACKER.md` |
| User story / acceptance criteria | `docs/PRD.md` + `docs/QA-TRACKER.md` |
| UI / UX / component / copy / layout | `docs/DESIGN.md` + `docs/TEST-COVERAGE.md` |
| API contract / endpoint / error code / wire shape | `docs/API.md` + `docs/TEST-COVERAGE.md` |
| Architecture / data model / infrastructure | new or updated ADR under `docs/architecture/` + affected docs |
| Test gap / QA finding | `docs/QA-TRACKER.md` + `docs/TEST-COVERAGE.md` |
| Bug / regression risk | `docs/REGRESSION-GUARD.md` + `docs/TEST-COVERAGE.md` + related `docs/QA-TRACKER.md` row |
| Refactor / cleanup / known trade-off | `docs/TECH-DEBT.md` |
| Dependency / external package assumption | `docs/TECH-DEBT.md` and ADR / retro if architectural or incident-derived |
| Rejected suggestion | affected doc changelog / notes or `docs/TECH-DEBT.md` with rationale |

---

## Workflow

1. Inventory each feedback item.
2. Classify each item using the matrix.
3. Assign one status per item:
   - `applied`
   - `deferred`
   - `rejected`
   - `needs David decision`
4. Update affected docs before or in the same change as code.
5. Keep `docs/PRD.md` and `docs/QA-TRACKER.md` synchronized for every `US-*` change.
6. For bug fixes, create or update the `RG-XXX` entry and regression coverage.
7. Run verification commands.
8. Final response must include:
   - feedback items handled
   - docs updated
   - deferred / rejected items and rationale
   - unresolved questions
   - verification commands and results

---

## Verification

Run from the repository root:

```bash
python3 scripts/docs_consistency_check.py
python3 scripts/docs_consistency_check.py --project-docs
python3 scripts/docs_consistency_check.py --project-docs --base-ref origin/main --doc-code-sync
git status --short
git diff --name-only
```

If a command fails because the downstream project documentation baseline intentionally does not exist yet, report the failure and whether it is expected for the current repository state. Do not hide failed verification.

---

## Final report format

```markdown
## Docs Delta

- Feedback items handled:
- Docs updated:
- Deferred items:
- Rejected items:
- Needs David decision:
- Verification run:
- Docs intentionally not updated and why:
```

---

## Related docs

- [Skills catalog](../README.md)
- [Project documentation standard](../../docs/project-documentation-standard.md)
- [QA Gate](../../docs/qa-gate.md)
- [Feedback Loop](../../docs/feedback-loop.md)
- [Regression Guard](../regression-guard/SKILL.md)
