"use client";

import { useState, useEffect, useCallback } from "react";
import { useParams, useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { AccessDeniedError } from "@/components/errors/access-denied-error";
import { useOrgBranch } from "@/lib/org-branch-context";
import { CustomerForm, type CustomerFormData, type AddressRow, type ContactRow, type SalesRep } from "../../_components/CustomerForm";
import { API_URL } from "@/lib/api/client";


interface Route { id: number; name: string; code: string; }

export default function EditCustomerPage() {
  const params     = useParams();
  const router     = useRouter();
  const customerId = params.id as string;
  const { token, orgId, branches } = useOrgBranch();

  const [initial,   setInitial]   = useState<Partial<CustomerFormData> | null>(null);
  const [routes,    setRoutes]    = useState<Route[]>([]);
  const [salesReps, setSalesReps] = useState<SalesRep[]>([]);
  const [loading,   setLoading]   = useState(false);
  const [errors,    setErrors]    = useState<string[]>([]);
  const [error, setError] = useState<{ status: number; message: string } | null>(null);

  useEffect(() => {
    const load = async () => {
      if (!token || !orgId) return;
      const headers = { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId };

      const [custRes, routesRes, usersRes] = await Promise.all([
        fetch(`${API_URL}/api/v1/customers/${customerId}`, { headers }),
        fetch(`${API_URL}/api/v1/routes?per_page=100`,     { headers }),
        fetch(`${API_URL}/api/v1/users?per_page=100`,      { headers }),
      ]);

      if (!custRes.ok) {
        const json = await custRes.json().catch(() => ({ errors: [custRes.statusText] }));
        setError({ status: custRes.status, message: json.errors?.[0] ?? "Failed to load customer" });
        return;
      }

      if (custRes.ok) {
        const json = await custRes.json();
        const c = json.data;

        const addresses: AddressRow[] = (c.addresses ?? []).map((a: AddressRow) => ({
          _key:        `edit-a-${a.id}`,
          id:          a.id,
          label:       a.label       ?? "billing",
          line1:       a.line1       ?? "",
          line2:       a.line2       ?? "",
          city:        a.city        ?? "",
          state:       a.state       ?? "",
          postal_code: a.postal_code ?? "",
          country:     a.country     ?? "India",
          latitude:    a.latitude    ?? "",
          longitude:   a.longitude   ?? "",
        }));

        const contacts: ContactRow[] = (c.contacts ?? []).map((ct: ContactRow) => ({
          _key:        `edit-c-${ct.id}`,
          id:          ct.id,
          name:        ct.name        ?? "",
          phone:       ct.phone       ?? "",
          email:       ct.email       ?? "",
          designation: ct.designation ?? "",
          is_primary:  ct.is_primary  ?? false,
        }));

        setInitial({
          name:              c.name,
          code:              c.code,
          customer_type:     c.customer_type     ?? "retailer",
          status:            c.status            ?? "active",
          channel:           c.channel,
          tier:              c.tier,
          branch_id:         String(c.branch_id),
          route_id:          c.route?.id          ? String(c.route.id)     : "",
          sales_rep_id:      c.sales_rep?.id      ? String(c.sales_rep.id) : "",
          visit_frequency:   c.visit_frequency    ?? "",
          phone:             c.phone              ?? "",
          email:             c.email              ?? "",
          gstin:             c.gstin              ?? "",
          pan:               c.pan                ?? "",
          credit_limit:      String(c.credit_limit      ?? 0),
          credit_days:       String(c.credit_days       ?? 30),
          credit_block_rule: c.credit_block_rule  ?? "none",
          opening_balance:   String(c.opening_balance   ?? 0),
          tags:              c.tag_list           ?? [],
          addresses,
          contacts,
        });
      }

      if (routesRes.ok) { const j = await routesRes.json(); setRoutes(j.data    ?? []); }
      if (usersRes.ok)  { const j = await usersRes.json();  setSalesReps(j.data ?? []); }
    };
    load();
  }, [customerId, token, orgId]);

  // Duplicate detection (excluded current customer)
  const checkDuplicate = useCallback(
    async (field: "name" | "phone" | "gstin", value: string) => {
      if (!token || !orgId) return { exists: false };
      try {
        const res  = await fetch(
          `${API_URL}/api/v1/customers/check_duplicate?field=${field}&value=${encodeURIComponent(value)}&exclude_id=${customerId}`,
          { headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId } },
        );
        const json = await res.json();
        return { exists: !!json.exists, match: json.match };
      } catch {
        return { exists: false };
      }
    },
    [token, orgId, customerId],
  );

  const handleSubmit = async (data: CustomerFormData) => {
    if (!token || !orgId) return;
    setLoading(true);
    setErrors([]);
    try {
      const { addresses, contacts, route_id, tags, ...rest } = data;

      const body: Record<string, unknown> = {
        ...rest,
        ...(route_id ? { route_id } : { route_id: null }),
        tag_list:             tags,
        addresses_attributes: addresses.map(({ _key, ...a }) => a),
        contacts_attributes:  contacts.map(({ _key, ...c }) => c),
      };

      const res  = await fetch(`${API_URL}/api/v1/customers/${customerId}`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
          "X-Organization-Id": orgId,
        },
        body: JSON.stringify({ customer: body }),
      });
      const json = await res.json();

      if (res.ok) {
        router.push(`/customers/${customerId}`);
      } else {
        setError({ status: res.status, message: json.errors?.[0] ?? "Failed to save customer" });
        setErrors(json.errors ?? ["Something went wrong"]);
      }
    } finally {
      setLoading(false);
    }
  };

  if (error) {
    return <AccessDeniedError status={error.status} message={error.message} backLink="/customers" resourceType="Customer" />;
  }

  if (!initial) {
    return (
      <AppShell title="Customers">
        <div className="flex items-center justify-center h-48">
          <div className="h-6 w-6 animate-spin rounded-full border-2 border-accent border-t-transparent" />
        </div>
      </AppShell>
    );
  }

  return (
    <AppShell title="Customers">
      <PageHeader title="Edit Customer" description="Update customer details." />
      <div className="mt-6">
        <CustomerForm
          initial={initial}
          branches={branches}
          routes={routes}
          salesReps={salesReps}
          onSubmit={handleSubmit}
          submitLabel="Save Changes"
          loading={loading}
          errors={errors}
          onCancel={() => router.push(`/customers/${customerId}`)}
          checkDuplicate={checkDuplicate}
        />
      </div>
    </AppShell>
  );
}

