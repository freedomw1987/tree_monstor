# Plan-Execution Deviation Protocol

Use when: a Plan JSON / spec / ADR contradicts itself, or a step
that reads as "preserve X" is incompatible with another step that
reads as "do Y to X". Resuming / building from a flawed spec is a
common resume case (2026-06-07 crm-system Step 6 was the trigger).

## Symptoms

- Plan JSON options table says "preserve /settings" but the new
  sub-route layout requires /settings to mount the layout
- ADR says "use X" but the codebase already uses Y in the only
  spot where X would have been added
- Spec from one day (Day 11) conflicts with spec from a later day
  (Day 14) for the same component
- Plan execution note in the code comment is required to make
  the build match the intent

## Recipe

### Step 1: Identify the contradiction

List the spec's *primary intent* (the option the user actually picked,
not the literal text). For crm-system 2026-06-07:

| Spec text | Primary intent |
|-----------|----------------|
| "default": "A) Tabs (one URL per sub-route)" | Unify entry under 7 tabs |
| "保留 `/settings` 舊 direct route" | Preserve bookmarks / deep links |

The literal reading "keep /settings = direct SettingsPage" is
incompatible with the primary intent "7-tab nav lives at /settings".
The PLAN's job is to deliver the intent, not the literal text.

### Step 2: Pick the deviation that satisfies the primary intent

For crm-system Step 6:

- **Pick (chosen)**: `/settings` becomes `<Navigate to=/settings/pipelines replace />`.
  The 7-tab layout mounts at `/settings/pipelines` (and `/settings/<tab>`).
  Bookmarks still land on Pipeline, but through the new layout.
  The literal "保留 direct route" is satisfied by URL preservation,
  not by code-path preservation.

- **Pick (alternative)**: render `<SettingsLayout />` at `/settings`
  with `defaultTab='pipelines'` when no sub-path is present. Same
  outcome, slightly different shape.

Both deviations **must be documented in the code comment AND the
commit body AND the report to David**. Three redundant
declarations because:

1. Code comment — next session agent reads it on resume
2. Commit body — git log + PR review
3. Report — David sees the deviation immediately and can push back

### Step 3: Document the deviation, then ship

The pattern to use in the file header (TypeScript example):

```ts
/**
 * <ComponentName> — <Day> Step N.
 * ...rest of docstring...
 *
 * **Plan execution note (<Day> Step N)**: <what the spec literally said>
 * was incompatible with <what the spec primarily intended>. The deviation
 * is: <what I did>. Literal spec text <reference to plan JSON path>.
 * Trade-off: <what was lost — usually "X is no longer Y, but is now Z">.
 */
```

Commit body template:

```
feat(<area>): <Day> Step N — <summary>

- <bullet 1: what changed>
- <bullet 2: deviation from plan, with reference to plan JSON path>
- <bullet 3: trade-off>

Refs: <plan-json-path>.
```

### Step 4: Flag the deviation in the report to David

After the commit, the report to the user **must** start with a
"Plan execution deviation" section before the done-list. David
has corrected me (2026-06-07) when I shipped deviations without
flagging — he needs the option to push back before Step 7 builds
on the wrong assumption.

Example report structure:

```
📍 progress 1/N

✅ Done (commit <hash>)
- <change 1>
- <change 2>

⚠️ Plan execution deviation
- <what the spec said vs. what I did and why>
- <trade-off / cost>

🔜 Next
- <next step preview>
```

## Anti-patterns

- ❌ **Hiding the deviation in the commit body without flagging it
  in the report.** David will catch it at smoke test time and the
  conversation will burn 5-10 turns on "why did you do this".
- ❌ **Asking the user to clarify mid-Build.** Resume flows must
  proceed with a defensible deviation and flag it. Asking
  "should I preserve /settings or unify under Tabs?" wastes the
  whole Plan stage that already decided.
- ❌ **Rewriting the Plan JSON to match the deviation.** Plan is
  the source of truth for *intent*; deviations are scope changes
  that should be in the commit body + retro, not a silent
  rewrite of the plan.
- ❌ **Multiple deviations without a separate ADR.** If the plan
  needs deviating in 3 places, write `docs/retros/<date>-plan-deviation.md`
  and link it from each commit. 1 deviation can stay in the commit.

## Worked example (2026-06-07, crm-system Step 6)

Plan JSON said:
- Decision: "A) Tabs (one URL per sub-route)" — chosen by David
- Risks section: "Backward compat 喺 nav layout 加 `<Navigate>` 自動 redirect `/users` → `/settings/users`"

But: 7-tab nav lives at `/settings` (the layout wraps the Outlet).
If `/settings` also directly renders `<SettingsPage />`, then
SettingsLayout never mounts at `/settings` and the Tabs chrome
disappears from the entry point.

Deviation picked: `/settings` → `<Navigate to=/settings/pipelines replace />`.
SettingsPage now mounts *inside* SettingsLayout at `/settings/pipelines`.

Documented in:
1. `components/settings-layout.tsx` header (Plan execution note)
2. `apps/web/src/App.tsx` route comment
3. Commit body (`72e13a2`) bullet 3 + footer "Refs: 2026-06-07-system-settings-plan"
4. Discord report — "⚠️ Plan execution deviation" section before done-list

David acknowledged: "B吧 / 之後..." style cue = deviation accepted,
proceed to Step 7.

## Related

- `dev-task-memory/SKILL.md` — state file workflow that surfaces
  the plan JSON on resume (this reference is the *handling* layer)
- `regression-guard/SKILL.md` — deviations that affect invariants
  must also have a RG-XXX entry
- SOUL.md 紅線 13-14 — every fix needs root cause + prevention;
  deviations count as fixes for the spec
