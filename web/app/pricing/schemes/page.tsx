"use client";

import { useState, useEffect, useCallback, useRef, KeyboardEvent } from "react";
import { AppShell } from "@/components/layout/app-shell";
import { PageHeader } from "@/components/layout/page-header";
import { DataTable, Column } from "@/components/ui/data-table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Modal } from "@/components/ui/modal";
import {
  Plus, Search, Pencil, PowerOff, Copy, Check, CheckCircle2,
  Zap, Clock, Shield, Infinity as InfinityIcon, AlertTriangle, X,
} from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";

// 
// Types
// 
interface SchemeCondition {
  id?: number;
  condition_type: string;
  operator: string;
  value: Record<string, unknown>;
}

interface SchemeReward {
  id?: number;
  reward_type: string;
  target_scope: string;
  reward_value: number;
  max_reward_value: number | null;
  target_product_id: number | null;
  free_per_x: number | null;
  free_qty_per_trigger: number | null;
}

interface Scheme {
  id: number;
  code: string;
  name: string;
  notes: string | null;
  scheme_type: string;
  status: string;
  applies_to: string;
  priority: number;
  exclusive: boolean;
  start_date: string | null;
  end_date: string | null;
  branch_id: number | null;
  applicable_days: number[];
  conditions_count: number;
  rewards_count: number;
  reward_summary: string | null;
  created_at: string | null;
  conditions?: SchemeCondition[];
  rewards?: SchemeReward[];
}

interface SchemeStats {
  total: number;
  active: number;
  inactive: number;
  expired: number;
  expiring_soon: number;
  exclusive: number;
  evergreen: number;
}

// 
// Constants
// 
const SCHEME_TYPE_LABELS: Record<string, string> = {
  buy_x_get_y: "Buy X Get Y",
  slab_discount: "Slab Discount",
  item_discount: "Item Discount",
  order_value_discount: "Order Value Discount",
};

const REWARD_TYPE_LABELS: Record<string, string> = {
  percent_off: "% Off",
  amount_off: "Amount Off (?)",
  free_qty: "Free Qty",
  fixed_price: "Fixed Price",
};

const CONDITION_TYPE_LABELS: Record<string, string> = {
  min_order_value: "Min Order Value (?)",
  min_total_qty: "Min Total Qty",
  product_inclusion: "Product Inclusion",
  category_inclusion: "Category Inclusion",
  retailer_inclusion: "Retailer Inclusion",
  retailer_exclusion: "Retailer Exclusion",
};

const TYPE_CHIP: Record<string, string> = {
  buy_x_get_y:          "bg-purple-50 text-purple-700 border border-purple-200",
  slab_discount:        "bg-blue-50 text-blue-700 border border-blue-200",
  item_discount:        "bg-emerald-50 text-emerald-700 border border-emerald-200",
  order_value_discount: "bg-amber-50 text-amber-700 border border-amber-200",
};

const APPLIES_TO_CHIP: Record<string, string> = {
  all:                "bg-background-subtle text-text-secondary border border-border",
  retailer_segment:   "bg-accent/10 text-accent border border-accent",
  specific_retailers: "bg-pink-50 text-pink-700 border border-pink-200",
  route:              "bg-sky-50 text-sky-700 border border-sky-200",
  beat:               "bg-orange-50 text-orange-700 border border-orange-200",
};

const APPLIES_TO_LABELS: Record<string, string> = {
  all:                "All retailers",
  retailer_segment:   "Segment",
  specific_retailers: "Specific",
  route:              "Route",
  beat:               "Beat",
};

// 
// Helpers
// 
function daysToExpiry(endDate: string | null): number | null {
  if (!endDate) return null;
  return Math.ceil((new Date(endDate).getTime() - Date.now()) / 86_400_000);
}

// 
// StatCard
// 
function StatCard({
  label, value, icon: Icon, color, loading,
}: {
  label: string;
  value: number;
  icon: React.ElementType;
  color: string;
  loading: boolean;
}) {
  return (
    <div className="flex items-center gap-3 rounded-xl border border-border bg-background px-4 py-3 min-w-0">
      <div className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-lg ${color}`}>
        <Icon className="h-4 w-4" />
      </div>
      <div className="min-w-0">
        <div className="text-xs text-text-secondary truncate">{label}</div>
        {loading ? (
          <div className="mt-0.5 h-5 w-8 rounded bg-border animate-pulse" />
        ) : (
          <div className="text-xl font-semibold text-text-primary tabular-nums leading-tight">{value}</div>
        )}
      </div>
    </div>
  );
}

// 
// CopyCodeBadge
// 
function CopyCodeBadge({ code }: { code: string }) {
  const [copied, setCopied] = useState(false);
  const copy = (e: React.MouseEvent) => {
    e.stopPropagation();
    navigator.clipboard.writeText(code).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    });
  };
  return (
    <button
      type="button"
      onClick={copy}
      title="Copy code"
      className="group inline-flex items-center gap-1 font-mono text-xs bg-background-subtle border border-border px-1.5 py-0.5 rounded text-text-secondary hover:border-primary hover:text-primary transition-colors"
    >
      {code}
      {copied
        ? <Check className="h-3 w-3 text-green-600" />
        : <Copy className="h-3 w-3 opacity-0 group-hover:opacity-100 transition-opacity" />
      }
    </button>
  );
}

// 
// ProductCombobox (for target product search in reward section)
// 
interface ProductOption { id: number; name: string; sku: string; }

function ProductCombobox({
  token, orgId, value, label, onChange,
}: {
  token: string | null;
  orgId: string | null;
  value: string;
  label: string;
  onChange: (id: string, label: string) => void;
}) {
  const [query, setQuery] = useState(label);
  const [results, setResults] = useState<ProductOption[]>([]);
  const [open, setOpen] = useState(false);
  const [searching, setSearching] = useState(false);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function h(e: MouseEvent) {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) setOpen(false);
    }
    document.addEventListener("mousedown", h);
    return () => document.removeEventListener("mousedown", h);
  }, []);

  useEffect(() => { if (!value) setQuery(""); }, [value]);

  const search = useCallback(async (q: string) => {
    if (!token || !orgId || q.trim().length < 1) { setResults([]); return; }
    setSearching(true);
    try {
      const res = await fetch(
        `${API_URL}/api/v1/products?q=${encodeURIComponent(q)}&status=active&per_page=20`,
        { headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId } }
      );
      const json = await res.json();
      setResults((json.data ?? []).map((p: { id: number; name: string; sku: string }) => ({ id: p.id, name: p.name, sku: p.sku })));
    } finally { setSearching(false); }
  }, [token, orgId]);

  const handleInput = (e: React.ChangeEvent<HTMLInputElement>) => {
    const q = e.target.value;
    setQuery(q); onChange("", ""); setOpen(true);
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => search(q), 300);
  };

  const handleSelect = (p: ProductOption) => {
    onChange(String(p.id), `${p.name}  ${p.sku}`);
    setQuery(`${p.name}  ${p.sku}`); setOpen(false); setResults([]);
  };

  return (
    <div ref={containerRef} className="relative flex flex-col gap-1.5 col-span-2">
      <label className="text-sm font-medium text-text-primary">Target Product</label>
      <div className="relative">
        <Search className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-text-secondary" />
        <input
          type="text" value={query} onChange={handleInput}
          onFocus={() => query && !value && setOpen(true)}
          placeholder="Search by name or SKU"
          className="h-10 w-full rounded-md border border-border bg-background pl-9 pr-8 text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
        />
        {(query || value) && (
          <button type="button" onClick={() => { onChange("", ""); setQuery(""); setResults([]); }}
            className="absolute right-2.5 top-1/2 -translate-y-1/2 text-text-secondary hover:text-text-primary">
            <X className="h-3.5 w-3.5" />
          </button>
        )}
      </div>
      {value && <p className="text-xs text-green-600 font-medium"> Selected � ID #{value}</p>}
      {open && (
        <div className="absolute top-full left-0 z-50 mt-1 w-full rounded-md border border-border bg-background shadow-lg max-h-52 overflow-y-auto">
          {searching ? (
            <div className="flex items-center justify-center py-4">
              <div className="h-4 w-4 animate-spin rounded-full border-2 border-primary border-t-transparent" />
            </div>
          ) : results.length === 0 ? (
            <p className="px-4 py-3 text-sm text-text-secondary">
              {query.trim().length < 1 ? "Type to search products" : "No products found."}
            </p>
          ) : results.map((p) => (
            <button key={p.id} type="button"
              onMouseDown={(e) => { e.preventDefault(); handleSelect(p); }}
              className="flex w-full items-center justify-between px-4 py-2.5 text-left text-sm hover:bg-background-subtle transition-colors">
              <span className="font-medium text-text-primary">{p.name}</span>
              <span className="ml-2 shrink-0 text-xs text-text-secondary">{p.sku}</span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

// 
// SelectField
// 
function SelectField({
  label, value, onChange, children, className = "",
}: {
  label?: string;
  value: string;
  onChange: (v: string) => void;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div className={`flex flex-col gap-1.5 ${className}`}>
      {label && <label className="text-sm font-medium text-text-primary">{label}</label>}
      <select
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="h-10 w-full rounded-md border border-border bg-background px-3 py-2 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
      >
        {children}
      </select>
    </div>
  );
}

// 
// ConditionValueInput
// 
function ConditionValueInput({ type, value, onChange }: {
  type: string;
  value: Record<string, unknown>;
  onChange: (v: Record<string, unknown>) => void;
}) {
  const cls = "h-9 rounded-md border border-border bg-background px-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary";
  if (type === "min_order_value")
    return <input type="number" placeholder="e.g. 1000" value={String(value.amount ?? "")}
      onChange={(e) => onChange({ amount: Number(e.target.value) })} className={`${cls} w-36`} />;
  if (type === "min_total_qty")
    return <input type="number" placeholder="e.g. 10" value={String(value.qty ?? "")}
      onChange={(e) => onChange({ qty: Number(e.target.value) })} className={`${cls} w-36`} />;
  const key = type === "product_inclusion" ? "product_ids"
    : type === "category_inclusion" ? "category_ids" : "customer_ids";
  return (
    <input placeholder="IDs, comma-separated"
      value={Array.isArray(value[key]) ? (value[key] as number[]).join(", ") : ""}
      onChange={(e) => onChange({ [key]: e.target.value.split(",").map((s) => s.trim()).filter(Boolean).map(Number) })}
      className={`${cls} w-48`} />
  );
}

// 
// SchemeFormModal
// 
interface SchemeFormModalProps {
  token: string | null;
  orgId: string | null;
  scheme: Scheme | null;
  isDuplicate?: boolean;
  onClose: () => void;
  onSaved: () => void;
}

function SchemeFormModal({ token, orgId, scheme, isDuplicate = false, onClose, onSaved }: SchemeFormModalProps) {
  const isEdit = !!scheme && !isDuplicate;
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const WEEKDAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

  const [form, setForm] = useState({
    code:           isDuplicate ? `${scheme?.code ?? ""}-COPY` : (scheme?.code ?? ""),
    name:           isDuplicate ? `${scheme?.name ?? ""} (Copy)` : (scheme?.name ?? ""),
    scheme_type:    scheme?.scheme_type ?? "item_discount",
    status:         scheme?.status ?? "active",
    applies_to:     scheme?.applies_to ?? "all",
    priority:       String(scheme?.priority ?? 10),
    exclusive:      scheme?.exclusive ?? false,
    start_date:     scheme?.start_date ? scheme.start_date.slice(0, 10) : "",
    end_date:       scheme?.end_date ? scheme.end_date.slice(0, 10) : "",
    applicable_days: scheme?.applicable_days ?? ([] as number[]),
    notes:          scheme?.notes ?? "",
  });

  const [reward, setReward] = useState({
    reward_type:          scheme?.rewards?.[0]?.reward_type ?? "percent_off",
    target_scope:         scheme?.rewards?.[0]?.target_scope ?? "order",
    reward_value:         String(scheme?.rewards?.[0]?.reward_value ?? "0"),
    max_reward_value:     String(scheme?.rewards?.[0]?.max_reward_value ?? ""),
    free_per_x:           String(scheme?.rewards?.[0]?.free_per_x ?? ""),
    free_qty_per_trigger: String(scheme?.rewards?.[0]?.free_qty_per_trigger ?? ""),
    target_product_id:    String(scheme?.rewards?.[0]?.target_product_id ?? ""),
    target_product_label: "",
  });

  const [conditions, setConditions] = useState<SchemeCondition[]>(
    scheme?.conditions?.map((c) => ({ ...c })) ?? []
  );

  function defaultValueFor(type: string): Record<string, unknown> {
    if (type === "min_order_value") return { amount: 0 };
    if (type === "min_total_qty") return { qty: 0 };
    if (type === "product_inclusion") return { product_ids: [] };
    if (type === "category_inclusion") return { category_ids: [] };
    return { customer_ids: [] };
  }

  const toggleDay = (d: number) =>
    setForm((f) => ({
      ...f,
      applicable_days: f.applicable_days.includes(d)
        ? f.applicable_days.filter((x) => x !== d)
        : [...f.applicable_days, d],
    }));

  const handleSubmit = async () => {
    if (!token || !orgId) return;
    if (!form.code.trim() || !form.name.trim()) { setError("Code and Name are required."); return; }
    setSaving(true); setError("");
    const body = {
      scheme: {
        ...form,
        priority: Number(form.priority),
        conditions,
        rewards: [{
          ...(() => { const { target_product_label: _l, ...r } = reward; return r; })(),
          reward_value:          Number(reward.reward_value),
          max_reward_value:      reward.max_reward_value ? Number(reward.max_reward_value) : null,
          free_per_x:            reward.free_per_x ? Number(reward.free_per_x) : null,
          free_qty_per_trigger:  reward.free_qty_per_trigger ? Number(reward.free_qty_per_trigger) : null,
          target_product_id:     reward.target_product_id ? Number(reward.target_product_id) : null,
        }],
      },
    };
    const url = isEdit
        ? `${API_URL}/api/v1/schemes/${scheme!.id}`
      : `${API_URL}/api/v1/schemes`;
    try {
      const res  = await fetch(url, {
        method: isEdit ? "PATCH" : "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
        body: JSON.stringify(body),
      });
      const json = await res.json();
      if (res.ok) onSaved();
      else setError(json.errors?.join(", ") ?? "Save failed");
    } catch { setError("Network error � please try again"); }
    finally { setSaving(false); }
  };

  const isBuyXGetY = form.scheme_type === "buy_x_get_y";
  const modalTitle = isDuplicate ? `Duplicate: ${scheme!.name}` : isEdit ? `Edit: ${scheme!.name}` : "New Scheme";

  return (
    <Modal open onClose={onClose} title={modalTitle} size="xl">
      <div className="max-h-[68vh] overflow-y-auto -mr-2 pr-2 space-y-6">
        {error && (
          <div className="rounded-md bg-red-50 border border-red-200 px-4 py-2.5 text-sm text-red-700">{error}</div>
        )}

        <section>
          <p className="text-xs font-semibold uppercase tracking-wider text-text-secondary mb-3">Identity</p>
          <div className="grid grid-cols-2 gap-4">
            <Input label="Code *" value={form.code} placeholder="SUMMER-10"
              onChange={(e) => setForm((f) => ({ ...f, code: e.target.value }))} />
            <Input label="Name *" value={form.name} placeholder="Summer Item Discount"
              onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))} />
            <div className="col-span-2">
              <Input label="Notes (internal)" value={form.notes ?? ""}
                placeholder="Optional internal notes about this scheme"
                onChange={(e) => setForm((f) => ({ ...f, notes: e.target.value }))} />
            </div>
          </div>
        </section>

        <section>
          <p className="text-xs font-semibold uppercase tracking-wider text-text-secondary mb-3">Configuration</p>
          <div className="grid grid-cols-2 gap-4">
            <SelectField label="Type" value={form.scheme_type} onChange={(v) => setForm((f) => ({ ...f, scheme_type: v }))}>
              {Object.entries(SCHEME_TYPE_LABELS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
            </SelectField>
            <SelectField label="Applies To" value={form.applies_to} onChange={(v) => setForm((f) => ({ ...f, applies_to: v }))}>
              <option value="all">All Retailers</option>
              <option value="retailer_segment">Retailer Segment</option>
              <option value="specific_retailers">Specific Retailers</option>
              <option value="route">Route</option>
              <option value="beat">Beat</option>
            </SelectField>
            <SelectField label="Status" value={form.status} onChange={(v) => setForm((f) => ({ ...f, status: v }))}>
              <option value="active">Active</option>
              <option value="inactive">Inactive</option>
            </SelectField>
            <Input label="Priority (lower = higher)" type="number" min={0} value={form.priority}
              onChange={(e) => setForm((f) => ({ ...f, priority: e.target.value }))} />
            <Input label="Start Date" type="date" value={form.start_date}
              onChange={(e) => setForm((f) => ({ ...f, start_date: e.target.value }))} />
            <Input label="End Date" type="date" value={form.end_date}
              onChange={(e) => setForm((f) => ({ ...f, end_date: e.target.value }))} />
          </div>
          <label className="mt-4 flex items-center gap-2.5 cursor-pointer select-none">
            <input type="checkbox" checked={form.exclusive}
              onChange={(e) => setForm((f) => ({ ...f, exclusive: e.target.checked }))}
              className="h-4 w-4 rounded border-border accent-primary" />
            <span className="text-sm text-text-primary">Exclusive � block lower-priority schemes when this fires</span>
          </label>
        </section>

        <section>
          <p className="text-xs font-semibold uppercase tracking-wider text-text-secondary mb-2">
            Applicable Days <span className="normal-case font-normal ml-1">(empty = every day)</span>
          </p>
          <div className="flex gap-2 flex-wrap">
            {WEEKDAYS.map((day, idx) => (
              <button key={idx} type="button" onClick={() => toggleDay(idx)}
                className={`px-3 py-1.5 rounded-full text-xs font-medium border transition-colors ${
                  form.applicable_days.includes(idx)
                    ? "bg-primary text-white border-primary"
                    : "border-border text-text-secondary hover:border-primary hover:text-text-primary"
                }`}>
                {day}
              </button>
            ))}
          </div>
        </section>

        <section>
          <p className="text-xs font-semibold uppercase tracking-wider text-text-secondary mb-3">Reward</p>
          <div className="grid grid-cols-2 gap-4">
            <SelectField label="Reward Type" value={reward.reward_type}
              onChange={(v) => setReward((r) => ({ ...r, reward_type: v }))}>
              {Object.entries(REWARD_TYPE_LABELS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
            </SelectField>
            <SelectField label="Applies On" value={reward.target_scope}
              onChange={(v) => setReward((r) => ({ ...r, target_scope: v }))}>
              <option value="order">Entire Order</option>
              <option value="line">Matching Lines</option>
              <option value="product">Specific Product</option>
            </SelectField>
            <Input
              label={reward.reward_type === "percent_off" ? "Discount %" : reward.reward_type === "amount_off" ? "Discount ?" : "Value"}
              type="number" min={0} value={reward.reward_value}
              onChange={(e) => setReward((r) => ({ ...r, reward_value: e.target.value }))} />
            <Input label="Max Discount Cap" type="number" min={0} placeholder="No cap"
              value={reward.max_reward_value}
              onChange={(e) => setReward((r) => ({ ...r, max_reward_value: e.target.value }))} />
            {reward.target_scope === "product" && (
              <ProductCombobox token={token} orgId={orgId}
                value={reward.target_product_id} label={reward.target_product_label}
                onChange={(id, lbl) => setReward((r) => ({ ...r, target_product_id: id, target_product_label: lbl }))} />
            )}
            {isBuyXGetY && (
              <>
                <Input label="Buy Qty (X)" type="number" min={1} placeholder="e.g. 6"
                  value={reward.free_per_x}
                  onChange={(e) => setReward((r) => ({ ...r, free_per_x: e.target.value }))} />
                <Input label="Free Qty per set (Y)" type="number" min={1} placeholder="e.g. 1"
                  value={reward.free_qty_per_trigger}
                  onChange={(e) => setReward((r) => ({ ...r, free_qty_per_trigger: e.target.value }))} />
              </>
            )}
          </div>
        </section>

        <section>
          <div className="flex items-center justify-between mb-3">
            <p className="text-xs font-semibold uppercase tracking-wider text-text-secondary">Conditions</p>
            <Button variant="outline" size="sm"
              onClick={() => setConditions((c) => [...c, { condition_type: "min_order_value", operator: ">=", value: { amount: 0 } }])}>
              <Plus className="h-3.5 w-3.5 mr-1" /> Add
            </Button>
          </div>
          {conditions.length === 0 ? (
            <p className="text-sm text-text-secondary py-1">No conditions � scheme applies to all qualifying orders.</p>
          ) : (
            <div className="space-y-2">
              {conditions.map((cond, i) => (
                <div key={i} className="flex items-center gap-2 rounded-md border border-border bg-background-subtle px-3 py-2">
                  <SelectField value={cond.condition_type} className="flex-1 min-w-0"
                    onChange={(v) => setConditions((c) => c.map((x, idx) => idx === i ? { ...x, condition_type: v, value: defaultValueFor(v) } : x))}>
                    {Object.entries(CONDITION_TYPE_LABELS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
                  </SelectField>
                  <ConditionValueInput type={cond.condition_type} value={cond.value}
                    onChange={(v) => setConditions((c) => c.map((x, idx) => idx === i ? { ...x, value: v } : x))} />
                  <button type="button"
                    onClick={() => setConditions((c) => c.filter((_, idx) => idx !== i))}
                    className="shrink-0 rounded p-1 text-text-secondary hover:text-red-600 hover:bg-red-50 transition-colors">
                    
                  </button>
                </div>
              ))}
            </div>
          )}
        </section>
      </div>

      <div className="mt-5 flex justify-end gap-3 pt-4 border-t border-border">
        <Button variant="outline" onClick={onClose} disabled={saving}>Cancel</Button>
        <Button onClick={handleSubmit} disabled={saving}>
          {saving ? "Saving" : isEdit ? "Save Changes" : isDuplicate ? "Create Duplicate" : "Create Scheme"}
        </Button>
      </div>
    </Modal>
  );
}

// 
// SchemesPage
// 
export default function SchemesPage() {
  const { token, orgId } = useOrgBranch();

  const [schemes, setSchemes]         = useState<Scheme[]>([]);
  const [loading, setLoading]         = useState(true);
  const [stats, setStats]             = useState<SchemeStats | null>(null);
  const [statsLoading, setStatsLoading] = useState(true);

  const [search, setSearch]           = useState("");
  const [typeFilter, setTypeFilter]   = useState("");
  const [statusTab, setStatusTab]     = useState("active");
  const [page, setPage]               = useState(1);
  const [meta, setMeta]               = useState({ total: 0, per: 20 });

  const [formOpen, setFormOpen]       = useState(false);
  const [editing, setEditing]         = useState<Scheme | null>(null);
  const [isDuplicate, setIsDuplicate] = useState(false);
  const [toggling, setToggling]       = useState<number | null>(null);

  //  Keyboard shortcut: N  new scheme 
  useEffect(() => {
    const handler = (e: globalThis.KeyboardEvent) => {
      if (
        e.key === "n" && !e.metaKey && !e.ctrlKey && !e.altKey &&
        !formOpen &&
        document.activeElement?.tagName !== "INPUT" &&
        document.activeElement?.tagName !== "TEXTAREA" &&
        document.activeElement?.tagName !== "SELECT"
      ) {
        setEditing(null); setIsDuplicate(false); setFormOpen(true);
      }
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [formOpen]);

  //  Load stats 
  const loadStats = useCallback(async () => {
    if (!token || !orgId) return;
    setStatsLoading(true);
    try {
      const res  = await fetch(`${API_URL}/api/v1/schemes/stats`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const json = await res.json();
      if (res.ok) setStats(json.data);
    } finally { setStatsLoading(false); }
  }, [token, orgId]);

  //  Load schemes list 
  const loadSchemes = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const qs = new URLSearchParams({ page: String(page), per: "20",
        ...(search     ? { q:           search }     : {}),
        ...(typeFilter ? { scheme_type: typeFilter }  : {}),
        ...(statusTab  ? { status:      statusTab }   : {}),
      });
      const res  = await fetch(`${API_URL}/api/v1/schemes?${qs}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const json = await res.json();
      if (res.ok) { setSchemes(json.data ?? []); setMeta({ total: json.meta?.total ?? 0, per: 20 }); }
    } finally { setLoading(false); }
  }, [token, orgId, page, search, typeFilter, statusTab]);

  useEffect(() => { loadStats(); }, [loadStats]);
  useEffect(() => { loadSchemes(); }, [loadSchemes]);

  //  Open edit (fetch full detail first) 
  const openEdit = async (scheme: Scheme) => {
    if (!token || !orgId) return;
    try {
      const res  = await fetch(`${API_URL}/api/v1/schemes/${scheme.id}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const json = await res.json();
      if (res.ok) { setEditing(json.data); setIsDuplicate(false); setFormOpen(true); }
    } catch { setEditing(scheme); setIsDuplicate(false); setFormOpen(true); }
  };

  //  Duplicate (clone) scheme 
  const openDuplicate = async (scheme: Scheme) => {
    if (!token || !orgId) return;
    try {
      const res  = await fetch(`${API_URL}/api/v1/schemes/${scheme.id}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const json = await res.json();
      if (res.ok) { setEditing(json.data); setIsDuplicate(true); setFormOpen(true); }
    } catch { setEditing(scheme); setIsDuplicate(true); setFormOpen(true); }
  };

  //  Inline status toggle 
  const toggleStatus = async (scheme: Scheme) => {
    if (!token || !orgId) return;
    setToggling(scheme.id);
    const newStatus = scheme.status === "active" ? "inactive" : "active";
    try {
      await fetch(`${API_URL}/api/v1/schemes/${scheme.id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
        body: JSON.stringify({ scheme: { status: newStatus } }),
      });
      setSchemes((prev) => prev.map((s) => s.id === scheme.id ? { ...s, status: newStatus } : s));
      loadStats();
    } finally { setToggling(null); }
  };

  //  Table columns 
  const columns: Column<Scheme>[] = [
    {
      key: "code",
      header: "Code",
      render: (_v, s) => <CopyCodeBadge code={s.code} />,
    },
    {
      key: "name",
      header: "Scheme",
      render: (_v, s) => (
        <div className="min-w-0">
          <div className="flex items-center gap-2 flex-wrap">
            <span className="font-medium text-text-primary text-sm">{s.name}</span>
            {s.exclusive && (
              <span className="inline-flex items-center gap-0.5 text-xs font-medium text-purple-600">
                <Shield className="h-3 w-3" /> Exclusive
              </span>
            )}
          </div>
          <div className="flex items-center gap-1.5 mt-1 flex-wrap">
            <span className={`inline-flex items-center px-1.5 py-0.5 text-xs font-medium rounded ${TYPE_CHIP[s.scheme_type] ?? "bg-background-subtle text-text-secondary border border-border"}`}>
              {SCHEME_TYPE_LABELS[s.scheme_type] ?? s.scheme_type}
            </span>
            <span className={`inline-flex items-center px-1.5 py-0.5 text-xs font-medium rounded ${APPLIES_TO_CHIP[s.applies_to] ?? "bg-background-subtle text-text-secondary border border-border"}`}>
              {APPLIES_TO_LABELS[s.applies_to] ?? s.applies_to}
            </span>
            {s.conditions_count > 0 && (
              <span className="text-xs text-text-secondary">{s.conditions_count} condition{s.conditions_count !== 1 ? "s" : ""}</span>
            )}
          </div>
        </div>
      ),
    },
    {
      key: "reward_summary",
      header: "Reward",
      render: (_v, s) => (
        <span className="text-sm text-text-primary whitespace-nowrap">
          {s.reward_summary ?? <span className="text-text-secondary italic">�</span>}
        </span>
      ),
    },
    {
      key: "status",
      header: "Status / Expiry",
      render: (_v, s) => {
        const days = daysToExpiry(s.end_date);
        const expiringSoon = days !== null && days <= 7 && days >= 0 && s.status === "active";
        const expired       = days !== null && days < 0;
        return (
          <div className="flex flex-col gap-1">
            <button
              type="button"
              title={`Click to ${s.status === "active" ? "deactivate" : "activate"}`}
              disabled={toggling === s.id || s.status === "expired"}
              onClick={() => toggleStatus(s)}
              className="inline-flex items-center gap-1 group"
            >
              <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium border transition-colors ${
                toggling === s.id ? "opacity-50" :
                s.status === "active"   ? "bg-green-50 text-green-700 border-green-200 group-hover:bg-red-50 group-hover:text-red-600 group-hover:border-red-200" :
                s.status === "inactive" ? "bg-amber-50 text-amber-700 border-amber-200 group-hover:bg-green-50 group-hover:text-green-700 group-hover:border-green-200" :
                                          "bg-red-50 text-red-700 border-red-200"
              }`}>
                {s.status === "active" ? (
                  <><CheckCircle2 className="h-3 w-3" /> Active</>
                ) : s.status === "inactive" ? (
                  <><PowerOff className="h-3 w-3" /> Inactive</>
                ) : (
                  <><AlertTriangle className="h-3 w-3" /> Expired</>
                )}
              </span>
            </button>
            {expiringSoon && (
              <span className="inline-flex items-center gap-1 text-xs font-medium text-amber-600">
                <Clock className="h-3 w-3" /> Expires in {days}d
              </span>
            )}
            {expired && s.status === "active" && (
              <span className="text-xs text-red-500">Past end date</span>
            )}
            {!s.end_date && s.status === "active" && (
              <span className="inline-flex items-center gap-1 text-xs text-text-secondary">
                <InfinityIcon className="h-3 w-3" /> No expiry
              </span>
            )}
          </div>
        );
      },
    },
    {
      key: "priority",
      header: "Pri.",
      render: (_v, s) => (
        <span className={`tabular-nums text-sm font-medium ${s.priority === 0 ? "text-primary" : "text-text-secondary"}`}>
          {s.priority}
        </span>
      ),
    },
    {
      key: "validity",
      header: "Validity",
      render: (_v, s) => (
        <span className="text-xs tabular-nums text-text-secondary whitespace-nowrap">
          {s.start_date ? s.start_date.slice(0, 10) : "�"}{"  "}{s.end_date ? s.end_date.slice(0, 10) : ""}
        </span>
      ),
    },
    {
      key: "actions",
      header: "",
      render: (_v, s) => (
        <div className="flex items-center gap-0.5 justify-end">
          <Button variant="ghost" size="sm" title="Edit scheme" onClick={() => openEdit(s)}>
            <Pencil className="h-3.5 w-3.5" />
          </Button>
          <Button variant="ghost" size="sm" title="Duplicate scheme" onClick={() => openDuplicate(s)}>
            <Copy className="h-3.5 w-3.5" />
          </Button>
        </div>
      ),
    },
  ];

  const totalPages = Math.ceil(meta.total / meta.per);

  const STATUS_TABS = [
    { value: "active",   label: "Active",   count: stats?.active },
    { value: "inactive", label: "Inactive", count: stats?.inactive },
    { value: "expired",  label: "Expired",  count: stats?.expired },
    { value: "",         label: "All",      count: stats?.total },
  ];

  return (
    <AppShell>
      <PageHeader
        title="Schemes"
        subtitle="Trade promotions · Trade program management"
        actions={[{
          label: "New Scheme",
          icon: Plus,
          onClick: () => { setEditing(null); setIsDuplicate(false); setFormOpen(true); },
        }]}
      />

      {/* Stats bar */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-5">
        <StatCard label="Active"        value={stats?.active ?? 0}        icon={CheckCircle2}   color="bg-green-100 text-green-600"  loading={statsLoading} />
        <StatCard label="Expiring Soon" value={stats?.expiring_soon ?? 0} icon={Clock}          color="bg-amber-100 text-amber-600"  loading={statsLoading} />
        <StatCard label="Exclusive"     value={stats?.exclusive ?? 0}     icon={Shield}         color="bg-purple-100 text-purple-600" loading={statsLoading} />
        <StatCard label="Evergreen"     value={stats?.evergreen ?? 0}     icon={InfinityIcon}   color="bg-teal-100 text-teal-600"    loading={statsLoading} />
      </div>

      {/* Status tabs + filters */}
      <div className="flex flex-wrap items-center gap-3 mb-4">
        {/* Status tabs */}
        <div className="flex items-center h-9 rounded-lg border border-border bg-background-subtle p-0.5 gap-0.5">
          {STATUS_TABS.map((tab) => (
            <button
              key={tab.value}
              type="button"
              onClick={() => { setStatusTab(tab.value); setPage(1); }}
              className={`inline-flex items-center gap-1.5 rounded-md px-3 h-8 text-sm font-medium transition-colors ${
                statusTab === tab.value
                  ? "bg-background text-text-primary shadow-sm"
                  : "text-text-secondary hover:text-text-primary"
              }`}
            >
              {tab.label}
              {tab.count !== undefined && (
                <span className={`text-xs tabular-nums px-1.5 py-0.5 rounded-full ${
                  statusTab === tab.value ? "bg-primary/10 text-primary" : "bg-border text-text-secondary"
                }`}>
                  {tab.count}
                </span>
              )}
            </button>
          ))}
        </div>

        {/* Search */}
        <div className="relative flex-1 min-w-[180px] max-w-xs">
          <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 h-4 w-4 text-text-secondary pointer-events-none" />
          <input
            className="h-9 w-full rounded-md border border-border bg-background pl-8 pr-3 text-sm placeholder:text-text-secondary focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
            placeholder="Search name or code"
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(1); }}
          />
        </div>

        {/* Type filter */}
        <select
          className="h-9 rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-primary"
          value={typeFilter}
          onChange={(e) => { setTypeFilter(e.target.value); setPage(1); }}
        >
          <option value="">All Types</option>
          {Object.entries(SCHEME_TYPE_LABELS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
        </select>
      </div>

      {/* Table */}
      <DataTable
        columns={columns}
        data={schemes}
        isLoading={loading}
        emptyMessage={
          search || typeFilter
            ? "No schemes match your filters."
            : statusTab === "active"
            ? "No active schemes. Click 'New Scheme' or press N to create one."
            : "No schemes found."
        }
      />

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="flex items-center justify-between mt-4 text-sm text-text-secondary">
          <span>{meta.total} scheme{meta.total !== 1 ? "s" : ""}</span>
          <div className="flex items-center gap-2">
            <Button variant="outline" size="sm" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>Previous</Button>
            <span className="px-2">{page} / {totalPages}</span>
            <Button variant="outline" size="sm" disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}>Next</Button>
          </div>
        </div>
      )}

      {/* Form Modal */}
      {formOpen && (
        <SchemeFormModal
          token={token}
          orgId={orgId}
          scheme={editing}
          isDuplicate={isDuplicate}
          onClose={() => { setFormOpen(false); setEditing(null); setIsDuplicate(false); }}
          onSaved={() => { setFormOpen(false); setEditing(null); setIsDuplicate(false); loadSchemes(); loadStats(); }}
        />
      )}
    </AppShell>
  );
}
