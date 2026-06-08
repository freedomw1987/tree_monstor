<!--
dev-task-state.md — Single Source of Truth for in-progress dev tasks.

Written by save_state.py (Layer 1 trigger fires it).
Read by load_state.py (new session / /new / after-compression / after-restart).
-->

# Dev Task State — <PROJECT_NAME>

> **這個文件係 dev-task-memory skill 嘅 Single Source of Truth。**
> 當 context 被壓縮 / session 重啟 / user send `/new` 時, 我哋 read 呢個 file 恢復 context。
> **不要 commit `docs/_meta/*` 落 git** — 自動 gitignore。

---

## 🎯 Goal (一句話)

<一句話講清楚要做咩, e.g. "Fix CRM Companies page: 編輯公司資料表單可以加聯繫人 sub-row">

## 📋 Decisions (with WHY)

<!-- 每個 decision 必須有 WHY, 唔好淨係寫 WHAT。Context 壓縮後仍要 keep 嘅嘢 -->

1. **<Decision 1>**
   - **Why**: <解釋為什麼揀呢個方案, 唔揀其他>
   - **When**: <YYYY-MM-DD HH:MM>
   - **Alternative considered**: <其他方案 + 點解唔揀>

2. **<Decision 2>**
   - **Why**: ...
   - **When**: ...
   - **Alternative considered**: ...

## 🏗️ Current State

### Files touched (in this task)

| File | Status | Last edit |
|------|--------|-----------|
| `<file path>` | `created` / `modified` / `deleted` | `<HH:MM>` |
| ... | ... | ... |

### Git state

- **Branch**: `<branch name>`
- **Last commit**: `<commit SHA> "<message>"`
- **Uncommitted changes**: `<yes / no, brief description>`

### Environment

- **DB migrations**: `<applied / pending, list>`
- **Dev server**: `<running on port X / not running>`
- **Test status**: `<X pass, Y fail, Z skip>`

## ⏭️ Next 3-5 Steps (concrete, file paths)

1. [ ] **<Step 1>** — `<file path>`: <what to do>
2. [ ] **<Step 2>** — `<file path>`: <what to do>
3. [ ] **<Step 3>** — `<file path>`: <what to do>
4. [ ] **<Step 4>** — `<file path>`: <what to do>
5. [ ] **<Step 5>** — `<file path>`: <what to do>

## 🚨 Risks / Blockers

- **<Risk 1>**: <description + mitigation>
- **<Risk 2>**: <description + mitigation>

## 🧠 Key Insights (唔可以忘記嘅)

- **<Insight 1>**: e.g. "Prisma 用 decimal(10,2), 唔好用 float 否則 rounding error"
- **<Insight 2>**: e.g. "Companies.Contacts 係 1-to-many, JOIN 時要注意 N+1"

## 🔗 Session Lineage

- **Current session ID**: `<2026XXXX_HHMMSS_xxxxxx>`
- **Parent session ID**: `<2026XXXX_HHMMSS_xxxxxx>` (if split from compression)
- **Resume command**: `hermes --resume <session_id>` or `hermes -c "<project name>"`
- **First message timestamp**: `<YYYY-MM-DD HH:MM:SS>`
- **Last save timestamp**: `<YYYY-MM-DD HH:MM:SS>` (auto-updated)

## 📚 References (file paths to read for resume)

- `<file path 1>`: <why important>
- `<file path 2>`: <why important>
- `<SOUL.md path>`: <always read first>

---

*Auto-saved by `dev-task-memory` skill. Do not edit manually unless you know what you're doing.*
