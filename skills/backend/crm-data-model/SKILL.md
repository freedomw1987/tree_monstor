---
name: crm-data-model
description: Design a modern CRM data model (HubSpot / Pipedrive inspired) — Company, Contact, Product, Quotation, Deal, Pipeline, ActivityLog, Tag, Conversation. Use when building a CRM, sales tool, quote/quotation system, or any sales pipeline tracking app. Vendor-neutral Prisma schema, ready to adapt to Postgres/MySQL/SQLite.
tags: ["crm", "data-model", "prisma", "schema", "sales", "quotation", "deal", "pipeline", "hubspot", "pipedrive"]
---

# CRM Data Model (Modern, HubSpot/Pipedrive-style)

## 觸發時機

- 用戶講「CRM」「報價單」「報價系統」「sales pipeline」「客戶管理」「deal tracking」「quotation」
- 用戶做 sales/quote/invoicing 重建,或者要加 sales 功能去現有 app
- 開始一個 CRM 項目嘅 Prisma schema / DB 設計階段
- 從零設計 B2B sales tool 嘅 backend

## 設計原則

1. **Customer = Company + Contacts (1:N)** — 同 HubSpot 一致。唔好用 flat `Customer` 將公司同聯絡人黐埋一齊
2. **Quote ≠ Invoice ≠ Deal** — 三件唔同嘅事:
   - **Quotation** = 你 send 出去嘅報價 (可改)
   - **Invoice** = 客戶 accept 咗之後出嘅 (不可改 / 會計用)
   - **Deal** = 商機 (仲未報價 / 傾緊)
3. **Pipeline 是 stage 配置, Deal 是 stage 上的 instance** — 分開兩個 model, 唔好 hardcode stage string
4. **Tag 多形** — 一個 Tag model 加 polymorphic FK, 唔好為 Company/Deal/Quotation 各做一個 Tag
5. **ActivityLog 萬能 audit trail** — 任何 interaction (email, call, meeting, note, AI agent action) 落呢度
6. **Conversation + Message 預留畀 AI agent / chat / WhatsApp** — Day 1 就要有, 之後唔使 migrate
7. **軟刪除** — `deletedAt` 字段 (唔用 `isDeleted` boolean), 標準 Prisma pattern
8. **Audit columns 必備** — `createdAt`, `updatedAt`, `createdById`, `updatedById`

## Core Models (11 個)

### Identity / Auth

#### 1. `User` — 系統用戶 (sales / admin)
```prisma
model User {
  id            String    @id @default(cuid())
  email         String    @unique
  name          String
  passwordHash  String
  role          UserRole  @default(SALES)
  isActive      Boolean   @default(true)
  lastLoginAt   DateTime?
  createdAt     DateTime  @default(now())
  updatedAt     DateTime  @updatedAt

  // Relations
  ownedCompanies   Company[]   @relation("AccountOwner")
  ownedDeals       Deal[]      @relation("DealOwner")
  createdQuotes    Quotation[] @relation("QuoteCreator")
  activities       ActivityLog[]
  conversations    Conversation[]

  @@map("users")
}

enum UserRole {
  ADMIN
  SALES
  VIEWER
}
```

### Customer Domain

#### 2. `Company` — 客戶公司 (主表)
```prisma
model Company {
  id           String    @id @default(cuid())
  name         String
  legalName    String?
  taxId        String?
  industry     String?
  website      String?
  phone        String?
  email        String?
  logoUrl      String?
  size         CompanySize?
  annualRevenue Decimal? @db.Decimal(15, 2)
  source       CompanySource @default(MANUAL)
  status       CompanyStatus @default(ACTIVE)
  notes        String?   @db.Text

  // Relations
  ownerId      String
  owner        User      @relation("AccountOwner", fields: [ownerId], references: [id])
  contacts     Contact[]
  addresses    Address[]
  deals        Deal[]
  quotations   Quotation[]
  activities   ActivityLog[]

  createdAt    DateTime  @default(now())
  updatedAt    DateTime  @updatedAt
  deletedAt    DateTime?

  @@index([ownerId])
  @@index([status])
  @@index([name])
  @@map("companies")
}

enum CompanySize { MICRO SMALL MEDIUM LARGE ENTERPRISE }
enum CompanySource { MANUAL REFERRAL WEBSITE LINKEDIN TRADE_SHOW COLD_OUTREACH OTHER }
enum CompanyStatus { ACTIVE INACTIVE CHURNED BLACKLIST }
```

#### 3. `Contact` — 客戶聯絡人
```prisma
model Contact {
  id          String   @id @default(cuid())
  firstName   String
  lastName    String
  fullName    String
  email       String?
  phone       String?
  mobile      String?
  jobTitle    String?
  department  String?
  isPrimary   Boolean  @default(false)
  linkedinUrl String?
  notes       String?  @db.Text

  companyId   String
  company     Company  @relation(fields: [companyId], references: [id], onDelete: Cascade)
  addresses   Address[]
  deals       Deal[]
  activities  ActivityLog[]

  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
  deletedAt   DateTime?

  @@index([companyId])
  @@index([email])
  @@index([fullName])
  @@map("contacts")
}
```

#### 4. `Address` — 公司 / 聯絡人地址
```prisma
model Address {
  id         String   @id @default(cuid())
  type       AddressType @default(BILLING)
  line1      String
  line2      String?
  city       String
  region     String?
  postalCode String?
  country    String   @default("HK")
  isDefault  Boolean  @default(false)

  // Polymorphic
  companyId  String?
  company    Company? @relation(fields: [companyId], references: [id], onDelete: Cascade)
  contactId  String?
  contact    Contact? @relation(fields: [contactId], references: [id], onDelete: Cascade)

  createdAt  DateTime @default(now())
  updatedAt  DateTime @updatedAt

  @@index([companyId])
  @@index([contactId])
  @@map("addresses")
}

enum AddressType { BILLING SHIPPING OFFICE HOME OTHER }
```

### Product / Catalogue

#### 5. `Product` — 產品目錄
```prisma
model Product {
  id            String   @id @default(cuid())
  sku           String   @unique
  name          String
  description   String?  @db.Text
  category      String?
  unit          String   @default("pcs")
  costPrice     Decimal  @db.Decimal(12, 2)
  sellPrice     Decimal  @db.Decimal(12, 2)
  currency      String   @default("HKD")
  taxRate       Decimal  @default(0) @db.Decimal(5, 2)
  isActive      Boolean  @default(true)
  stock         Int?
  imageUrl      String?
  metadata      Json?

  quotationItems QuotationItem[]

  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt
  deletedAt     DateTime?

  @@index([sku])
  @@index([category])
  @@map("products")
}
```

### Sales Pipeline

#### 6. `Pipeline` + `PipelineStage` — pipeline 配置
```prisma
model Pipeline {
  id          String   @id @default(cuid())
  name        String   @unique
  isDefault   Boolean  @default(false)
  description String?

  stages      PipelineStage[]
  deals       Deal[]

  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  @@map("pipelines")
}

model PipelineStage {
  id           String   @id @default(cuid())
  name         String
  order        Int
  probability  Int      @default(0)
  isWon        Boolean  @default(false)
  isLost       Boolean  @default(false)
  color        String?

  pipelineId   String
  pipeline     Pipeline @relation(fields: [pipelineId], references: [id], onDelete: Cascade)
  deals        Deal[]

  @@unique([pipelineId, order])
  @@map("pipeline_stages")
}
```

#### 7. `Deal` — 商機
```prisma
model Deal {
  id           String   @id @default(cuid())
  title        String
  value        Decimal  @db.Decimal(15, 2)
  currency     String   @default("HKD")
  expectedCloseDate DateTime?
  status       DealStatus @default(OPEN)
  lostReason   String?

  pipelineId   String
  pipeline     Pipeline @relation(fields: [pipelineId], references: [id])
  stageId      String
  stage        PipelineStage @relation(fields: [stageId], references: [id])
  companyId    String
  company      Company  @relation(fields: [companyId], references: [id])
  primaryContactId String?
  primaryContact Contact? @relation(fields: [primaryContactId], references: [id])
  ownerId      String
  owner        User     @relation("DealOwner", fields: [ownerId], references: [id])
  quotationId  String?  @unique
  quotation    Quotation? @relation(fields: [quotationId], references: [id])

  activities   ActivityLog[]

  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt
  closedAt     DateTime?
  deletedAt    DateTime?

  @@index([pipelineId, stageId])
  @@index([ownerId])
  @@index([companyId])
  @@map("deals")
}

enum DealStatus { OPEN WON LOST }
```

### Quotation

#### 8. `Quotation` — 報價單主表
```prisma
model Quotation {
  id           String    @id @default(cuid())
  number       String   @unique
  status       QuotationStatus @default(DRAFT)
  issueDate    DateTime @default(now())
  validUntil   DateTime
  currency     String   @default("HKD")
  subtotal     Decimal  @db.Decimal(15, 2) @default(0)
  taxTotal     Decimal  @db.Decimal(15, 2) @default(0)
  discount     Decimal  @db.Decimal(15, 2) @default(0)
  total        Decimal  @db.Decimal(15, 2) @default(0)
  notes        String?  @db.Text
  terms        String?  @db.Text
  pdfUrl       String?

  companyId    String
  company      Company  @relation(fields: [companyId], references: [id])
  contactId    String?
  contact      Contact? @relation(fields: [contactId], references: [id])
  createdById  String
  createdBy    User     @relation("QuoteCreator", fields: [createdById], references: [id])
  deal         Deal?
  items        QuotationItem[]
  activities   ActivityLog[]

  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt
  sentAt       DateTime?
  acceptedAt   DateTime?
  rejectedAt   DateTime?
  deletedAt    DateTime?

  @@index([companyId])
  @@index([status])
  @@index([number])
  @@map("quotations")
}

enum QuotationStatus { DRAFT SENT VIEWED ACCEPTED REJECTED EXPIRED INVOICED }
```

#### 9. `QuotationItem` — 報價單 line items
```prisma
model QuotationItem {
  id          String   @id @default(cuid())
  order       Int

  productId   String?
  product     Product? @relation(fields: [productId], references: [id])
  sku         String?
  name        String
  description String?  @db.Text

  quantity    Decimal  @db.Decimal(12, 4)
  unitPrice   Decimal  @db.Decimal(12, 2)
  discount    Decimal  @db.Decimal(5, 2) @default(0)
  taxRate     Decimal  @db.Decimal(5, 2) @default(0)
  lineTotal   Decimal  @db.Decimal(15, 2)

  quotationId String
  quotation   Quotation @relation(fields: [quotationId], references: [id], onDelete: Cascade)

  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  @@index([quotationId])
  @@map("quotation_items")
}
```

> **Snapshot 原則**: 報價單上嘅 product name / price 必須 snapshot, 唔好 `references` 後 derive. 否則改咗 product price 會搞亂歷史報價.

### Universal Audit / Activity

#### 10. `ActivityLog` — 萬能 audit trail
```prisma
model ActivityLog {
  id          String   @id @default(cuid())
  type        ActivityType
  subject     String?
  body        String?  @db.Text
  metadata    Json?

  // Polymorphic
  companyId   String?
  company     Company? @relation(fields: [companyId], references: [id], onDelete: Cascade)
  contactId   String?
  contact     Contact? @relation(fields: [contactId], references: [id], onDelete: Cascade)
  dealId      String?
  deal        Deal?    @relation(fields: [dealId], references: [id], onDelete: Cascade)
  quotationId String?
  quotation   Quotation? @relation(fields: [quotationId], references: [id], onDelete: Cascade)

  userId      String?
  user        User?    @relation(fields: [userId], references: [id])
  isAiAgent   Boolean  @default(false)

  occurredAt  DateTime @default(now())
  createdAt   DateTime @default(now())

  @@index([companyId, occurredAt])
  @@index([dealId, occurredAt])
  @@index([type])
  @@map("activity_logs")
}

enum ActivityType {
  EMAIL_SENT
  EMAIL_OPENED
  EMAIL_REPLIED
  CALL
  MEETING
  NOTE
  QUOTATION_SENT
  QUOTATION_VIEWED
  QUOTATION_ACCEPTED
  QUOTATION_REJECTED
  DEAL_CREATED
  DEAL_STAGE_CHANGED
  DEAL_WON
  DEAL_LOST
  AI_AGENT_ACTION
  SYSTEM
}
```

### AI / Chat

#### 11. `Conversation` + `Message` — AI agent 對話記錄
```prisma
model Conversation {
  id          String    @id @default(cuid())
  title       String?
  channel     ConversationChannel @default(WEB)
  status      ConversationStatus  @default(ACTIVE)
  metadata    Json?

  userId      String
  user        User      @relation(fields: [userId], references: [id])
  companyId   String?
  company     Company?  @relation(fields: [companyId], references: [id])
  dealId      String?
  deal        Deal?     @relation(fields: [dealId], references: [id])

  messages    Message[]

  createdAt   DateTime  @default(now())
  updatedAt   DateTime  @updatedAt
  closedAt    DateTime?

  @@index([userId, updatedAt])
  @@map("conversations")
}

model Message {
  id              String   @id @default(cuid())
  role            MessageRole
  content         String   @db.Text
  toolCalls       Json?
  tokens          Int?
  latencyMs       Int?

  conversationId  String
  conversation    Conversation @relation(fields: [conversationId], references: [id], onDelete: Cascade)

  createdAt       DateTime @default(now())

  @@index([conversationId, createdAt])
  @@map("messages")
}

enum ConversationChannel { WEB WHATSAPP SLACK EMAIL API }
enum ConversationStatus { ACTIVE CLOSED ARCHIVED }
enum MessageRole { USER ASSISTANT TOOL SYSTEM }
```

## 字段設計備忘

| 問題 | 答案 |
|---|---|
| 金額 decimal 定 float? | **Decimal** 必備 (`@db.Decimal(15, 2)`), float 有 floating point 問題 |
| 軟刪除用咩? | `deletedAt DateTime?` + Prisma middleware filter |
| Audit columns | `createdAt`, `updatedAt`, `createdById`, `updatedById`, `deletedAt` 必備 |
| ID 用咩? | `cuid()` — sort-friendly, URL-safe, 比 UUID 短 |
| Tag 點做? | Postgres native `String[]` 最簡; MySQL/SQLite 用 join table `Tag` + `Taggable` |
| Currency 點存? | String ISO 4217 (HKD, USD, CNY), 唔好 enum |
| Address 點做? | 獨立 model, polymorphic FK, 唔好 JSON |
| 報價單編號? | `Q-YYYY-NNNN` 格式, sequence table 或者 app-level counter |

## 唔好用嘅 anti-patterns

- ❌ `Customer` 一個 model 包公司 + 聯絡人 (一對多拆開)
- ❌ Quotation 直接 `references Product` 攞價錢 (報價要 snapshot)
- ❌ Stage 用 enum 寫死 唔可改 (用 `PipelineStage` table)
- ❌ Tag 為每個 entity 各做一個 (polymorphic + join table)
- ❌ 金額用 `Float` (永遠用 `Decimal`)
- ❌ `isDeleted Boolean` (用 `deletedAt DateTime?`)
- ❌ ID 用 auto-increment Int (sort 唔 friendly, multi-tenant 易撞; 用 `cuid()`)
- ❌ 將 `notes` 塞入 `Quotation` (有 `ActivityLog` 做 thread)

## Common Adjacent Models (按需要加)

| Model | 何時加 |
|---|---|
| `Invoice` | 客戶 accept 報價後出 invoice (會計用, immutable after issue) |
| `Payment` | 追蹤 invoice 收錢記錄 |
| `EmailTemplate` | 報價 / follow-up 電郵範本 |
| `Lead` | 仲未 qualify 嘅潛在客戶 (Pipeline stage 1) |
| `Campaign` | Marketing campaign 追蹤 (email blast, event) |
| `Document` | 合約、提案附件 (S3 presigned URLs) |
| `Task` | Sales 嘅 follow-up task |
| `Subscription` | SaaS 公司用 (recurring revenue) |

## 變體: 報價單包含「服務」(Service + Man-Day Breakdown) — Day 7 crm-system pattern

當報價單需要包括「人天計費」嘅 service offer(consulting / agency / SaaS implementation 嘅典型),Product 單一 model 唔夠用 — 要加 `Service` + `ServiceManDay` model,然後 **polymorphic 化 QuotationItem**。

### 觸發時機

用戶講:
- 「報價單要包括服務同產品」
- 「服務要按人天計費」(man-day pricing)
- 「SOW 點存」(statement of work)
- 「我想 pre-define 一個 service 個 default 嘅人天結構」
- 「同個 service 唔同嘅 project 可以 reuse」

### 5 個 schema 改動

**1. 加 `Service` table**(service 模板,independent of any specific project):

```prisma
model Service {
  id          String   @id @default(cuid())
  name        String                                    // e.g. "AI Implementation Consulting"
  description String?  @db.Text                        // SOW — full scope of work text
  unitPrice   Decimal  @db.Decimal(15, 2)              // total default price
  currency    String   @default("HKD")
  isActive    Boolean  @default(true)
  sortOrder   Int      @default(0)

  manDayLines ServiceManDay[]                          // pre-defined role × day structure
  quotationItems QuotationItem[]

  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
  deletedAt   DateTime?

  @@index([isActive])
  @@map("services")
}

model ServiceManDay {
  id         String  @id @default(cuid())
  serviceId  String
  service    Service @relation(fields: [serviceId], references: [id], onDelete: Cascade)

  role       String                                       // e.g. "Senior Consultant", "Junior Engineer"
  dayRate    Decimal  @db.Decimal(12, 2)                  // per-day cost for this role
  days       Decimal  @db.Decimal(8, 2)                   // number of days
  subtotal   Decimal  @db.Decimal(15, 2)                  // dayRate × days (cached for performance)

  position   Int      @default(0)                         // display order

  createdAt  DateTime @default(now())
  updatedAt  DateTime @updatedAt

  @@index([serviceId, position])
  @@map("service_man_days")
}
```

**2. 加 `ItemType` enum 同 polymorphic fields 喺 QuotationItem**:

```prisma
enum ItemType {
  PRODUCT
  SERVICE
}

model QuotationItem {
  id          String   @id @default(cuid())
  position    Int

  // Polymorphic — exactly one of productId or serviceId is set, matching itemType
  itemType    ItemType
  productId   String?
  product     Product? @relation(fields: [productId], references: [id])
  serviceId   String?
  service     Service? @relation(fields: [serviceId], references: [id])

  // Snapshotted at creation time so historical quotes are frozen
  sku         String?                                     // products only
  name        String                                      // copy of product/service name
  description String?  @db.Text                           // copy of SOW for service

  quantity    Decimal  @db.Decimal(12, 4)
  unitPrice   Decimal  @db.Decimal(12, 2)                 // service: derived from sum(manDayLines)
  discount    Decimal  @db.Decimal(5, 2)  @default(0)
  taxRate     Decimal  @db.Decimal(5, 2)  @default(0)
  lineTotal   Decimal  @db.Decimal(15, 2)

  // For service items: snapshot of the man-day breakdown that priced this quote
  manDaySnapshot Json?                                     // [{role, dayRate, days, subtotal}]

  quotationId String
  quotation   Quotation @relation(fields: [quotationId], references: [id], onDelete: Cascade)

  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  @@index([quotationId, position])
  @@index([productId])
  @@index([serviceId])
  @@map("quotation_items")
}
```

### 兩種 price 策略

| Strategy | Service.unitPrice | 報價時 | 邊個揀 |
|---|---|---|---|
| **A: 預先 locked** (Day 7 揀咗) | 固定總額 (e.g. 45,000 HKD) | user 揀 service → 自動 snapshot 價錢, 只改 quantity | user 唔可以 override 個別 man-day line |
| **B: 報價時 expand** | 0 (或預設) | user 揀 service → 載入 default man-day structure → user 可改 individual lines | user 客製化 mix, price = sum(lines) |

**揀 A 嘅理由**: 真實 PM 想控制 pricing;B 適合 freelance / 工程報價。

**A 嘅報價 builder UX**:
1. User 揀 service → snapshot `name + unitPrice + manDayLines (read-only display)`
2. User 改 quantity (e.g. 1 個 phase = 1 unit)
3. lineTotal = unitPrice × quantity × (1 - discount)

**man-day 純 display 唔入 price calculation**(A strategy),但保留 `manDaySnapshot` JSON 用於:
- 報價 detail 顯示 「Senior x 5 days, Junior x 10 days = 45,000 HKD」 breakdown
- Audit log 可見「個 quote 用咗咩 structure」
- 將來如果想改做 B strategy, 有 raw data 喺度

### 3 個 pitfalls (Day 7 撞過)

1. **Prisma JSON + enum polymorphic 嘅 type cast** — `itemType: string` 同 `manDaySnapshot: unknown` 都唔啱 Prisma 嘅 `ItemType` enum + `InputJsonValue` type,要用 `as never` cast。詳見 `backend-rbac-audit-log` skill Step 11。

2. **唔好用 STI (single-table inheritance) Prisma 5 仲係 experimental** — 用 Option A (兩 table + discriminator) 唔用 `@@delegate`。Prisma 5.x STI production 有 future 風險。

3. **Migration order** — 改 `QuotationItem` 加 polymorphic fields 之前要先後向 (1) `services` table → (2) backfill default `itemType=PRODUCT` 喺 existing rows → (3) 加 FK columns → (4) 設 `NOT NULL` 喺 `itemType`。喺 docker postgres container 入面要 `docker exec psql` 行 SQL + 手動 insert `_prisma_migrations` row,詳見 `bun-elysia-react-vite-stack` skill。

### Backend route pattern

```typescript
// Create item with polymorphic handling
.post('/:id/items', async ({ params, body, set }) => {
  const data = body as { productId?: string; serviceId?: string;
                         name: string; quantity: number; unitPrice: number;
                         discount?: number; manDaySnapshot?: unknown };
  const itemType: string = data.serviceId ? 'SERVICE' : 'PRODUCT';
  const last = await prisma.quotationItem.findFirst({
    where: { quotationId: params.id },
    orderBy: { position: 'desc' },
  });
  const item = await prisma.quotationItem.create({
    data: {
      quotationId: params.id,
      itemType: itemType as never,                                              // ← string → enum
      productId: itemType === 'PRODUCT' ? data.productId : null,
      serviceId: itemType === 'SERVICE' ? data.serviceId : null,
      name: data.name,
      unitPrice: Number(data.unitPrice),
      discount: Number(data.discount ?? 0),
      lineTotal: lineTotalOf(...),
      manDaySnapshot: (data.manDaySnapshot ?? undefined) as never,             // ← unknown → JSON
      position: (last?.position ?? -1) + 1,
    },
  });
  return item;
})
```

### Frontend builder UX

- **Item type radio**: `📦 產品` vs `🛠 服務` (喺每行 item 頂部)
- **揀 product**: 顯示 product dropdown + 自動 snapshot name/price
- **揀 service**: 顯示 service dropdown + 自動 snapshot name/price/SOW
- **Service 詳情 panel** (read-only): 顯示 man-day breakdown 「Senior x 5 days, Junior x 10 days = 45,000 HKD」
- **報價 detail**: 顯示 product 嘅 description 同 service 嘅 SOW + man-day breakdown

詳細嘅 frontend pattern 喺 `references/polymorphic-quotation-builder-frontend.md` (TODO: 之後補)。

## 配套 skills

- `devops/bun-elysia-react-vite-stack` — Prisma + Elysia 嘅 setup pattern
- `crm-ai-agent-tool-calling` — 用 `Conversation` / `Message` 嘅 AI agent 實作
- `backend-rbac-audit-log` — User model + RBAC + AuditLog 嘅完整 backend 實作 pattern
- `prisma-sqlite-bun-setup` — 如果 dev 環境用 SQLite (要 pin Prisma 5)
- `prisma-migrate-private-rds` — Production RDS 嘅 migration SOP

## 配套 references

- `references/crm-14-model-variant.md` — Day 1 crm-system 嘅 14-model 變體差異(Tag 拆 join table、aiPrompt 欄位、ConversationMessage + toolArgs 欄位、seed data scale、dev login 賬號)
- `references/crm-day8-deal-region-kanban.md` — Day 8 schema + UI pattern: 區域 enum、Deals Kanban (1-to-many Quotation)、Quotation Builder polymorphic autocomplete

## Pitfalls (跨 task,後人必讀)

### 🚨 Prisma `Decimal` field 喺 JSON 之後係 string — frontend 唔好 `reduce` 加

`Decimal` field 經 Prisma query 後喺 backend 仲係 `Prisma..Decimal` object,但經 `JSON.stringify` 同 HTTP 傳輸後 frontend 收到嘅係**string**(e.g. `"75000"` 唔係 `75000`)。

```typescript
// ❌ 死法:reduce 加 string,變 string concat
const total = deals.reduce((s, d) => s + d.value, 0);
// "75000" + "50000" + "120000" = "7500050000120000"  ← trillion!

// ✅ 每次都強制 Number()
const total = deals.reduce((s, d) => s + Number(d.value), 0);
```

**應用範圍**:`Deal.value` / `QuotationItem.unitPrice` / `Quotation.total` / 所有 `@db.Decimal(...)` 嘅 field,凡係 frontend 累加都要 `Number(...)` 包住。

**Backend render 之前**亦最好 `Number(d.value)` 喺 controller 處理一次(避免兩邊都踩雷)。Elysia JSON serializer 預設會 `String(prismaDecimal)`,所以 frontend 唔可以假設 number type。

### 1-to-many 父子關係:加 FK 之前要 backfill 舊 data

由 1-to-1 (`Deal.quotationId @unique`) 升級去 1-to-many (`Deal.quotations Quotation[]`) 嘅時候,Prisma migration 唔識自動 backfill。**步驟**:

1. `ALTER TABLE "quotations" ADD COLUMN "dealId" TEXT` (nullable)
2. `UPDATE quotations SET "dealId" = ...` (如有舊 data 要配對)
3. `ALTER TABLE "quotations" ADD FOREIGN KEY ("dealId") REFERENCES "deals"("id") ON DELETE SET NULL`
4. 唔好設 `NOT NULL`,因為可能 Deal 唔見咗 quotation 仍然存在

In Docker-based dev:`docker exec crm-postgres psql` 行 SQL + 手動 `INSERT INTO _prisma_migrations`。詳細 step 喺 `bun-elysia-react-vite-stack` skill 嘅 migration section。

### Enum + free-form 組合:用 enum 鎖死 primary,再加 `customX String?` 補丁

要 region 呢類有 3-4 個 primary option 但要支援 "其他" free-form,**唔好**:

- ❌ 用 `String` 純字串(typo 唔會被 schema 攔截)
- ❌ 開獨立 Region table(overkill,Day 8 階段太重)

**應該**:

```prisma
enum Region { HK MO CN OTHER }
model Company {
  region       Region   @default(HK)
  customRegion String?  // 僅 region = OTHER 時填
}
```

UI 用 Select,揀 OTHER 時顯示 Input 收 `customRegion`。Backend validator 用 `t.Union([t.Literal('HK'), t.Literal('MO'), t.Literal('CN'), t.Literal('OTHER')])` 鎖死。

### 🚨 Prisma `enum` field — schema/DB drift 嘅 silent trap (Day 9 撞過)

`QuotationItem.itemType ItemType` 寫 schema 係 enum,但你個 migration 寫
`ADD COLUMN "itemType" TEXT NOT NULL DEFAULT 'PRODUCT'` — DB column 係
`text`,而 Prisma 期望 enum type。**Build 唔 fail,Prisma client 跑 migration
亦唔 detect**,但首次寫入 `prisma.quotationItem.create({ data: { itemType: 'PRODUCT' } })`
會 throw `42704: type "public.ItemType" does not exist`。

**點解會撞**:Day 7 寫 enum 嘅 migration 之後手動改 column type(例如
為咗加新 value 唔想做 DDL),但忘記 sync `schema.prisma`。或者
`bunx prisma generate` 啱啱行咗而 dev container 嘅 `node_modules` 仲
cache 住舊 generated client。

**Symptom**: `Prisma.quotationItem.create()` 報 `type "public.<EnumName>"
does not exist` 但 `prisma migrate status` 話 0 pending migrations。

**Fix (Day 9 揀)**:**直接用 `String` + `@default("PRODUCT")`**,唔再
用 Prisma enum。理由:

1. 加新 item type (SUBSCRIPTION, USAGE) 唔需要 DDL migration
2. Postgres enum 加 value 嘅 syntax 麻煩
3. Prisma client 嘅 enum cast 同 JSON.stringify 之後的 string 之間 type 唔 match
4. Application code 用 hard-coded `if (it.serviceId) 'SERVICE' else 'PRODUCT'` 做 discriminator 反而更直接

```prisma
// Day 9 schema fix
model QuotationItem {
  // ... no enum declaration, just text + default
  itemType    String   @default("PRODUCT")
}
```

**Verify path**:`bunx prisma generate` 一定要喺 host 跑一次(會覆蓋
`node_modules/.prisma/client`),然後 `docker compose build --no-cache api`
確保 stage 1 嘅 `bunx prisma generate` 都 produce 新 client。Host 嘅
`node_modules` 改咗唔等於 container 內嘅改咗。

### 🚨 升級 enum → table 嘅 production migration(Region: Day 8 → Day 9 真實案例)

David 撞咗 3 個新需求時升級:

1. Admin 唔可以再加新 region(Taiwan / Singapore / Japan)唔做 DDL
2. UI 要動態 render filter pills + form dropdown
3. Frontend 唔再 hard-code 4 個 region

從 `enum Region { HK MO CN OTHER }` 升級到 `model Region { id, code, name, ... }`
+ `Company.regionId String?` FK,**Prisma `migrate dev` 唔識 produce
呢個 migration**(因為 enum→model 唔係 Prisma express 得到)。要手動:

```sql
-- 1. Create regions table with deterministic cuids so backfill JOIN works
CREATE TABLE regions (
  id TEXT PRIMARY KEY,
  code TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  flag TEXT,
  "isActive" BOOLEAN NOT NULL DEFAULT true,
  "sortOrder" INTEGER NOT NULL DEFAULT 0,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2. Seed base regions (cuids must match what the app code expects)
INSERT INTO regions (id, code, name, flag, "isActive", "sortOrder", "createdAt", "updatedAt") VALUES
  ('reg_hk_seed', 'HK', 'Hong Kong 香港', '🇭🇰', true, 1, NOW(), NOW()),
  ('reg_mo_seed', 'MO', 'Macau 澳門', '🇲🇴', true, 2, NOW(), NOW()),
  ('reg_cn_seed', 'CN', '中國 China', '🇨🇳', true, 3, NOW(), NOW()),
  ('reg_other_seed', 'OTHER', '其他 (自由填寫)', '🌏', true, 4, NOW(), NOW())
ON CONFLICT (code) DO NOTHING;

-- 3. Add regionId column (nullable first, fill, then FK)
ALTER TABLE companies ADD COLUMN "regionId" TEXT;

-- 4. Backfill from enum value
UPDATE companies SET "regionId" = 'reg_hk_seed'   WHERE region = 'HK';
UPDATE companies SET "regionId" = 'reg_mo_seed'   WHERE region = 'MO';
UPDATE companies SET "regionId" = 'reg_cn_seed'   WHERE region = 'CN';
UPDATE companies SET "regionId" = 'reg_other_seed' WHERE region = 'OTHER';
UPDATE companies SET "regionId" = 'reg_hk_seed'   WHERE "regionId" IS NULL;

-- 5. Add FK + index
ALTER TABLE companies ADD CONSTRAINT companies_regionId_fkey
  FOREIGN KEY ("regionId") REFERENCES regions(id) ON DELETE SET NULL;
CREATE INDEX companies_regionId_idx ON companies("regionId");

-- 6. Drop the old enum column + enum type
ALTER TABLE companies DROP COLUMN region;
DROP TYPE IF EXISTS "Region";
```

**Schema 對應改動**(Prisma 入面):

```prisma
// REMOVE: enum Region { HK MO CN OTHER }
model Region {
  id        String   @id @default(cuid())
  code      String   @unique
  name      String
  flag      String?
  isActive  Boolean  @default(true)
  sortOrder Int      @default(0)
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  companies Company[]
  @@map("regions")
}

model Company {
  // REMOVE: region Region @default(HK)
  regionId    String?
  region      Region?  @relation(fields: [regionId], references: [id], onDelete: SetNull)
  customRegion String?
}
```

**然後 create 一個 no-op migration file** record 呢個 drift,否則
docker entrypoint 嘅 `prisma migrate deploy` 會見到 schema 跟 migrations
folder 唔 match 而 fail:

```
migrations/20260606000000_day9_region_table_quotation_item_string/migration.sql
```

檔案入面淨係 `SELECT 1;` + comment 解釋 DDL 已手動 apply(避免下次
新人 run `migrate dev` 撞 conflict)。

**Backend code 改動**:
- `Company` GET endpoint include `region: { select: { id, code, name, flag } }`
- `Company` POST/PATCH 接受 `regionId` (cuid) 或 `region` (code) 任一,
  後端做 `prisma.region.findFirst({ where: { code } })` resolve
- 新 `regionRoutes.ts` 暴露 `GET /regions` (公開) + `POST/PATCH/DELETE` (admin only)

**Frontend code 改動**:
- 加 `regionsApi = { list, get, create, update, remove }`
- 刪 static `REGION_LABELS` / `REGIONS` array
- `Company.region` 改 `Region | null` 而非 `'HK' | 'MO' | 'CN' | 'OTHER'`
- Form 攞 `regionId` state 而非 `region` state
- Filter pills 由 `useQuery(['regions'])` 動態 render,fallback 4 個 seed region

**驗證**:`docker exec crm-postgres psql -c "SELECT c.name, c.\"regionId\", r.code FROM companies c LEFT JOIN regions r ON c.\"regionId\"=r.id;"` 應該見到 6 行,全部 `code=HK`。

## 變體: User-facing Activity (NOTE/CALL/EMAIL/MEETING) + Attachment — Day 9+ crm-system pattern

> **同 ActivityLog 嘅分別**:`ActivityLog` 係 **system audit trail**(every action: login, drag-drop, RBAC change),**冇附件**,只 read-only。**User-facing Activity** 係 **sales 人寫嘅跟進記錄**(call 左邊個、send 咗咩、合約 PDF),**有附件**,係 CRM 嘅 sales pipeline 核心。

### 觸發時機

用戶講:
- 「記錄跟進進度」
- 「Activity log / timeline / 跟進記錄」
- 「上傳附件 / upload files / attach PDF」
- 「Sales pipeline 週會 view」

### 2 個 schema 改動

**1. `Activity` table** (polymorphic, exactly one of companyId/dealId, with attachments):

```prisma
enum ActivityType { NOTE CALL EMAIL MEETING }

model Activity {
  id        String       @id @default(cuid())
  companyId String?
  dealId    String?
  authorId  String
  type      ActivityType @default(NOTE)
  content   String       @db.Text
  createdAt DateTime     @default(now())

  company     Company?     @relation(fields: [companyId], references: [id], onDelete: Cascade)
  deal        Deal?        @relation(fields: [dealId], references: [id], onDelete: Cascade)
  author      User         @relation(fields: [authorId], references: [id])
  attachments Attachment[]

  @@index([companyId, createdAt(sort: Desc)])
  @@index([dealId, createdAt(sort: Desc)])
  @@index([authorId, createdAt(sort: Desc)])   // for sales rep filter
  @@map("activities")
}
```

**2. `Attachment` table** (always belongs to an Activity — orphan rule enforced):

```prisma
model Attachment {
  id           String   @id @default(cuid())
  fileName     String                                 // original filename
  mimeType     String                                 // application/pdf, image/png, ...
  sizeBytes    Int
  storageKey   String   @unique                       // path on disk: data/uploads/YYYY/MM/<cuid>-<safeName>
  activityId   String
  uploadedById String
  createdAt    DateTime @default(now())

  activity     Activity @relation(fields: [activityId], references: [id], onDelete: Cascade)
  uploadedBy   User     @relation(fields: [uploadedById], references: [id])

  @@index([activityId])
  @@map("attachments")
}
```

### 3 個 design decisions

1. **Polymorphic via nullable FK** (`companyId?` / `dealId?`) — **唔好用 STI / JSON discriminator**,Prisma join 仲係 plain FK,query / filter / index 全部行 relational way。**Constraint**:Application code 必須 enforce「exactly one 唔係 null」(DB-level check constraint 之後再加)。
2. **Attachment 永遠 belongs to Activity** — orphan rule `Activity deletion CASCADE 刪 Attachment`。**唔好**直接 `belongs to Company/Deal`,否則「同一份合約在多個 context 出現」嘅 use case 會撞。
3. **`storageKey @unique` + on-disk path**:`/data/uploads/YYYY/MM/<cuid>-<safeName>`(sharded by month 防單一目錄爆)。唔好直接用 user filename(`../../etc/passwd` traversal)。

### 同 ActivityLog 共存(兩個都需要的 scenario)

```prisma
model Company {
  // ...
  activities     ActivityLog[]   // system audit (immutable, no attachments)
  userActivities Activity[]      // sales rep follow-ups (with attachments)
}
```

**Use case 分工**:
- **ActivityLog**:「邊個 user 喺咩時候改咗 deal stage」(system event, audit compliance)
- **Activity**:「sales 週五 call 咗客戶,send 咗新報價 PDF,客戶話要再減 5%」(sales narrative, with attachments)

**前端 UI**:
- **Admin → /audit** → render `ActivityLog`(system events, type icon: ⚙️/👤/📝)
- **Sales → /companies/:id** → render `Activity`(user events, type icon: 📞/✉️/📝/🤝,with attachment download)
- **Sales → /deals (Kanban)** → render `Activity` list(時間倒排,可 filter by author/date)

### 🚨 升級 ActivityLog → Activity 嘅 clean-slate migration (crm-system Day-N 真實案例)

如果而家個 codebase 已經有 `ActivityLog` table(從 crm-data-model default 嚟)但**完全冇 code reference**(冇 routes / frontend page 引用),可以考慮 **DROP + 重建** 唔係 ALTER:

```sql
-- 1. Drop unused ActivityLog (CASCADE 因為 Contact / Deal / Company 都有 FK 指返佢)
DROP TABLE IF EXISTS "activity_logs" CASCADE;
DROP TYPE  IF EXISTS "ActivityType" CASCADE;   -- old enum

-- 2. New enum with only the 4 user-facing types
CREATE TYPE "ActivityType" AS ENUM ('NOTE', 'CALL', 'EMAIL', 'MEETING');

-- 3. New activity table (with explicit `authorId` NOT NULL — old table 冇)
CREATE TABLE "activities" (
  "id"        TEXT PRIMARY KEY,
  "companyId" TEXT,
  "dealId"    TEXT,
  "authorId"  TEXT NOT NULL,
  "assignedToId" TEXT,
  "type"      "ActivityType" NOT NULL DEFAULT 'NOTE',
  "content"   TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  ...
);
```

**點解 clean-slate 唔係 ALTER**:
- `ActivityLog` 個 `type` enum 有 9 個 system 值(`TASK`, `QUOTATION_SENT`, `DEAL_STAGE_CHANGED` etc.)— David 揀 new Activity 唔需要呢啲 system events
- 個 `body` 同 `subject` 兩個 free-form field 變 `content` 單 field 較 clean
- 加 `authorId` NOT NULL(舊 table 冇呢個 column)
- 冇 existing data 要 preserve(冇 code reference 過 ActivityLog)
- 避免舊 schema constraints 污染新 table

**Detection 點 clean-slate 啱**: `grep -r 'activityLog' apps/` / `grep -r 'ActivityLog' apps/` 返 0 個 reference,然後先決定 clean-slate。**如果有 reference**,用 ALTER 唔好 DROP。

### Attachment storage options

| Option | Trade-off |
|---|---|
| **Local disk + Docker volume** (Day 9+ 揀) | 簡單, demo 完美, **唔 survive `docker-compose down -v`**(volume 唔 remove 嘅話仲喺度) |
| AWS S3 (ap-east-1) | $0.09/GB egress, 已喺 David AWS account |
| Cloudflare R2 | $0 egress, S3-compatible, 較 S3 平 |
| Postgres BLOB | 影響 query, 唔建議 production |

**Demo / SMB → Local disk + named volume**:
```yaml
# docker-compose.yml
services:
  crm-api:
    volumes:
      - crm_uploads:/app/data/uploads
volumes:
  crm_uploads:
```
```dockerfile
# Dockerfile.api
RUN mkdir -p /app/data/uploads
```

**完整 multipart upload pattern 見 `backend/elysia-file-upload-multer` skill** — crm-system 揀咗 hand-rolled parser 唔揀 multer 因為 Elysia 1.2 對 multer 嘅 integration 唔順。

### Backend routes(Elysia example)

```typescript
// POST /activities
.post('/activities', async ({ body, user, set }) => {
  const data = body as { companyId?: string; dealId?: string; type: ActivityType; content: string };
  if (!data.companyId && !data.dealId) {
    set.status = 400;
    return { error: 'EITHER_COMPANY_OR_DEAL_REQUIRED' };
  }
  const activity = await prisma.activity.create({
    data: {
      companyId: data.companyId ?? null,
      dealId:    data.dealId ?? null,
      authorId:  user.id,
      type:      data.type,
      content:   data.content,
    },
    include: { author: { select: { id: true, name: true } }, attachments: true },
  });
  await logEvent({ userId: user.id, action: 'ACTIVITY_CREATED', entityType: 'Activity', entityId: activity.id });
  return activity;
})

// GET /activities?companyId=X | ?dealId=Y
.get('/activities', async ({ query }) => {
  return prisma.activity.findMany({
    where: { OR: [{ companyId: query.companyId }, { dealId: query.dealId }] },
    orderBy: { createdAt: 'desc' },
    include: { author: { select: { id: true, name: true } }, attachments: true },
  });
})

// GET /activities/recent?limit=10 — for Dashboard
.get('/activities/recent', async ({ query }) => {
  const limit = Math.min(Number(query.limit ?? 10), 100);
  return prisma.activity.findMany({
    take: limit,
    orderBy: { createdAt: 'desc' },
    include: {
      author: { select: { id: true, name: true } },
      attachments: { select: { id: true, fileName: true, sizeBytes: true } },
      company: { select: { id: true, name: true } },
      deal:    { select: { id: true, title: true } },
    },
  });
})
```

### Nginx body size limit(50MB match frontend)

```nginx
location /api/ {
  client_max_body_size 50M;     # match frontend validation
  proxy_pass http://crm-api:3000;
}
```

### Frontend component reuse

- `<ActivityFeed mode="company" | "deal" | "cross">` — same component 3 處用(Company detail tab, Deal detail panel, Dashboard latest 10)
- `<ActivityDialog>` — form(textarea + type select + file dropzone)
- `<AttachmentList>` — render `activity.attachments` with `<a href="/api/attachments/:id/download" target="_blank" download>`

### Cross-tab download warning 嘅解法

Plain `<a target="_blank">` + `Content-Disposition: attachment` 喺 Chrome 仍然會出「leave site?」warning 因為 backend response 唔肯定係 user intent。

**Best UX**:
```typescript
async function downloadAttachment(id: string, fileName: string) {
  const res = await fetch(`/api/attachments/${id}/download`, { credentials: 'include' });
  const blob = await res.blob();
  const url  = URL.createObjectURL(blob);
  const a    = document.createElement('a');
  a.href     = url;
  a.download = fileName;       // ← forces download dialog, NO leave-site warning
  a.click();
  URL.revokeObjectURL(url);
}
```

### Pitfalls

1. **Path traversal**:`file.originalname` 直接落 disk → `../../etc/passwd`。**必須** `path.basename()` + sanitize + 用 random uuid 撞 storage key。
2. **Local disk 唔 survive container recreate**:`docker-compose down -v` 會 wipe named volume。Backup 策略:Daily `tar` named volume 到 S3 / R2。
3. **Polymorphic invariant**:DB-level `CHECK (("companyId" IS NOT NULL) <> ("dealId" IS NOT NULL))` 加埋,否則 application bug 可以 insert row 兩個 FK 都 null 兩個都 set,前端會 crash。
4. **50MB file + nginx**:`client_max_body_size 50M` 同時 frontend validation 50MB,否則 user 見到 frontend 通但 server 收 413。
5. **Activity deletion CASCADE 刪 attachment** = **冇 recovery**。如果 audit 需要保留,改 `onDelete: SetNull` + 加 `isOrphaned Boolean` flag。
6. **Authored activities 冇 `authorId` 是 dead design** — 將來做「sales rep X 嘅跟進」「老闆 問下邊個冇 update deal」會撞牆。一開始就 `authorId String NOT NULL`。

David 嘅 2026-06-06 設計 trade-off 揀咗:
- Storage:**本地 disk + named volume**(demo 階段,demo 結束後再評估 S3)
- File size:**50MB**(寬鬆,Demo 用)
- Activity type:**全部 4 個**(`NOTE` / `CALL` / `EMAIL` / `MEETING`)
- List render:**Plain 列表**,**時間倒排預設**,`Sales 篩選` + `日期 range filter` 跟手加
- Download auth:**登入即可**(JWT cookie),frontend 用 `fetch` + blob + `download` attribute 避 cross-tab warning

### 🚨 Admin-only endpoint 用 `userRole === 'ADMIN'` 而唔係 `requirePermission` (crm-system Day-N 真實撞牆)

`backend-rbac-audit-log` skill 推薦用 `requirePermission('admin:foo:manage')` 做 admin-only check。**但係** 如果個 seed 唔寫 `RolePermission` row(而家 crm-system 嘅 seed.ts 冇 sync permission table),permission 名喺 DB 唔存在,`requirePermission` middleware 會 403 **所有** user 包括 admin。

**Symptom**: 建立 `routes/man-day-role.ts`,用 `.use(requirePermission('admin:man_day_role:manage'))` → 任何 user(包括 admin)call 個 endpoint 收 403 `Forbidden: missing permission 'admin:man_day_role:manage'`。`userHasPermission()` 用 `prisma.rolePermission.findMany({ where: { roleId, permission } })`,**冇 row 即係 0 個 permission**。

**Quick fix (admin-only endpoints that DON'T need per-role fine-grained control)**:

```typescript
.post('/', async ({ body, set, userId, userRole, request }) => {
  // Hardcoded role check — bypass the RolePermission table.
  // Acceptable when v1 has 3 hardcoded roles (ADMIN/SALES/VIEWER)
  // and admin pages are a closed set.
  if (userRole !== 'ADMIN') { set.status = 403; return { error: 'Admin only' }; }
  // ... admin-only mutation ...
})
```

**點解 work**:`authContext` derive 將 `userRole` 加落 handler context(由 JWT 嘅 `role` claim 解出)。直接 string compare `userRole === 'ADMIN'` 唔經 DB,亦唔受 seed 唔寫 RolePermission 影響。

**Trade-off**:
- ✅ Work 即刻,唔需要 migrate seed
- ✅ 將來 implement 真正 per-role custom permission 都唔需要改 endpoint signature
- ❌ 唔可以 "marketing manager 都可以改 man-day role 唔止 admin" 除非 rewrite 個 check
- ❌ Bypasses `requirePermission` 嘅 5-min cache + admin-edit 嘅 cache invalidation pattern

**Long-term fix** (apply when seed script mature):
```typescript
// packages/db/prisma/seed.ts
for (const role of await prisma.role.findMany()) {
  for (const perm of ROLE_PERMISSIONS[role.name as UserRole]) {
    await prisma.rolePermission.upsert({
      where: { roleId_permission: { roleId: role.id, permission: perm } },
      update: {},
      create: { roleId: role.id, permission: perm },
    });
  }
}
```

**Detection 點用 hardcoded check 啱**:
- v1 已有 3 個 hardcoded role(ADMIN/SALES/VIEWER),admin endpoints 數量 < 5
- Seed 仲未 migrate 到 RolePermission-driven
- 唔需要 "marketing manager 都可以 X" 嘅粒度

**Detection 點用 `requirePermission` 啱**:
- 已經有 per-role custom permission UI(`/roles` page)
- Seed 已經 sync permission table
- 需要「manager 可以 read 但唔可以 write」呢類粒度

### 🚨 Dashboard / summary endpoint 唔好用 `limit: 5` 攞 preview 嚟計 total(Day 9 撞過)

`DashboardPage` 個 pattern `useQuery(['deals', { limit: 5 }])` 然後
`deals.filter(d => d.status === 'OPEN').length` 看似「最近 5 個」preview,
但 David 期望個數字係「全部 OPEN 嘅 deal count」。一旦 DB 過咗 5 個 deal,
個 count 永遠停喺 5(或者更少,視乎 LIMIT 截咗邊個 stage)。

**Antipattern**:

```tsx
// ❌ fetch preview, summarize
const { data: deals = [] } = useQuery({
  queryKey: ['deals', { limit: 5 }],
  queryFn: () => dealsApi.list({ limit: 5 }),
});
const openDeals = deals.filter((d) => d.status === 'OPEN');
const pipelineValue = openDeals.reduce((s, d) => s + d.value, 0);
const winRate = deals.length > 0
  ? Math.round(deals.filter(d => d.status === 'WON').length / deals.length * 100) + '%'
  : '—';
```

**Better**:分開兩條 query,或加 stats endpoint:

```tsx
// Option A: fetch all (with reasonable ceiling) for stats, separately fetch top 5 for display
const STATS_LIMIT = 1000;
const { data: deals = [] } = useQuery({
  queryKey: ['deals', { limit: STATS_LIMIT }],
  queryFn: () => dealsApi.list({ limit: STATS_LIMIT }),
});
// display uses deals.slice(0, 5) for "Recent Deals" card
```

**Option B (preferred for scale)**: 加 backend `/deals/stats` endpoint 返
`{ openCount, wonCount, totalValue, weightedValue, winRate }`,frontend
一個 query 攞晒。

**Triggers** (即係 code review 應該 catch 呢個 antipattern):
- `useQuery` 配 `limit: <small number>` + 之後攞嚟 count / sum / filter
- Variable 名叫 `recentXxx` 但用嚟做 KPI card 個 number
- `deals.length` / `companies.length` 攞嚟做 % 計算的 base

**Bonus pitfall (同時撞)**:`d.value` 經 Prisma `Decimal` 之後係 string
(詳見上面 pitfall),所以 `d.value` 唔加 `Number()` 嘅話 reduce 會 string concat
變「HK$10,050,010,010,054,500」嘅 trillion bug。
