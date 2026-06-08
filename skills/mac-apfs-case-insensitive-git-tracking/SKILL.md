---
name: mac-apfs-case-insensitive-git-tracking
description: When a file path is written with mixed case (e.g. `docs/API.md`) on macOS dev host but the project runs in a Linux Docker container, git tracks the file in lowercase. Use when `patch` / `write_file` reports success but `git ls-files` shows a different casing, or when the diff looks like it modified `API.md` but git tracks it as `api.md`.
version: 1
category: devops
---

# Mac APFS Case-Insensitive Git Tracking

## The problem

macOS HFS+ / APFS file systems are **case-insensitive by default** (even
though they're case-preserving). Git's `core.ignorecase` is `true` on
Mac, so git tracks files using whatever case the file was first
committed in — usually lowercase, because most tools (Node, npm,
TypeScript, MDX tooling) lowercase paths during initial scaffold.

When you write a file via `path: ".../docs/API.md"` (uppercase `API`),
the Mac filesystem accepts it: there is already a tracked file at
`docs/api.md` (lowercase), and APFS treats both paths as the same
inode. The write succeeds. But:

- `git status` shows `M docs/api.md` (lowercase, the originally
  tracked case) — even though you wrote to `API.md`
- `git diff` works fine (path-independent for diffs)
- `ls docs/` shows only `api.md` (no `API.md`)
- The container side (Linux ext4) sees the file as `api.md` too — but
  if you ever `docker cp` or `git clone` to a Linux host, the case
  mismatch between your hard-coded path and the tracked case can
  cause "file not found" surprises in CI / container build steps

## When this trips you

This is most painful in **monorepos with documentation files** that
follow the "all-uppercase" Markdown convention (`API.md`, `PRD.md`,
`README.md` etc.) but were initially scaffolded lowercase. Common
scenarios:

1. You `patch` a doc file with `path: ".../docs/API.md"` (matching
   the spec). The diff lands. You commit. You see `M docs/api.md` in
   `git status` and worry you wrote to the wrong file. You didn't —
   the diff is on the right file; the displayed case is just the
   tracked case.
2. You write a new ADR at `docs/architecture/0015-system-settings-tabs.md`
   (matches the 4-digit ADR convention). Git tracks it as-is (mixed
   case in the middle is fine — only the leading letter is at risk
   if a sibling `docs/architecture.md` exists).
3. You `read_file` `.../docs/API.md` then `patch` the same path.
   Returns success. But `git diff --name-only` shows lowercase.
   That's normal APFS behavior, not a bug.

## Diagnostic (run when in doubt)

```bash
# 1. What case is git tracking?
git -C ~/www/<project> ls-files docs/ | grep -i api

# → docs/api.md   (lowercase — this is git's tracked case)

# 2. What inodes does the filesystem show?
ls -li ~/www/<project>/docs/API.md ~/www/<project>/docs/api.md
# → Both paths show the SAME inode number (e.g. 102191507)
# → Both files show the same size and mtime
# This is the proof: it's one file with two paths

# 3. Is the diff on the right content?
git -C ~/www/<project> diff HEAD -- docs/api.md | head -20
# → The diff you expect, just under the lowercase path
```

If step 1 shows lowercase AND step 2 shows same inode AND step 3 shows
your expected diff → your write succeeded, the file is just tracked
under the originally committed case. **Do not rename the file** —
that creates a "rename" in git history and triggers case-mismatch
problems on Linux CI hosts (which see the rename as a delete + add).

## Why renaming is the wrong fix

You might be tempted to `git mv api.md API.md` to "fix" the case.
Don't. Consequences:

- `git log --follow API.md` breaks (git's rename detection isn't
  perfect across case-only changes)
- Linux CI / Docker containers are case-SENSITIVE. If they ever
  checkout the repo, they see both `api.md` (if any old commit
  references it) AND `API.md` (if any new commit references it) as
  **two different files**. Build scripts that reference `API.md`
  (e.g. a docs build step) work locally (Mac) but 404 on CI (Linux).
- Subagents that follow your lead and write to `API.md` keep
  working on Mac, but the next agent that pulls on a Linux dev
  host sees the discrepancy.

If the project really needs `API.md` uppercase, the fix is a
**one-time bulk rename across the whole project** with every
reference updated in the same commit — not an ad-hoc `git mv` per
file. And it should be done as its own commit, not mixed into a
feature commit. Most projects don't bother; they just live with
`api.md`.

## Conventions that avoid the trap

1. **Match the tracked case in your patch paths**. Before writing,
   run `git ls-files <dir> | grep -i <name>` to find the actual
   tracked case. Use that case in your `path` argument, not what
   the spec doc says.
2. **Don't trust spec-doc casing**. Project specs often say
   `docs/API.md` because that's how humans write the constant
   in their head. The repo may track it as `docs/api.md`. The
   filesystem will accept either, but git operations are case-
   sensitive on the tracked-name.
3. **Read the inode, not the path name**. When verifying "did the
   write land in the right file?", check `ls -li` shows the same
   inode for the path you wrote and the path git tracks. That's
   the definitive proof on case-insensitive filesystems.

## Related quirks (same root cause)

- **`git mv API.md api.md` is silently a no-op on Mac** (file
  doesn't actually move). You need to rename to a totally different
  name first, then back: `git mv API.md tmp.md && git mv tmp.md api.md`.
- **Tab completion in zsh on Mac may show `API.md` while bash shows
  `api.md`** — the file is the same, the autocomplete just picks
  the case from the lookup path.
- **Docker volume mounts from a Mac dev host into a Linux container**
  preserve the Mac case (case-insensitive filesystem doesn't
  normalize), but the container-side tool then sees the case as
  you mounted it. If your Dockerfile does `COPY docs/API.md`, the
  build context passes the lowercase file (since git tracks it that
  way) and the container sees `api.md` even though your spec said
  `API.md`.

## crm-system 2026-06-07 case

I wrote 3 file edits to `docs/API.md` (uppercase, per the spec) via
`patch`. The diff was on the right file (verified by reading the
content). But `git status` showed `M docs/api.md` (lowercase — the
case it was originally committed in). Confirmed same inode
(`102191507`) for both `API.md` and `api.md` paths. No action taken
(renaming would have caused more problems than it solved). The
commit shipped with the lowercase tracked name; subsequent agents
reading this skill will know to expect the same display.

## Related skills

- `docker-build-cache-debug/SKILL.md` — sibling skill for the
  "stale image" failure mode that often co-occurs (you rebuild the
  image, but the docs or scripts reference a case that doesn't match
  the container's view)
- `patch-corruption-recovery` — for when a patch goes wrong, NOT
  for case-mismatch (which is cosmetic on Mac)
- `dev-task-memory/SKILL.md` — state-file hygiene, orthogonal to
  filesystem case but often confused in incident reports
