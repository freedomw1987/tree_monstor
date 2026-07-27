---
id: claude-code-workflow
aliases: []
tags: [claude-code, runtime]
---

# Claude Code Workflow Runtime

> **Status:** Reference. Claude Code-specific runtime feature guide. Canonical content lives in root and `docs/`; this doc covers features that only exist in the Claude Code runtime.

> **Use only when the installed Claude Code runtime supports this mode.** If unavailable, fall back to normal Think/Plan/Build flow, Claude Code subagents when available, and staged verification.

**Reference**: https://code.claude.com/docs/en/workflows

---

## When to consider Dynamic Workflow

| Trigger scenario | Example |
|-----------------|---------|
| Codebase-wide scans/audits | Every API endpoint missing auth check, every form's XSS risk |
| Large-scale migrations (>50 files) | React class → hooks, CommonJS → ESM, framework upgrade |
| Cross-source research + verification | Tech selection comparison, market analysis, competitor research |
| Difficult plans needing multi-angle design | Architecture decisions needing multiple independent proposals |
| High-quality review needing adversarial verify | Security review, perf analysis, major refactor PR review |
| Tasks needing 3+ subagents in parallel with stage sync | Think→Plan→Build→Review→Test each stage needs parallelism |

**Decision principle**: If a single Claude conversation's context cannot hold intermediate results, or the same orchestration needs to run repeatedly, consider Workflow if supported. For high-cost/high-parallelism runs, explain the value and get user consent when not already authorized.

---

## Possible launch methods, if supported

### Method 1: Include `workflow` keyword in prompt

```
Run a workflow to audit every API endpoint under src/routes/ for missing auth checks
```

### Method 2: Use an installed bundled workflow / skill

Example, if available in the current Claude Code runtime:

| Command | Use |
|---------|-----|
| `/deep-research <question>` | Multi-angle web search → fetch sources → adversarial verify → cited report |

### Method 3: Use a high-effort / ultracode mode, if available

```
/effort ultracode
```

If these mechanisms are not available, do not block the task; use normal Claude Code planning, subagents, and verification.

---

## Workflow script writing conventions

When the Workflow runtime is available, scripts Developer writes should follow:

```javascript
export const meta = {
  name: 'audit-api-auth',
  description: 'Scan all API routes for missing auth checks, verify each finding',
  phases: ['Scan', 'Verify', 'Report'],
}

phase('Scan')
// Default uses pipeline (each item independently through all stages, no barrier)
const findings = await pipeline(
  routeFiles,
  (file) => agent(`Scan ${file} for missing auth`, { schema: FINDING_SCHEMA }),
  (finding) => agent(`Adversarially verify: ${finding.claim}`, { schema: VERDICT_SCHEMA })
)

phase('Report')
return findings.filter(f => f.verdict === 'real')
```

### Core principles

1. **`pipeline` is the default parallel mode** — each item independently through all stages, max throughput
2. **`parallel()` only when barrier sync needed** — e.g., must dedup after all scans complete
3. **Adversarial verify is key to quality** — every finding must be independently attempted to refute
4. **Budget-aware** — dynamically adjust parallelism and depth based on token budget
5. **No mid-run user input** — Workflow cannot ask user questions during execution; if signoff needed, split into multiple workflows

---

## Developer decision tree

```
Received task
  ├─ Need 3+ subagents in parallel + stage sync and Workflow is available?
  │   └─ Yes → propose or launch Dynamic Workflow when authorized
  ├─ Deep research / cross-source verification and runtime skill is available?
  │   └─ Yes → suggest the relevant research workflow/skill
  ├─ Whole session is difficult deep work and high-effort mode is available?
  │   └─ Yes → suggest high-effort / ultracode mode
  └─ No → standard Think/Plan/Build flow
```

---

## Example: Suggesting workflow to user

```
User: "Help me audit every API under src/routes/ for missing auth"

Developer: "This is a codebase-wide audit task, spans dozens of files and needs cross-verification.
If Dynamic Workflow is available in this Claude Code runtime, I recommend using it — more thorough and repeatable:

My plan:
Phase 1 (Scan): parallel scan each route file
Phase 2 (Verify): adversarial verify each finding (avoid false positives)
Phase 3 (Report): output verified issue list + fix suggestions

Want me to launch with workflow? Estimated ~30 agents, ~50-80k tokens."
```

---

## Reference docs

- Official: https://code.claude.com/docs/en/workflows
- Local skills catalog: [`skills/README.md`](../skills/README.md)
- Optional workflow/ultrawork skill: if installed in this environment, read that skill before using its patterns

---

## Related docs

- [Claude Code bridge](../CLAUDE.md)
- [Documentation index](00-index.md)
- [Core identity](../SOUL.md)
- [Session and workspace rules](../AGENTS.md)