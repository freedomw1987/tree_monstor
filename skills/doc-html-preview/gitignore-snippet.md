# Gitignore snippet for Hermes doc-html-preview

When using the `doc-html-preview` skill in a project, add this to the
project's `.gitignore` (root level) so generated HTML previews are
never committed to git:

```gitignore
# Hermes doc-html-preview generated HTML (do not commit; MD is source of truth)
docs/_html/
```

## Why

`docs/_html/` contains **generated artifacts**. The MD files in `docs/*.md`
are the source of truth — they're what gets reviewed, diffed, and merged.
The HTML files are convenience previews for the user (David) to read
in a browser via `file://`.

## How to apply

When you start a new project using the doc-html-preview skill:

1. Create `docs/.gitignore` (or add to root `.gitignore`):

   ```bash
   echo "docs/_html/" >> docs/.gitignore
   ```

2. Verify the rule is in place:

   ```bash
   git check-ignore -v docs/_html/PRD.html
   # Should print something like: .gitignore:1:docs/_html/    docs/_html/PRD.html
   ```

3. The skill's `build.sh` will create `docs/_html/` automatically on first
   build. Git will silently ignore the directory.
