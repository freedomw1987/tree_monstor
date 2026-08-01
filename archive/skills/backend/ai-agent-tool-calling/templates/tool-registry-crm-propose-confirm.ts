/**
 * CRM Tool Registry — Propose-and-Confirm Pattern
 * ───────────────────────────────────────────────
 * 給 AI agent 嘅 CRM tools,分 3 個 confirmation level:
 *   - safe: AI 直接做 (read, log_activity, draft quotation as DRAFT)
 *   - sensitive: AI propose,user 喺 frontend 確認 (update deal stage, update quotation status)
 *   - destructive: AI 永遠唔做 (delete),只係引導 user 去 UI
 *
 * 用法: copy 呢個 file 嘅 shape,改 `execute` 邏輯。
 *
 * 配套 reference: ../SKILL.md (Component 1) + ../references/audit-existing-before-build.md
 */

import { z } from 'zod'
import type { PrismaClient } from '@prisma/client'

// ============================================================
// Tool interface — 加 `requiresConfirmation` field
// ============================================================
export interface ToolContext {
  userId: string
  prisma: PrismaClient
  conversationId: string
}

export type ConfirmationLevel = 'safe' | 'sensitive' | 'destructive'

export interface Tool<T extends z.ZodTypeAny = z.ZodTypeAny> {
  name: string
  description: string
  schema: T
  requiresPermission?: string[]              // RBAC
  requiresConfirmation: ConfirmationLevel    // UX guard
  execute: (args: z.infer<T>, ctx: ToolContext) => Promise<unknown>
}

// ============================================================
// Example 1: SAFE — read company
// ============================================================
export const searchCompanies: Tool = {
  name: 'search_companies',
  description: 'Search for customer companies by name, industry, or status. Returns matching companies with contact counts and deal counts.',
  schema: z.object({
    query: z.string().optional().describe('Search term (matches name, legal name, email)'),
    industry: z.string().optional().describe('Filter by industry'),
    status: z.enum(['active', 'inactive', 'blacklisted']).optional(),
    limit: z.number().int().min(1).max(50).default(10),
  }),
  requiresConfirmation: 'safe',
  requiresPermission: ['sales:read'],
  execute: async (args, { prisma }) => {
    const where: Record<string, unknown> = {}
    if (args.status) where.status = args.status
    if (args.industry) where.industry = args.industry
    if (args.query) {
      where.OR = [
        { name: { contains: args.query, mode: 'insensitive' } },
        { legalName: { contains: args.query, mode: 'insensitive' } },
        { email: { contains: args.query, mode: 'insensitive' } },
      ]
    }
    const companies = await prisma.company.findMany({
      where,
      take: args.limit ?? 10,
      orderBy: { createdAt: 'desc' },
      include: {
        _count: { select: { contacts: true, quotations: true, deals: true } },
      },
    })
    return companies.map((c) => ({
      id: c.id,
      name: c.name,
      industry: c.industry,
      status: c.status,
      contactCount: c._count.contacts,
      quotationCount: c._count.quotations,
      dealCount: c._count.deals,
    }))
  },
}

// ============================================================
// Example 2: SAFE — draft quotation (saved as DRAFT, user promote)
// ============================================================
export const draftQuotation: Tool = {
  name: 'draft_quotation',
  description: 'Create a draft quotation for a company. Returns the new quotation ID. The quotation is saved as DRAFT status — user can review and promote to SENT in the UI.',
  schema: z.object({
    companyId: z.string().describe('The customer company ID'),
    items: z
      .array(
        z.object({
          name: z.string(),
          quantity: z.number().positive(),
          unitPrice: z.number().nonnegative(),
          discount: z.number().min(0).max(100).default(0),
        })
      )
      .min(1),
    title: z.string().optional(),
    notes: z.string().optional(),
    taxRate: z.number().min(0).max(100).default(0),
  }),
  requiresConfirmation: 'safe',
  requiresPermission: ['sales:write'],
  execute: async (args, { prisma, userId }) => {
    // Auto-generate next quotation number
    const year = new Date().getFullYear()
    const prefix = `Q-${year}-`
    const last = await prisma.quotation.findFirst({
      where: { number: { startsWith: prefix } },
      orderBy: { number: 'desc' },
    })
    const lastSeq = last ? parseInt(last.number.slice(prefix.length), 10) : 0
    const number = `${prefix}${(lastSeq + 1).toString().padStart(4, '0')}`

    let subtotal = 0
    const items = args.items.map((it, idx) => {
      const qty = Number(it.quantity)
      const price = Number(it.unitPrice)
      const disc = Number(it.discount ?? 0)
      const lineTotal = qty * price * (1 - disc / 100)
      subtotal += lineTotal
      return {
        name: it.name,
        quantity: qty,
        unitPrice: price,
        discount: disc,
        lineTotal,
        position: idx,
      }
    })
    const taxRate = Number(args.taxRate ?? 0)
    const taxAmount = subtotal * (taxRate / 100)
    const total = subtotal + taxAmount

    const created = await prisma.quotation.create({
      data: {
        number,
        companyId: args.companyId,
        createdById: userId,
        title: args.title,
        notes: args.notes,
        subtotal,
        taxRate,
        taxAmount,
        total,
        status: 'DRAFT',                  // ← Saved as DRAFT, user promote
        generatedByAi: true,              // ← Mark AI-generated for audit
        aiPrompt: '',                     // ← Set from caller context
        items: { create: items },
      },
      include: { items: true, company: true },
    })
    return {
      quotationId: created.id,
      number: created.number,
      company: created.company.name,
      total,
      itemCount: created.items.length,
    }
  },
}

// ============================================================
// Example 3: SENSITIVE — propose update, do NOT execute
// (Frontend 收到 proposal,顯示「Confirm 執行?」button,user click 先 fire PUT)
// ============================================================
export const proposeUpdateDealStage: Tool = {
  name: 'propose_update_deal_stage',
  description: 'Propose changing a deal\'s stage. Returns a proposal object — user must confirm in the UI before the change is applied.',
  schema: z.object({
    dealId: z.string().describe('The deal ID'),
    newStage: z.string().describe('The proposed new stage name (e.g. "WON", "LOST", or a custom stage)'),
    reason: z.string().optional().describe('Why the AI is proposing this change'),
  }),
  requiresConfirmation: 'sensitive',
  requiresPermission: ['sales:write'],
  execute: async (args, { prisma }) => {
    // ❗ Do NOT update — return proposal only
    const deal = await prisma.deal.findUnique({
      where: { id: args.dealId },
      include: { stage: { select: { name: true, probability: true } } },
    })
    if (!deal) throw new Error(`Deal not found: ${args.dealId}`)

    const newStage = await prisma.dealStage.findFirst({ where: { name: args.newStage } })
    if (!newStage) throw new Error(`Stage not found: ${args.newStage}`)

    return {
      type: 'proposal',                       // ← Frontend 識別呢個 shape
      action: 'update_deal_stage',
      dealId: deal.id,
      dealTitle: deal.title,
      currentStage: deal.stage.name,
      proposedStage: newStage.name,
      reason: args.reason ?? null,
      // Frontend 收到呢個就顯示「Confirm / Cancel」button,
      // confirm 時 fire `PUT /deals/${dealId}` with `{ stageId: newStage.id }`
    }
  },
}

// ============================================================
// Example 4: DESTRUCTIVE — NEVER delete, only guide user
// ============================================================
export const guideDeleteDeal: Tool = {
  name: 'guide_delete_deal',
  description: 'The user wants to delete a deal. AI cannot do this directly. Returns a guidance message pointing to the UI.',
  schema: z.object({
    dealId: z.string().describe('The deal ID'),
  }),
  requiresConfirmation: 'destructive',
  requiresPermission: ['sales:write'],
  execute: async (args, { prisma }) => {
    const deal = await prisma.deal.findUnique({ where: { id: args.dealId } })
    if (!deal) throw new Error(`Deal not found: ${args.dealId}`)
    return {
      type: 'guidance',
      message: `要刪除 deal "${deal.title}", 請去 Deal detail page 嘅「刪除」button(右上角 dropdown menu)做確認。AI 唔可以幫你做 destructive 嘅操作。`,
      dealUrl: `/deals/${deal.id}`,
    }
  },
}

// ============================================================
// Registry
// ============================================================
export const toolRegistry: Tool[] = [
  searchCompanies,
  draftQuotation,
  proposeUpdateDealStage,
  guideDeleteDeal,
]

// ============================================================
// Frontend tool result rendering (喺 chat UI 入面)
// ============================================================
/**
 * 根據 tool 嘅 `requiresConfirmation` level 決定點 render result:
 *
 * - 'safe': 直接 render result
 * - 'sensitive': 顯示「Confirm / Cancel」button,click 先 fire backend action
 * - 'destructive': 顯示 guidance message + 「去 UI 做」link
 *
 * Example (React):
 *
 * ```tsx
 * function ToolResultBubble({ toolName, result }: { toolName: string; result: any }) {
 *   const tool = toolRegistry.find(t => t.name === toolName)
 *   const level = tool?.requiresConfirmation ?? 'safe'
 *
 *   if (level === 'destructive' && result.type === 'guidance') {
 *     return (
 *       <Card>
 *         <p>{result.message}</p>
 *         <Link to={result.dealUrl}><Button>去打開 Deal</Button></Link>
 *       </Card>
 *     )
 *   }
 *
 *   if (level === 'sensitive' && result.type === 'proposal') {
 *     return (
 *       <Card>
 *         <p>AI 建議將 deal <b>{result.dealTitle}</b> 嘅 stage 由 <Badge>{result.currentStage}</Badge> 改去 <Badge>{result.proposedStage}</Badge></p>
 *         {result.reason && <p className="text-muted-foreground text-sm">原因:{result.reason}</p>}
 *         <div className="flex gap-2">
 *           <Button onClick={() => applyProposal(result)}>Confirm</Button>
 *           <Button variant="ghost" onClick={() => dismissProposal(result)}>Cancel</Button>
 *         </div>
 *       </Card>
 *     )
 *   }
 *
 *   return <pre>{JSON.stringify(result, null, 2)}</pre>
 * }
 * ```
 */
