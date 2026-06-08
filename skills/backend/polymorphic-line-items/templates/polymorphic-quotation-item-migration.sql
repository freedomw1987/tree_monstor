-- Polymorphic QuotationItem migration (Option A: separate Product/Service tables + dual FK)
-- Apply: docker exec -i crm-postgres psql -U crm -d crm_system -f /dev/stdin < polymorphic-quotation-item-migration.sql
-- Mark: insert into _prisma_migrations (see role-rbac-migration.sql comment for pattern)

-- 1. Service catalogue (new)
CREATE TABLE IF NOT EXISTS "services" (
  "id" TEXT PRIMARY KEY,
  "name" TEXT NOT NULL,
  "description" TEXT,
  "unitPrice" DECIMAL(12,2) NOT NULL,
  "currency" TEXT NOT NULL DEFAULT 'HKD',
  "isActive" BOOLEAN NOT NULL DEFAULT true,
  "sortOrder" INTEGER NOT NULL DEFAULT 0,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS "services_isActive_idx" ON "services"("isActive");

-- 2. Service man-day breakdown (nested)
CREATE TABLE IF NOT EXISTS "service_man_days" (
  "id" TEXT PRIMARY KEY,
  "serviceId" TEXT NOT NULL REFERENCES "services"("id") ON DELETE CASCADE,
  "role" TEXT NOT NULL,
  "dayRate" DECIMAL(12,2) NOT NULL,
  "days" INTEGER NOT NULL,
  "subtotal" DECIMAL(12,2) NOT NULL,
  "sortOrder" INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS "service_man_days_serviceId_idx" ON "service_man_days"("serviceId");

-- 3. ItemType enum + column on quotation_items
DO $$ BEGIN
  CREATE TYPE "ItemType" AS ENUM ('PRODUCT', 'SERVICE');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

ALTER TABLE "quotation_items"
  ADD COLUMN IF NOT EXISTS "itemType" "ItemType" NOT NULL DEFAULT 'PRODUCT';

-- 4. serviceId FK
ALTER TABLE "quotation_items"
  ADD COLUMN IF NOT EXISTS "serviceId" TEXT REFERENCES "services"("id") ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS "quotation_items_serviceId_idx" ON "quotation_items"("serviceId");

-- 5. manDaySnapshot JSONB
ALTER TABLE "quotation_items"
  ADD COLUMN IF NOT EXISTS "manDaySnapshot" JSONB;

-- 6. Index on itemType for fast type-filtered queries
CREATE INDEX IF NOT EXISTS "quotation_items_itemType_idx" ON "quotation_items"("itemType");

-- 7. Drop the backfill default so future writes must set it explicitly
ALTER TABLE "quotation_items" ALTER COLUMN "itemType" DROP DEFAULT;
