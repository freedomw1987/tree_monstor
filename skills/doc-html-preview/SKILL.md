---
name: doc-html-preview
description: Sync `docs/*.md` to standalone HTML previews in `docs/_html/` for user confirmation. MD stays as the source of truth (git-friendly, code-review friendly); HTML is a generated artifact for the user to view in a browser via `file://` during Think / Plan / Build phases. Trigger after any docs/*.md write or update in a project.
version: 1.0.0
platforms: [macos, linux]
metadata:
  hermes:
    tags: [docs, markdown, html, pandoc, preview, developer-profile]
---

# Doc HTML Preview

> **Single source of truth is the MD. HTML is a generated preview.**

## Why this exists

`SOUL.md` 紅線 10 says: "**沒有文件的代碼不能 merge**" — every project must have `PROJECT-OVERVIEW.md / PRD.md / DESIGN.md / ADR / API.md / TEST-COVERAGE.md / TECH-DEBT.md` committed to git.

David needs to **read and confirm** these documents during **Think** and **Plan** phases. Reading raw MD in a terminal is OK, but:

- 60+ projects in `~/www/` make it hard to navigate
- Some documents have design tables, color tokens, wireframes — much easier to see rendered
- Discord screenshots / file attachments get garbled in MD form

This skill gives the user (David) a **standalone HTML preview** that opens with `file://` from any browser, **without** setting up a web server, **without** committing HTML to git.

## Conventions (frozen — do not change without David's approval)

| Aspect | Rule |
|--------|------|
| Source of truth | `~/www/<project>/docs/*.md` |
| HTML output dir | `~/www/<project>/docs/_html/` (same folder as MD, `_html/` subdir) |
| HTML filename | `<doc-name>.html` (e.g. `PRD.md` → `PRD.html`) |
| Git status | **HTML is NOT committed.** `docs/_html/` MUST be in `.gitignore` |
| CSS | GitHub-like light/dark theme (respects `prefers-color-scheme`) |
| CSS embedding | Inline in `<style>` tag — no external assets, no fonts, no JS |
| Banner | Top of every HTML: "Preview of docs/X.md — built at Y by hermes dev doc-build" |
| Tools | `pandoc` (already installed) + `python3` (already installed) |
| Server | **None.** HTML opens via `file://` |

## When to trigger

**Every time the developer profile writes or updates a `docs/*.md` file** in any `~/www/<project>/` directory, immediately rebuild the HTML preview.

Concretely, in any task that produces or modifies project documentation:
1. Write the MD file.
2. **Run the build script** (see below) — do not skip.
3. **Do NOT** send a Discord notification (David is opening HTML manually via `file://`).
4. **Do NOT** commit the HTML to git.

## How to use

### After writing a project doc

```bash
bash ~/.hermes/profiles/developer/skills/doc-html-preview/scripts/build.sh \
  --project <project-name>
```

Example:
```bash
bash ~/.hermes/profiles/developer/skills/doc-html-preview/scripts/build.sh \
  --project ai-mailer
```

### Verifying

```bash
ls ~/www/<project>/docs/_html/
# Should list: PRD.html  DESIGN.html  PROJECT-OVERVIEW.html  ...
```

Open one:
```bash
open ~/www/ai-mailer/docs/_html/PRD.html   # macOS
# or
xdg-open ~/www/ai-mailer/docs/_html/PRD.html  # Linux
```

### One-off file outside `docs/`

```bash
bash .../build.sh --project ai-mailer \
  ~/www/ai-mailer/README.md
```

## What this skill does NOT do

- ❌ Does NOT set up a web server (no port, no daemon)
- ❌ Does NOT push to a hosting platform (no Vercel, no S3)
- ❌ Does NOT integrate with Hermes dashboard 9119 (that's a separate future effort)
- ❌ Does NOT send Discord notifications (David is opening HTML manually)
- ❌ Does NOT change MD content (MD is read-only input to this skill)

## Future evolution (recorded, not implemented)

| If you want... | Then consider... |
|----------------|------------------|
| Cross-project nav, search, sidebar | Upgrade to **MkDocs + Material** (B方案 in 2026-06-06 conversation) |
| Live reload on MD save | Add `watchdog` or `fswatch` watcher |
| Embed preview inside Hermes dashboard 9119 | Write a Hermes plugin (C方案) |
| Per-stage notifications (Think/Plan only) | Add Discord notifier with stage filter |

## Files in this skill

| Path | Purpose |
|------|---------|
| `SKILL.md` | This file |
| `scripts/build.sh` | Pandoc + Python MD→HTML converter (self-contained CSS) |
| `templates/github-like.css` | GitHub-like stylesheet (light + dark via `prefers-color-scheme`) |

## Related files in developer profile

- `SOUL.md` §"📋 落實後必產文件" — documents that trigger this skill
- `docs/project-documentation-standard.md` — the 8 required documents per project
- `docs/environment-isolation.md` — dev/prod boundary (this skill is dev-only)
