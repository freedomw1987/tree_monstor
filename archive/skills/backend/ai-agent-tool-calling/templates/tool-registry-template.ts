/**
 * CRM Agent Tool Registry — Starter Template
 *
 * 8 tools for a "Day 1" CRM AI agent. Lightweight pattern (no Zod).
 * Copy this file into packages/ai/src/tools.ts and customize the tool logic
 * for your Prisma schema.
 *
 * To register/unregister tools: edit the `toolRegistry` array at the bottom.
 */

import { prisma } from '@crm/db';

export interface ToolContext {
  userId: string;
}

export interface Tool {
  name: string;
  description: string;
  parameters: {
    type: 'object';
    properties: Record<string, unknown>;
    required?: string[];
  };
  execute: (args: any, ctx: ToolContext) => Promise<unknown>;
}

// ─── 1. search_companies ─────────────────────────────────────────────
const searchCompanies: Tool = {
  name: 'search_companies',
  description: 'Search for customer companies by name, industry, or status.',
  parameters: {
    type: 'object',
    properties: {
      query: { type: 'string', description: 'Name/email/partial match' },
      industry: { type: 'string' },
      status: { type: 'string', enum: ['active', 'inactive', 'blacklisted'] },
      limit: { type: 'number' },
    },
  },
  execute: async (args) => {
    const where: Record<string, unknown> = {};
    if (args.status) where.status = args.status;
    if (args.industry) where.industry = args.industry;
    if (args.query) {
      where.OR = [
        { name: { contains: args.query, mode: 'insensitive' } },
        { email: { contains: args.query, mode: 'insensitive' } },
      ];
    }
    return prisma.company.findMany({
      where,
      take: args.limit ?? 10,
      orderBy: { createdAt: 'desc' },
      include: { _count: { select: { contacts: true, quotations: true } } },
    });
  },
};

// ─── 2. get_company ───────────────────────────────────────────────────
const getCompany: Tool = {
  name: 'get_company',
  description: 'Get full details of one company including contacts, recent quotations, and deals.',
  parameters: {
    type: 'object',
    properties: { companyId: { type: 'string' } },
    required: ['companyId'],
  },
  execute: async (args) => {
    return prisma.company.findUnique({
      where: { id: args.companyId },
      include: {
        contacts: true,
        quotations: { take: 10, orderBy: { createdAt: 'desc' } },
        deals: { take: 10, orderBy: { createdAt: 'desc' } },
      },
    });
  },
};

// ─── 3. search_products ───────────────────────────────────────────────
const searchProducts: Tool = {
  name: 'search_products',
  description: 'Search product catalog by name, SKU, or category.',
  parameters: {
    type: 'object',
    properties: {
      query: { type: 'string' },
      category: { type: 'string' },
      limit: { type: 'number' },
    },
  },
  execute: async (args) => {
    const where: Record<string, unknown> = { status: 'ACTIVE' };
    if (args.category) where.category = args.category;
    if (args.query) {
      where.OR = [
        { name: { contains: args.query, mode: 'insensitive' } },
        { sku: { contains: args.query, mode: 'insensitive' } },
      ];
    }
    return prisma.product.findMany({
      where,
      take: args.limit ?? 20,
      orderBy: { name: 'asc' },
    });
  },
};

// ─── 4. list_quotations ───────────────────────────────────────────────
const listQuotations: Tool = {
  name: 'list_quotations',
  description: 'List recent quotations, optionally filtered by company or status.',
  parameters: {
    type: 'object',
    properties: {
      companyId: { type: 'string' },
      status: { type: 'string', enum: ['DRAFT', 'SENT', 'VIEWED', 'ACCEPTED', 'REJECTED', 'EXPIRED', 'INVOICED'] },
      limit: { type: 'number' },
    },
  },
  execute: async (args) => {
    const where: Record<string, unknown> = {};
    if (args.companyId) where.companyId = args.companyId;
    if (args.status) where.status = args.status;
    return prisma.quotation.findMany({
      where,
      take: args.limit ?? 20,
      orderBy: { createdAt: 'desc' },
      include: { company: { select: { id: true, name: true } } },
    });
  },
};

// ─── 5. list_deals ────────────────────────────────────────────────────
const listDeals: Tool = {
  name: 'list_deals',
  description: 'List sales deals in the pipeline with optional filters.',
  parameters: {
    type: 'object',
    properties: {
      status: { type: 'string', enum: ['OPEN', 'WON', 'LOST'] },
      ownerId: { type: 'string' },
      companyId: { type: 'string' },
      limit: { type: 'number' },
    },
  },
  execute: async (args) => {
    const where: Record<string, unknown> = {};
    if (args.status) where.status = args.status;
    if (args.ownerId) where.ownerId = args.ownerId;
    if (args.companyId) where.companyId = args.companyId;
    return prisma.deal.findMany({
      where,
      take: args.limit ?? 20,
      orderBy: { createdAt: 'desc' },
      include: {
        company: { select: { id: true, name: true } },
        stage: { select: { name: true, probability: true } },
      },
    });
  },
};

// ─── 6. draft_quotation ───────────────────────────────────────────────
const draftQuotation: Tool = {
  name: 'draft_quotation',
  description: 'Create a DRAFT quotation for a company. Use search_products first to get accurate SKUs and prices.',
  parameters: {
    type: 'object',
    properties: {
      companyId: { type: 'string' },
      items: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            productId: { type: 'string' },
            sku: { type: 'string' },
            name: { type: 'string' },
            quantity: { type: 'number' },
            unitPrice: { type: 'number' },
            discount: { type: 'number' },
          },
          required: ['name', 'quantity', 'unitPrice'],
        },
      },
      title: { type: 'string' },
      notes: { type: 'string' },
      taxRate: { type: 'number' },
      prompt: { type: 'string', description: 'Original user prompt (for audit trail)' },
    },
    required: ['companyId', 'items'],
  },
  execute: async (args, ctx) => {
    // Auto-generate Q-YYYY-NNNN number
    const year = new Date().getFullYear();
    const prefix = `Q-${year}-`;
    const last = await prisma.quotation.findFirst({
      where: { number: { startsWith: prefix } },
      orderBy: { number: 'desc' },
    });
    const lastSeq = last ? parseInt(last.number.slice(prefix.length), 10) : 0;
    const number = `${prefix}${(lastSeq + 1).toString().padStart(4, '0')}`;

    let subtotal = 0;
    const items = (args.items as any[]).map((it, idx) => {
      const qty = Number(it.quantity);
      const price = Number(it.unitPrice);
      const disc = Number(it.discount ?? 0);
      const lineTotal = qty * price * (1 - disc / 100);
      subtotal += lineTotal;
      return {
        productId: it.productId,
        sku: it.sku,
        name: it.name,
        quantity: qty,
        unitPrice: price,
        discount: disc,
        lineTotal,
        position: idx,
      };
    });
    const taxRate = Number(args.taxRate ?? 0);
    const taxAmount = subtotal * (taxRate / 100);
    const total = subtotal + taxAmount;

    return prisma.quotation.create({
      data: {
        number,
        companyId: args.companyId,
        createdById: ctx.userId,
        title: args.title,
        notes: args.notes,
        subtotal,
        taxRate,
        taxAmount,
        total,
        generatedByAi: true,
        aiPrompt: args.prompt,
        items: { create: items },
      },
      include: { items: true, company: true },
    });
  },
};

// ─── 7. log_activity ──────────────────────────────────────────────────
const logActivity: Tool = {
  name: 'log_activity',
  description: 'Log a sales activity (call, email, meeting, note) against a company, contact, or deal.',
  parameters: {
    type: 'object',
    properties: {
      type: { type: 'string', enum: ['CALL', 'EMAIL', 'MEETING', 'NOTE', 'TASK'] },
      subject: { type: 'string' },
      body: { type: 'string' },
      companyId: { type: 'string' },
      contactId: { type: 'string' },
      dealId: { type: 'string' },
      dueAt: { type: 'string' },
    },
    required: ['type', 'subject'],
  },
  execute: async (args, ctx) => {
    return prisma.activityLog.create({
      data: {
        type: args.type,
        subject: args.subject,
        body: args.body,
        companyId: args.companyId,
        contactId: args.contactId,
        dealId: args.dealId,
        assignedToId: ctx.userId,
        dueAt: args.dueAt ? new Date(args.dueAt) : null,
      },
    });
  },
};

// ─── 8. get_top_customers ─────────────────────────────────────────────
const getTopCustomers: Tool = {
  name: 'get_top_customers',
  description: 'Get top customers ranked by total quotation value.',
  parameters: {
    type: 'object',
    properties: {
      limit: { type: 'number' },
      statusFilter: { type: 'string', enum: ['all', 'accepted', 'invoiced'] },
    },
  },
  execute: async (args) => {
    const where: Record<string, unknown> = {};
    if (args.statusFilter === 'accepted') where.status = 'ACCEPTED';
    else if (args.statusFilter === 'invoiced') where.status = 'INVOICED';

    const grouped = await prisma.quotation.groupBy({
      by: ['companyId'],
      where,
      _sum: { total: true },
      _count: { id: true },
      orderBy: { _sum: { total: 'desc' } },
      take: args.limit ?? 5,
    });
    const companies = await prisma.company.findMany({
      where: { id: { in: grouped.map(g => g.companyId) } },
      select: { id: true, name: true, industry: true },
    });
    const byId = new Map(companies.map(c => [c.id, c]));
    return grouped.map(g => ({
      companyId: g.companyId,
      companyName: byId.get(g.companyId)?.name ?? 'Unknown',
      industry: byId.get(g.companyId)?.industry,
      totalRevenue: g._sum.total ?? 0,
      quotationCount: g._count.id,
    }));
  },
};

// ─── Registry ─────────────────────────────────────────────────────────
export const toolRegistry: Tool[] = [
  searchCompanies,
  getCompany,
  searchProducts,
  listQuotations,
  listDeals,
  draftQuotation,
  logActivity,
  getTopCustomers,
];
