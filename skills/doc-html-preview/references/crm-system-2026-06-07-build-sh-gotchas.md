# crm-system Day 14.6 — build.sh sub-folder + JSON filename gotchas

**Date**: 2026-06-07
**Project**: `~/www/crm-system`
**Context**: Wrote a plan doc `docs/retros/2026-06-07-system-settings-plan.md` and tried to render it via `build.sh`. Hit two pitfalls not covered by SKILL.md or the existing 2026-06-06 placeholder incident reference.

## Pitfall 1 — `build.sh` only globs `docs/*.md`, not sub-folders

**Symptom**: After running `bash build.sh --project crm-system`, the only output was the 17 standard docs. The retro/plan MD I had just written was NOT rendered, no error, no warning.

**Root cause**: `build.sh` line 8 says "Source MD: `~/www/<project>/docs/*.md`" — that's a literal glob, not a recursive find. Anything in `docs/retros/`, `docs/architecture/`, `docs/handoff/`, etc. is invisible to the default invocation.

**Fix**: Pass sub-folder MDs as positional arguments:

```bash
bash ~/.hermes/profiles/developer/skills/doc-html-preview/scripts/build.sh \
  --project crm-system \
  docs/retros/2026-06-07-system-settings-plan.md \
  docs/architecture/0001-ai-assistant-architecture.md
```

The script will produce `<basename>.html` + `<basename>-boss.html` in `docs/_html/` — note that the **sub-folder prefix is dropped from the output filename**. So `docs/retros/plan.md` becomes `docs/_html/plan.html`. This is fine for one-off retro / plan / ADR docs; if you have many sub-folder MDs to publish regularly, either:

- **Flatten into `docs/`** with a numbering scheme (e.g. `0001-ai-architecture.md` lives in `docs/`, not `docs/architecture/`)
- **Wrap `build.sh` in a loop** that calls it per-path

## Pitfall 2 — Boss JSON key is filename-derived, not semantic

**Symptom**: I wrote a JSON at `docs/_meta/plan-system-settings.json` (semantic name), then ran the build with the retro MD as a positional arg. The boss HTML rendered as placeholder.

**Root cause**: `build_html.py` looks up the boss summary JSON by **exact basename match** with the MD. For input `2026-06-07-system-settings-plan.md`, the script looks for `docs/_meta/2026-06-07-system-settings-plan.json` — NOT a more semantically named JSON.

**Three workable patterns**:

1. **Match the name from the start** — name the MD and JSON with the same basename. Predictable, no extra step.
2. **Copy/symlink before building** — write JSON to the semantic name, then `cp` (or `ln -s`) it to the filename-derived name:
   ```bash
   cp docs/_meta/plan-system-settings.json \
      docs/_meta/2026-06-07-system-settings-plan.json
   bash build.sh --project crm-system docs/retros/2026-06-07-system-settings-plan.md
   ```
3. **Use the MD override** — add a `## 👀 老闆版摘要` section to the MD and the script will use that body content instead of looking up JSON. Best when you want full control over the boss view and don't want to maintain a separate JSON file. The first `<p>` of the override becomes the one-liner in the top blue callout.

The build script does NOT log which key it looked up, so if your boss HTML renders as placeholder, the first debug step is "does the JSON basename match the MD basename exactly?" — use the body-region grep recipe from the 2026-06-06 reference to confirm.

## Pitfall 3 — `verify_boss_html.sh` fails on macOS default bash 3.2

**Symptom**: Running the verify script produces:
```
verify_boss_html.sh: line 49: mapfile: command not found
```
The script exits non-zero, but the non-zero exit is the bash version failing, not a real verification failure.

**Root cause**: `mapfile` is a bash 4+ builtin. macOS ships `/bin/bash` = 3.2 (Apple's last GPLv2-compatible bash release; they did not adopt GPLv3 so stayed on 3.2 forever). The skill's verify script was tested on Linux bash 5+.

**Two workarounds** (the inline grep is preferred — works anywhere the agent runs):

```bash
# Body-region grep recipe (bash 3.2 safe)
for f in docs/_html/*-boss.html; do
  if awk '/<\/head>/,/<script>/' "$f" | grep -q 'class="boss-placeholder"'; then
    echo "❌ PLACEHOLDER  $f"
  else
    echo "✅ HAS CONTENT  $f"
  fi
done
```

Or invoke the script with a Homebrew-installed bash:
```bash
brew install bash
/usr/local/bin/bash ~/.hermes/profiles/developer/skills/doc-html-preview/scripts/verify_boss_html.sh crm-system
```

**Do NOT trust a non-zero exit on macOS** as a "verification failed" — it might just be the bash version. Always read the error message: `mapfile: command not found` = environment, not verification result.

## Take-aways for future sessions

1. **Sub-folder MDs need explicit positional args to `build.sh`** — the default glob is `docs/*.md` only.
2. **JSON key = MD basename, period** — name them identically, or copy the JSON before building.
3. **macOS bash 3.2 is the default and `mapfile` will bite you** — use the inline body-region grep; it's bash-version-agnostic.
4. **These three pitfalls are NOT in SKILL.md as of 2026-06-07** — this reference IS the fix. Future agents reading this should add it to the project's mental model of the skill's known gotchas.

## Related files

- `SKILL.md` §"📂 Sub-folder MDs" and §"🔑 Boss JSON key is filename-derived" (patched 2026-06-07)
- `SKILL.md` §"⚠️ macOS bash 3.2 incompatibility" (patched 2026-06-07 inside `verify_boss_html.sh` reference)
- `references/crm-system-2026-06-06-boss-placeholder-silent-failure.md` — the original placeholder-silent-failure lesson
- `scripts/verify_boss_html.sh` — the script that fails on macOS bash 3.2
