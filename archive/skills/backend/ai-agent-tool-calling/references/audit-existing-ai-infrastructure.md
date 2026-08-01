# Audit Existing AI / Agent Infrastructure — 5-Step Protocol

**Why this exists**: 2026-06-07 crm-system — user submitted T1-T3 (3 AI tasks). Previous session's recon was 100% wrong: claimed "backend 完全冇 AI route", but actual state was full backend (894-line `packages/ai/` + `chat.ts` + `ai-config.ts` + DB schema + 11-tool registry) **already shipped**. Plan went from "8-9 hours coding" to "1 hour of bug fixes". Lesson: recon must use **systemic audit**, not keyword grep + memory assumption.

**When to run this**: BEFORE planning any task that mentions "AI", "agent", "chat", "assistant", "tool calling", "LLM", or "RAG". Even if you think you know the codebase, run it. **5 minutes of audit saves hours of rebuild.**

---

## Step 1: Filesystem search (broad, multi-token)

Don't grep 1-2 keywords. Grep **all possible naming variants** + check for dedicated packages:

```bash
# Backend route files
find apps/api -type f \( -name "*ai*" -o -name "*chat*" -o -name "*assistant*" -o -name "*llm*" -o -name "*agent*" \)

# Frontend page / component files
find apps/web -type f \( -name "*ai*" -o -name "*chat*" -o -name "*assistant*" -o -name "*llm*" -o -name "*agent*" \)

# Shared packages
ls packages/                                # any ai/llm/agent/chat package?
find packages -type f \( -name "*ai*" -o -name "*agent*" -o -name "*llm*" -o -name "*tool*" \)

# Library / SDK hints
grep -l "openai\|anthropic\|langchain\|mastra\|@crm/ai" apps/api/package.json apps/web/package.json
```

**What to record**:
- AI-specific package exists? (`packages/ai/` with `index.ts` / `tools.ts` / `encryption.ts`)
- Route files: `apps/api/src/routes/{ai-config,chat,llm,...}.ts`
- Page files: `apps/web/src/pages/{ai-config,ai-chat,...}.tsx`
- API client surface: grep `apps/web/src/lib/api.ts` for `aiConfigApi`, `chatApi`, `llmApi`

---

## Step 2: Schema grep (DB layer evidence)

Even if no backend route, the **schema model is design intent**:

```bash
# AI-related models
grep -n "model\s\+AiConfig\|model\s\+Conversation\|model\s\+ChatMessage\|model\s\+AgentRun\|model\s\+LLM" \
  packages/db/prisma/schema.prisma

# Related enums
grep -n "enum\s\+AiAction\|enum\s\+ChatRole\|enum\s\+ToolCall" packages/db/prisma/schema.prisma
```

**If models exist**: someone designed this. The implementation may or may not be complete. **Check next step.**

**If models don't exist**: greenfield, you can design fresh.

---

## Step 3: Route / page listing (what's wired up)

```bash
# All backend routes
ls apps/api/src/routes/

# All frontend pages
ls apps/web/src/pages/

# Check the route registration — is each route file actually mounted in index.ts?
grep -n "import.*from.*routes" apps/api/src/index.ts
grep -n "import.*Routes" apps/api/src/index.ts
```

**What to record**:
- Route file exists but NOT imported in `index.ts`? → orphaned, not deployed
- Page file exists but NOT in router config (`App.tsx` / route definitions)? → orphaned

---

## Step 4: Container API probe (the critical test)

**The most important step** — confirms code is **deployed + running**, not just sitting in the filesystem:

```bash
# 1. Check containers
docker ps --format "table {{.Names}}\t{{.Status}}"

# 2. Probe via in-container fetch (avoids host→container port confusion)
docker exec crm-api sh -c 'cat > /tmp/probe.mjs << "EOF"
const login = await fetch("http://localhost:3001/auth/login", {
  method: "POST", headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ email: "admin@crm.local", password: "admin123" })
});
const { token } = await login.json();
console.log("login status:", login.status);

// Probe AI routes
for (const path of ["/ai/config/status", "/ai/config", "/chat/conversations"]) {
  const r = await fetch(`http://localhost:3001${path}`, {
    headers: { Authorization: `Bearer ${token}` }
  });
  console.log(`${path}: ${r.status} ${(await r.text()).slice(0, 100)}`);
}
EOF
node /tmp/probe.mjs'
```

**What to record**:
- `200` → route works, possibly with caveats (check body)
- `401` → unauth (expected without proper token)
- `403` → permission denied — **common after adding new permission to map but not DB**
- `404` → route file exists but not mounted
- `503` → service unavailable — often "not configured" for AI (no LLM key, no AiConfig row)
- `500` → runtime error (catch the response body for the stack trace)

**If your container's API port isn't exposed to host** (only `0.0.0.0:3001->3001/tcp` is internal), use the `docker exec` pattern above. If there's an nginx reverse proxy, probe via the proxy URL.

---

## Step 5: DB content query (configuration state)

Permission-related questions need a DB query, not just code grep:

```bash
# Get DB credentials from env (don't hardcode)
DB_USER=$(docker exec crm-api sh -c 'echo $POSTGRES_USER')
DB_NAME=$(docker exec crm-api sh -c 'echo $POSTGRES_DB')

# Check role permissions
docker exec crm-postgres psql -U $DB_USER -d $DB_NAME -c "
  SELECT r.name, rp.permission
  FROM roles r
  JOIN role_permissions rp ON r.id = rp.\"roleId\"
  WHERE r.name = 'ADMIN'
  ORDER BY rp.permission;
"

# Check if AiConfig row exists
docker exec crm-postgres psql -U $DB_USER -d $DB_NAME -c "
  SELECT id, \"endpointUrl\", \"modelName\", LENGTH(\"apiKeyCipher\") as key_len, \"updatedAt\"
  FROM ai_config;
"

# Check existing conversations (proof AI has been used)
docker exec crm-postgres psql -U $DB_USER -d $DB_NAME -c "
  SELECT id, title, \"updatedAt\",
    (SELECT COUNT(*) FROM conversation_messages WHERE \"conversationId\" = c.id) as msg_count
  FROM conversations c
  ORDER BY \"updatedAt\" DESC LIMIT 5;
"
```

**What to record**:
- Admin role has which permissions? Is the new `ai-config:read` there?
- Is there an `ai_config` row? If not, the page will show "not configured"
- Are there prior conversations? Proves the route has been used before (smoke history)

---

## Output: audit summary table

After running all 5 steps, build a summary like:

| Component | File | Status |
|---|---|---|
| DB schema | `schema.prisma` line 698-735, 820-850 | Complete (AiConfig singleton + Conversation + ConversationMessage) |
| Backend route | `apps/api/src/routes/ai-config.ts` (299 lines) | Complete (status / get / put / test) |
| Backend route | `apps/api/src/routes/chat.ts` (86 lines) | Complete but Bug X (env var check) |
| Frontend page | `apps/web/src/pages/ai-config.tsx` (291 lines) | Complete |
| Frontend page | `apps/web/src/pages/ai-chat.tsx` (298 lines) | Complete |
| Frontend API | `apps/web/src/lib/api.ts` line 512, 787 | aiConfigApi + chatApi |
| Nav links | `app-layout.tsx` line 33, 34 | Both present |
| AI package | `packages/ai/src/{index,tools,encryption,prompts,config}.ts` (894 lines) | Complete |
| Tool registry | `packages/ai/src/tools.ts` (483 lines) | 11 tools (Q2=C scope) |
| Container probe | curl /ai/config/status | 200 `{configured:false}` |
| Container probe | curl /ai/config | 403 — admin role missing `ai-config:read` |
| DB check | `role_permissions` for `ai-config:*` | 0 rows |
| DB check | `ai_config` row exists | No row |

**Then** go to user with **specific bug list + 2-4 fix options** — not a generic plan.

---

## Why this works when "I remember" doesn't

| "I remember" | "5-step audit" |
|---|---|
| LLM memory — lost after compression | File on disk — survives forever |
| My recollection of yesterday's session | git log + actual file contents |
| Grep 1 keyword may miss 5 variants | Multi-token grep + filesystem + DB |
| Plan: "8-9 hours build X" | Plan: "1 hour fix Bug Y" |

**The audit is fast** (5-10 min) and **the savings are huge** (hours of misdirected work).

---

## Related skills

- `dev-task-memory` — state file for "what was the audit conclusion" so future sessions don't re-audit
- `subagent-timeout-recovery` — when delegating audit, verify the subagent's report (audit conclusion can be wrong)
- `backend-rbac-audit-log` — when audit shows permission gaps (Pitfall 8e)
