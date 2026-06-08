# Reference example: crm-system System Settings plan boss JSON (2026-06-07)

> **Why this is in the skill**: This is the JSON that pairs with the plan MD — what David actually reads when he opens the boss HTML. Demonstrates the 4 cards, 3 decisions with `chosen_by` fields, and 5 project-specific `risks_boss_speak` items.

## Full source

```json
{
  "doc": "2026-06-07-system-settings-plan",
  "source_md": "docs/retros/2026-06-07-system-settings-plan.md",
  "generated_at": "2026-06-07T18:30:00+08:00",
  "generated_by": "main-agent (David picked option B: write plan doc first, review before building)",
  "one_liner": "把 5 個 admin page + Tax Rate 新設定 + 現有 Pipeline 全部收埋入「系統設置」變 7 個 sub-route tab,Tax Rate 寫落新 SystemConfig table,Quotation builder 預填系統值但可逐張覆寫(歷史 quotation 唔變)。",
  "cards": {
    "timeline": "Plan stage only — David review 緊。Approve 後實作 4-6 小時,4-6 commits,1 個 DB migration。",
    "cost": "12 files 改,~+400 lines / -15 lines。零新 dep,零 infra 改動,純 frontend restructure + 1 個 endpoint + 1 個 table。",
    "mitigation": "Deep link backward compat(`/users` → `/settings/users` redirect);Quotation 歷史資料唔變(per-quotation field 保留);Audit log 完整(SYSTEM_CONFIG_UPDATED 12mo retention);RBAC 唔變(全部用現有 permission)。",
    "disclaimer": "David working changes 仲 stash 住,我喺 main 直接寫 plan doc,實作時會先 fork `feat/system-settings-tabs-2026-06-07` branch 再 un-stash。Plan stage 不動 source code。"
  },
  "decisions": [
    {
      "question": "5 個 admin page 點樣收埋入 系統設置?",
      "options": [
        {
          "label": "A) Tabs (一個 URL 切換)",
          "pros": "Deep link 仍 work(/settings/users),每個 sub-route 仍係獨立 page,URL semantic 清晰。",
          "cons": "URL 結構要由 root 變 sub-route,要做 backward compat redirect。"
        },
        {
          "label": "B) Sidebar layout (左 list 右 content)",
          "pros": "視覺清晰,settings 一打開就見到 5 個 entry。",
          "cons": "佔 screen real estate;Mobile RWD 要 re-design。"
        },
        {
          "label": "C) Mega menu (dropdown nav)",
          "pros": "改動 surface area 最細。",
          "cons": "Deep link 體驗同今日一樣 — 個問題根本冇解。"
        }
      ],
      "default": "A) Tabs (一個 URL 切換)",
      "blocking": false,
      "chosen_by": "David 2026-06-07"
    },
    {
      "question": "Tax Rate 喺系統設置入面,點樣同 quotation 互動?",
      "options": [
        {
          "label": "A) 預設值 (per-quotation 可覆寫)",
          "pros": "Historical quotation 唔變(per-row snapshot 保留),新 quotation 用系統預設但 sales 可 override,完善。",
          "cons": "Per-quotation field 仲要保留(migration 唔刪 column)。"
        },
        {
          "label": "B) 強制覆寫所有 (historical 也改)",
          "pros": "Simple 邏輯,永遠一個 source of truth。",
          "cons": "破壞 historical reporting data(sales 入面睇舊 Q 會見到新 rate,失真)。"
        },
        {
          "label": "C) 全局唯一 (column 也要刪)",
          "pros": "DB schema 最簡潔。",
          "cons": "Migration 刪 column、報價要改 logic、冇 override 空間。Sales 一改 region 全部 Q 同時變。"
        }
      ],
      "default": "A) 預設值 (per-quotation 可覆寫)",
      "blocking": false,
      "chosen_by": "David 2026-06-07"
    },
    {
      "question": "Tax Rate 跨區域單一值定 per region?",
      "options": [
        {
          "label": "A) 全公司單一稅率",
          "pros": "起步簡單,1 個 row,UI 簡單。",
          "cons": "將來 per-region 需求(eg. 中國 13% vs 香港 0%)要加 migration。"
        },
        {
          "label": "B) Per region (HK / MO / CN 各有)",
          "pros": "一開始就對齊多 region 場景。",
          "cons": "UI 複雜(7 個 region × tax rate 都要設);起步 overkill。"
        },
        {
          "label": "C) Default 單一 + override per region",
          "pros": "兩全。",
          "cons": "UI 最複雜(2-layer),起步 overkill。"
        }
      ],
      "default": "A) 全公司單一稅率",
      "blocking": false,
      "chosen_by": "David 2026-06-07"
    }
  ],
  "risks_boss_speak": [
    "Plan 純文件,未動 source code。David approve 之後先 fork branch 做。",
    "David 嘅 4 modified + 3 untracked Day 14.1 working changes 仲 stash 住,實作時先攞返。",
    "Tax rate 寫落新 SystemConfig table 要 1 個 Prisma migration,跟 Day 14 嘅 audit log retention ADR 對齊(12mo 普通 retention)。",
    "Settings 7 個 sub-route tab 入面有 5 個係搬遷(existing pages wrap 入 SettingsLayout),Tax Rate + 結構改動 1 個 endpoint。",
    "Backward compat 喺 nav layout 加 `<Navigate>` 自動 redirect `/users` → `/settings/users` 等,demo 連結唔會死。"
  ]
}
```

## What makes this a good boss JSON

### The 4 cards (timeline / cost / mitigation / disclaimer)

| Card | Purpose | What NOT to write |
|------|---------|-------------------|
| `timeline` | David wants to know "how long" | "soon", "ASAP", "TBD" |
| `cost` | David wants to know "how big" | "moderate", "small change" |
| `mitigation` | "what's already planned to de-risk" | "best practices", "careful design" |
| `disclaimer` | "what could still go wrong" | empty / generic warnings |

Each card is ≤ 2 sentences. Specific numbers (4-6 commits, +400 lines) beat vague adjectives (moderate, small).

### The decisions array — `chosen_by` is critical

```json
{
  "question": "...",
  "options": [...],         // 2-4 options, each with pros + cons
  "default": "A) ...",      // what the AI would pick if David didn't
  "blocking": false,        // true = project can't ship without David's pick
  "chosen_by": "David 2026-06-07"   // OR "AI default (no David input yet)"
}
```

**`chosen_by` MUST be one of**:
- `"David <date>"` — David explicitly picked this in conversation
- `"AI default"` — agent picked this without David input (flag for follow-up)
- `"Pending — David to confirm"` — agent asked, David hasn't answered yet (block implementation)

A blank / missing `chosen_by` is a bug — the boss HTML renders the decision as "未拍板" and David can't tell if he was supposed to pick or if it was already decided.

### The risks array — concrete > generic

**Good risks (project-specific, verifiable)**:
- "Plan 純文件, 未動 source code。David approve 之後先 fork branch 做。"
- "David 嘅 4 modified + 3 untracked Day 14.1 working changes 仲 stash 住, 實作時先攞返。"
- "Tax rate 寫落新 SystemConfig table 要 1 個 Prisma migration, 跟 Day 14 嘅 audit log retention ADR 對齊(12mo 普通 retention)。"

**Bad risks (generic, forgettable)**:
- ❌ "Technical debt might accumulate."
- ❌ "Scope creep is a risk."
- ❌ "User adoption may be slower than expected."

The good ones reference actual project incidents (Day 14.1 stash, Day 14 ADR), the bad ones could apply to any project on Earth.

## Schema reminder (from doc-html-preview skill)

The boss JSON schema is **frozen** — `build_html.py` reads these keys literally. Don't rename `risks_boss_speak` to `risks` or `cards.timeline` to `cards.duration`, the build will silently ignore the renamed keys and the boss HTML will render empty.

See `doc-html-preview/SKILL.md` §"Generating the boss summary JSON" for the canonical schema.

## Anti-patterns to avoid

- ❌ Putting the plan summary IN the JSON's `one_liner` field — `one_liner` is for what this doc IS (a plan doc), not a re-summary of the plan content
- ❌ More than 5 decisions — David can't read 5 decisions in 5 minutes, and you probably don't NEED 5 decisions
- ❌ Risks that say "we'll be careful" — David has heard "careful" before, give him concrete mitigation
- ❌ `blocking: true` on every decision — only true when ship literally can't happen without the pick
