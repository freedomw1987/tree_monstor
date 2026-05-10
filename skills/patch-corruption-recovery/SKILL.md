---
name: patch-corruption-recovery
description: When a patch edit corrupts a file (syntax error, mismatched braces, nested function inside wrong scope) — restore from git and re-patch cleanly instead of patching the broken state.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [debugging, patch, git, recovery, troubleshooting]
    related_skills: [systematic-debugging]
---

# Patch Corruption Recovery

## When to Use

These symptoms mean a patch landed incorrectly and the file is corrupted:

- `SyntaxError: Unexpected }` or `Unexpected token` after a patch
- `bun run typecheck` shows NEW errors in a file that was clean before the patch
- Patch accidentally inserted code inside the wrong function (e.g., `parsePdf` inside `fileMimeFromPath`)
- File line count changes unexpectedly (e.g., a 50-line file becomes 120 lines after a patch meant to add 20)
- Incremental patches can't fix the corruption because the file structure is already broken

## The Recovery Workflow

### Step 1: Confirm the original was clean

Find the last known-good commit and verify it had no errors:

```bash
# Check recent commits
git log --oneline -5

# Restore file to last known good commit (DON'T commit yet)
git checkout <last-good-commit> -- path/to/corrupted/file

# Verify typecheck passes
bun run typecheck
# Should show 0 errors (ignore node_modules pre-existing errors)
```

### Step 2: Restore the file

```bash
# Restore to clean state — this is the cleanest path
git checkout <last-good-commit> -- path/to/corrupted/file
```

### Step 3: Re-patch correctly — ONE change at a time

After each patch, verify before proceeding:

```bash
# Verify typecheck
bun run typecheck

# Verify startup (for server files)
timeout 5 bun src/index.ts
```

### Step 4: Commit only after verified

```bash
git add -A && git commit -m "description"
```

## Why NOT to Patch a Broken File

When a patch corrupts a file, the file structure is already wrong:
- Extra/missing braces put code in the wrong scope
- Functions nested inside other functions create dangling code
- Each additional patch on the broken state compounds the damage

Trying to fix with more patches is like trying to untangle by adding more knots.

**The cleanest path is always:**
```
Corrupted file → git restore to last clean → re-patch correctly
```

## Real Example: chat.ts pdf-parse patch corruption (2026-04-26)
- Old `fileMimeFromPath` function body got replaced because `old_string` matched from `import pdf-parse` to its closing `}` — the patch tool matched first occurrence which was INSIDE `fileMimeFromPath`, replacing the entire function body with `parsePdf` definition
- Fix: `git checkout 343ec07 -- backend/src/routes/chat.ts` then re-apply all patches cleanly

## Prevention

| Practice | Why |
|----------|-----|
| **Typecheck BEFORE and AFTER each patch** | Catch corruption immediately, not after 3 more patches |
| **One concept per patch** | If a 50-line file becomes 120 lines after a patch meant to add 20, something went wrong |
| **Check `git diff --stat`** | Always look at what actually changed |
| **Verify startup for server files** | `timeout 5 bun src/index.ts` catches runtime errors typecheck misses |

## Diagnostic Commands

```bash
# Find the extra/missing brace causing SyntaxError
python3 -c "
content = open('path/to/file').read()
brace_count = 0
for i, c in enumerate(content):
    if c == '{': brace_count += 1
    elif c == '}': brace_count -= 1
    if brace_count < 0:
        print(f'Extra }} at position {i}, line {content[:i].count(chr(10))+1}')
        break
if brace_count > 0:
    print(f'{brace_count} missing }} at end')
"

# Compare file size before and after patch
git diff HEAD --stat path/to/file

# Isolate the problematic commit
git bisect start
git bisect bad HEAD
git bisect good <last-known-good-commit>
```
