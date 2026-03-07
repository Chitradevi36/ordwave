"use client";

import { useState, useEffect } from "react";
import { useParams, useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Tag, Package, CalendarDays, Zap, ArrowLeft, ShieldCheck,
  Gift, Layers, Info, BarChart2, Hash, CheckCircle2,
  XCircle, AlertTriangle, TrendingUp, Clock,
} from "lucide-react";
import { API_URL } from "@/lib/api/client";

// ─── Types ────────────────────────────────────────────────────────────────────

interface ProductRef { id: number; name: string | null; sku: string | null }

interface SchemeCondition {
  id: number;
  condition_type: string;
  operator: string;
  value: Record<string, unknown>;
  products?: ProductRef[];               // enriched by backend for product_inclusion/exclusion
}

interface SchemeReward {
  id: number;
  reward_type: string;
  target_scope: string;
  target_product_id: number | null;
  target_product: ProductRef | null;     // enriched by backend
  reward_value: number;
  max_reward_value: number | null;
  free_per_x: number | null;
  free_qty_per_trigger: number | null;
}

interface SchemeDetail {
  id: number;
  code: string;
  name: string;
  scheme_type: string;
  status: string;
  applies_to: string;
  start_date: string | null;
  end_date: string | null;
  priority: number;
  exclusive: boolean;
  applicable_days: number[];
  branch_id: number | null;
  notes: string | null;
  conditions_count: number;
  rewards_count: number;
  reward_summary: string | null;
  products_preview: ProductRef[];
  created_at: string;
  conditions: SchemeCondition[];
  rewards: SchemeReward[];
}

// ─── Constants ────────────────────────────────────────────────────────────────

const DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

const TYPE_LABELS: Record<string, string> = {
  buy_x_get_y:           "Buy X Get Y",
  slab_discount:         "Slab Discount",
  item_discount:         "Item Discount",
  order_value_discount:  "Order Value Discount",
};

const TYPE_COLORS: Record<string, string> = {
  buy_x_get_y:           "bg-violet-100 text-violet-700 border-violet-200",
  slab_discount:         "bg-blue-100 text-blue-700 border-blue-200",
  item_discount:         "bg-teal-100 text-teal-700 border-teal-200",
  order_value_discount:  "bg-orange-100 text-orange-700 border-orange-200",
};

const STATUS_VARIANT: Record<string, "default" | "secondary" | "success" | "outline" | "danger"> = {
  active:   "success",
  inactive: "secondary",
  expired:  "danger",
};

const CONDITION_LABELS: Record<string, string> = {
  min_order_value:    "Minimum Order Value",
  min_total_qty:      "Minimum Total Qty",
  product_inclusion:  "Products Required",
  product_exclusion:  "Products Excluded",
  category_inclusion: "Categories Required",
  retailer_inclusion: "Specific Retailers",
  retailer_exclusion: "Retailers Excluded",
};

const REWARD_LABELS: Record<string, string> = {
  percent_off:  "% Discount",
  amount_off:   "Flat Amount Off",
  free_qty:     "Free Products",
  fixed_price:  "Fixed Price",
};

// ─── Helpers ─────────────────────────────────────────────────────────────────

function fmtDate(d: string | null) {
  if (!d) return null;
  return new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
}

function fmtINR(n: number) {
  return `₹${n.toLocaleString("en-IN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

// ─── Condition renderer ───────────────────────────────────────────────────────

function ConditionCard({ cond }: { cond: SchemeCondition }) {
  const label = CONDITION_LABELS[cond.condition_type] ?? cond.condition_type;
  const isProductCond = cond.condition_type === "product_inclusion" || cond.condition_type === "product_exclusion";
  const isExclusion = cond.condition_type === "product_exclusion" || cond.condition_type === "retailer_exclusion";

  return (
    <div className={`rounded-lg border px-4 py-3 ${isExclusion ? "border-danger/20 bg-danger/5" : "border-border bg-muted/30"}`}>
      <div className="flex items-center gap-2 mb-2">
        {isExclusion
          ? <XCircle className="h-4 w-4 text-danger shrink-0" />
          : <CheckCircle2 className="h-4 w-4 text-success shrink-0" />
        }
        <span className="text-sm font-medium text-text-primary">{label}</span>
        {cond.operator && cond.operator !== ">=" && (
          <span className="ml-auto text-[10px] font-mono bg-muted border border-border rounded px-1.5 py-0.5 text-text-secondary">
            {cond.operator}
          </span>
        )}
      </div>

      {/* Value display */}
      {cond.condition_type === "min_order_value" && (
        <p className="text-sm text-text-primary font-semibold">
          {fmtINR(Number(cond.value.amount ?? 0))}
        </p>
      )}

      {cond.condition_type === "min_total_qty" && (
        <p className="text-sm text-text-primary font-semibold">
          {cond.value.qty as number} units
        </p>
      )}

      {isProductCond && (
        <div>
          {cond.products && cond.products.length > 0 ? (
            <div className="flex flex-wrap gap-1.5 mt-1">
              {cond.products.map(p => (
                <ProductChip key={p.id} product={p} highlight={!isExclusion} />
              ))}
            </div>
          ) : (
            <p className="text-xs text-text-secondary italic">
              {(cond.value.product_ids as number[])?.length ?? 0} product(s) — names not available
            </p>
          )}
        </div>
      )}

      {cond.condition_type === "category_inclusion" && (
        <div className="flex flex-wrap gap-1.5 mt-1">
          {(cond.value.category_ids as number[])?.map(id => (
            <span key={id} className="text-xs bg-muted border border-border rounded px-2 py-0.5 text-text-secondary">
              Category #{id}
            </span>
          ))}
        </div>
      )}

      {(cond.condition_type === "retailer_inclusion" || cond.condition_type === "retailer_exclusion") && (
        <p className="text-xs text-text-secondary">
          {(cond.value.customer_ids as number[])?.length ?? 0} retailer(s) specified
        </p>
      )}
    </div>
  );
}

function ProductChip({ product, highlight }: { product: ProductRef; highlight: boolean }) {
  return (
    <span className={`inline-flex items-center gap-1 text-xs font-medium rounded-md border px-2 py-1
      ${highlight
        ? "bg-primary/5 border-primary/20 text-primary"
        : "bg-danger/5 border-danger/20 text-danger"
      }`}
    >
      <Package className="h-3 w-3 shrink-0" />
      <span className="font-mono">{product.sku ?? `#${product.id}`}</span>
      {product.name && (
        <span className="text-[10px] text-current/70 font-normal max-w-[160px] truncate">
          {product.name}
        </span>
      )}
    </span>
  );
}

// ─── Reward renderer ──────────────────────────────────────────────────────────

function RewardCard({ reward }: { reward: SchemeReward }) {
  const label = REWARD_LABELS[reward.reward_type] ?? reward.reward_type;

  return (
    <div className="rounded-lg border border-primary/15 bg-primary/[0.03] px-4 py-3 space-y-2">
      <div className="flex items-center gap-2">
        <Gift className="h-4 w-4 text-primary shrink-0" />
        <span className="text-sm font-semibold text-primary">{label}</span>
        <span className="ml-auto text-[10px] text-text-secondary bg-muted border border-border rounded px-1.5 py-0.5">
          scope: {reward.target_scope}
        </span>
      </div>

      {reward.reward_type === "percent_off" && (
        <div className="flex items-baseline gap-2">
          <span className="text-2xl font-bold text-primary">{reward.reward_value}%</span>
          <span className="text-sm text-text-secondary">off</span>
          {reward.max_reward_value && (
            <span className="text-xs text-text-secondary ml-2">
              (max {fmtINR(Number(reward.max_reward_value))})
            </span>
          )}
        </div>
      )}

      {reward.reward_type === "amount_off" && (
        <div className="flex items-baseline gap-2">
          <span className="text-2xl font-bold text-primary">{fmtINR(Number(reward.reward_value))}</span>
          <span className="text-sm text-text-secondary">off</span>
        </div>
      )}

      {reward.reward_type === "free_qty" && (
        <div className="space-y-1.5">
          <div className="flex items-center gap-3 text-sm">
            <span className="text-text-secondary">Buy</span>
            <span className="font-bold text-primary text-lg">{reward.free_per_x}</span>
            <span className="text-text-secondary">→ Get</span>
            <span className="font-bold text-success text-lg">{reward.free_qty_per_trigger} free</span>
          </div>
          {reward.target_product && (
            <div className="mt-1">
              <span className="text-xs text-text-secondary mr-1">Free product:</span>
              <ProductChip product={reward.target_product} highlight />
            </div>
          )}
        </div>
      )}

      {reward.reward_type === "fixed_price" && (
        <div className="space-y-1">
          <div className="flex items-baseline gap-2">
            <span className="text-2xl font-bold text-primary">{fmtINR(Number(reward.reward_value))}</span>
            <span className="text-sm text-text-secondary">fixed price</span>
          </div>
          {reward.target_product && (
            <div className="mt-1">
              <span className="text-xs text-text-secondary mr-1">For product:</span>
              <ProductChip product={reward.target_product} highlight />
            </div>
          )}
        </div>
      )}
    </div>
  );
}

// ─── Main Page ────────────────────────────────────────────────────────────────

export default function SchemeDetailPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const [scheme, setScheme] = useState<SchemeDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const token = typeof window !== "undefined" ? localStorage.getItem("auth_token") : "";
  const orgId = typeof window !== "undefined" ? localStorage.getItem("organization_id") : "";
  const headers = { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId ?? "" };

  useEffect(() => {
    if (!id) return;
    setLoading(true);
    fetch(`${API_URL}/api/v1/schemes/${id}`, { headers })
      .then(r => r.json())
      .then(j => {
        if (j.data) setScheme(j.data);
        else setError(j.errors?.[0] ?? "Scheme not found");
      })
      .catch(() => setError("Failed to load scheme"))
      .finally(() => setLoading(false));
  }, [id]);

  if (loading) {
    return (
      <AppShell>
        <div className="space-y-4 animate-pulse">
          <div className="h-10 bg-muted/50 rounded-lg w-2/3" />
          <div className="h-40 bg-muted/50 rounded-xl" />
          <div className="grid gap-4 md:grid-cols-2">
            <div className="h-32 bg-muted/50 rounded-xl" />
            <div className="h-32 bg-muted/50 rounded-xl" />
          </div>
        </div>
      </AppShell>
    );
  }

  if (error || !scheme) {
    return (
      <AppShell>
        <div className="flex flex-col items-center justify-center py-20 gap-4 text-center">
          <AlertTriangle className="h-10 w-10 text-danger/60" />
          <p className="text-text-secondary">{error ?? "Scheme not found"}</p>
          <Button variant="outline" onClick={() => router.push("/schemes")}>Back to Schemes</Button>
        </div>
      </AppShell>
    );
  }

  const startFmt = fmtDate(scheme.start_date);
  const endFmt   = fmtDate(scheme.end_date);

  return (
    <AppShell
      breadcrumbs={[
        { label: "Schemes", href: "/schemes" },
        { label: scheme.name },
      ]}
    >
      <PageHeader
        title={scheme.name}
        description={`${scheme.code} · ${TYPE_LABELS[scheme.scheme_type] ?? scheme.scheme_type}`}
        actions={[{
          label: "Back to Schemes",
          onClick: () => router.push("/schemes"),
          variant: "outline",
          icon: ArrowLeft,
        }]}
      />

      {/* ── Header summary card ───────────────────────────────────────────── */}
      <Card className="mb-5">
        <CardContent className="p-5">
          <div className="flex flex-wrap gap-3 items-center mb-4">
            <Badge variant={STATUS_VARIANT[scheme.status] ?? "secondary"}>
              {scheme.status}
            </Badge>
            <span className={`inline-flex items-center rounded-md border px-2 py-0.5 text-xs font-medium ${TYPE_COLORS[scheme.scheme_type] ?? "bg-muted text-text-secondary border-border"}`}>
              {TYPE_LABELS[scheme.scheme_type] ?? scheme.scheme_type}
            </span>
            {scheme.exclusive && (
              <span className="inline-flex items-center gap-1 text-xs font-medium text-violet-600 bg-violet-50 border border-violet-200 rounded-md px-2 py-0.5">
                <Zap className="h-3 w-3" />Exclusive
              </span>
            )}
            <span className="ml-auto flex items-center gap-1 text-xs text-text-secondary">
              <Hash className="h-3 w-3" />Priority {scheme.priority}
            </span>
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 text-sm">
            <div>
              <p className="text-[10px] uppercase tracking-wide text-text-secondary mb-0.5">Start Date</p>
              <div className="flex items-center gap-1">
                <CalendarDays className="h-3.5 w-3.5 text-text-secondary" />
                <span className="font-medium">{startFmt ?? <span className="text-text-secondary italic">—</span>}</span>
              </div>
            </div>
            <div>
              <p className="text-[10px] uppercase tracking-wide text-text-secondary mb-0.5">End Date</p>
              <div className="flex items-center gap-1">
                {scheme.end_date
                  ? <>
                      <Clock className="h-3.5 w-3.5 text-text-secondary" />
                      <span className="font-medium">{endFmt}</span>
                    </>
                  : <>
                      <TrendingUp className="h-3.5 w-3.5 text-teal-500" />
                      <span className="font-medium text-teal-600">Evergreen</span>
                    </>
                }
              </div>
            </div>
            <div>
              <p className="text-[10px] uppercase tracking-wide text-text-secondary mb-0.5">Applies To</p>
              <span className="font-medium capitalize">{scheme.applies_to.replace(/_/g, " ")}</span>
            </div>
            <div>
              <p className="text-[10px] uppercase tracking-wide text-text-secondary mb-0.5">Applicable Days</p>
              {scheme.applicable_days.length === 0
                ? <span className="font-medium text-teal-600">All days</span>
                : <div className="flex flex-wrap gap-0.5 mt-0.5">
                    {DAYS.map((d, i) => (
                      <span key={i} className={`text-[9px] px-1.5 py-0.5 rounded font-medium
                        ${scheme.applicable_days.includes(i)
                          ? "bg-primary/10 text-primary"
                          : "bg-muted text-text-secondary/40"
                        }`}>
                        {d}
                      </span>
                    ))}
                  </div>
              }
            </div>
          </div>

          {scheme.reward_summary && (
            <div className="mt-4 flex items-center gap-2 rounded-md bg-primary/5 border border-primary/15 px-3 py-2">
              <BarChart2 className="h-4 w-4 text-primary shrink-0" />
              <span className="text-sm font-semibold text-primary">{scheme.reward_summary}</span>
            </div>
          )}
        </CardContent>
      </Card>

      <div className="grid gap-5 md:grid-cols-2">
        {/* ── Conditions ────────────────────────────────────────────────── */}
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm flex items-center gap-2">
              <Layers className="h-4 w-4 text-text-secondary" />
              Conditions
              <span className="ml-auto text-[10px] text-text-secondary font-normal">
                {scheme.conditions.length} condition{scheme.conditions.length !== 1 ? "s" : ""}
              </span>
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-2">
            {scheme.conditions.length === 0 ? (
              <p className="text-sm text-text-secondary italic">No conditions — scheme applies to all eligible carts</p>
            ) : (
              scheme.conditions.map(c => <ConditionCard key={c.id} cond={c} />)
            )}
          </CardContent>
        </Card>

        {/* ── Rewards ───────────────────────────────────────────────────── */}
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm flex items-center gap-2">
              <Gift className="h-4 w-4 text-primary" />
              Rewards
              <span className="ml-auto text-[10px] text-text-secondary font-normal">
                {scheme.rewards.length} reward{scheme.rewards.length !== 1 ? "s" : ""}
              </span>
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-2">
            {scheme.rewards.length === 0 ? (
              <p className="text-sm text-text-secondary italic">No rewards configured</p>
            ) : (
              scheme.rewards.map(r => <RewardCard key={r.id} reward={r} />)
            )}
          </CardContent>
        </Card>
      </div>

      {/* ── Notes ────────────────────────────────────────────────────────── */}
      {scheme.notes && (
        <Card className="mt-5">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm flex items-center gap-2">
              <Info className="h-4 w-4 text-text-secondary" />
              Notes
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-text-secondary whitespace-pre-wrap">{scheme.notes}</p>
          </CardContent>
        </Card>
      )}

      {/* ── Products at a glance ─────────────────────────────────────────── */}
      {scheme.products_preview.length > 0 && (
        <Card className="mt-5">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm flex items-center gap-2">
              <Package className="h-4 w-4 text-text-secondary" />
              Products Involved
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex flex-wrap gap-2">
              {scheme.products_preview.map(p => (
                <ProductChip key={p.id} product={p} highlight />
              ))}
            </div>
          </CardContent>
        </Card>
      )}
    </AppShell>
  );
}
