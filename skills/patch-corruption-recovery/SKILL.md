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
| **Re-read the full file with `read_file` (no offset/limit) before patching a region that has nearby lookalike blocks** | Avoids `patch` fuzzy-match anchoring on the wrong copy of a repeated anchor (see "Adjacent-anchor pitfall" below) |
| **Pause on "Found 2 matches for old_string" errors** | It means the file has near-duplicate anchor regions (e.g. two consecutive `import { ... }` blocks). Add MORE surrounding context, don't blindly `replace_all` |

## Adjacent-anchor pitfall (2026-06-08, crm-system ChartBlock.tsx)

**Symptom**: `patch replace` silently deletes a comment block 5 lines
above the intended anchor, while the actual edit lands correctly.
Typecheck / build passes because the deleted lines were a comment —
so the corruption is INVISIBLE until someone reads the file.

**Root cause**: I had used `read_file(..., offset=15, limit=20)` to
inspect a region of `ChartBlock.tsx`. The first 20 lines contained
one occurrence of a 5-line "Register the controllers..." comment.
A few lines below, the actual `ChartJS.register(...)` block started.
When I later tried to delete the "5 lines before `ChartJS.register`"
(so I could move the comment to a different position), my `old_string`
matched the comment by its textual content — but `patch` was also
fuzzy-matching on the lines AFTER it, which were the `import` block.
Fuzzy match picked a different region that happened to have the same
trailing pattern, and the comment in that OTHER region got deleted.

**Import-silently-dropped pitfall (2026-06-09, pm-system agent/runtime.ts)**

**Symptom**: After a `patch` that *should* have only modified a
middle block of `agent/runtime.ts`, the `import { Elysia } from 'elysia'`
line at the top of the file vanished. TypeScript compiler reported:
```
ERROR [358:10] Cannot find name 'Elysia'.
```
LSP diagnostics showed 30+ noise errors from intermediate-state
corruption, so the real issue (missing import) was buried.

**Root cause (the bit that actually bit me)**: My `old_string`
matched a **second occurrence** of the import block deeper in the
file (a copy-pasted fragment in a function body, which I had no
reason to know existed because I'd only `read_file` a windowed
view). `patch`'s fuzzy-match picked that second occurrence, leaving
the actual top-of-file import block in an intermediate state
where the `Elysia` import line was no longer reachable by
post-patch `new_string`.

**Detection recipe (use this when you see many LSP errors at once)**:
1. **Verify with the actual runtime**, not LSP. For Bun:
   ```bash
   bun --print 'import("./src/path/file.ts").then(m => Object.keys(m))'
   ```
   If the import resolves and `Object.keys` returns the expected
   exports, the file is fine — LSP is stale.
2. **Read the file fresh** (`read_file(path)` with NO `offset/limit`)
   to see the actual top-of-file imports, then check each
   `import { X }` against every usage site of `X` in the file.
3. **Diff against HEAD**: `git diff path/to/file` — if you see a
   deleted `import` line that you didn't intend to delete, that's
   the corruption.

**Recovery if it happens**:
1. `git diff path/to/file` to confirm what got dropped.
2. **Manually re-add the missing import** at the top of the file
   (a one-line `patch` is safer than trying to chain more patches
   on a partially-broken state).
3. Re-run `bun --print 'import(...)'` to confirm fix.

**Prevention recipe (extends adjacent-anchor pitfall)**:
- **Never write an `old_string` that starts with a bare `import {`**
  if the file has multiple import blocks. Anchor on a more specific
  pattern (a unique comment, a function signature, the line just
  before *and* just after the target).
- **After every `patch` on a file**, run
  `git diff path/to/file | head -30` to eyeball what changed at
  the top, even if the patch was supposed to touch only line 50.
- If a session has introduced a corrupt intermediate state and LSP
  is flooding you with errors, **trust `bun --print 'import(...)'`**
  **over LSP diagnostics** — the runtime is the source of truth.

**Why this is dangerous**:
- The patch "succeeded" (no fuzzy-match errors)
- The replaced region was syntactically valid
- LSP diagnostics were full of *unrelated* stale errors (because
  during the patch sequence I had introduced an intermediate
  corrupt state, and the LSP server cached the error report)
- The real bug — missing `Elysia` import — only surfaces as ONE
  error line among 30+ noise lines, easy to miss

**Detection recipe (use this when you see many LSP errors at once)**:
1. **Verify with the actual runtime**, not LSP. For Bun:
   ```bash
   bun --print 'import("./src/path/file.ts").then(m => Object.keys(m))'
   ```
   If the import resolves and `Object.keys` returns the expected
   exports, the file is fine — LSP is stale.
2. **Read the file fresh** (`read_file(path)` with NO `offset/limit`)
   to see the actual top-of-file imports, then check each
   `import { X }` against every usage site of `X` in the file.
3. **Diff against HEAD**: `git diff path/to/file` — if you see a
   deleted `import` line that you didn't intend to delete, that's
   the corruption.

**Recovery if it happens**:
1. `git diff path/to/file` to confirm what got dropped.
2. **Manually re-add the missing import** at the top of the file
   (a one-line `patch` is safer than trying to chain more patches
   on a partially-broken state).
3. Re-run `bun --print 'import(...)'` to confirm fix.

**Prevention recipe (extends adjacent-anchor pitfall)**:
- **Never write an `old_string` that starts with a bare `import {`**
  if the file has multiple import blocks. Anchor on a more specific
  pattern (a unique comment, a function signature, the line just
  before *and* just after the target).
- **After every `patch` on a file**, run
  `git diff path/to/file | head -30` to eyeball what changed at
  the top, even if the patch was supposed to touch only line 50.
- If a session has introduced a corrupt intermediate state and LSP
  is flooding you with errors, **trust `bun --print 'import(...)'`
  over LSP diagnostics** — the runtime is the source of truth.

**Why this is dangerous**:
- The patch "succeeded" (no `replace_all` errors)
- `bun typecheck` was clean (deleting a comment is invisible to TS)
- `bun test` passed (no behavioural change)
- `git diff --stat` showed the right number of lines added/removed
- Only a careful read of the diff (or someone reading the file later)
  caught the deletion

**Prevention recipe**:
1. Before any non-trivial patch (>5 line addition/removal), re-read
   the **full file** with `read_file(path)` (no offset/limit) so the
   LLM context has the entire file, not a windowed slice.
2. Anchor the `old_string` on a **unique** line that appears EXACTLY
   once in the file — usually a function signature, a unique
   identifier, or a comment that's truly one-of-a-kind.
3. If `patch` reports "Found N matches for old_string", NEVER
   `replace_all=true` blindly. Either (a) add 3+ more lines of
   surrounding context, (b) split into two smaller patches with
   different anchors, or (c) `git checkout HEAD -- <file>` and
   re-patch from scratch.
4. After patching, run `git diff <file>` and READ the diff
   end-to-end (not just `--stat`). Comment deletions are silent
   if you only look at line counts.

**Real transcript excerpt**:
```
> patch mode=replace path=ChartBlock.tsx
  old_string: "import { Bar, Line, Pie, Doughnut } from 'react-chartjs-2';"
  new_string: "import { Bar, Line, Pie, Doughnut } from 'react-chartjs-2';\n\n// Register..."
  Result: comment block 7 lines above got deleted, anchor was
  re-matched to a second occurrence near `ChartJS.register`
```

**Recovery if it happens**: `git diff <file>` to confirm the deletion,
then `git checkout HEAD -- <file>` to restore, then re-patch with
the corrected `old_string` (more unique context).

**Scripted detection** (use this BEFORE reading the diff manually
on any non-trivial patch — catches silent comment deletions):
```bash
# Compare the file against HEAD byte-for-byte ignoring whitespace
git show HEAD:path/to/file > /tmp/before.txt
cp path/to/file /tmp/after.txt
# Lines that were deleted (excluding empty deletions = the anchor itself)
diff /tmp/before.txt /tmp/after.txt | grep '^<' | grep -v '^<$' | head -20
# If you see comment lines (start with // or # or /* or *) in the
# "deleted" output that you didn't intend to delete → recovery time
```

```bash
# Quick sanity: line count delta should match what you expected
git show HEAD:path/to/file | wc -l
wc -l path/to/file
# If the delta is way off (>2× what you expected), investigate
```

```bash
# Catches "I deleted a comment but kept the code" case — verifies
# the file's top-level structure (function count, export count) is
# what you think it is
git show HEAD:path/to/file | grep -cE '^(export |function |const \w+ =)'
grep -cE '^(export |function |const \w+ =)' path/to/file
# Should match. Mismatch = structural change you didn't intend.
```

**The "double-match" sub-pattern** (2026-06-08, crm-system ChartBlock.tsx,
later in same session): the first `replace_all=true` patch with an
identical-match anchor **silently re-inserted** the comment I had just
deleted (because by then there were TWO copies of the comment — the
original + the patch trying to "restore" it). The fix was yet a
THIRD patch with explicit `replace_all=true` on the now-identical
duplicates. The lesson: **`replace_all=true` is only safe when the
duplicates are intentional and you want both replaced**. If you
hit the same anchor twice in the same session, treat it as a
recovery signal — restore from HEAD and start over.

**Prevention recipe (extended)**: if your patch returns
"Found N matches for old_string" AND you've already done one
patch in this session on the same file, **STOP** and
`git diff <file>` to see the current state before re-running.

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
