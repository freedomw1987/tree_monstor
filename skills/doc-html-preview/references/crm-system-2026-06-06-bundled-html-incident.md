# crm-system Day 9 — bundled HTML incident + audience-mismatch lesson

**Date**: 2026-06-06
**Project**: `~/www/crm-system`
**Skill used (in retrospect)**: `doc-html-preview` (loaded AFTER the wrong docs shipped)

## What happened

David asked: 「整理您項目文檔」

I (mistakenly) interpreted this as "build the full engineering reference set" and produced 11 docs (architecture, database, api, frontend, rbac, ai-agent, operations, contributing, plus a doc index and the existing PROGRESS/README). All 11 were written in developer-language with code samples, schema field tables, and endpoint signatures — appropriate for the dev team, wrong for the boss.

David then said: 「stop, 我是想給老闆看的 PRD 和Design」

I re-derived `docs/PRD.md` and `docs/DESIGN.md` as separate boss-facing docs, rebuilt the bundled HTML, pushed 5 commits, and shipped the fix.

## What I should have done

Loaded `skill_view(name="doc-html-preview")` BEFORE writing anything. The skill's `AUDIENCE GATE` section (added in this very patch) explicitly lists "給老闆看" / "for the boss" / "老闆版" as trigger phrases for the boss-facing doc set, with a `Failure mode to avoid (crm-system 2026-06-06)` entry that is THIS incident.

**Lesson: when a doc request is ambiguous, ask "for whom?" up front.** Specifically look for these phrases in the user's request and trigger the gate before producing any docs:

- 「我想要 PRD / 給老闆看 / 畀老闆睇 / for the boss / for 客戶 / 老闆版」
- 「Design / 設計稿 / mockup / 視覺」
- 「畀客戶睇 / 客戶負責人 / 投資者 / board member」
- 「唔好太多 technical / 唔好 schema / 唔好 code sample / 講人話」

## The second issue — bundled HTML syntax error (line 4898)

After shipping the new PRD/Design, David reported:

```
Uncaught SyntaxError: Invalid or unexpected token
  at index.html.bundled.html:4898:72
```

**Root cause**: my `build-html.cjs` had escaped `</script>` only
inside markdown content but not in the inlined `app.js` source.
While `app.js` itself didn't contain a literal `</script>`, the
markdown content in `architecture.md` (and possibly other docs)
included a JS code sample whose source string contained
`</script>` indirectly through `\` substitutions, and the resulting
inlined JS was syntactically invalid.

**Fix** (in this patch): the recipe now requires:

1. Escape `</script>` in `app.js` and `styles.css` too, not just MD
2. Add a `node --check` self-test at the end of the build script
   that extracts the inlined JS and validates its syntax. Build
   fails loudly instead of shipping a broken file.

## The third issue — uncommitted `apps/api/src/lib/context.ts` change

While reviewing `git status` before `git push`, I discovered an
uncommitted `apps/api/src/lib/context.ts` change that looked like a
**half-done auth bug fix** from a prior session:

```ts
// authContext now does nothing — empty Elysia instance
export const authContext = new Elysia({ name: 'auth-context' });

// Helper that callers were supposed to use, but NO route file imported it
export async function getUserIdFromRequest(...) { ... }
```

If I had pushed without auditing, every POST handler that relies on
`ctx.userId` would have started returning 401 (or silently
bypassing audit attribution). The fix was incomplete: the helper
existed but `quotation.ts`'s import of it broke the build
(quarantine route couldn't resolve `getUserIdFromRequest`).

**Lesson: before `git push`, audit uncommitted work you didn't author
in this session.** Specifically:

1. `git status` + `git diff <file>` for every modified file
2. Trace the imports/exports — does anything reference a symbol
   that doesn't exist in the same file or in a sibling file?
3. For auth/security files, run `typecheck` + `grep` for the
   claimed-to-be-fixed symbols
4. If unsure, `git checkout -- <file>` to revert and let the
   original owner finish the fix

This lesson was added to the `subagent-timeout-recovery` skill
under "trust-but-verify before git push".

## Take-aways for future sessions

1. **Load `doc-html-preview` BEFORE writing docs.** The skill's
   `AUDIENCE GATE` (added in this patch) surfaces the right
   audience up front.

2. **Always add `node --check` self-test to bundled HTML build
   scripts.** The recipe now requires it. See
   `references/bundled-html-recipe.md` § 2a.

3. **Before `git push`, run trust-but-verify on every file you
   didn't author this session.** Pattern documented in
   `subagent-timeout-recovery`.

4. **The bundled HTML viewer in this project is committed**
   (`docs/index.html.bundled.html`) — David specifically wanted
   it pushed so the team has a stable URL to share. Future doc
   changes MUST re-run the build and commit the rebuilt file.
