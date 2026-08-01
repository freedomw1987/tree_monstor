// Elysia + Prisma + SQLite backend
// 用 SQLite 嘅 Prisma 5 setup. 詳見 prisma-sqlite-bun-setup skill.
import { Elysia, t } from "elysia"
import { PrismaClient } from "@prisma/client"

const prisma = new PrismaClient()
const PORT = Number(process.env.PORT) || 3200

const app = new Elysia()
  .get("/api/health", () => ({ ok: true, timestamp: new Date().toISOString() }))

  // GET /api/items?limit=20
  .get("/api/items", async ({ query }) => {
    const items = await prisma.item.findMany({
      take: Number(query.limit) || 20,
    })
    return items
  })

  // POST /api/items
  .post("/api/items", async ({ body }) => {
    const item = await prisma.item.create({ data: body as any })
    return item
  }, {
    body: t.Object({
      name: t.String(),
      // 視實際 schema 改
    }),
  })

  .listen(PORT)

console.log(`🚀 Backend at http://localhost:${PORT}`)
