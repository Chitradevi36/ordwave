"use client";

import { useState, useEffect } from "react";
import { useParams, useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Tabs } from "@/components/ui/tabs";
import {
  Phone, Mail, MapPin, User, CreditCard, Edit, Trash2,
  AlertTriangle, Tag, UserCheck, Ban, CheckCircle2,
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

function CreditTab({ credit, editHref, creditDays, creditBlockRule }: {
  credit: CreditAccount | null; editHref: string; creditDays?: number; creditBlockRule?: string;
}) {
  if (!credit) return (
    <div className="rounded-lg border border-dashed border-border p-8 text-center">
      <CreditCard className="h-8 w-8 mx-auto text-text-secondary mb-3" />
      <p className="text-sm font-medium text-text-primary">No credit account</p>
      <p className="text-xs text-text-secondary mt-1">Set a credit limit to enable credit sales for this customer.</p>
      <a href={editHref}
        className="mt-3 inline-flex items-center gap-1.5 text-sm text-accent hover:underline">
        <Edit className="h-3.5 w-3.5" /> Set credit policy via Edit
      </a>
    </div>
  );

  const utilPct = credit.credit_limit > 0
    ? Math.min(100, Math.round((credit.current_balance / credit.credit_limit) * 100))
    : 0;

  return (
    <div className="space-y-4">
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard label="Credit Limit"      value={`₹${credit.credit_limit.toLocaleString("en-IN")}`} />
        <StatCard label="Available Credit"  value={`₹${credit.available_credit.toLocaleString("en-IN")}`} color="text-success" />
        <StatCard label="Current Balance"   value={`₹${credit.current_balance.toLocaleString("en-IN")}`} />
        <StatCard label="Overdue"           value={`₹${credit.overdue_amount.toLocaleString("en-IN")}`} color={credit.overdue_amount > 0 ? "text-danger" : undefined} />
      </div>

      <Card>
        <CardContent className="pt-4">
          <div className="flex justify-between text-xs text-text-secondary mb-1.5">
            <span>Credit Utilisation</span><span>{utilPct}%</span>
          </div>
          <div className="h-2 w-full rounded-full bg-border overflow-hidden">
            <div
              className={`h-full rounded-full transition-all ${utilPct >= 90 ? "bg-danger" : utilPct >= 70 ? "bg-warning" : "bg-success"}`}
              style={{ width: `${utilPct}%` }}
            />
          </div>
          {credit.overdue_days > 0 && (
            <p className="mt-2 text-xs text-danger">{credit.overdue_days} days overdue</p>
          )}
        </CardContent>
      </Card>
      {(creditDays || creditBlockRule) && (
        <Card>
          <CardContent className="pt-4 flex gap-6 text-sm">
            {creditDays && (
              <div>
                <p className="text-xs text-text-secondary">Payment Terms</p>
                <p className="font-medium mt-0.5">{creditDays} days</p>
              </div>
            )}
            {creditBlockRule && creditBlockRule !== "none" && (
              <div>
                <p className="text-xs text-text-secondary">Block Rule</p>
                <p className="font-medium mt-0.5 capitalize">{creditBlockRule.replace(/_/g, " ")}</p>
              </div>
            )}
          </CardContent>
        </Card>
      )}
    </div>
  );
}

function StatCard({ label, value, color }: { label: string; value: string; color?: string }) {
  return (
    <Card>
      <CardContent className="pt-4">
        <p className="text-xs text-text-secondary">{label}</p>
        <p className={`text-lg font-semibold mt-1 ${color ?? "text-text-primary"}`}>{value}</p>
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
    { value: "credit",    label: "Credit",    content: <CreditTab credit={customer.credit_account} editHref={editHref} creditDays={customer.credit_days} creditBlockRule={customer.credit_block_rule} /> },
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
