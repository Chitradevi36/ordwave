"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

export interface SupplierFormData {
  name:               string;
  code:               string;
  status:             string;
  phone:              string;
  email:              string;
  contact_person:     string;
  gstin:              string;
  pan:                string;
  address:            string;
  city:               string;
  state:              string;
  pincode:            string;
  bank_name:          string;
  bank_account:       string;
  bank_ifsc:          string;
  payment_terms_days: string;
  credit_limit:       string;
  notes:              string;
}

const EMPTY: SupplierFormData = {
  name: "", code: "", status: "active",
  phone: "", email: "", contact_person: "",
  gstin: "", pan: "",
  address: "", city: "", state: "", pincode: "",
  bank_name: "", bank_account: "", bank_ifsc: "",
  payment_terms_days: "30", credit_limit: "", notes: "",
};

const PAYMENT_TERMS = [0, 7, 15, 30, 45, 60];
const STATUSES      = ["active", "inactive"];

interface SupplierFormProps {
  initial?:   Partial<SupplierFormData>;
  supplierId?: number;
  token:      string | null;
  orgId:      string | null;
}

export function SupplierForm({ initial, supplierId, token, orgId }: SupplierFormProps) {
  const router  = useRouter();
  const isEdit  = !!supplierId;

  const [form,    setForm]    = useState<SupplierFormData>({ ...EMPTY, ...initial });
  const [saving,  setSaving]  = useState(false);
  const [errors,  setErrors]  = useState<string[]>([]);

  const set = (key: keyof SupplierFormData) => (
    e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>
  ) => setForm((f) => ({ ...f, [key]: e.target.value }));

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!token || !orgId) return;
    setSaving(true); setErrors([]);

    const body: Record<string, unknown> = {
      supplier: {
        name:               form.name,
        code:               form.code,
        status:             form.status,
        phone:              form.phone   || null,
        email:              form.email   || null,
        contact_person:     form.contact_person || null,
        gstin:              form.gstin   || null,
        pan:                form.pan     || null,
        address:            form.address || null,
        city:               form.city    || null,
        state:              form.state   || null,
        pincode:            form.pincode || null,
        bank_name:          form.bank_name     || null,
        bank_account:       form.bank_account  || null,
        bank_ifsc:          form.bank_ifsc     || null,
        payment_terms_days: Number(form.payment_terms_days),
        credit_limit:       form.credit_limit ? Number(form.credit_limit) : null,
        notes:              form.notes || null,
      },
    };

    try {
      const url    = isEdit
        ? `http://localhost:3001/api/v1/suppliers/${supplierId}`
        : `http://localhost:3001/api/v1/suppliers`;
      const method = isEdit ? "PATCH" : "POST";

      const res  = await fetch(url, {
        method,
        headers: {
          "Content-Type":   "application/json",
          Authorization:    `Bearer ${token}`,
          "X-Organization-Id": orgId,
        },
        body: JSON.stringify(body),
      });
      const json = await res.json();

      if (res.ok) {
        router.push(isEdit ? `/suppliers/${supplierId}` : `/suppliers/${json.data?.id}`);
      } else {
        setErrors(json.errors ?? ["Something went wrong"]);
      }
    } catch {
      setErrors(["Network error — please try again"]);
    } finally {
      setSaving(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-8 max-w-3xl">
      {errors.length > 0 && (
        <div className="rounded-md bg-danger/8 border border-danger/20 px-4 py-3 text-sm text-danger space-y-1">
          {errors.map((e, i) => <p key={i}>{e}</p>)}
        </div>
      )}

      {/* Basic Info */}
      <section className="space-y-4">
        <h3 className="text-sm font-semibold text-text-primary border-b border-border pb-2">
          Basic Information
        </h3>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div className="space-y-1.5">
            <label className="text-sm font-medium text-text-primary">
              Supplier Name <span className="text-danger">*</span>
            </label>
            <Input value={form.name} onChange={set("name")} placeholder="e.g. Sharma Distributors" required />
          </div>
          <div className="space-y-1.5">
            <label className="text-sm font-medium text-text-primary">
              Code <span className="text-danger">*</span>
            </label>
            <Input value={form.code} onChange={set("code")} placeholder="e.g. SUPP-001" required />
          </div>
          <div className="space-y-1.5">
            <label className="text-sm font-medium text-text-primary">Contact Person</label>
            <Input value={form.contact_person} onChange={set("contact_person")} placeholder="Primary contact name" />
          </div>
          <div className="space-y-1.5">
            <label className="text-sm font-medium text-text-primary">Phone</label>
            <Input value={form.phone} onChange={set("phone")} placeholder="10-digit mobile" />
          </div>
          <div className="space-y-1.5">
            <label className="text-sm font-medium text-text-primary">Email</label>
            <Input type="email" value={form.email} onChange={set("email")} placeholder="supplier@example.com" />
          </div>
          <div className="space-y-1.5">
            <label className="text-sm font-medium text-text-primary">Status</label>
            <select
              className="h-9 w-full rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent"
              value={form.status}
              onChange={set("status")}
            >
              {STATUSES.map((s) => (
                <option key={s} value={s}>{s.charAt(0).toUpperCase() + s.slice(1)}</option>
              ))}
            </select>
          </div>
        </div>
      </section>

      {/* Tax & Legal */}
      <section className="space-y-4">
        <h3 className="text-sm font-semibold text-text-primary border-b border-border pb-2">
          Tax & Legal
        </h3>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div className="space-y-1.5">
            <label className="text-sm font-medium text-text-primary">GSTIN</label>
            <Input
              value={form.gstin}
              onChange={set("gstin")}
              placeholder="15-char GSTIN"
              maxLength={15}
              className="font-mono uppercase"
            />
          </div>
          <div className="space-y-1.5">
            <label className="text-sm font-medium text-text-primary">PAN</label>
            <Input
              value={form.pan}
              onChange={set("pan")}
              placeholder="10-char PAN"
              maxLength={10}
              className="font-mono uppercase"
            />
          </div>
        </div>
      </section>

      {/* Address */}
      <section className="space-y-4">
        <h3 className="text-sm font-semibold text-text-primary border-b border-border pb-2">
          Address
        </h3>
        <div className="space-y-1.5">
          <label className="text-sm font-medium text-text-primary">Street Address</label>
          <Input value={form.address} onChange={set("address")} placeholder="Building / Street" />
        </div>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
          <div className="space-y-1.5">
            <label className="text-sm font-medium text-text-primary">City</label>
            <Input value={form.city} onChange={set("city")} placeholder="City" />
          </div>
          <div className="space-y-1.5">
            <label className="text-sm font-medium text-text-primary">State</label>
            <Input value={form.state} onChange={set("state")} placeholder="State" />
          </div>
          <div className="space-y-1.5">
            <label className="text-sm font-medium text-text-primary">Pincode</label>
            <Input value={form.pincode} onChange={set("pincode")} placeholder="6-digit PIN" maxLength={6} />
          </div>
        </div>
      </section>

      {/* Banking */}
      <section className="space-y-4">
        <h3 className="text-sm font-semibold text-text-primary border-b border-border pb-2">
          Banking Details
        </h3>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
          <div className="space-y-1.5">
            <label className="text-sm font-medium text-text-primary">Bank Name</label>
            <Input value={form.bank_name} onChange={set("bank_name")} placeholder="e.g. State Bank of India" />
          </div>
          <div className="space-y-1.5">
            <label className="text-sm font-medium text-text-primary">Account Number</label>
            <Input value={form.bank_account} onChange={set("bank_account")} placeholder="Account number" className="font-mono" />
          </div>
          <div className="space-y-1.5">
            <label className="text-sm font-medium text-text-primary">IFSC Code</label>
            <Input
              value={form.bank_ifsc}
              onChange={set("bank_ifsc")}
              placeholder="e.g. SBIN0001234"
              maxLength={11}
              className="font-mono uppercase"
            />
          </div>
        </div>
      </section>

      {/* Commercial */}
      <section className="space-y-4">
        <h3 className="text-sm font-semibold text-text-primary border-b border-border pb-2">
          Commercial Terms
        </h3>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div className="space-y-1.5">
            <label className="text-sm font-medium text-text-primary">Payment Terms</label>
            <select
              className="h-9 w-full rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent"
              value={form.payment_terms_days}
              onChange={set("payment_terms_days")}
            >
              {PAYMENT_TERMS.map((d) => (
                <option key={d} value={String(d)}>
                  {d === 0 ? "Immediate" : `Net ${d} days`}
                </option>
              ))}
            </select>
          </div>
          <div className="space-y-1.5">
            <label className="text-sm font-medium text-text-primary">Credit Limit (₹)</label>
            <Input
              type="number"
              min="0"
              step="1000"
              value={form.credit_limit}
              onChange={set("credit_limit")}
              placeholder="Leave blank for unlimited"
            />
          </div>
        </div>
        <div className="space-y-1.5">
          <label className="text-sm font-medium text-text-primary">Notes</label>
          <textarea
            className="flex w-full rounded-md border border-border bg-background px-3 py-2 text-sm text-text-primary placeholder:text-text-secondary focus:outline-none focus:ring-2 focus:ring-accent min-h-[80px] resize-y"
            value={form.notes}
            onChange={set("notes")}
            placeholder="Internal notes about this supplier…"
          />
        </div>
      </section>

      {/* Actions */}
      <div className="flex justify-end gap-3 border-t border-border pt-4">
        <Button type="button" variant="outline" onClick={() => router.back()}>
          Cancel
        </Button>
        <Button type="submit" disabled={saving}>
          {saving
            ? <><span className="h-3.5 w-3.5 mr-2 animate-spin rounded-full border-2 border-white border-t-transparent inline-block" />Saving…</>
            : isEdit ? "Save Changes" : "Create Supplier"
          }
        </Button>
      </div>
    </form>
  );
}
