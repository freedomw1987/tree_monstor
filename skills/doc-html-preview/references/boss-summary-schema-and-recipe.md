# Boss Summary JSON — Schema, Recipe, and Pitfalls

> Generated after the 2026-06-06 crm-system incident where 10/12 boss.html silently rendered as placeholders despite the build script reporting success.

## What this covers

The JSON schema that the boss template expects, a copy-pasteable example, a generation pattern, and a verification script.

## JSON schema (frozen by template)

```jsonc
{
  "doc": "<basename of MD, e.g. 'api'>",                        // string
  "source_md": "docs/<doc>.md",                                   // string
  "generated_at": "<ISO 8601 with TZ, e.g. '2026-06-06T16:45:00+08:00'>",
  "generated_by": "AI (developer profile / CEO subagent)",         // string
  "one_liner": "<1-2 sentences, plain language, what is this doc for the boss>",
  "cards": {
    "timeline": "<short estimate, e.g. 'Day 9 done; 1-3 months to revenue'>",
    "cost":     "<short cost estimate, infra + dev time>",
    "mitigation": "<what is already in place to de-risk>",
    "disclaimer": "<one-line warning that numbers are estimates>"
  },
  "decisions": [
    {
      "question": "<the yes/no or A/B question>",
      "options": [
        { "label": "A. ...", "pros": "+ ...", "cons": "- ..." },
        { "label": "B. ...", "pros": "+ ...", "cons": "- ..." }
      ],
      "default": "A",          // string, must match one of the option labels' prefix
      "blocking": true         // boolean, true = "要你拍板" tag
    }
    // ... 3 decisions total
  ],
  "risks_boss_speak": [
    "<risk 1 in plain language>",
    "<risk 2 in plain language>"
    // ... 2-4 risks
  ]
}
```

## When to use which input mode

| Input mode | When to pick | How to trigger |
|------------|-------------|----------------|
| **JSON file** (`docs/_meta/<doc>.json`) | Default for engineering docs (api.md, database.md, architecture.md) where the boss cares about scope, cost, risk, not exact content | Write JSON, then `build.sh --project <name>` |
| **MD override** (`## 👀 老闆版摘要`) | Use for **boss-facing docs** (PRD.md, DESIGN.md) where the human author wants full control over what the boss sees — no AI hallucination of risks | Add the section to the MD, the build script will use the first `<p>` as the one-liner and the rest as the body |
| **Both** | MD override wins (template prefers it if present) | — |

## Generation pattern (main agent)

When the main agent has full project context, write JSONs directly:

1. **For each MD**, read the first 20 lines to extract the title and first paragraph.
2. **Write the one_liner** = the first non-empty paragraph, trimmed to ~80–120 chars, in plain language (no schema, no code).
3. **Cards** = generic shape with values tuned to the doc type:
   - `api.md` → timeline: "Day X 完成,每月 review deprecated list", cost: "infra 成本", mitigation: "OpenAPI + version prefix + rate limit"
   - `database.md` → timeline: "schema 持續演進, Day 30 freeze", cost: "RDS $70/月", mitigation: "Prisma migrate + 手工 SQL escape hatch"
4. **Decisions** = 3 questions where the boss/PM genuinely needs to pick A or B. Each option has +pros / -cons in plain language. Mark `blocking: true` on questions that block implementation, `false` on questions that can be deferred.
5. **Risks** = 2–4 bullets, plain language, name the **specific failure mode** (e.g. "Prisma enum drift 導致 production 42704") not generic "data loss" hand-waving.

## Verification script

After every `build.sh` run, verify all boss.html have content:

```bash
# Save as scripts/verify-boss-html.sh
#!/usr/bin/env bash
set -euo pipefail
PROJECT="${1:?usage: $0 <project-name>}"
DOCS_DIR="$HOME/www/$PROJECT/docs/_html"
MISSING=0
for f in "$DOCS_DIR"/*-boss.html; do
  # body is between </head> and the first <script> (decision capture JS)
  if awk '/<\/head>/,/<script>/' "$f" | grep -q 'boss-placeholder'; then
    echo "❌ PLACEHOLDER  $f"
    MISSING=$((MISSING + 1))
  else
    echo "✅ HAS CONTENT  $f"
  fi
done
if [ "$MISSING" -gt 0 ]; then
  echo ""
  echo "$MISSING boss.html file(s) still placeholder. Run main agent to write"
  echo "docs/_meta/<doc>.json for each missing doc, then re-run build.sh."
  exit 1
fi
```

Usage: `bash ~/.hermes/profiles/developer/skills/doc-html-preview/scripts/verify-boss-html.sh <project-name>`

## Common pitfalls

1. **File size lies**. The template skeleton is ~20 KB. Don't trust `ls -la` to tell you if a boss.html is "populated" — they all look similar. Always grep for the placeholder class in the body.
2. **JSON path is `docs/_meta/`, not `docs/_html/_meta/`**. The `docs/_meta/` dir is gitignored along with `docs/_html/` per the skill's `.gitignore` snippet.
3. **`default` field is a string, not an index**. It must match the option label's `A. ...` prefix exactly, otherwise the "預設" marker won't render.
4. **Risks array, not string**. Don't write `"risks_boss_speak": "AI 會壞, 客戶會投訴"` — the template iterates over an array. Each risk is a separate `<li>`.
5. **One-liner length cap ~150 chars**. Longer than that and the gradient box wraps awkwardly on mobile.
6. **JSON generation by LLM is fine for content; bad for risk specificity**. If the agent's risk reads like generic advice ("performance may be slow", "users may be confused"), the agent didn't read the MD. Re-do with project context.
