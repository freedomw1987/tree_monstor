# AI Config (API Key) Storage — Encrypted DB Pattern

> **Context**: Admin 喺 UI 改 LLM endpoint / API key / model name,個 key 必須存落 DB(唔可以 env-only,因為 user 要喺 UI 改),**但紅線 1 禁止 plaintext secret 落 DB**。**Production pattern**:AES-256-GCM encrypt,key 從 env 拎。

## 為何需要加密

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **Plaintext in DB** | 簡單 | ❌ 紅線 1 違規,DB dump 漏 key | ❌ |
| **Env var only** | 12-factor,簡單 | ❌ User 唔可以喺 UI 改 | ❌ |
| **Hash (bcrypt)** | One-way | ❌ AI 需要 plaintext key call LLM | ❌ |
| **Encrypted (AES-GCM)** | 存 DB 但安全 | ⚠️ Key 喺 env(rotation 難) | ✅ |

## Schema

```prisma
// packages/db/prisma/schema.prisma
model AiConfig {
  id           Int      @id @default(1)  // Singleton pattern
  endpointUrl  String
  apiKey       String   // Encrypted with AES-256-GCM
  modelName    String
  systemPrompt String?  @db.Text
  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt
}
```

**Singleton pattern**(`id: 1`)保證只有 1 個 config row,免麻煩。

**Migration**:

```bash
cd packages/db
bunx prisma migrate dev --create-only --name add_ai_config
```

**Generated SQL** 應該類似:

```sql
-- Verify by hand BEFORE applying
CREATE TABLE "ai_configs" (
  "id" INTEGER NOT NULL DEFAULT 1,
  "endpointUrl" TEXT NOT NULL,
  "apiKey" TEXT NOT NULL,
  "modelName" TEXT NOT NULL,
  "systemPrompt" TEXT,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMPTZ NOT NULL,
  CONSTRAINT "ai_configs_pkey" PRIMARY KEY ("id")
);
```

## Encryption helper

```typescript
// packages/ai/src/crypto.ts
import { createCipheriv, createDecipheriv, randomBytes, scryptSync } from 'crypto'

const ALGO = 'aes-256-gcm'
const IV_LENGTH = 12
const AUTH_TAG_LENGTH = 16

function getKey(): Buffer {
  const hex = process.env.AI_CONFIG_ENCRYPTION_KEY
  if (!hex) {
    throw new Error('AI_CONFIG_ENCRYPTION_KEY env var not set (32 bytes hex)')
  }
  const key = Buffer.from(hex, 'hex')
  if (key.length !== 32) {
    throw new Error(`AI_CONFIG_ENCRYPTION_KEY must be 32 bytes hex, got ${key.length}`)
  }
  return key
}

/** Returns base64-encoded `iv:ciphertext:authTag` */
export function encryptSecret(plaintext: string): string {
  const key = getKey()
  const iv = randomBytes(IV_LENGTH)
  const cipher = createCipheriv(ALGO, key, iv)
  const ct = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()])
  const tag = cipher.getAuthTag()
  return Buffer.concat([iv, ct, tag]).toString('base64')
}

export function decryptSecret(encoded: string): string {
  const key = getKey()
  const buf = Buffer.from(encoded, 'base64')
  const iv = buf.subarray(0, IV_LENGTH)
  const tag = buf.subarray(buf.length - AUTH_TAG_LENGTH)
  const ct = buf.subarray(IV_LENGTH, buf.length - AUTH_TAG_LENGTH)
  const decipher = createDecipheriv(ALGO, key, iv)
  decipher.setAuthTag(tag)
  return Buffer.concat([decipher.update(ct), decipher.final()]).toString('utf8')
}
```

## Env var source

```bash
# .env (gitignored)
AI_CONFIG_ENCRYPTION_KEY=$(openssl rand -hex 32)
```

```yaml
# docker-compose.yml
services:
  api:
    environment:
      - AI_CONFIG_ENCRYPTION_KEY=${AI_CONFIG_ENCRYPTION_KEY}
      - OPENAI_BASE_URL=${OPENAI_BASE_URL:-https://api.openai.com/v1}
```

**Key rotation**:Production upgrade 到 AWS Secrets Manager / Parameter Store,setter 自動 inject env。

## Backend routes

```typescript
// apps/api/src/routes/ai-config.ts
import { Elysia } from 'elysia'
import { prisma } from '@crm/db'
import { encryptSecret, decryptSecret } from '@crm/ai/crypto'
import { jwtVerify } from 'jose'

const SECRET = process.env.JWT_SECRET ?? 'dev-only-secret-please-change'
const secretKey = new TextEncoder().encode(SECRET)

async function verifyToken(authHeader: string | null) {
  if (!authHeader?.startsWith('Bearer ')) return null
  const token = authHeader.slice(7)
  try {
    const { payload } = await jwtVerify(token, secretKey)
    const sub = (payload as Record<string, unknown>).sub
    return typeof sub === 'string' ? sub : null
  } catch {
    return null
  }
}

export const aiConfigRoutes = new Elysia({ prefix: '/ai-config', tags: ['admin'] })
  .get('/', async ({ request, set }) => {
    const userId = await verifyToken(request.headers.get('authorization'))
    if (!userId) { set.status = 401; return { error: 'Unauthorized' } }

    // Check admin role
    const user = await prisma.user.findUnique({ where: { id: userId } })
    if (user?.role !== 'ADMIN') {
      set.status = 403
      return { error: 'Admin only' }
    }

    const config = await prisma.aiConfig.findUnique({ where: { id: 1 } })
    if (!config) return { configured: false }

    return {
      configured: true,
      endpointUrl: config.endpointUrl,
      // ❗ 永遠唔返 plaintext key
      apiKeySet: !!config.apiKey,
      modelName: config.modelName,
      systemPrompt: config.systemPrompt,
      updatedAt: config.updatedAt,
    }
  })

  .put('/', async ({ request, body, set }) => {
    const userId = await verifyToken(request.headers.get('authorization'))
    if (!userId) { set.status = 401; return { error: 'Unauthorized' } }

    const user = await prisma.user.findUnique({ where: { id: userId } })
    if (user?.role !== 'ADMIN') {
      set.status = 403
      return { error: 'Admin only' }
    }

    const { endpointUrl, apiKey, modelName, systemPrompt } = body as {
      endpointUrl?: string
      apiKey?: string
      modelName?: string
      systemPrompt?: string
    }

    if (!endpointUrl || !modelName) {
      set.status = 400
      return { error: 'endpointUrl and modelName are required' }
    }

    // Build data
    const data: any = {
      endpointUrl,
      modelName,
      systemPrompt,
    }
    // Only update apiKey if provided
    if (apiKey && apiKey.length > 0) {
      data.apiKey = encryptSecret(apiKey)
    }

    const config = await prisma.aiConfig.upsert({
      where: { id: 1 },
      create: { id: 1, ...data, apiKey: data.apiKey ?? '' },
      update: data,
    })

    return { success: true, apiKeySet: !!config.apiKey }
  })
```

## Frontend form

```tsx
// apps/web/src/pages/ai-config.tsx
import { useEffect, useState } from 'react'
import { useQuery, useMutation } from '@tanstack/react-query'
import { aiConfigApi } from '@/lib/api'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card'

export function AiConfigPage() {
  const { data, isLoading } = useQuery({
    queryKey: ['ai-config'],
    queryFn: () => aiConfigApi.get(),
  })

  const [endpointUrl, setEndpointUrl] = useState('')
  const [apiKey, setApiKey] = useState('')  // 不會 prefill
  const [modelName, setModelName] = useState('')
  const [systemPrompt, setSystemPrompt] = useState('')

  useEffect(() => {
    if (data?.configured) {
      setEndpointUrl(data.endpointUrl)
      setModelName(data.modelName)
      setSystemPrompt(data.systemPrompt ?? '')
    }
  }, [data])

  const save = useMutation({
    mutationFn: () =>
      aiConfigApi.update({
        endpointUrl,
        // 不送 apiKey if user 冇填
        ...(apiKey && { apiKey }),
        modelName,
        systemPrompt,
      }),
  })

  if (isLoading) return <p>載入中...</p>

  return (
    <div className="max-w-2xl space-y-4">
      <h1 className="text-2xl font-bold">AI 設定</h1>
      <p className="text-muted-foreground">管理 AI 助手用嘅 LLM endpoint 同 API key。</p>

      <Card>
        <CardHeader>
          <CardTitle>LLM Endpoint</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          <div>
            <label className="text-sm">Endpoint URL</label>
            <Input
              value={endpointUrl}
              onChange={(e) => setEndpointUrl(e.target.value)}
              placeholder="https://api.openai.com/v1"
            />
            <p className="text-xs text-muted-foreground mt-1">
              OpenAI-compatible 嘅 endpoint。例:OpenAI / OpenRouter / Together / 自建 vLLM。
            </p>
          </div>

          <div>
            <label className="text-sm">API Key</label>
            <Input
              type="password"
              value={apiKey}
              onChange={(e) => setApiKey(e.target.value)}
              placeholder={data?.apiKeySet ? '現有 API key 已設定,留空保持不變' : ''}
              autoComplete="off"
            />
            <p className="text-xs text-muted-foreground mt-1">
              {data?.apiKeySet
                ? '✅ 已有 API key。輸入新嘅 key 取代,或者留空保持唔變。'
                : '⚠️ 未設定。'}
            </p>
          </div>

          <div>
            <label className="text-sm">Model Name</label>
            <Input
              value={modelName}
              onChange={(e) => setModelName(e.target.value)}
              placeholder="gpt-4o / claude-3-5-sonnet / mock-gpt-4o"
            />
          </div>

          <div>
            <label className="text-sm">System Prompt (optional)</label>
            <textarea
              value={systemPrompt}
              onChange={(e) => setSystemPrompt(e.target.value)}
              rows={4}
              className="w-full border rounded px-2 py-1"
            />
          </div>

          <Button
            onClick={() => save.mutate()}
            disabled={save.isPending || !endpointUrl || !modelName}
          >
            {save.isPending ? '儲存中...' : '儲存設定'}
          </Button>
          {save.isSuccess && <p className="text-sm text-green-600">✅ 已儲存</p>}
          {save.error && <p className="text-sm text-red-600">❌ {save.error.message}</p>}
        </CardContent>
      </Card>
    </div>
  )
}
```

## Wiring 落 runAgent

`packages/ai/src/index.ts` 個 `runAgent` 原本用 `process.env.OPENAI_API_KEY`,改成讀 DB:

```typescript
import OpenAI from 'openai'
import { prisma } from '@crm/db'
import { decryptSecret } from './crypto'

let cachedClient: { client: OpenAI; model: string; fetchedAt: number } | null = null
const CACHE_TTL_MS = 60_000  // 60 秒 cache,避免每個 request 都讀 DB

async function getAiClient(): Promise<{ client: OpenAI; model: string }> {
  if (cachedClient && Date.now() - cachedClient.fetchedAt < CACHE_TTL_MS) {
    return { client: cachedClient.client, model: cachedClient.model }
  }

  const config = await prisma.aiConfig.findUnique({ where: { id: 1 } })
  if (!config) {
    throw new Error('AI not configured. Admin must set up at /admin/ai-config')
  }

  const client = new OpenAI({
    apiKey: decryptSecret(config.apiKey),
    baseURL: config.endpointUrl,
  })
  cachedClient = { client, model: config.modelName, fetchedAt: Date.now() }
  return { client, model: config.modelName }
}

// In runAgent:
const { client, model } = await getAiClient()
const resp = await client.chat.completions.create({
  model,
  messages,
  tools: tools.length > 0 ? tools : undefined,
  tool_choice: tools.length > 0 ? 'auto' : undefined,
})
```

**Cache invalidation**:Admin 改 config 之後,broadcast 一個 event / 設 short TTL (60 秒) 就夠。

## 紅線

> **AI Config 紅線**:
> - ❌ 永遠唔好 plaintext 存 API key 落 DB
> - ❌ 永遠唔好喺 API response 返 plaintext API key
> - ❌ 永遠唔好 commit `AI_CONFIG_ENCRYPTION_KEY` 入 git
> - ❌ 永遠唔好將個 encryption key 同 `JWT_SECRET` 同一個(independent keys)
> - ✅ Always use AES-256-GCM(有 authentication tag,防止 tampering)
> - ✅ Always 32-byte key(256-bit)
> - ✅ Admin UI 必須明確顯示「API key 已設定」flag,唔顯示 plaintext
