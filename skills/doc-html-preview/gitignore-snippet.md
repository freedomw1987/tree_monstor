# Gitignore snippet for Hermes doc-html-preview

When using the `doc-html-preview` skill in a project, add this to the
project's `.gitignore` (root level) so generated HTML previews AND the
generated boss summary JSON are never committed to git:

```gitignore
# Hermes doc-html-preview generated artifacts (do not commit; MD is source of truth)
docs/_html/
docs/_meta/
```

## Why

`docs/_html/` contains **generated HTML previews** (engineering + boss version).
`docs/_meta/` contains the **boss summary JSON** that the LLM generates from
reading the MD. Both are derived artifacts — the MD files in `docs/*.md` are
the source of truth (reviewed, diffed, merged).

## How to apply

When you start a new project using the doc-html-preview skill:

1. Create `docs/.gitignore` (or add to root `.gitignore`):

   ```bash
   cat >> docs/.gitignore <<'EOF'
   docs/_html/
   docs/_meta/
   EOF
   ```

2. Verify both rules are in place:

   ```bash
   git check-ignore -v docs/_html/PRD.html docs/_meta/PRD.json
   # Should print two lines, each showing the .gitignore match
   ```

3. The skill's `build.sh` will create `docs/_html/` automatically on first
   build. The developer profile / kanban CEO worker creates `docs/_meta/`
   when generating boss summaries. Git will silently ignore both.
