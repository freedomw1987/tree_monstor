# CRM 14-Model Variant (crm-system 2026-06-05)

The base `crm-data-model` skill has 11 models. The `crm-system` Day 1 build (crm-system at ~/www/crm-system) used a 14-model variant with these specific tweaks:

## Models added on top of the 11-model baseline

1. **`Tag` + `CompanyTag` / `DealTag`** — separated into polymorphic join tables (vs the skill's `String[]` Postgres-native approach). Reason: David wants tags to be admin-editable entities with their own color + category, not just free-form strings. Trade-off: more joins but richer tag management UI.
2. **`Address` is standalone (not in skill)** — already in skill. Used.
3. **`PipelineStage` separated from `Pipeline`** — already in skill. Used with `@@unique([pipelineId, order])` for ordering.
4. **`Conversation` + `ConversationMessage`** — split as two separate models (skill's `Conversation` + `Message` are equivalent). The `Message` in this build is renamed to `ConversationMessage` and has explicit `toolName` + `toolArgs` + `toolResult` columns for AI agent function-calling audit trail.

## Field differences

- `Quotation.aiPrompt` (String?) and `Quotation.generatedByAi` (Boolean) — added for AI agent audit trail ("this quotation was drafted by the agent from prompt X")
- `QuotationItem.position` (Int) instead of `order` (Int) — naming preference, same semantics
- `Product.unitPrice` (Decimal) used instead of `sellPrice` — naming preference (less ambiguous, "sellPrice" implies only retail)
- `Product.stockQuantity` (Int) instead of `stock` (Int?) — explicit naming, nullable for non-stock items
- `Deal.expectedValue` (Decimal) is NOT used; instead `value` (Decimal) directly

## Conversation model (this variant)

```prisma
model Conversation {
  id        String   @id @default(cuid())
  userId    String
  user      User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  title     String?
  // Soft link to the CRM record the conversation is "about" (optional)
  companyId String?
  company   Company? @relation(fields: [companyId], references: [id], onDelete: SetNull)
  dealId    String?
  deal      Deal?    @relation(fields: [dealId], references: [id], onDelete: SetNull)
  messages  ConversationMessage[]
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  @@index([userId, updatedAt])
  @@map("conversations")
}

model ConversationMessage {
  id             String   @id @default(cuid())
  conversationId String
  conversation   Conversation @relation(fields: [conversationId], references: [id], onDelete: Cascade)
  role           MessageRole  // USER | ASSISTANT | TOOL | SYSTEM
  content        String   @db.Text
  // AI agent function-calling audit
  toolName       String?
  toolArgs       Json?
  toolResult     Json?
  // Token accounting
  promptTokens     Int?
  completionTokens Int?
  createdAt      DateTime @default(now())
  @@index([conversationId, createdAt])
  @@map("conversation_messages")
}

enum MessageRole { USER ASSISTANT TOOL SYSTEM }
```

## Seed data scale (Day 1)

- 2 users (admin + sales)
- 3 companies
- 5 contacts
- 8 products
- 1 pipeline with 6 stages (Lead → Qualified → Proposal → Negotiation → Won/Lost)
- 3 deals in different stages
- 3 activity logs
- 1 quotation
- 1 conversation (left empty for the user to test the agent on)

## Dev login

- `admin@crm.local` / `admin123` (role: ADMIN)
- `sales@crm.local` / `sales123` (role: SALES)

## Lessons from this build

1. **Decimal type works fine with `mode: "insensitive"` in string searches** — Prisma 5.22 with Postgres handles the case-insensitive search on `name` etc. without issue.
2. **`@@unique([pipelineId, order])`** is a clean way to enforce stage ordering without a separate `order` sequence table.
3. **`@db.Text` for `body` / `notes` fields** is good practice even for short content — avoids the 255-char VARCHAR trap when an agent writes a long follow-up note.
4. **`toolArgs: Json?` instead of `String?`** means you can directly inspect AI agent decisions in Prisma Studio without parsing JSON strings.
