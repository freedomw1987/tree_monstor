// related-entity-entry-points-pattern.tsx
// 4 個 entry-point patterns (從 crm-system Day 10 extract)
//
// Pattern 1 — Detail page 嘅 child section 永遠 render
// Pattern 2 — Child list page 接收 ?parentId=, auto-open create dialog
// Pattern 3 — Card-level action button
// Pattern 4 — Grandchild page 接收 multi-preset, auto-open builder
// Pattern 5 — Sidebar ↔ FAB positioning
//
// 全套 skill 喺 <profile-root>/skills/frontend/related-entity-entry-points/

import { useEffect, useState } from 'react';
import { Link, useLocation, useNavigate, useSearchParams } from 'react-router-dom';
import {
  Building2, FileText, KanbanSquare, LogOut, LayoutDashboard,
  Menu, X, Users, History, Briefcase, Shield, Package, Sparkles, Plus,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { cn } from '@/lib/utils';

// ============================================================
// Pattern 1 — Detail page 嘅 child section 永遠 render
// ============================================================

export function CompanyDetailPageExample({ id, deals, quotations, contacts }: {
  id: string;
  deals: Deal[];
  quotations: Quotation[];
  contacts: Contact[];
}) {
  return (
    <div className="space-y-6">
      {/* Company info section ... */}

      {/* Deals — always render so "+ 新增 Deal" 永遠有 affordance */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-3">
          <CardTitle>Deals ({deals.length})</CardTitle>
          <Button asChild size="sm" variant="outline">
            <Link to={`/deals?companyId=${id}`}>
              <Plus className="h-3.5 w-3.5 mr-1" /> 新增 Deal
            </Link>
          </Button>
        </CardHeader>
        <CardContent className="p-0">
          {deals.length === 0 ? (
            <p className="text-sm text-muted-foreground text-center py-8">
              暫未有 deal · 撳右上「新增 Deal」開第一個
            </p>
          ) : (
            <ul className="divide-y">
              {deals.map((d) => (
                <li key={d.id}>
                  <Link to={`/deals/${d.id}`} className="flex items-center justify-between p-4 hover:bg-muted/50">
                    <div className="font-medium">{d.title}</div>
                    <div className="font-semibold tabular-nums">${d.value.toLocaleString()}</div>
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </CardContent>
      </Card>

      {/* Quotations — same pattern */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-3">
          <CardTitle>Quotations ({quotations.length})</CardTitle>
          <Button asChild size="sm" variant="outline">
            <Link to={`/quotations?companyId=${id}`}>
              <Plus className="h-3.5 w-3.5 mr-1" /> 新增 Quotation
            </Link>
          </Button>
        </CardHeader>
        <CardContent className="p-0">
          {quotations.length === 0 ? (
            <p className="text-sm text-muted-foreground p-6 text-center">
              仲未有報價單 · 撳右上「新增 Quotation」開第一份
            </p>
          ) : (
            <ul className="divide-y">{quotations.map((q) => <li key={q.id}>...</li>)}</ul>
          )}
        </CardContent>
      </Card>
    </div>
  );
}

// ============================================================
// Pattern 2 — Child list page 接收 ?parentId=, auto-open dialog
// ============================================================

export function DealsPageExample() {
  const [createOpen, setCreateOpen] = useState(false);
  const [editing, setEditing] = useState<Deal | null>(null);
  const [searchParams, setSearchParams] = useSearchParams();
  const presetCompanyId = searchParams.get('companyId') ?? undefined;
  const { data: companies = [] } = useCompaniesQuery();

  useEffect(() => {
    if (presetCompanyId) setCreateOpen(true);
  }, [presetCompanyId]);

  function closeCreate() {
    setCreateOpen(false);
    if (presetCompanyId) {
      const next = new URLSearchParams(searchParams);
      next.delete('companyId');
      setSearchParams(next, { replace: true });  // 重要: replace, 唔係 push
    }
  }

  return (
    <>
      <Button onClick={() => setCreateOpen(true)}>
        <Plus className="h-4 w-4 mr-1" /> 新增 Deal
      </Button>

      <DealDialog
        open={createOpen}
        onOpenChange={(v) => (v ? setCreateOpen(true) : closeCreate())}
        companies={companies}
        defaultCompanyId={presetCompanyId ?? companies[0]?.id}  // preset 優先
        onSaved={() => qc.invalidateQueries({ queryKey: ['deals-kanban'] })}
      />
    </>
  );
}

// ============================================================
// Pattern 3 — Card-level action button (Kanban)
// ============================================================

export function DealCardExample({ deal, onEdit }: { deal: Deal; onEdit: (d: Deal) => void }) {
  const navigate = useNavigate();
  const [dragging, setDragging] = useState(false);
  const quoteCount = deal._count?.quotations ?? 0;
  return (
    <div
      draggable
      onDragStart={() => setDragging(true)}
      onDragEnd={() => setDragging(false)}
      onClick={() => { if (!dragging) onEdit(deal); }}
      className="p-2.5 rounded border bg-card hover:border-primary transition-all cursor-grab group"
    >
      <div className="flex items-start gap-1.5">
        <GripVertical className="h-3.5 w-3.5 text-muted-foreground/50 mt-0.5" />
        <div className="flex-1">
          <div className="font-medium text-sm">{deal.title}</div>
          <div className="text-xs text-muted-foreground">{deal.company?.name}</div>

          {/* Action button: 永遠 show, count=0 時做 CTA */}
          <button
            type="button"
            onClick={(e) => {
              e.stopPropagation();  // ⭐ 避免 bubble 觸發 card 嘅 onClick
              navigate(`/quotations?dealId=${deal.id}`);
            }}
            className={cn(
              'mt-1.5 inline-flex items-center gap-1 text-[10px] px-1.5 py-0.5 rounded',
              'hover:bg-primary/10 transition-colors',
              quoteCount > 0 ? 'text-muted-foreground' : 'text-primary font-medium'
            )}
            title={quoteCount > 0 ? `已有 ${quoteCount} 份報價,撳再加一份` : '為此 deal 建立報價'}
          >
            <FileText className="h-3 w-3" />
            {quoteCount > 0 ? `${quoteCount} 份報價 · ＋` : '＋ 報價'}
          </button>
        </div>
      </div>
    </div>
  );
}

// ============================================================
// Pattern 4 — Grandchild page 接收 multi-preset, auto-open builder
// (Day 10 後改進: 同時支持 dealId + companyId 兩個 preset)
// ============================================================

interface QuotationBuilderProps {
  existing?: Quotation;
  initialDealId?: string;        // Day 7 加
  initialCompanyId?: string;     // Day 10 加 (公司 detail → 新增 quotation shortcut)
  onSaved: (q: Quotation) => void;
  onCancel: () => void;
}

export function QuotationBuilderExample({
  existing, initialDealId, initialCompanyId, onSaved, onCancel,
}: QuotationBuilderProps) {
  // preset 優先 fallback 既有 value
  const [companyId, setCompanyId] = useState<string>(initialCompanyId ?? existing?.companyId ?? '');
  const [dealId, setDealId] = useState<string>(initialDealId ?? '');
  // ...
}

export function QuotationsPageExample() {
  const [searchParams, setSearchParams] = useSearchParams();
  // 同一 page 可能從 deal 入(preset dealId)或者從 company 入(preset companyId)
  const presetDealId = searchParams.get('dealId') ?? undefined;
  const presetCompanyId = searchParams.get('companyId') ?? undefined;
  const [builderOpen, setBuilderOpen] = useState(false);

  useEffect(() => {
    if (presetDealId || presetCompanyId) setBuilderOpen(true);
  }, [presetDealId, presetCompanyId]);

  function closeBuilder() {
    setBuilderOpen(false);
    if (presetDealId || presetCompanyId) {
      const next = new URLSearchParams(searchParams);
      next.delete('dealId');
      next.delete('companyId');
      setSearchParams(next, { replace: true });
    }
  }

  return (
    <Dialog open={builderOpen} onOpenChange={(v) => (v ? setBuilderOpen(true) : closeBuilder())}>
      <DialogContent>
        <QuotationBuilder
          initialDealId={presetDealId}
          initialCompanyId={presetCompanyId}
          onSaved={...}
          onCancel={closeBuilder}
        />
      </DialogContent>
    </Dialog>
  );
}

// ============================================================
// Pattern 5 — Sidebar ↔ FAB positioning
// ============================================================

const navItems = [
  // 按 sales funnel 排,唔按 module 排
  { to: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { to: '/companies', label: 'Companies', icon: Building2 },
  { to: '/deals', label: 'Deals', icon: KanbanSquare },
  { to: '/quotations', label: 'Quotation', icon: FileText },
  { to: '/products', label: 'Product', icon: Package },
  { to: '/services', label: 'Service', icon: Briefcase },
  // AI Assistant 唔再喺 nav, 改去 FAB
];

export function AppLayoutExample() {
  return (
    <div className="min-h-screen flex">
      <aside>{/* sidebar with navItems */}</aside>
      <div className="flex-1 flex flex-col">
        <main><Outlet /></main>
      </div>

      {/* FAB 必須 render 喺 <main> 之外, fixed position 唔會被 clip */}
      <AiFabExample />
    </div>
  );
}

export function AiFabExample() {
  const navigate = useNavigate();
  const location = useLocation();
  const [showLabel, setShowLabel] = useState(false);

  if (location.pathname === '/ai') return null;  // 唔好 cover 自己

  return (
    <button
      type="button"
      onClick={() => navigate('/ai')}
      onMouseEnter={() => setShowLabel(true)}
      onMouseLeave={() => setShowLabel(false)}
      aria-label="開 AI Assistant"
      className={cn(
        'group fixed bottom-6 right-6 z-50',
        'h-14 w-14 rounded-full',                          // 56px Material spec
        'bg-primary text-primary-foreground shadow-lg',
        'flex items-center justify-center',
        'transition-all hover:scale-105 active:scale-95',
        'focus:outline-none focus:ring-4 focus:ring-primary/30'
      )}
    >
      <span className="absolute inset-0 rounded-full bg-primary/40 animate-ping opacity-30" />
      <Sparkles className="relative h-6 w-6" />
      <span
        className={cn(
          'absolute right-full mr-3 whitespace-nowrap',
          'bg-foreground text-background text-xs font-medium px-2.5 py-1.5 rounded-md shadow-md',
          'transition-opacity',
          showLabel ? 'opacity-100' : 'opacity-0 pointer-events-none'
        )}
        aria-hidden="true"
      >
        AI Assistant
      </span>
    </button>
  );
}

// ============================================================
// Type stubs (for completeness — would come from your lib/api.ts)
// ============================================================

type Deal = { id: string; title: string; value: number; company?: { name: string }; stage?: { id: string; name: string; color: string }; _count?: { quotations: number } };
type Quotation = { id: string; number: string; status: string; total: number; companyId: string; createdAt: string };
type Contact = { id: string; firstName: string; lastName: string };
function useCompaniesQuery() { return { data: [] as { id: string; name: string }[] }; }
