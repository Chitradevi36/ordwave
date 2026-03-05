"use client";

import { useState, useEffect, useCallback } from "react";
import { useParams, useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Modal } from "@/components/ui/modal";
import { Tabs } from "@/components/ui/tabs";
import {
  Phone, Mail, MapPin, User, CreditCard, Edit, Trash2,
  AlertTriangle, Tag, UserCheck, Ban, CheckCircle2, Flag, History,
  TrendingUp, ExternalLink, ShoppingCart, ArrowRight,
} from "lucide-react";
import { Breadcrumb } from "@/components/ui/breadcrumb";
import { useOrgBranch } from "@/lib/org-branch-context";

// ─── Types ───────────────────────────────────────────────────────────────────
interface Address {
  id: number; label: string; line1: string; line2?: string;
  city: string; state: string; postal_code: string; country: string;
}
interface Contact {
  id: number; name: string; phone?: string; email?: string;
  designation?: string; is_primary: boolean;
}
interface CreditAccount {
  id: number; credit_limit: number; current_balance: number;
  available_credit: number; overdue_amount: number; overdue_days: number;
  collection_first?: boolean; hold_required?: boolean; watchlist?: boolean;
  overdue_bucket?: string;
}

interface LimitRequest {
  id: number; new_limit: number; status: string;
  reason: string; requested_by: string; decided_by: string | null;
  created_at: string; decision_note: string | null;
  counter_offer_limit: number | null;
}
interface CustomerDetail {
  id: number; name: string; code: string; channel: string; tier: string; status: string;
  phone: string | null; email: string | null; gstin: string | null; pan: string | null;
  credit_limit: number; branch_id: number;
  customer_type: string;
  visit_frequency: string | null;
  credit_days: number;
  credit_block_rule: string;
  opening_balance: string;
  tag_list: string[];
  route: { id: number; name: string; code: string } | null;
  sales_rep: { id: number; name: string; email: string } | null;
  credit_account: CreditAccount | null;
  addresses: Address[];
  contacts: Contact[];
}

const CHANNEL_LABEL: Record<string, string> = {
  general_trade: "General Trade", modern_trade: "Modern Trade", horeca: "HoReCa",
  pharmacy: "Pharmacy", electronics: "Electronics", wholesale: "Wholesale", distributor: "Distributor",
};
const CUSTOMER_TYPE_LABEL: Record<string, string> = {
  retailer: "Retailer", wholesaler: "Wholesaler", distributor: "Distributor",
  institution: "Institution", horeca: "HoReCa",
};
const VISIT_FREQ_LABEL: Record<string, string> = {
  daily: "Daily", weekly: "Weekly", biweekly: "Bi-weekly",
  monthly: "Monthly", quarterly: "Quarterly",
};
const TIER_VARIANT: Record<string, "default" | "secondary" | "warning" | "outline"> = {
  platinum: "default", gold: "warning", silver: "secondary", bronze: "outline",
};

// ─── Sub-components ───────────────────────────────────────────────────────────
function OverviewTab({ customer, editHref }: { customer: CustomerDetail; editHref: string }) {
  const missingOptional = !customer.gstin && !customer.sales_rep && !customer.visit_frequency && !customer.email;
  return (
    <div className="space-y-4">
      {missingOptional && (
        <div className="flex items-start gap-3 rounded-md bg-warning/10 border border-warning/20 px-4 py-3 text-sm text-warning">
          <AlertTriangle className="h-4 w-4 mt-0.5 shrink-0" />
          <div>
            <p className="font-medium">Profile incomplete</p>
            <p className="text-xs mt-0.5 text-text-secondary">
              Add GSTIN, email, sales rep and visit frequency to complete this customer&apos;s profile.{" "}
              <a href={editHref} className="text-accent underline">Edit customer →</a>
            </p>
          </div>
        </div>
      )}
      <div className="grid gap-4 sm:grid-cols-2">
        <Card>
          <CardHeader><CardTitle className="text-sm">Details</CardTitle></CardHeader>
          <CardContent className="space-y-2 text-sm">
            <Row label="Code"          value={customer.code} />
            <Row label="Type"          value={CUSTOMER_TYPE_LABEL[customer.customer_type] ?? customer.customer_type} />
            <Row label="Channel"       value={CHANNEL_LABEL[customer.channel] ?? customer.channel} />
            <Row label="Tier"          value={<Badge variant={TIER_VARIANT[customer.tier] ?? "outline"}>{customer.tier}</Badge>} />
            <Row label="Route"         value={customer.route ? `${customer.route.name} (${customer.route.code})` : <MissingHint href={editHref} text="No route" />} />
            <Row label="Sales Rep"     value={customer.sales_rep ? customer.sales_rep.name : <MissingHint href={editHref} text="Not assigned" />} />
            <Row label="Visit Freq"    value={customer.visit_frequency ? VISIT_FREQ_LABEL[customer.visit_frequency] ?? customer.visit_frequency : <MissingHint href={editHref} text="Not set" />} />
            {customer.gstin && <Row label="GSTIN" value={customer.gstin} />}
            {customer.pan   && <Row label="PAN"   value={customer.pan} />}
            {!customer.gstin && !customer.pan && (
              <Row label="Tax Info" value={<MissingHint href={editHref} text="No GSTIN / PAN added" />} />
            )}
          </CardContent>
        </Card>

        <div className="space-y-4">
          <Card>
            <CardHeader><CardTitle className="text-sm">Contact Info</CardTitle></CardHeader>
            <CardContent className="space-y-2 text-sm">
              {customer.phone && (
                <div className="flex items-center gap-2 text-text-secondary">
                  <Phone className="h-3.5 w-3.5" /><span>{customer.phone}</span>
                </div>
              )}
              {customer.email && (
                <div className="flex items-center gap-2 text-text-secondary">
                  <Mail className="h-3.5 w-3.5" /><span>{customer.email}</span>
                </div>
              )}
              {!customer.phone && !customer.email && (
                <p className="text-xs text-text-secondary">
                  No contact info.{" "}
                  <a href={editHref} className="text-accent hover:underline">Add via Edit →</a>
                </p>
              )}
            </CardContent>
          </Card>

          {customer.tag_list?.length > 0 && (
            <Card>
              <CardHeader><CardTitle className="text-sm flex items-center gap-1.5"><Tag className="h-3.5 w-3.5" /> Tags</CardTitle></CardHeader>
              <CardContent>
                <div className="flex flex-wrap gap-1.5">
                  {customer.tag_list.map((tag) => (
                    <Badge key={tag} variant="outline" className="text-xs">{tag}</Badge>
                  ))}
                </div>
              </CardContent>
            </Card>
          )}
        </div>
      </div>
    </div>
  );
}

function MissingHint({ href, text }: { href: string; text: string }) {
  return (
    <span className="text-text-secondary">
      {text} · <a href={href} className="text-accent hover:underline text-xs">Add →</a>
    </span>
  );
}

function ContactsTab({ contacts, editHref }: { contacts: Contact[]; editHref: string }) {
  if (!contacts.length) return (
    <div className="rounded-lg border border-dashed border-border p-8 text-center">
      <UserCheck className="h-8 w-8 mx-auto text-text-secondary mb-3" />
      <p className="text-sm font-medium text-text-primary">No contacts yet</p>
      <p className="text-xs text-text-secondary mt-1">Add contacts to track key people at this customer location.</p>
      <a href={editHref}
        className="mt-3 inline-flex items-center gap-1.5 text-sm text-accent hover:underline">
        <Edit className="h-3.5 w-3.5" /> Add contacts via Edit
      </a>
    </div>
  );
  return (
    <div className="space-y-3">
      {contacts.map((c) => (
        <Card key={c.id}>
          <CardContent className="pt-4 space-y-1">
            <div className="flex items-center gap-2">
              <User className="h-4 w-4 text-text-secondary" />
              <span className="font-medium text-text-primary">{c.name}</span>
              {c.is_primary && <Badge variant="default">Primary</Badge>}
            </div>
            {c.designation && <p className="text-xs text-text-secondary pl-6">{c.designation}</p>}
            {c.phone && (
              <div className="flex items-center gap-2 text-xs text-text-secondary pl-6">
                <Phone className="h-3 w-3" />{c.phone}
              </div>
            )}
            {c.email && (
              <div className="flex items-center gap-2 text-xs text-text-secondary pl-6">
                <Mail className="h-3 w-3" />{c.email}
              </div>
            )}
          </CardContent>
        </Card>
      ))}
    </div>
  );
}

function AddressesTab({ addresses, editHref }: { addresses: Address[]; editHref: string }) {
  if (!addresses.length) return (
    <div className="rounded-lg border border-dashed border-border p-8 text-center">
      <MapPin className="h-8 w-8 mx-auto text-text-secondary mb-3" />
      <p className="text-sm font-medium text-text-primary">No addresses yet</p>
      <p className="text-xs text-text-secondary mt-1">Add billing, shipping or other addresses for this customer.</p>
      <a href={editHref}
        className="mt-3 inline-flex items-center gap-1.5 text-sm text-accent hover:underline">
        <Edit className="h-3.5 w-3.5" /> Add addresses via Edit
      </a>
    </div>
  );
  return (
    <div className="space-y-3">
      {addresses.map((a) => (
        <Card key={a.id}>
          <CardContent className="pt-4 space-y-1">
            <div className="flex items-center gap-2">
              <MapPin className="h-4 w-4 text-text-secondary" />
              <Badge variant="outline" className="capitalize">{a.label}</Badge>
            </div>
            <p className="text-sm text-text-primary pl-6">{a.line1}{a.line2 ? `, ${a.line2}` : ""}</p>
            <p className="text-xs text-text-secondary pl-6">{a.city}, {a.state} {a.postal_code}, {a.country}</p>
          </CardContent>
        </Card>
      ))}
    </div>
  );
}

interface ContributingOrder {
  id:           number;
  order_number: string;
  status:       string;
  total_amount: number;
  created_at:   string;
}

interface CreditUsageDetail {
  credit_limit:         number;
  invoice_outstanding:  number;
  order_exposure:       number;
  hold_exposure:        number;
  credit_used_total:    number;
  available_credit:     number;
  contributing_orders:  ContributingOrder[];
  breakdown: {
    orders_count_exposure: number;
    orders_count_hold:     number;
  };
}

function CreditTab({ credit, editHref, creditDays, creditBlockRule, customerId }: {
  credit: CreditAccount | null; editHref: string; creditDays?: number;
  creditBlockRule?: string; customerId: string;
}) {
  const { token, orgId } = useOrgBranch();

  // ── Credit usage (order exposure + invoice outstanding + contributing orders)
  const [creditUsage, setCreditUsage]               = useState<CreditUsageDetail | null>(null);
  const [creditUsageLoading, setCreditUsageLoading] = useState(false);

  useEffect(() => {
    if (!credit || !token || !orgId) return;
    setCreditUsageLoading(true);
    fetch(`http://localhost:3001/api/v1/customers/${customerId}/credit_usage`, {
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    })
      .then((r) => r.json())
      .then((j) => { if (j.data) setCreditUsage(j.data); })
      .finally(() => setCreditUsageLoading(false));
  }, [credit, token, orgId, customerId]);

  // ── Manager-level check (owner/admin/manager may toggle flags) ────────────
  const [isManager, setIsManager] = useState(false);
  useEffect(() => {
    if (!token || !orgId) return;
    fetch("http://localhost:3001/api/v1/profile", {
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    })
      .then((r) => r.json())
      .then((j) => {
        const orgs: { id: number; role: string }[] = j.data?.organizations ?? [];
        const membership = orgs.find((o) => String(o.id) === orgId);
        const role = membership?.role ?? "";
        setIsManager(["owner", "admin", "manager"].includes(role));
      })
      .catch(() => {});
  }, [token, orgId]);

  // ── Flags state ───────────────────────────────────────────────────────────
  const [flags, setFlags] = useState({
    collection_first: credit?.collection_first ?? false,
    hold_required:    credit?.hold_required    ?? false,
    watchlist:        credit?.watchlist        ?? false,
  });
  useEffect(() => {
    if (credit) {
      setFlags({
        collection_first: credit.collection_first ?? false,
        hold_required:    credit.hold_required    ?? false,
        watchlist:        credit.watchlist        ?? false,
      });
    }
  }, [credit]);

  // Flag confirm modal state
  const [flagConfirm, setFlagConfirm] = useState<{
    flagKey: "collection_first" | "hold_required" | "watchlist";
    label:    string;
    newValue: boolean;
  } | null>(null);
  const [flagReason, setFlagReason]         = useState("");
  const [flagSubmitting, setFlagSubmitting] = useState(false);

  const commitFlagChange = async () => {
    if (!flagConfirm || !credit || !token || !orgId) return;
    setFlagSubmitting(true);
    const newFlags = { ...flags, [flagConfirm.flagKey]: flagConfirm.newValue };
    try {
      const res = await fetch(
        `http://localhost:3001/api/v1/credit_accounts/${credit.id}/update_flags`,
        {
          method: "PATCH",
          headers: {
            Authorization: `Bearer ${token}`,
            "X-Organization-Id": orgId,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ credit_account: newFlags, reason: flagReason }),
        }
      );
      if (res.ok) {
        setFlags(newFlags);
        showToast("success", `${flagConfirm.label} ${flagConfirm.newValue ? "enabled" : "disabled"}.`);
      } else {
        showToast("error", "Failed to update flag. Check your permissions.");
      }
    } finally {
      setFlagSubmitting(false);
      setFlagConfirm(null);
      setFlagReason("");
    }
  };

  // ── Limit request state ───────────────────────────────────────────────────
  const [showRequestModal, setShowRequestModal] = useState(false);
  const [reqForm, setReqForm]     = useState({ new_limit: "", reason: "", notes: "" });
  const [submittingReq, setSubmittingReq] = useState(false);

  const [history, setHistory]           = useState<LimitRequest[]>([]);
  const [historyLoading, setHistoryLoading] = useState(false);

  const [toast, setToast] = useState<{ type: "success" | "error"; msg: string } | null>(null);
  const showToast = (type: "success" | "error", msg: string) => {
    setToast({ type, msg });
    setTimeout(() => setToast(null), 3500);
  };

  const fetchHistory = useCallback(async () => {
    if (!credit || !token || !orgId) return;
    setHistoryLoading(true);
    try {
      const res  = await fetch(
        `http://localhost:3001/api/v1/credit_limit_change_requests?credit_account_id=${credit.id}`,
        { headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId } }
      );
      const json = await res.json();
      if (res.ok) setHistory(json.data ?? []);
    } finally {
      setHistoryLoading(false);
    }
  }, [credit, token, orgId]);

  useEffect(() => { fetchHistory(); }, [fetchHistory]);

  const handleRequestLimit = async () => {
    if (!credit || !token || !orgId) return;
    setSubmittingReq(true);
    try {
      const res = await fetch(
        `http://localhost:3001/api/v1/credit_accounts/${credit.id}/limit_change_requests`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${token}`,
            "X-Organization-Id": orgId,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            credit_limit_change_request: {
              new_limit: Number(reqForm.new_limit),
              reason:    reqForm.reason,
              notes:     reqForm.notes || undefined,
            },
          }),
        }
      );
      const json = await res.json();
      if (res.ok) {
        showToast("success", "Limit change request submitted.");
        setShowRequestModal(false);
        setReqForm({ new_limit: "", reason: "", notes: "" });
        fetchHistory();
      } else {
        showToast("error", json.errors?.join(", ") ?? "Submission failed");
      }
    } finally {
      setSubmittingReq(false);
    }
  };

  // ── Derived numeric values ────────────────────────────────────────────────
  if (!credit) return (
    <div className="rounded-lg border border-dashed border-border p-8 text-center">
      <CreditCard className="h-8 w-8 mx-auto text-text-secondary mb-3" />
      <p className="text-sm font-medium text-text-primary">No credit account</p>
      <p className="text-xs text-text-secondary mt-1">Set a credit limit to enable credit sales for this customer.</p>
      <a href={editHref} className="mt-3 inline-flex items-center gap-1.5 text-sm text-accent hover:underline">
        <Edit className="h-3.5 w-3.5" /> Set credit policy via Edit
      </a>
    </div>
  );

  // Always use enriched figures when available; fall back to credit_account fields.
  const creditLimitN   = creditUsage ? creditUsage.credit_limit     : Number(credit.credit_limit);
  const creditUsedN    = creditUsage ? creditUsage.credit_used_total : Number(credit.current_balance);
  const availableN     = creditUsage ? creditUsage.available_credit  : Number(credit.available_credit);
  const overdueN       = Number(credit.overdue_amount);
  const overduedays    = Number(credit.overdue_days);

  const utilPct = creditLimitN > 0
    ? Math.min(100, Math.round((creditUsedN / creditLimitN) * 100))
    : 0;
  const utilColor = utilPct >= 80 ? "bg-danger" : utilPct >= 60 ? "bg-warning" : "bg-success";
  const utilTextColor = utilPct >= 80 ? "text-danger" : utilPct >= 60 ? "text-warning" : "text-success";

  const showPaymentCTA = overdueN > 0 || utilPct >= 80;

  const fmt = (n: number) => `₹${n.toLocaleString("en-IN", { maximumFractionDigits: 0 })}`;

  const STATUS_VARIANT: Record<string, "default" | "secondary" | "warning" | "outline"> = {
    pending: "warning", approved: "default", rejected: "secondary", countered: "outline",
  };

  const ORDER_STATUS_VARIANT: Record<string, "default" | "secondary" | "warning" | "outline"> = {
    submitted: "outline", approved: "default", on_hold: "warning",
  };

  // Suggested limit for modal pre-fill
  const suggestedLimit = creditUsage
    ? Math.ceil((creditUsage.credit_used_total * 1.15) / 1000) * 1000
    : undefined;

  const contribOrders = creditUsage?.contributing_orders ?? [];
  const totalExposureOrders = creditUsage?.breakdown.orders_count_exposure ?? 0;

  return (
    <div className="space-y-5">
      {/* ── Toast ──────────────────────────────────────────────────────────── */}
      {toast && (
        <div className={`rounded-md border px-4 py-2.5 text-sm ${
          toast.type === "success"
            ? "bg-success/10 border-success/20 text-success"
            : "bg-danger/10 border-danger/20 text-danger"
        }`}>{toast.msg}</div>
      )}

      {/* ── Section A: Credit Overview ─────────────────────────────────────── */}
      <div className="flex items-start justify-between gap-3 flex-wrap">
        <div>
          <h3 className="text-sm font-semibold text-text-primary flex items-center gap-1.5">
            <CreditCard className="h-4 w-4 text-accent" />
            Credit Overview
          </h3>
          {credit.overdue_bucket && credit.overdue_bucket !== "current" && (
            <p className="text-xs text-warning mt-0.5 capitalize">
              Overdue bucket: {credit.overdue_bucket.replace(/_/g, " ")}
            </p>
          )}
        </div>
        {/* Smart primary CTAs */}
        <div className="flex gap-2 flex-wrap">
          {showPaymentCTA && (
            <Button
              size="sm"
              onClick={() => showToast("error", "Payment collection module coming soon. Please record via Finance.")}
            >
              Record Payment
            </Button>
          )}
          <Button
            size="sm"
            variant={showPaymentCTA ? "outline" : undefined}
            onClick={() => {
              if (suggestedLimit) setReqForm((p) => ({ ...p, new_limit: String(suggestedLimit) }));
              setShowRequestModal(true);
            }}
          >
            Request Limit Change
          </Button>
        </div>
      </div>

      {/* 4 overview cards */}
      {creditUsageLoading ? (
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          {["Credit Limit", "Credit Used", "Available Credit", "Overdue"].map((l) => (
            <Card key={l}>
              <CardContent className="pt-4">
                <p className="text-xs text-text-secondary">{l}</p>
                <div className="h-5 mt-1 w-24 rounded bg-border animate-pulse" />
              </CardContent>
            </Card>
          ))}
        </div>
      ) : (
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <StatCard label="Credit Limit"    value={fmt(creditLimitN)} />
          <StatCard
            label="Credit Used"
            value={fmt(creditUsedN)}
            sub={`${utilPct}% used`}
            color={utilTextColor}
          />
          <StatCard
            label="Available Credit"
            value={fmt(availableN)}
            color={availableN <= 0 ? "text-danger" : "text-success"}
          />
          <StatCard
            label="Overdue"
            value={fmt(overdueN)}
            sub={overduedays > 0 ? `${overduedays}d overdue` : undefined}
            color={overdueN > 0 ? "text-danger" : undefined}
          />
        </div>
      )}

      {/* Utilization bar */}
      <Card>
        <CardContent className="pt-4 pb-3">
          <div className="flex justify-between items-baseline text-sm mb-2">
            <span className="font-medium text-text-primary">
              {fmt(creditUsedN)}{" "}
              <span className="text-text-secondary font-normal">used of {fmt(creditLimitN)}</span>
            </span>
            <span className={`font-semibold tabular-nums ${utilTextColor}`}>{utilPct}%</span>
          </div>
          <div className="h-3 w-full rounded-full bg-border overflow-hidden">
            <div
              className={`h-full rounded-full transition-all duration-500 ${utilColor}`}
              style={{ width: `${utilPct}%` }}
            />
          </div>
          <div className="flex justify-between text-[10px] text-text-secondary mt-1.5">
            <span className="text-success">0%</span>
            <span className="text-warning">60%</span>
            <span className="text-danger">80%+</span>
          </div>
          {(creditDays || (creditBlockRule && creditBlockRule !== "none")) && (
            <div className="flex gap-6 mt-3 pt-3 border-t border-border text-xs text-text-secondary">
              {creditDays && <span>Payment terms: <strong className="text-text-primary">{creditDays} days</strong></span>}
              {creditBlockRule && creditBlockRule !== "none" && (
                <span>Block rule: <strong className="text-text-primary capitalize">{creditBlockRule.replace(/_/g, " ")}</strong></span>
              )}
            </div>
          )}
        </CardContent>
      </Card>

      {/* ── Section B: Credit Breakdown ────────────────────────────────────── */}
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm flex items-center gap-1.5">
            <TrendingUp className="h-3.5 w-3.5 text-accent" /> Credit Breakdown
          </CardTitle>
        </CardHeader>
        <CardContent className="p-0">
          {creditUsageLoading ? (
            <div className="flex items-center gap-2 px-4 py-3 text-xs text-text-secondary">
              <div className="h-3.5 w-3.5 animate-spin rounded-full border-2 border-accent border-t-transparent" />
              Computing credit breakdown…
            </div>
          ) : (
            <div className="divide-y divide-border">
              <UsageRow
                label="Invoice Outstanding"
                hint="Past-due invoiced debt reflected on the credit account"
                value={creditUsage?.invoice_outstanding ?? 0}
              />
              <UsageRow
                label={`Orders Consuming Credit${
                  creditUsage ? ` (${creditUsage.breakdown.orders_count_exposure} orders)` : ""
                }`}
                hint="Submitted + approved orders not yet settled — actively consuming credit limit"
                value={creditUsage?.order_exposure ?? 0}
                valueClass={creditUsage && creditUsage.order_exposure > 0 ? "text-warning font-medium" : undefined}
              />
              {creditUsage && creditUsage.hold_exposure > 0 && (
                <UsageRow
                  label={`Orders On Hold (${creditUsage.breakdown.orders_count_hold})`}
                  hint="Under manager review — shown for visibility, not counted in credit used"
                  value={creditUsage.hold_exposure}
                  valueClass="text-text-secondary"
                />
              )}
              <div className="flex items-center justify-between gap-2 px-4 py-3 bg-background-subtle">
                <span className="font-semibold text-sm text-text-primary">Total Credit Used</span>
                <span className={`tabular-nums font-bold text-sm ${utilTextColor}`}>
                  {fmt(creditUsedN)}
                </span>
              </div>
            </div>
          )}
        </CardContent>
      </Card>

      {/* ── Section C: Contributing Orders ────────────────────────────────── */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between pb-2">
          <CardTitle className="text-sm flex items-center gap-1.5">
            <ShoppingCart className="h-3.5 w-3.5 text-accent" />
            Contributing Orders
            {totalExposureOrders > 0 && (
              <span className="ml-1 inline-flex items-center justify-center rounded-full bg-warning/15 px-1.5 py-0.5 text-[10px] font-semibold text-warning">
                {totalExposureOrders}
              </span>
            )}
          </CardTitle>
          {totalExposureOrders > 10 && (
            <a
              href={`/orders?customer_id=${customerId}&status=submitted,approved`}
              className="text-xs text-accent hover:underline flex items-center gap-1"
            >
              View all <ArrowRight className="h-3 w-3" />
            </a>
          )}
        </CardHeader>
        <CardContent className="p-0">
          {creditUsageLoading ? (
            <div className="flex items-center gap-2 px-4 py-3 text-xs text-text-secondary">
              <div className="h-3.5 w-3.5 animate-spin rounded-full border-2 border-accent border-t-transparent" />
              Loading orders…
            </div>
          ) : contribOrders.length === 0 ? (
            <div className="px-4 py-8 text-center">
              <ShoppingCart className="h-7 w-7 mx-auto text-text-secondary/40 mb-2" />
              <p className="text-sm text-text-secondary">No active orders consuming credit.</p>
              <p className="text-xs text-text-secondary mt-0.5">Draft and cancelled orders are excluded.</p>
            </div>
          ) : (
            <div className="overflow-auto">
              <table className="w-full text-sm">
                <thead className="bg-background-subtle">
                  <tr>
                    {["Order #", "Status", "Amount", "Created", ""].map((h, i) => (
                      <th
                        key={i}
                        className="px-4 py-2 text-left text-xs font-semibold uppercase tracking-wider text-text-secondary"
                      >
                        {h}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {contribOrders.map((o) => (
                    <tr key={o.id} className="hover:bg-background-subtle/50 transition-colors">
                      <td className="px-4 py-2.5 font-medium text-text-primary tabular-nums">
                        {o.order_number}
                      </td>
                      <td className="px-4 py-2.5">
                        <Badge
                          variant={ORDER_STATUS_VARIANT[o.status] ?? "outline"}
                          className="capitalize text-xs"
                        >
                          {o.status.replace(/_/g, " ")}
                        </Badge>
                      </td>
                      <td className="px-4 py-2.5 tabular-nums">{fmt(o.total_amount)}</td>
                      <td className="px-4 py-2.5 text-xs text-text-secondary">
                        {new Date(o.created_at).toLocaleDateString("en-IN")}
                      </td>
                      <td className="px-4 py-2.5">
                        <a
                          href={`/orders/${o.id}`}
                          className="text-xs text-accent hover:underline flex items-center gap-0.5"
                        >
                          View <ExternalLink className="h-3 w-3" />
                        </a>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {totalExposureOrders > contribOrders.length && (
                <div className="px-4 py-2.5 border-t border-border bg-background-subtle text-xs text-text-secondary">
                  Showing {contribOrders.length} of {totalExposureOrders} orders.{" "}
                  <a
                    href={`/orders?customer_id=${customerId}&status=submitted,approved`}
                    className="text-accent hover:underline"
                  >
                    View all →
                  </a>
                </div>
              )}
            </div>
          )}
        </CardContent>
      </Card>

      {/* ── Section D: Risk Flags ─────────────────────────────────────────── */}
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm flex items-center gap-1.5">
            <Flag className="h-3.5 w-3.5" /> Risk Flags
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          {(
            [
              {
                key:   "collection_first" as const,
                label: "Collection First",
                hint:  "Require payment collection before new orders can be placed",
              },
              {
                key:   "hold_required" as const,
                label: "Hold Required",
                hint:  "All outgoing orders will be placed on hold pending manager approval",
              },
              {
                key:   "watchlist" as const,
                label: "Watchlist",
                hint:  "Flag this retailer for closer monitoring by the credit team",
              },
            ] as const
          ).map(({ key, label, hint }) => (
            <div key={key} className="flex items-start gap-3">
              <input
                type="checkbox"
                id={`flag-${key}`}
                checked={flags[key]}
                disabled={!isManager}
                onChange={(e) => {
                  if (!isManager) return;
                  setFlagConfirm({ flagKey: key, label, newValue: e.target.checked });
                  setFlagReason("");
                }}
                className="mt-0.5 h-4 w-4 rounded border-border accent-accent disabled:opacity-50"
              />
              <label
                htmlFor={`flag-${key}`}
                className={`flex-1 ${isManager ? "cursor-pointer" : "cursor-not-allowed opacity-70"}`}
              >
                <p className="text-sm font-medium text-text-primary">{label}</p>
                <p className="text-xs text-text-secondary">{hint}</p>
              </label>
            </div>
          ))}
          {!isManager && (
            <p className="text-xs text-text-secondary italic">
              Only managers and owners can change risk flags.
            </p>
          )}
        </CardContent>
      </Card>

      {/* ── Section E: Limit Change Requests ─────────────────────────────── */}
      <div className="flex items-center justify-between">
        <p className="text-sm font-semibold text-text-primary flex items-center gap-1.5">
          <History className="h-4 w-4" /> Limit Change Requests
        </p>
        <Button
          size="sm"
          variant="outline"
          onClick={() => {
            if (suggestedLimit) setReqForm((p) => ({ ...p, new_limit: String(suggestedLimit) }));
            setShowRequestModal(true);
          }}
        >
          + Request Limit Change
        </Button>
      </div>

      {historyLoading ? (
        <div className="flex justify-center py-6">
          <div className="h-5 w-5 animate-spin rounded-full border-2 border-accent border-t-transparent" />
        </div>
      ) : history.length === 0 ? (
        <div className="rounded-lg border border-dashed border-border px-4 py-6 text-center">
          <p className="text-sm text-text-secondary">No limit change requests yet.</p>
        </div>
      ) : (
        <div className="overflow-auto rounded-lg border border-border">
          <table className="w-full text-sm">
            <thead className="bg-background-subtle">
              <tr>
                {["Requested Limit", "Status", "Reason", "Requested By", "Decided By", "Date"].map((h) => (
                  <th key={h} className="px-4 py-2.5 text-left text-xs font-semibold uppercase tracking-wider text-text-secondary">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {history.map((r) => (
                <tr key={r.id} className="bg-background hover:bg-background-subtle/50 transition-colors">
                  <td className="px-4 py-2.5 font-medium tabular-nums">{fmt(Number(r.new_limit))}</td>
                  <td className="px-4 py-2.5">
                    <Badge variant={STATUS_VARIANT[r.status] ?? "outline"} className="capitalize">{r.status}</Badge>
                  </td>
                  <td className="px-4 py-2.5 text-text-secondary max-w-[180px] truncate">{r.reason}</td>
                  <td className="px-4 py-2.5 text-xs">{r.requested_by}</td>
                  <td className="px-4 py-2.5 text-xs">{r.decided_by ?? "—"}</td>
                  <td className="px-4 py-2.5 text-xs text-text-secondary">{new Date(r.created_at).toLocaleDateString("en-IN")}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* ── Flag Confirm Modal ─────────────────────────────────────────────── */}
      <Modal
        open={!!flagConfirm}
        onClose={() => { setFlagConfirm(null); setFlagReason(""); }}
        title={flagConfirm ? `${flagConfirm.newValue ? "Enable" : "Disable"} ${flagConfirm.label}` : ""}
        description="This action will be audited. Please provide a reason before confirming."
        size="sm"
      >
        <div className="space-y-4">
          <div>
            <label className="text-sm font-medium text-text-primary">Reason *</label>
            <textarea
              value={flagReason}
              onChange={(e) => setFlagReason(e.target.value)}
              placeholder="Why are you making this change?"
              rows={3}
              className="mt-1 w-full rounded-md border border-border bg-background px-3 py-2 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent resize-none"
            />
          </div>
          <div className="flex justify-end gap-2 pt-1">
            <Button variant="outline" onClick={() => { setFlagConfirm(null); setFlagReason(""); }}>
              Cancel
            </Button>
            <Button
              onClick={commitFlagChange}
              disabled={flagSubmitting || !flagReason.trim()}
            >
              {flagSubmitting ? "Saving…" : "Confirm"}
            </Button>
          </div>
        </div>
      </Modal>

      {/* ── Limit Change Modal ─────────────────────────────────────────────── */}
      <Modal
        open={showRequestModal}
        onClose={() => { setShowRequestModal(false); setReqForm({ new_limit: "", reason: "", notes: "" }); }}
        title="Request Credit Limit Change"
        description={`Current limit: ${fmt(creditLimitN)}`}
        size="sm"
      >
        <div className="space-y-4">
          {suggestedLimit && (
            <div className="rounded-md bg-accent/5 border border-accent/20 px-3 py-2 text-xs text-text-secondary">
              Suggested limit based on current exposure (+15% buffer):{" "}
              <strong className="text-text-primary">{fmt(suggestedLimit)}</strong>
            </div>
          )}
          <div>
            <label className="text-sm font-medium text-text-primary">New Limit *</label>
            <Input
              type="number"
              placeholder="Enter requested limit"
              value={reqForm.new_limit}
              onChange={(e) => setReqForm((p) => ({ ...p, new_limit: e.target.value }))}
              className="mt-1"
            />
          </div>
          <div>
            <label className="text-sm font-medium text-text-primary">Reason *</label>
            <textarea
              value={reqForm.reason}
              onChange={(e) => setReqForm((p) => ({ ...p, reason: e.target.value }))}
              placeholder="Why is this limit increase needed?"
              rows={3}
              className="mt-1 w-full rounded-md border border-border bg-background px-3 py-2 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent resize-none"
            />
          </div>
          <div className="flex justify-end gap-2 pt-1">
            <Button
              variant="outline"
              onClick={() => { setShowRequestModal(false); setReqForm({ new_limit: "", reason: "", notes: "" }); }}
            >
              Cancel
            </Button>
            <Button
              onClick={handleRequestLimit}
              disabled={submittingReq || !reqForm.new_limit || !reqForm.reason}
            >
              {submittingReq ? "Submitting…" : "Submit Request"}
            </Button>
          </div>
        </div>
      </Modal>
    </div>
  );
}

function UsageRow({
  label, hint, value, valueClass,
}: {
  label:       string;
  hint?:       string;
  value:       number;
  valueClass?: string;
}) {
  return (
    <div className="flex items-center justify-between gap-2 px-3 py-2">
      <div>
        <p className="text-text-primary text-sm">{label}</p>
        {hint && <p className="text-[10px] text-text-secondary">{hint}</p>}
      </div>
      <span className={`tabular-nums text-sm ${valueClass ?? "text-text-primary"}`}>
        ₹{value.toLocaleString("en-IN", { minimumFractionDigits: 0 })}
      </span>
    </div>
  );
}

function StatCard({ label, value, sub, color }: { label: string; value: string; sub?: string; color?: string }) {
  return (
    <Card>
      <CardContent className="pt-4">
        <p className="text-xs text-text-secondary">{label}</p>
        <p className={`text-lg font-semibold mt-1 ${color ?? "text-text-primary"}`}>{value}</p>
        {sub && <p className={`text-xs mt-0.5 ${color ? color : "text-text-secondary"}`}>{sub}</p>}
      </CardContent>
    </Card>
  );
}

function Row({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="flex justify-between gap-4">
      <span className="text-text-secondary shrink-0">{label}</span>
      <span className="text-text-primary text-right">{value}</span>
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────
export default function CustomerDetailPage() {
  const params     = useParams();
  const router     = useRouter();
  const customerId = params.id as string;
  const { token, orgId } = useOrgBranch();

  const [customer, setCustomer]   = useState<CustomerDetail | null>(null);
  const [loading, setLoading]     = useState(false);
  const [deleting, setDeleting]   = useState(false);
  const [blocking, setBlocking]   = useState(false);

  useEffect(() => {
    const fetch_ = async () => {
      if (!token || !orgId) return;
      setLoading(true);
      try {
        const res  = await fetch(`http://localhost:3001/api/v1/customers/${customerId}`, {
          headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
        });
        const json = await res.json();
        if (res.ok) setCustomer(json.data);
      } finally {
        setLoading(false);
      }
    };
    fetch_();
  }, [customerId, token, orgId]);

  const handleBlockToggle = async () => {
    if (!customer) return;
    const action = customer.status === "blocked" ? "unblock" : "block";
    if (!confirm(`${action.charAt(0).toUpperCase() + action.slice(1)} this customer?`)) return;
    setBlocking(true);
    try {
      const res = await fetch(`http://localhost:3001/api/v1/customers/${customerId}/${action}`, {
        method: "POST",
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      if (res.ok) {
        setCustomer((prev) => prev ? { ...prev, status: action === "block" ? "blocked" : "active" } : prev);
      }
    } finally {
      setBlocking(false);
    }
  };

  const handleDelete = async () => {
    if (!confirm("Delete this customer? This action cannot be undone.")) return;
    setDeleting(true);
    try {
      await fetch(`http://localhost:3001/api/v1/customers/${customerId}`, {
        method: "DELETE",
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      router.push("/customers");
    } finally {
      setDeleting(false);
    }
  };

  if (loading) {
    return (
      <AppShell title="Customers">
        <div className="flex items-center justify-center h-48">
          <div className="h-6 w-6 animate-spin rounded-full border-2 border-accent border-t-transparent" />
        </div>
      </AppShell>
    );
  }

  if (!customer) {
    return (
      <AppShell title="Customers">
        <p className="text-text-secondary">Customer not found.</p>
      </AppShell>
    );
  }

  const editHref = `/customers/${customerId}/edit`;

  const tabItems = [
    { value: "overview",  label: "Overview",  content: <OverviewTab customer={customer} editHref={editHref} /> },
    { value: "contacts",  label: "Contacts",  content: <ContactsTab contacts={customer.contacts} editHref={editHref} /> },
    { value: "addresses", label: "Addresses", content: <AddressesTab addresses={customer.addresses} editHref={editHref} /> },
    { value: "credit",    label: "Credit",    content: <CreditTab credit={customer.credit_account} editHref={editHref} creditDays={customer.credit_days} creditBlockRule={customer.credit_block_rule} customerId={customerId} /> },
  ];

  return (
    <AppShell title="Customers">
      <Breadcrumb items={[
        { label: "Customers", href: "/customers" },
        { label: customer.name },
      ]} />

      <PageHeader
        title={customer.name}
        description={`${customer.code} · ${CHANNEL_LABEL[customer.channel] ?? customer.channel}`}
        actions={[
          { label: "Edit", onClick: () => router.push(`/customers/${customerId}/edit`), icon: Edit },
          {
            label: blocking ? "…" : customer.status === "blocked" ? "Unblock" : "Block",
            onClick: handleBlockToggle,
            variant: "outline" as const,
            icon: customer.status === "blocked" ? CheckCircle2 : Ban,
          },
          { label: deleting ? "Deleting…" : "Delete", onClick: handleDelete, variant: "outline", icon: Trash2 },
        ]}
      />

      {/* Blocked banner */}
      {customer.status === "blocked" && (
        <div className="mb-4 flex items-center gap-2 rounded-md bg-warning/10 border border-warning/20 px-4 py-2.5 text-sm text-warning">
          <Ban className="h-4 w-4 shrink-0" />
          <span>This customer is <strong>blocked</strong>. New orders cannot be placed.</span>
        </div>
      )}

      {/* Credit banner for overdue */}
      {customer.credit_account && customer.credit_account.overdue_amount > 0 && (
        <div className="mb-4 flex items-center gap-2 rounded-md bg-danger/10 border border-danger/20 px-4 py-2.5 text-sm text-danger">
          <CreditCard className="h-4 w-4 shrink-0" />
          <span>
            Overdue: ₹{customer.credit_account.overdue_amount.toLocaleString("en-IN")} · {customer.credit_account.overdue_days} days
          </span>
        </div>
      )}

      <Tabs items={tabItems} />
    </AppShell>
  );
}
