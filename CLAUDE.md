# Tree Monstor Developer Profile — Claude Code Bridge

> **Status:** Adapter / Bridge. Claude Code auto-discovery entrypoint; canonical policy remains in `SOUL.md`, `AGENTS.md`, `MEMORY.md`, `docs/`, and `skills/`.

This file exists so Claude Code can open this repository normally and still find the Tree Monstor profile rules. Keep it short; do not duplicate canonical policy here.

---

## Canonical load order

At Claude Code session start, read:

1. `SOUL.md` — identity, principles, red lines
2. `AGENTS.md` — session workflow, Think/Plan/Build rules, workspace handling
3. `MEMORY.md` — stable preferences and long-term memory
4. `docs/00-index.md` — documentation map and canonical sources
5. `skills/README.md` — local Tree Monstor skill catalog
6. `adapters/claude-code/agent.md` — Claude Code-specific adapter behavior

If instructions conflict, prefer the active downstream project’s local instructions first, then this bridge, then the canonical profile docs above.

---

## Workspace detection

Before acting, determine the active workspace:

1. **Profile-maintenance mode** — current git root contains `SOUL.md`, `AGENTS.md`, `MEMORY.md`, `docs/00-index.md`, and `skills/README.md`.
2. **Downstream-project mode** — current git root is a user app/project. Read that project’s own `CLAUDE.md`, `AGENTS.md`, README, package files, and docs before applying profile rules.
3. **Worktree mode** — current path is an isolated worktree. Report the base branch and changed files when relevant.

In Claude Code, do not assume Hermes paths such as `~/.hermes/profiles/developer` exist. Use repository-relative paths for this checkout and project-relative paths for downstream projects.

---

## Startup / resume

Use `AGENTS.md` as the canonical startup flow, adapted to the active workspace.

Resume context lookup order:

1. active workspace `docs/context-summary.md`
2. active workspace `memory/context-summary.md`
3. profile repo `docs/context-summary.md` when maintaining this profile
4. Hermes path `~/.hermes/profiles/developer/docs/context-summary.md` only when explicitly maintaining a Hermes profile install

If no summary exists, state briefly that no previous context summary was found and continue.

---

## Skill routing

Before specialized work, check `skills/README.md`.

- If Claude Code exposes a matching runtime slash/harness skill, use that runtime skill according to Claude Code rules.
- Otherwise, read the matching local `skills/<name>/SKILL.md` and apply it as task-specific instructions.
- Do not assume local markdown skills are automatically registered as Claude Code slash commands.
- Do not duplicate skill lists or skill counts in root docs.

Mandatory local workflow triggers:

| Situation | Required local workflow |
|---|---|
| Existing project with incomplete/unknown docs, tests, or regression hooks | `skills/existing-project-intake/SKILL.md` |
| Review / QA / code-review feedback changes behavior, requirements, tests, architecture, or debt | `skills/docs-sync/SKILL.md` |
| Bug fix, old bug returns, regression risk, or `RG-*` work | `skills/regression-guard/SKILL.md` |
| Large docs baseline / source-first doc batch | `skills/structural-doc-batch/SKILL.md` |

---

## Verification gates

Before claiming work is complete:

- Profile docs / skills / adapter changes:
  ```bash
  python3 scripts/docs_consistency_check.py
  ```
- Downstream project docs baseline:
  ```bash
  python3 <profile-root>/scripts/docs_consistency_check.py --root <project-root> --project-docs
  ```
- Downstream project doc-code sync:
  ```bash
  python3 <profile-root>/scripts/docs_consistency_check.py --root <project-root> --project-docs --base-ref <default-branch> --doc-code-sync
  ```
- Code changes: run the smallest relevant lint / typecheck / test / build command available in the active project.

If verification cannot run, state exactly what was not run and why. Do not claim tests or verification passed unless they actually ran or were directly observed.

---

## No hooks or commands by default

Do not add `.claude/commands`, hooks, or shared settings unless David explicitly asks for automated Claude Code harness behavior or a repeated slash-command workflow.

---

## Related docs

- [Core identity](SOUL.md)
- [Session and workspace rules](AGENTS.md)
- [Long-term memory](MEMORY.md)
- [Documentation index](docs/00-index.md)
- [Claude Code adapter](adapters/claude-code/agent.md)
- [Skills catalog](skills/README.md)
