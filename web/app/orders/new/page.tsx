"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Modal } from "@/components/ui/modal";
import {
  Plus, Trash2, Search, Loader2, History, X,
  RefreshCw, Minus, Info, Tag, CheckCircle, Zap,
} from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { CreditDecisionModal, CreditResult } from "@/components/ui/credit-decision-modal";
import { API_URL } from "@/lib/api/client";
import { ANALYTICS_EVENTS, trackBusinessEvent, orderEvents } from "@/lib/analytics";

// â”€â”€â”€ Types â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
interface CustomerOption { id: number; name: string; code: string; branch_id: number }
interface BranchOption   { id: number; name: string; code: string }
interface ProductOption  { id: number; name: string; sku: string; gst_rate: number; hsn_code: string | null }

interface RecentOrderLine {
  product_id:   number;
  product_name: string;
  product_sku:  string;
  qty:          number;
  unit_price:   number;
  discount_pct: number;
  gst_rate:     number;
  price_source: string;
  hsn_code:     string | null;
}
interface RecentOrder {
  id:           number;
  order_number: string;
  status:       string;
  total_amount: number;
  created_at:   string;
  lines:        RecentOrderLine[];
}

interface PriceData {
  unit_price:    number;
  discount_pct:  number;
  source:        string;
  price_list_id: number | null;
  price_list_name?: string;
  min_qty?:      number;
  valid_until?:  string;
}

interface SchemeFreebie {
  product_id:    number;
  qty_free:      number;
  scheme_id:     number;
  scheme_code:   string;
  scheme_name?:  string;
  product_name?: string;
  product_sku?:  string;
  gst_rate?:     number;
  hsn_code?:     string | null;
}
interface SchemeOrderDiscount {
  scheme_id: number;
  amount:    number;
}
interface SchemeExplainItem {
  scheme_id: number;
  code:      string;
  name:      string;
  message?:  string;
  reason?:   string;
  hint?:     SchemeHint | null;
}
type SchemeHint =
  | { type: 'increase_qty'; product_ids: number[]; qualifying_product_ids?: number[];
      current_qty: number;  target_qty: number;    gap: number }
  | { type: 'total_qty';    product_ids: number[]; current_qty: number;
      target_qty: number;   gap: number }
  | { type: 'order_value';  current: number;       target: number; gap: number }
  | { type: 'add_products'; product_ids: number[] }
  | { type: 'add_category'; category_ids: number[] };
interface SchemePreviewResult {
  lines:           { product_id: number; scheme_discount_pct: number; scheme_tags: string[] }[];
  freebies:        SchemeFreebie[];
  order_discounts: SchemeOrderDiscount[];
  totals: {
    subtotal:              number;
    scheme_discount_total: number;
    order_scheme_discount: number;
    grand_total:           number;
  };
  explain: {
    applied:     SchemeExplainItem[];
    not_applied: SchemeExplainItem[];
  };
}

interface OrderLine {
  _key:          string;
  product:       ProductOption | null;
  productQuery:  string;
  productResults: ProductOption[];
  productOpen:   boolean;
  qty:           string;
  unit_price:    string;
  discount_pct:  string;
  price_source:  string;
  priceLoading:  boolean;
  priceData:     PriceData | null;   // full resolution result for "Why this price?" modal
}

function newLine(): OrderLine {
  return {
    _key:          crypto.randomUUID(),
    product:       null,
    productQuery:  "",
    productResults: [],
    productOpen:   false,
    qty:           "1",
    unit_price:    "",
    discount_pct:  "0",
    price_source:  "missing",
    priceLoading:  false,
    priceData:     null,
  };
}

function lineTotal(line: OrderLine): number {
  const qty   = parseFloat(line.qty)          || 0;
  const price = parseFloat(line.unit_price)   || 0;
  const disc  = parseFloat(line.discount_pct) || 0;
  return parseFloat((qty * price * (1 - disc / 100)).toFixed(2));
}

function fmtINR(n: number) {
  return `₹${n.toLocaleString("en-IN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

const PRICE_SOURCE_LABEL: Record<string, string> = {
  retailer_specific: "Retailer Price",
  tier_specific:     "Tier Price",
  promo:             "Promo",
  standard:          "Standard",
  manual:            "Manual",
  missing:           "No Price",
};

const PRICE_SOURCE_COLOR: Record<string, string> = {
  retailer_specific: "bg-success/10 text-success",
  tier_specific:     "bg-success/10 text-success",
  promo:             "bg-primary/10 text-primary",
  standard:          "bg-muted text-text-secondary",
  manual:            "bg-warning/10 text-warning",
  missing:           "bg-danger/10 text-danger",
};

// â”€â”€â”€ Page â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
export default function NewOrderPage() {
  const router = useRouter();
  const { token, orgId } = useOrgBranch();

  // Order header
  const [customerQuery,   setCustomerQuery]   = useState("");
  const [customerResults, setCustomerResults] = useState<CustomerOption[]>([]);
  const [customerOpen,    setCustomerOpen]    = useState(false);
  const [customer,        setCustomer]        = useState<CustomerOption | null>(null);

  const [branches,  setBranches]  = useState<BranchOption[]>([]);
  const [branchId,  setBranchId]  = useState("");

  const [deliveryDate, setDeliveryDate] = useState("");
  const [notes,        setNotes]        = useState("");

  // Lines
  const [lines, setLines] = useState<OrderLine[]>([newLine()]);

  // Dirty tracking + autosave
  const [isDirty,      setIsDirty]      = useState(false);
  const [savedOrderId, setSavedOrderId] = useState<number | null>(null);
  const autoSaveTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Recent orders (repeat order quick action)
  const [recentOrders,    setRecentOrders]    = useState<RecentOrder[]>([]);
  const [recentLoading,   setRecentLoading]   = useState(false);
  const [repeatPanelOpen, setRepeatPanelOpen] = useState(false);

  // "Why this price?" modal
  const [priceModal, setPriceModal] = useState<{
    product: ProductOption;
    line:    OrderLine;
  } | null>(null);

  // Submit state
  const [saving,       setSaving]       = useState(false);
  const [submitAfter,  setSubmitAfter]  = useState(false);
  const [toast,        setToast]        = useState<{ type: "success" | "error"; msg: string } | null>(null);

  // Available credit (fetched when customer is selected)
  const [availableCredit, setAvailableCredit] = useState<number | null>(null);

  // Scheme preview
  const [schemePreview,  setSchemePreview]  = useState<SchemePreviewResult | null>(null);
  const [schemeLoading,  setSchemeLoading]  = useState(false);
  const schemeTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Credit decision modal
  const [creditModal,    setCreditModal]    = useState(false);
  const [creditResult,   setCreditResult]   = useState<CreditResult | null>(null);
  const [draftOrderId,   setDraftOrderId]   = useState<number | null>(null);
  const [draftOrderNum,  setDraftOrderNum]  = useState<string | null>(null);

  // Debounce timers
  const customerTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const productTimers = useRef<Record<string, ReturnType<typeof setTimeout>>>({});

  // Live refs — always carry the latest value so async callbacks never use stale state
  const branchIdRef  = useRef(branchId);
  const customerRef  = useRef<CustomerOption | null>(customer);

  const markDirty = useCallback(() => {
    setIsDirty(true);
  }, []);

  const showToast = (type: "success" | "error", msg: string) => {
    setToast({ type, msg });
    setTimeout(() => setToast(null), 3500);
  };

  // â”€â”€ Load branches â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  useEffect(() => {
    if (!token || !orgId) return;
    fetch(`${API_URL}/api/v1/branches?per_page=100`, {
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    })
      .then(r => r.json())
      .then(j => { if (j.data) setBranches(j.data); });
  }, [token, orgId]);

  // â”€â”€ Customer search â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  const searchCustomers = useCallback((q: string) => {
    if (!token || !orgId || q.length < 2) { setCustomerResults([]); return; }
    fetch(`${API_URL}/api/v1/customers?q=${encodeURIComponent(q)}&status=active&per_page=20`, {
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    })
      .then(r => r.json())
      .then(j => setCustomerResults(j.data ?? []));
  }, [token, orgId]);

  const handleCustomerInput = (val: string) => {
    setCustomerQuery(val);
    setCustomerOpen(true);
    setCustomer(null);
    markDirty();
    if (customerTimer.current) clearTimeout(customerTimer.current);
    customerTimer.current = setTimeout(() => searchCustomers(val), 300);
  };

  const selectCustomer = (c: CustomerOption) => {
    setCustomer(c);
    customerRef.current = c;
    setCustomerQuery(`${c.name} (${c.code})`);
    setCustomerOpen(false);
    setRepeatPanelOpen(false);
    setRecentOrders([]);
    setAvailableCredit(null);
    markDirty();
    if (c.branch_id) {
      const bid = String(c.branch_id);
      setBranchId(bid);
      branchIdRef.current = bid;
    }
    if (token && orgId) {
      // Fetch available credit for this customer
      fetch(`${API_URL}/api/v1/customers/${c.id}/credit_usage`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      })
        .then(r => r.json())
        .then(j => { if (j.data?.available_credit !== undefined) setAvailableCredit(j.data.available_credit); })
        .catch(() => {});

      setRecentLoading(true);
      fetch(`${API_URL}/api/v1/sales_orders/recent_for_customer?customer_id=${c.id}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      })
        .then(r => r.json())
        .then(j => {
          if (j.data?.length) {
            setRecentOrders(j.data);
            setRepeatPanelOpen(true);
          }
        })
        .finally(() => setRecentLoading(false));
    }
  };

  // â”€â”€ Product search (per line) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  const searchProducts = useCallback((lineKey: string, q: string) => {
    if (!token || !orgId || q.length < 2) {
      setLines(prev => prev.map(l => l._key === lineKey ? { ...l, productResults: [] } : l));
      return;
    }
    fetch(`${API_URL}/api/v1/products?q=${encodeURIComponent(q)}&status=active&per_page=20`, {
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    })
      .then(r => r.json())
      .then(j => setLines(prev => prev.map(l =>
        l._key === lineKey ? { ...l, productResults: j.data ?? [] } : l
      )));
  }, [token, orgId]);

  const handleProductInput = (lineKey: string, val: string) => {
    setLines(prev => prev.map(l =>
      l._key === lineKey ? { ...l, productQuery: val, productOpen: true, product: null } : l
    ));
    markDirty();
    if (productTimers.current[lineKey]) clearTimeout(productTimers.current[lineKey]);
    productTimers.current[lineKey] = setTimeout(() => searchProducts(lineKey, val), 300);
  };

  // â”€â”€ Price resolution â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  const resolvePrice = useCallback(async (lineKey: string, productId: number, qty: string) => {
    const bid  = branchIdRef.current;
    const cust = customerRef.current;
    if (!token || !orgId || !bid || !productId) return;
    setLines(prev => prev.map(l => l._key === lineKey ? { ...l, priceLoading: true } : l));
    try {
      const qp = new URLSearchParams({ branch_id: bid, qty: qty || "1" });
      if (cust) qp.set("retailer_id", String(cust.id));
      const res  = await fetch(`${API_URL}/api/v1/products/${productId}/price?${qp}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const json = await res.json();
      if (res.ok && json.data) {
        const pd: PriceData = json.data;
        setLines(prev => prev.map(l =>
          l._key === lineKey
            ? {
                ...l,
                unit_price:   String(pd.unit_price ?? ""),
                discount_pct: String(pd.discount_pct ?? "0"),
                price_source: pd.source ?? "missing",
                priceData:    pd,
                priceLoading: false,
              }
            : l
        ));
      }
    } finally {
      setLines(prev => prev.map(l => l._key === lineKey ? { ...l, priceLoading: false } : l));
    }
  }, [token, orgId]);

  const selectProduct = (lineKey: string, product: ProductOption) => {
    setLines(prev => prev.map(l =>
      l._key === lineKey
        ? { ...l, product, productQuery: `${product.sku} — ${product.name}`, productOpen: false }
        : l
    ));
    markDirty();
    const line = lines.find(l => l._key === lineKey);
    resolvePrice(lineKey, product.id, line?.qty ?? "1");
  };

  const updateLine = (lineKey: string, field: keyof OrderLine, value: string) => {
    setLines(prev => prev.map(l => l._key === lineKey ? { ...l, [field]: value } : l));
    markDirty();
    if (field === "qty") {
      const line = lines.find(l => l._key === lineKey);
      if (line?.product) resolvePrice(lineKey, line.product.id, value);
    }
  };

  const stepQty = (lineKey: string, delta: number) => {
    const line = lines.find(l => l._key === lineKey);
    if (!line) return;
    const current = parseFloat(line.qty) || 1;
    const next    = Math.max(1, Math.round((current + delta) * 1000) / 1000);
    updateLine(lineKey, "qty", String(next));
  };

  const addLine    = ()           => { setLines(prev => [...prev, newLine()]); markDirty(); };
  const removeLine = (key: string) => { setLines(prev => prev.filter(l => l._key !== key)); markDirty(); };

  // ── Add freebie line to cart ──────────────────────────────────────────────
  const addFreebieToCart = async (freebie: SchemeFreebie) => {
    const doAppend = (p: ProductOption) => {
      setLines(prev => [...prev, {
        _key:           crypto.randomUUID(),
        product:        p,
        productQuery:   `${p.sku} — ${p.name} (FREE)`,
        productResults: [],
        productOpen:    false,
        qty:            String(freebie.qty_free),
        unit_price:     "0",
        discount_pct:   "0",
        price_source:   "promo",
        priceLoading:   false,
        priceData:      null,
      }]);
      markDirty();
      showToast("success", `${freebie.qty_free}× ${p.name} added as free item`);
    };
    // Fast path — product info already in preview payload, no extra fetch needed
    if (freebie.product_name && freebie.product_sku) {
      doAppend({ id: freebie.product_id, name: freebie.product_name, sku: freebie.product_sku,
                 gst_rate: freebie.gst_rate ?? 0, hsn_code: freebie.hsn_code ?? null });
      return;
    }
    // Fallback: fetch from API when product info is absent
    if (!token || !orgId) return;
    try {
      const res  = await fetch(`${API_URL}/api/v1/products/${freebie.product_id}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const json = await res.json();
      if (!res.ok || !json.data) { showToast("error", "Could not load product"); return; }
      doAppend(json.data);
    } catch {
      showToast("error", "Failed to add free item");
    }
  };

  // ── Quick-apply: bump line qty to unlock a near-miss scheme ───────────────
  const quickApplyScheme = (hint: SchemeHint, schemeName: string) => {
    if (hint.type !== "increase_qty" && hint.type !== "total_qty") return;
    const eligible = lines
      .filter(l => l.product && hint.product_ids.includes(l.product.id))
      .sort((a, b) => (parseFloat(b.qty) || 0) - (parseFloat(a.qty) || 0));
    if (!eligible.length) {
      showToast("error", "Add a qualifying product line first");
      return;
    }
    const target = eligible[0];
    const newQty = String((parseFloat(target.qty) || 0) + hint.gap);
    updateLine(target._key, "qty", newQty);
    showToast("success", `+${hint.gap} added to unlock '${schemeName}'`);
  };

  // â”€â”€ Repeat Order â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  const repeatOrder = (order: RecentOrder) => {
    const newLines: OrderLine[] = order.lines.map(l => ({
      _key:           crypto.randomUUID(),
      product:        { id: l.product_id, name: l.product_name, sku: l.product_sku, gst_rate: l.gst_rate, hsn_code: l.hsn_code },
      productQuery:   `${l.product_sku} — ${l.product_name}`,
      productResults: [],
      productOpen:    false,
      qty:            String(l.qty),
      unit_price:     String(l.unit_price),
      discount_pct:   String(l.discount_pct),
      price_source:   l.price_source,
      priceLoading:   false,
      priceData:      null,
    }));
    // Append to existing lines, but drop any trailing blank placeholder first
    setLines(prev => {
      const filled = prev.filter(l => l.product !== null);
      return [...filled, ...newLines].length ? [...filled, ...newLines] : [newLine()];
    });
    setRepeatPanelOpen(false);
    markDirty();
    showToast("success", `${order.lines.length} line${order.lines.length !== 1 ? "s" : ""} appended from ${order.order_number}`);
    newLines.forEach(l => {
      if (l.product) resolvePrice(l._key, l.product.id, l.qty);
    });
  };

  // â”€â”€ Totals â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  const totalAmount    = lines.reduce((s, l) => s + lineTotal(l), 0);
  const discountAmount = lines.reduce((s, l) => {
    const qty   = parseFloat(l.qty)          || 0;
    const price = parseFloat(l.unit_price)   || 0;
    const disc  = parseFloat(l.discount_pct) || 0;
    return s + parseFloat((qty * price * disc / 100).toFixed(2));
  }, 0);
  const grossAmount = lines.reduce((s, l) => {
    const qty   = parseFloat(l.qty)        || 0;
    const price = parseFloat(l.unit_price) || 0;
    return s + qty * price;
  }, 0);

  const hasMissingPrice = lines.some(l => l.product && l.price_source === "missing");

  // â”€â”€ Autosave (debounced 2 s) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  useEffect(() => {
    if (!isDirty || !savedOrderId) return;
    if (autoSaveTimer.current) clearTimeout(autoSaveTimer.current);
    autoSaveTimer.current = setTimeout(() => { void autoSave(); }, 2000);
    return () => { if (autoSaveTimer.current) clearTimeout(autoSaveTimer.current); };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isDirty, savedOrderId, lines, deliveryDate, notes]);

  // ── Scheme preview (debounced 600 ms) ───────────────────────────────────────────────────────────────────
  useEffect(() => {
    const cust       = customer;
    const bid        = branchId;
    const validLines = lines.filter(l => l.product && parseFloat(l.qty) > 0);
    if (!cust || !bid || !validLines.length || !token || !orgId) {
      setSchemePreview(null);
      return;
    }
    if (schemeTimer.current) clearTimeout(schemeTimer.current);
    schemeTimer.current = setTimeout(async () => {
      setSchemeLoading(true);
      try {
        const res  = await fetch(`${API_URL}/api/v1/order_pricing/preview`, {
          method: "POST",
          headers: {
            Authorization:       `Bearer ${token}`,
            "X-Organization-Id": orgId,
            "Content-Type":      "application/json",
          },
          body: JSON.stringify({
            customer_id: cust.id,
            branch_id:   parseInt(bid),
            lines: validLines.map(l => ({ product_id: l.product!.id, qty: parseFloat(l.qty) })),
          }),
        });
        const json = await res.json();
        if (res.ok && json.data) setSchemePreview(json.data);
        else setSchemePreview(null);
      } catch {
        setSchemePreview(null);
      } finally {
        setSchemeLoading(false);
      }
    }, 600);
    return () => { if (schemeTimer.current) clearTimeout(schemeTimer.current); };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [customer?.id, branchId, lines]);

  const autoSave = async () => {
    if (!customer || !branchId || !savedOrderId) return;
    const validLines = lines.filter(l => l.product && parseFloat(l.qty) > 0);
    if (!validLines.length) return;
    try {
      await fetch(`${API_URL}/api/v1/sales_orders/${savedOrderId}`, {
        method: "PATCH",
        headers: {
          Authorization: `Bearer ${token}`,
          "X-Organization-Id": orgId!,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          order: {
            delivery_date: deliveryDate || null,
            notes:         notes || null,
            lines: validLines.map(l => ({
              product_id:   l.product!.id,
              qty:          parseFloat(l.qty),
              unit_price:   parseFloat(l.unit_price) || null,
              discount_pct: parseFloat(l.discount_pct) || 0,
            })),
          },
        }),
      });
      setIsDirty(false);
    } catch {
      // silent; user can still manually save
    }
  };

  // â”€â”€ Save â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  const buildOrderBody = () => {
    const validLines = lines.filter(l => l.product && parseFloat(l.qty) > 0);
    return {
      order: {
        customer_id:   customer!.id,
        branch_id:     parseInt(branchId),
        delivery_date: deliveryDate || null,
        notes:         notes || null,
        lines: validLines.map(l => ({
          product_id:   l.product!.id,
          qty:          parseFloat(l.qty),
          unit_price:   parseFloat(l.unit_price) || null,
          discount_pct: parseFloat(l.discount_pct) || 0,
        })),
      },
    };
  };

  const save = async (andSubmit = false) => {
    if (!customer) return showToast("error", "Please select a customer");
    if (!branchId) return showToast("error", "Please select a branch");
    const validLines = lines.filter(l => l.product && parseFloat(l.qty) > 0);
    if (!validLines.length) return showToast("error", "Add at least one order line");

    setSaving(true);
    setSubmitAfter(andSubmit);
    try {
      // Create or update draft
      const isUpdate = !!savedOrderId;
      const url    = isUpdate
        ? `${API_URL}/api/v1/sales_orders/${savedOrderId}`
        : `${API_URL}/api/v1/sales_orders`;
      const method = isUpdate ? "PATCH" : "POST";

      const res  = await fetch(url, {
        method,
        headers: {
          Authorization: `Bearer ${token}`,
          "X-Organization-Id": orgId!,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(buildOrderBody()),
      });
      const json = await res.json();

      if (!res.ok) {
        showToast("error", json.errors?.[0] ?? "Failed to save order");
        return;
      }

      const orderId = json.data?.id;
      if (!orderId) { showToast("error", "Unexpected response"); return; }
      setSavedOrderId(orderId);
      setIsDirty(false);

      if (!isUpdate) {
        trackBusinessEvent(ANALYTICS_EVENTS.ORDER_CREATED, {
          module:      "sales",
          page:        "/orders/new",
          order_id:    orderId,
          items_count: validLines.length,
        });
        orderEvents.create(
          String(orderId),
          customer!.name,
          totalAmount,
          validLines.length
        );
      }

      if (andSubmit) {
        const subRes  = await fetch(`${API_URL}/api/v1/sales_orders/${orderId}/submit`, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${token}`,
            "X-Organization-Id": orgId!,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({}),
        });
        const subJson = await subRes.json();

        if (subRes.ok && subJson.data) {
          trackBusinessEvent(ANALYTICS_EVENTS.ORDER_SUBMITTED, {
            module:   "sales",
            page:     "/orders/new",
            order_id: orderId,
          });
          setCreditResult(subJson.credit ?? null);
          setDraftOrderId(orderId);
          setDraftOrderNum(subJson.data.order_number ?? null);
          setCreditModal(true);
        } else if (!subRes.ok && subJson.code === "credit_blocked") {
          setCreditResult(subJson.credit ?? null);
          setDraftOrderId(orderId);
          setDraftOrderNum(json.data.order_number ?? null);
          setCreditModal(true);
        } else {
          showToast("error", subJson.errors?.[0] ?? "Created but failed to submit");
          router.push(`/orders/${orderId}`);
        }
        return;
      }

      showToast("success", isUpdate ? "Draft updated" : "Draft saved");
      router.push(`/orders/${orderId}`);
    } finally {
      setSaving(false);
    }
  };

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Scheme discount badge map: product_id → cumulative scheme_discount_pct
  const schemeLineMap: Record<number, number> = {};
  schemePreview?.lines.forEach(l => {
    if (l.scheme_discount_pct > 0)
      schemeLineMap[l.product_id] = (schemeLineMap[l.product_id] ?? 0) + l.scheme_discount_pct;
  });

  return (
    <>
    <AppShell>
      {toast && (
        <div className={`fixed top-4 right-4 z-50 rounded-lg px-4 py-3 text-sm text-white shadow-lg ${
          toast.type === "success" ? "bg-success" : "bg-danger"
        }`}>
          {toast.msg}
        </div>
      )}


      <PageHeader title="New Sales Order" description="Create a draft order" />

      {/* Two-panel grid */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 pb-10">

        {/* â”€â”€ LEFT: Customer + Repeat + Lines â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */}
        <div className="lg:col-span-2 space-y-5">

          {/* Customer picker */}
          <Card>
            <CardHeader><CardTitle>Customer</CardTitle></CardHeader>
            <CardContent>
              <div className="relative">
                <label className="text-sm font-medium mb-1 block">Select customer *</label>
                <div className="relative">
                  <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-text-secondary" />
                  <Input
                    placeholder="Search by name or code…"
                    value={customerQuery}
                    onChange={e => handleCustomerInput(e.target.value)}
                    onFocus={() => setCustomerOpen(true)}
                    className="pl-9"
                  />
                </div>
                {customerOpen && customerResults.length > 0 && (
                  <div className="absolute z-20 top-full left-0 right-0 bg-white border border-border rounded-md shadow-lg max-h-48 overflow-y-auto mt-1">
                    {customerResults.map(c => (
                      <button
                        key={c.id}
                        className="w-full text-left px-3 py-2 text-sm hover:bg-muted"
                        onMouseDown={e => { e.preventDefault(); selectCustomer(c); }}
                      >
                        <span className="font-medium">{c.name}</span>
                        <span className="ml-2 text-text-secondary text-xs">{c.code}</span>
                      </button>
                    ))}
                  </div>
                )}
                {customer && (
                  <p className="mt-1.5 text-xs text-success flex items-center gap-1.5">
                    ✓ {customer.name} ({customer.code})
                    {recentLoading && <Loader2 className="h-3 w-3 animate-spin text-text-secondary" />}
                    {recentOrders.length > 0 && !repeatPanelOpen && !recentLoading && (
                      <button
                        type="button"
                        onClick={() => setRepeatPanelOpen(true)}
                        className="ml-1 inline-flex items-center gap-1 text-primary hover:underline"
                      >
                        <History className="h-3 w-3" /> Repeat prev. order
                      </button>
                    )}
                  </p>
                )}
              </div>
            </CardContent>
          </Card>

          {/* Repeat Order panel */}
          {(recentLoading || repeatPanelOpen) && (
            <Card className="border-primary/30 bg-primary/5">
              <CardHeader className="flex flex-row items-center justify-between py-3">
                <CardTitle className="text-sm flex items-center gap-2">
                  <History className="h-4 w-4 text-primary" />
                  Repeat a Previous Order
                  {recentLoading && <Loader2 className="h-3.5 w-3.5 animate-spin text-text-secondary" />}
                </CardTitle>
                <button onClick={() => setRepeatPanelOpen(false)} className="p-1 rounded hover:bg-muted text-text-secondary">
                  <X className="h-4 w-4" />
                </button>
              </CardHeader>
              {!recentLoading && (
                <CardContent className="pt-0">
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    {recentOrders.map(order => (
                      <div key={order.id} className="rounded-lg border border-border bg-white p-3 flex flex-col gap-2">
                        <div className="flex items-start justify-between gap-2">
                          <div>
                            <p className="text-sm font-semibold font-mono">{order.order_number}</p>
                            <p className="text-xs text-text-secondary">
                              {new Date(order.created_at).toLocaleDateString("en-IN", {
                                day: "2-digit", month: "short", year: "numeric",
                              })}
                            </p>
                          </div>
                          <span className={`text-[10px] px-1.5 py-0.5 rounded font-medium capitalize ${
                            order.status === "approved"  ? "bg-success/10 text-success" :
                            order.status === "submitted" ? "bg-primary/10 text-primary" :
                            "bg-muted text-text-secondary"
                          }`}>
                            {order.status}
                          </span>
                        </div>
                        <p className="text-xs text-text-secondary">
                          {order.lines.length} item{order.lines.length !== 1 ? "s" : ""} &nbsp;·&nbsp; {fmtINR(order.total_amount ?? 0)}
                        </p>
                        <ul className="text-xs text-text-secondary space-y-0.5 max-h-16 overflow-y-auto">
                          {order.lines.map((l, i) => (
                            <li key={i} className="truncate">• {l.product_sku} – {l.product_name} × {l.qty}</li>
                          ))}
                        </ul>
                        <Button size="sm" variant="outline" className="w-full mt-1 text-xs h-7" onClick={() => repeatOrder(order)}>
                          <RefreshCw className="h-3 w-3 mr-1" /> Repeat this order
                        </Button>
                      </div>
                    ))}
                  </div>
                </CardContent>
              )}
            </Card>
          )}


          {/* Schemes Panel ─ appears once customer + branch + ≥1 line are filled */}
          {(customer && branchId && lines.some(l => l.product)) && (
            <Card className={schemePreview?.explain.applied.length ? "border-success/40" : "border-border"}>
              <CardHeader className="flex flex-row items-center justify-between py-3">
                <CardTitle className="text-sm flex items-center gap-2">
                  <Tag className="h-4 w-4 text-primary" />
                  Active Schemes
                  {schemeLoading && <Loader2 className="h-3.5 w-3.5 animate-spin text-text-secondary" />}
                  {!schemeLoading && schemePreview && schemePreview.explain.applied.length > 0 && (
                    <span className="inline-flex items-center rounded-full bg-success/10 px-2 py-0.5 text-[10px] font-semibold text-success">
                      {schemePreview.explain.applied.length} applied
                    </span>
                  )}
                </CardTitle>
                {!schemeLoading && schemePreview && (schemePreview.totals.scheme_discount_total + schemePreview.totals.order_scheme_discount) > 0 && (
                  <span className="text-xs font-semibold text-success">
                    Saving {fmtINR(schemePreview.totals.scheme_discount_total + schemePreview.totals.order_scheme_discount)}
                  </span>
                )}
              </CardHeader>
              <CardContent className="pt-0 space-y-3">
                {schemeLoading && (
                  <div className="space-y-2">
                    {[1, 2].map(i => <div key={i} className="h-6 rounded bg-muted animate-pulse" />)}
                  </div>
                )}
                {!schemeLoading && schemePreview &&
                  schemePreview.explain.applied.length === 0 &&
                  schemePreview.freebies.length === 0 &&
                  schemePreview.order_discounts.length === 0 && (
                  <p className="text-xs text-text-secondary">No schemes qualify for this cart yet.</p>
                )}
                {/* Applied */}
                {!schemeLoading && schemePreview && schemePreview.explain.applied.length > 0 && (
                  <div>
                    <p className="text-[10px] font-semibold uppercase tracking-wide text-text-secondary mb-1.5">Applied</p>
                    <div className="flex flex-wrap gap-2">
                      {schemePreview.explain.applied.map(s => (
                        <span key={s.scheme_id} className="inline-flex items-center gap-1 rounded-full bg-success/10 px-2.5 py-1 text-xs font-medium text-success">
                          <CheckCircle className="h-3 w-3 shrink-0" />
                          {s.name}
                          {s.message && <span className="ml-0.5 text-[10px] opacity-70">· {s.message}</span>}
                        </span>
                      ))}
                    </div>
                  </div>
                )}
                {/* Freebies */}
                {!schemeLoading && schemePreview && schemePreview.freebies.length > 0 && (
                  <div>
                    <p className="text-[10px] font-semibold uppercase tracking-wide text-text-secondary mb-1.5">Free Items</p>
                    <div className="space-y-1.5">
                      {schemePreview.freebies.map((f, i) => {
                        const alreadyAdded = lines.some(l => l.product?.id === f.product_id && l.unit_price === "0");
                        return (
                          <div key={i} className="flex items-center justify-between rounded-md border border-success/20 bg-success/5 px-3 py-2 gap-3">
                            <div className="min-w-0">
                              <p className="text-sm font-medium text-text-primary truncate">
                                {f.product_name ?? `Product #${f.product_id}`}
                                {f.product_sku && (
                                  <span className="ml-1.5 font-mono text-xs text-text-secondary">{f.product_sku}</span>
                                )}
                              </p>
                              <div className="flex items-center gap-1.5 mt-0.5">
                                <span className="text-xs font-semibold text-success">×{f.qty_free} FREE</span>
                                <span className="text-[10px] bg-success/10 text-success px-1.5 py-0.5 rounded-full">
                                  {f.scheme_name ?? f.scheme_code}
                                </span>
                              </div>
                            </div>
                            <Button
                              size="sm" variant="outline"
                              className="h-6 text-[10px] px-2 border-success/40 text-success hover:bg-success/10"
                              onClick={() => void addFreebieToCart(f)}
                              disabled={alreadyAdded}
                            >
                              {alreadyAdded ? "Added ✓" : "+ Add Free"}
                            </Button>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                )}
                {/* Order discounts */}
                {!schemeLoading && schemePreview && schemePreview.order_discounts.length > 0 && (
                  <div>
                    <p className="text-[10px] font-semibold uppercase tracking-wide text-text-secondary mb-1.5">Order Discounts</p>
                    <div className="space-y-1">
                      {schemePreview.order_discounts.map((d, i) => {
                        const name = schemePreview.explain.applied.find(a => a.scheme_id === d.scheme_id)?.name;
                        return (
                          <div key={i} className="flex items-center justify-between rounded-md border border-primary/20 bg-primary/5 px-3 py-1.5 text-xs">
                            <span className="text-text-secondary">{name ?? `Scheme #${d.scheme_id}`}</span>
                            <span className="font-semibold text-primary">−{fmtINR(d.amount)}</span>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                )}
                {/* Near-misses — expanded, now actionable with Quick Apply */}
                {!schemeLoading && schemePreview && schemePreview.explain.not_applied.length > 0 && (
                  <details className="group" open>
                    <summary className="cursor-pointer select-none list-none flex items-center gap-1 text-[10px] font-semibold uppercase tracking-wide text-text-secondary">
                      <span className="inline-block transition-transform group-open:rotate-90">›</span>
                      {schemePreview.explain.not_applied.length} scheme{schemePreview.explain.not_applied.length !== 1 ? "s" : ""} not yet unlocked
                    </summary>
                    <div className="mt-1.5 space-y-2">
                      {schemePreview.explain.not_applied.map(s => {
                        const prog = parseNearMissProgress(s.reason ?? "");
                        const hint = s.hint;
                        const hasQtyApply = hint &&
                          (hint.type === "increase_qty" || hint.type === "total_qty") &&
                          lines.some(l => l.product && hint.product_ids.includes(l.product.id));
                        return (
                          <div key={s.scheme_id} className="rounded-md border border-border bg-background px-3 py-2 space-y-1.5">
                            <div className="flex items-center justify-between gap-2">
                              <div className="flex items-center gap-1.5 min-w-0">
                                <span className="text-xs font-semibold text-text-primary truncate">{s.name}</span>
                                {prog && (
                                  <span className="text-[10px] tabular-nums text-text-secondary whitespace-nowrap">{prog.pct}%</span>
                                )}
                              </div>
                              {hasQtyApply && hint && (hint.type === "increase_qty" || hint.type === "total_qty") && (
                                <Button
                                  size="sm"
                                  variant="outline"
                                  className="h-6 shrink-0 text-[10px] px-2 border-primary/40 text-primary hover:bg-primary/5 gap-1"
                                  onClick={() => quickApplyScheme(hint, s.name)}
                                >
                                  <Zap className="h-2.5 w-2.5" />
                                  +{hint.gap} qty
                                </Button>
                              )}
                              {hint?.type === "order_value" && (
                                <span className="text-[10px] text-warning whitespace-nowrap shrink-0 font-medium">
                                  Need {fmtINR(hint.gap)} more
                                </span>
                              )}
                            </div>
                            <p className="text-[10px] text-text-secondary">{s.reason}</p>
                            {prog && (
                              <div className="h-1.5 rounded-full bg-border overflow-hidden">
                                <div
                                  className="h-full rounded-full transition-[width] bg-gradient-to-r from-primary/40 to-primary"
                                  style={{ width: `${prog.pct}%` }}
                                />
                              </div>
                            )}
                          </div>
                        );
                      })}
                    </div>
                  </details>
                )}
              </CardContent>
            </Card>
          )}

          {/* Lines */}
          <Card>
            <CardHeader className="flex flex-row items-center justify-between">
              <CardTitle>Order Lines</CardTitle>
              <Button variant="outline" size="sm" onClick={addLine}>
                <Plus className="h-4 w-4 mr-1" /> Add Line
              </Button>
            </CardHeader>
            <CardContent className="overflow-x-auto p-0">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border text-left text-text-secondary text-xs">
                    <th className="pb-2 pt-3 px-4 min-w-[220px]">Product</th>
                    <th className="pb-2 pt-3 px-2 w-[110px]">Qty</th>
                    <th className="pb-2 pt-3 px-2 w-[120px]">Unit Price</th>
                    <th className="pb-2 pt-3 px-2 w-[80px]">Disc %</th>
                    <th className="pb-2 pt-3 px-2 w-[100px] text-right">Subtotal</th>
                    <th className="pb-2 pt-3 px-2 w-[90px]">Source</th>
                    <th className="pb-2 pt-3 px-2 w-[36px]" />
                  </tr>
                </thead>
                <tbody>
                  {lines.map(line => (
                    <tr key={line._key} className="border-b border-border/50 last:border-0 hover:bg-muted/20">
                      {/* Product */}
                      <td className="py-2 px-4 relative">
                        <div className="relative">
                          <Input
                            placeholder="Search SKU or name…"
                            value={line.productQuery}
                            onChange={e => handleProductInput(line._key, e.target.value)}
                            onFocus={() => setLines(prev => prev.map(l => l._key === line._key ? { ...l, productOpen: true } : l))}
                            className="text-sm"
                          />
                          {line.productOpen && line.productResults.length > 0 && (
                            <div className="absolute z-20 top-full left-0 right-0 bg-white border border-border rounded-md shadow-lg max-h-48 overflow-y-auto mt-1">
                              {line.productResults.map(p => (
                                <button
                                  key={p.id}
                                  className="w-full text-left px-3 py-2 text-sm hover:bg-muted"
                                  onMouseDown={e => { e.preventDefault(); selectProduct(line._key, p); }}
                                >
                                  <span className="font-mono font-medium">{p.sku}</span>
                                  <span className="ml-2 text-text-secondary">{p.name}</span>
                                </button>
                              ))}
                            </div>
                          )}
                        </div>
                      </td>

                      {/* Qty stepper */}
                      <td className="py-2 px-2">
                        <div className="flex items-center border border-border rounded-md overflow-hidden">
                          <button
                            type="button"
                            onClick={() => stepQty(line._key, -1)}
                            className="px-2 py-1.5 text-text-secondary hover:bg-muted transition-colors"
                          >
                            <Minus className="h-3 w-3" />
                          </button>
                          <input
                            type="number"
                            min="0.001"
                            step="1"
                            value={line.qty}
                            onChange={e => updateLine(line._key, "qty", e.target.value)}
                            className="w-12 text-center text-sm border-0 focus:outline-none bg-transparent py-1.5"
                          />
                          <button
                            type="button"
                            onClick={() => stepQty(line._key, 1)}
                            className="px-2 py-1.5 text-text-secondary hover:bg-muted transition-colors"
                          >
                            <Plus className="h-3 w-3" />
                          </button>
                        </div>
                      </td>

                      {/* Unit price */}
                      <td className="py-2 px-2">
                        <div className="relative">
                          <Input
                            type="number"
                            min="0"
                            step="0.01"
                            value={line.unit_price}
                            onChange={e => updateLine(line._key, "unit_price", e.target.value)}
                            placeholder={line.priceLoading ? "…" : "0.00"}
                            className="text-sm pr-6"
                          />
                          {line.priceLoading && (
                            <Loader2 className="absolute right-2 top-1/2 -translate-y-1/2 h-3 w-3 animate-spin text-text-secondary" />
                          )}
                        </div>
                        {line.product && (schemeLineMap[line.product.id] ?? 0) > 0 && (
                          <p className="mt-0.5 text-[10px] font-medium text-success text-right tabular-nums">
                            −{schemeLineMap[line.product.id].toFixed(2)}% scheme
                          </p>
                        )}
                      </td>

                      {/* Discount */}
                      <td className="py-2 px-2">
                        <Input
                          type="number"
                          min="0"
                          max="100"
                          step="0.01"
                          value={line.discount_pct}
                          onChange={e => updateLine(line._key, "discount_pct", e.target.value)}
                          className="text-sm"
                        />
                      </td>

                      {/* Subtotal */}
                      <td className="py-2 px-2 text-right font-medium tabular-nums">
                        {fmtINR(lineTotal(line))}
                      </td>

                      {/* Price source badge (clickable â†’ Why this price?) */}
                      <td className="py-2 px-2">
                        {line.product && (
                          <button
                            type="button"
                            title="Why this price?"
                            onClick={() => line.product && setPriceModal({ product: line.product, line })}
                            className={`inline-flex items-center gap-1 text-[10px] px-1.5 py-0.5 rounded font-medium transition-opacity hover:opacity-80 ${
                              PRICE_SOURCE_COLOR[line.price_source] ?? "bg-muted text-text-secondary"
                            }`}
                          >
                            {PRICE_SOURCE_LABEL[line.price_source] ?? line.price_source}
                            <Info className="h-2.5 w-2.5 shrink-0" />
                          </button>
                        )}
                      </td>

                      {/* Remove */}
                      <td className="py-2 px-2">
                        {lines.length > 1 && (
                          <button
                            onClick={() => removeLine(line._key)}
                            className="p-1 rounded hover:bg-danger/10 text-danger"
                          >
                            <Trash2 className="h-3.5 w-3.5" />
                          </button>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>

              <div className="flex justify-end gap-2 px-4 py-3 border-t border-border text-sm">
                <div className="text-right space-y-1">
                  <div className="flex items-center justify-end gap-8">
                    <span className="text-text-secondary">Gross</span>
                    <span className="tabular-nums w-28 text-right">{fmtINR(grossAmount)}</span>
                  </div>
                  <div className="flex items-center justify-end gap-8">
                    <span className="text-text-secondary">Discount</span>
                    <span className="tabular-nums w-28 text-right text-danger">−{fmtINR(discountAmount)}</span>
                  </div>
                  <div className="flex items-center justify-end gap-8 pt-1 border-t border-border">
                    <span className="font-semibold">Net Total</span>
                    <span className="tabular-nums w-28 text-right font-bold text-base">{fmtINR(totalAmount)}</span>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* â”€â”€ RIGHT: Branch + Details + Summary + Actions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */}
        <div className="space-y-4">

          {/* Branch, delivery date, notes */}
          <Card>
            <CardHeader><CardTitle>Order Details</CardTitle></CardHeader>
            <CardContent className="space-y-4">
              <div>
                <label className="text-sm font-medium mb-1 block">Branch *</label>
                <select
                  value={branchId}
                  onChange={e => {
                    setBranchId(e.target.value);
                    branchIdRef.current = e.target.value;
                    markDirty();
                  }}
                  className="w-full rounded-md border border-border px-3 py-2 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-primary"
                >
                  <option value="">— Select branch —</option>
                  {branches.map(b => (
                    <option key={b.id} value={String(b.id)}>{b.name}</option>
                  ))}
                </select>
              </div>

              <div>
                <label className="text-sm font-medium mb-1 block">Delivery Date</label>
                <Input
                  type="date"
                  value={deliveryDate}
                  min={new Date().toISOString().split("T")[0]}
                  onChange={e => { setDeliveryDate(e.target.value); markDirty(); }}
                />
              </div>

              {/* <div>
                <label className="text-sm font-medium mb-1 block">Notes</label>
                <textarea
                  rows={3}
                  placeholder="Optional notes…"
                  value={notes}
                  onChange={e => { setNotes(e.target.value); markDirty(); }}
                  className="w-full rounded-md border border-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary resize-none"
                />
              </div> */}
            </CardContent>
          </Card>

          {/* Summary */}
          <Card>
            <CardHeader><CardTitle>Summary</CardTitle></CardHeader>
            <CardContent className="space-y-3 text-sm">
              <div className="flex justify-between">
                <span className="text-text-secondary">Lines</span>
                <span className="font-medium">{lines.filter(l => l.product).length}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-text-secondary">Gross</span>
                <span className="tabular-nums">{fmtINR(grossAmount)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-text-secondary">Discount</span>
                <span className="tabular-nums text-danger">−{fmtINR(discountAmount)}</span>
              </div>
              {schemePreview && schemePreview.totals.scheme_discount_total > 0 && (
                <div className="flex justify-between text-success">
                  <span>Scheme Savings</span>
                  <span className="tabular-nums font-medium">−{fmtINR(schemePreview.totals.scheme_discount_total)}</span>
                </div>
              )}
              <div className="flex justify-between pt-2 border-t border-border">
                <span className="font-semibold">Net Total</span>
                <span className="tabular-nums font-bold text-base">{fmtINR(totalAmount)}</span>
              </div>

              {/* Available credit */}
              {availableCredit !== null && (
                <div className={`rounded-md px-3 py-2 text-xs border ${
                  availableCredit < totalAmount
                    ? "bg-danger/10 border-danger/30 text-danger"
                    : "bg-success/10 border-success/30 text-success"
                }`}>
                  <div className="flex justify-between">
                    <span>Available Credit</span>
                    <span className="tabular-nums font-semibold">{fmtINR(availableCredit)}</span>
                  </div>
                  {availableCredit < totalAmount && (
                    <p className="mt-0.5">Draft total exceeds available credit. Credit check runs on submit.</p>
                  )}
                </div>
              )}

              {hasMissingPrice && (
                <div className="rounded-md bg-warning/10 border border-warning/30 px-3 py-2 text-xs text-warning">
                  ⚠ Some lines are missing a price. Resolve before submitting.
                </div>
              )}

              {savedOrderId && !isDirty && (
                <div className="text-xs text-success flex items-center gap-1">
                  ✓ Draft auto-saved
                </div>
              )}
            </CardContent>
          </Card>

          {/* Actions */}
          <div className="space-y-2">
            <Button
              className="w-full"
              onClick={() => save(true)}
              disabled={saving}
            >
              {saving && submitAfter
                ? <Loader2 className="h-4 w-4 animate-spin mr-1" />
                : null}
              Save &amp; Submit
            </Button>

            {isDirty && (
              <Button
                variant="outline"
                className="w-full"
                onClick={() => save(false)}
                disabled={saving}
              >
                {saving && !submitAfter
                  ? <Loader2 className="h-4 w-4 animate-spin mr-1" />
                  : null}
                Save Draft
              </Button>
            )}

            <Button
              variant="ghost"
              className="w-full text-text-secondary"
              onClick={() => router.push("/orders")}
            >
              Discard
            </Button>
          </div>
        </div>
      </div>
    </AppShell>

    {/* Credit decision modal */}
    <CreditDecisionModal
      open={creditModal}
      onClose={() => setCreditModal(false)}
      credit={creditResult}
      orderId={draftOrderId ?? undefined}
      orderNumber={draftOrderNum ?? undefined}
      customerId={customer?.id}
    />

    {/* "Why this price?" modal */}
    <Modal
      open={!!priceModal}
      onClose={() => setPriceModal(null)}
      title="Why this price?"
      size="sm"
    >
      {priceModal && (
        <div className="space-y-3 text-sm">
          <div>
            <p className="font-medium">{priceModal.product.sku} — {priceModal.product.name}</p>
            <p className="text-xs text-text-secondary mt-0.5">GST: {priceModal.product.gst_rate}%</p>
          </div>

          <div className="rounded-lg border border-border bg-muted/30 p-3 space-y-2">
            <Row label="Price Source"  value={PRICE_SOURCE_LABEL[priceModal.line.price_source] ?? priceModal.line.price_source} />
            <Row label="Unit Price"    value={fmtINR(parseFloat(priceModal.line.unit_price) || 0)} />
            <Row label="Discount"      value={`${priceModal.line.discount_pct}%`} />
            {priceModal.line.priceData?.price_list_name && (
              <Row label="Price List" value={priceModal.line.priceData.price_list_name} />
            )}
            {priceModal.line.priceData?.min_qty && (
              <Row label="Min Qty Rule" value={String(priceModal.line.priceData.min_qty)} />
            )}
            {priceModal.line.priceData?.valid_until && (
              <Row label="Valid Until" value={new Date(priceModal.line.priceData.valid_until).toLocaleDateString("en-IN")} />
            )}
          </div>

          <p className="text-xs text-text-secondary">
            Prices are resolved at the time of adding a product and refreshed on submit.
            Manual overrides are preserved at submit.
          </p>
        </div>
      )}
    </Modal>
    </>
  );
}

function parseNearMissProgress(reason: string): { pct: number } | null {
  const m = reason.match(/(\d+(?:\.\d+)?)\s*<\s*(?:minimum|min)\s*(\d+(?:\.\d+)?)/i);
  if (!m) return null;
  const threshold = parseFloat(m[2]);
  if (threshold <= 0) return null;
  return { pct: Math.min(99, Math.round((parseFloat(m[1]) / threshold) * 100)) };
}

function Row({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="flex items-center gap-2 text-sm">
      <span className="w-28 text-text-secondary shrink-0">{label}</span>
      <span className="flex-1 font-medium">{value}</span>
    </div>
  );
}

