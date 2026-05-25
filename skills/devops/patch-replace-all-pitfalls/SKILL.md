---
name: patch-replace-all-pitfalls
description: Avoid syntax errors when using patch replace_all on source code — regex token replacement can corrupt parentheses and expressions.
triggers:
  - replace_all on code files
  - bulk regex substitution
  - token replacement (user.role, user.id)
---

# patch replace_all Pitfalls

## When to Use
When using the `patch` tool with `replace_all=true` on source code files.

## Core Lesson
> **Regex `replace_all` on code files is dangerous.** Replacing a short token like `user.role` with `user?.role` can corrupt parentheses balance, create malformed expressions, and produce syntax errors that are hard to spot.

## The Failure Mode
```
Original:
  if (!user || (user.role !== 'admin')) {

After replace_all user.role → user?.role:
  if (!user || (user?.user?.id !== 'admin'))   ← WRONG: double replacement
  if (!user || (user?.role !== 'admin') {       ← WRONG: missing ) in original
```

## Rules
1. **Never use `replace_all` on code files** for short token replacements (e.g. `user.role`, `user.id`)
2. **Always read the file after any bulk replacement** to verify syntax
3. **Use unique context strings** that include enough surrounding code to be unambiguous
4. For TypeScript safety: check for common patterns after replace_all:
   - Missing `)` or `}` — search for `){` or `) {` without matching open paren
   - Double replacements like `user?.user?.id`
   - Orphaned `(` with no content between

## Verification Steps
After any `replace_all` on code:
```bash
npx tsc --noEmit 2>&1 | head -30
```

## What Went Wrong in This Case
- worklogs.ts: `replace_all` replaced `user.role` inside a larger expression `!user || (user.role !== 'admin')`, producing `!user || (user?.role !== 'admin')` but the original already had a missing `)` from a prior bad replacement
- projects.ts: `replace_all` produced `user.role !== 'admin' && (!membership || !['pm', 'tech_lead'].includes(membership.role)))` with unbalanced parens

## Better Approach
Use `replace_all=false` (default) with unique context around each occurrence:
```
old_string: "if (!user || (user.role !== 'admin')) {"
new_string: "if (!user || (user?.role !== 'admin')) {"
```