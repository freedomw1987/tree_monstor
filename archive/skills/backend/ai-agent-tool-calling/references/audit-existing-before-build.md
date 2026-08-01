# Audit Existing Infrastructure Before Build

> **Context**: AI agent 嘅 infrastructure 容易由唔同 session 增量 build 出嚟 (Conversation schema, tools, chat UI, AiConfig)。入新 task 之前必須 audit,避免重複造輪子或者破壞已有嘅 working code。

## 為何 audit-first

**Common scenario** (crm-system 2026-06-08):
- David 提交 task:「加 AI 設定 page + AI 助手 + tool calling」
- 預期 scope:8-9 小時 coding (schema + backend + frontend + nav + encryption)
- 真正 audit 結果:AI 助手 + 8 tools + chat UI 已經全部 ship 咗 → scope 縮到 audit + 增量 + encryption
- 慳咗 6+ 小時 + 冇破壞已有 working code

**Anti-pattern**:直接 plan + 寫 code → 重新發明 `runAgent` → 破壞 `chat.ts` route → David 嗰邊 push 失敗。

## Audit checklist (15 分鐘必跑)

### Step 1: 搜 files

```bash
# AI / chat / assistant related files
find apps/ packages/ -type f \( -name "*ai*" -o -name "*chat*" -o -name "*assistant*" -o -name "*agent*" -o -name "*llm*" \) 2>/dev/null

# Tool registry 入口
grep -rn "toolRegistry\|runAgent\|chatApi\|AiConfig" apps/ packages/ 2>/dev/null | head -40
```

### Step 2: 睇 schema

```bash
# 搵 AI 相關 Prisma models
grep -E "^model (Conversation|Message|Chat|Ai)" packages/db/prisma/schema.prisma

# 搵 tool result / function calling 嘅 field
grep -E "toolName|toolArgs|toolResult|function_call" packages/db/prisma/schema.prisma
```

### Step 3: 睇 backend routes

```bash
# Mount 咗咩 AI routes
grep -rn "ai\|chat\|assistant" apps/api/src/index.ts apps/api/src/routes/ 2>/dev/null

# Check 入口係咪已有
grep -E "OPENAI_API_KEY|OPENAI_BASE_URL|ANTHROPIC_API_KEY" apps/api/src/ packages/ai/src/
```

### Step 4: 睇 frontend

```bash
# Chat UI 入口
find apps/web/src/pages -name "*chat*" -o -name "*ai*" -o -name "*assistant*"

# API client 端
grep -E "chatApi|aiApi|aiConfigApi" apps/web/src/lib/api.ts

# FAB / floating button
grep -E "AiFab|AI Assistant|chat.*button" apps/web/src/components/
```

### Step 5: 睇 nav 結構

```bash
# Admin nav items
grep -E "adminNavItems|to: '/(ai|chat|admin)" apps/web/src/components/layout/app-layout.tsx

# Routes 已 mount 咗咩
grep -E "ai|chat" apps/web/src/App.tsx
```

### Step 6: git log 探勘

```bash
# 最近 14 日有冇人 build 過 AI 相關嘢
git log --since="14 days ago" --oneline -- 'apps/api/src/routes/chat*' 'apps/web/src/pages/ai*' 'packages/ai/' 'apps/web/src/components/layout/*Fab*'

# 邊個 user / branch build
git log --since="30 days ago" --format="%h %an %s" -- 'packages/ai/'
```

### Step 7: 搵 dead imports / types

```bash
# 任何 import 緊 chatApi / runAgent / AiConfig 嘅 file
grep -rln "from.*['\"].*chat.*api.*['\"]" apps/web/src/
grep -rln "runAgent\|toolRegistry" apps/ packages/

# 確認 backend route 係咪真係 mount 咗
grep "chatRoutes\|aiRoutes" apps/api/src/index.ts
```

## Audit 結果判定

| 結果 | 行動 |
|------|------|
| **完全冇** AI infrastructure | Plan 全做,設計由零 |
| **有 schema + backend route + chat UI** 但**冇 AiConfig** | Plan:加 AiConfig + encryption + nav link |
| **有 schema + backend + UI + config** | Plan:純 audit + missing tools + human-confirm pattern |
| **Dead import**(frontend 用緊 chatApi 但 backend 冇 route) | 標記 dead code,清除或者補 backend |

## 跟住嘅 planning steps

After audit 確認現有 infrastructure:

1. **寫 audit summary**:列出「已有 / 缺 / 破爛」三類
2. **Diff plan against existing**:我哋 plan 嘅 scope 同 audit 結果對齊
3. **Lock-in assumptions**:Audit 結論要同 David 確認「我哋而家 audit 見到 X,Y,Z;我哋會加 A,B,C」
4. **Use existing as source of truth**:如果 backend `chat.ts` 已經寫咗某個 shape,frontend 對齊佢,唔好重新設計

## 紅線

> **Audit-first 紅線**:入任何 AI assistant 相關 task 之前,**必須跑 audit checklist**。冇 audit 嘅 plan = David 會 push 失敗 / 重複造輪子。
