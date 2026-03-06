"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { useOrgBranch } from "@/lib/org-branch-context";
import { CustomerForm, type CustomerFormData } from "../_components/CustomerForm";
import { API_URL } from "@/lib/api/client";


interface Route { id: number; name: string; code: string; }

export default function NewCustomerPage() {
  const router = useRouter();
  const { token, orgId, branchId, branches } = useOrgBranch();

  const [routes,  setRoutes]  = useState<Route[]>([]);
  const [loading,  setLoading] = useState(false);
  const [errors,   setErrors]  = useState<string[]>([]);

  const defaultBranchId = branchId || (branches[0] ? String(branches[0].id) : "");

  useEffect(() => {
    const load = async () => {
      if (!token || !orgId) return;
      const headers = { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId };

      const qs = new URLSearchParams({ per_page: "100" });
      if (defaultBranchId) qs.set("branch_id", defaultBranchId);

      const [routesRes] = await Promise.all([
        fetch(`${API_URL}/api/v1/routes?${qs}`, { headers }),
      ]);

      if (routesRes.ok) { const j = await routesRes.json(); setRoutes(j.data ?? []); }
    };
    load();
  }, [token, orgId, defaultBranchId]);

  // Duplicate detection
  const checkDuplicate = useCallback(
    async (field: "name" | "phone" | "gstin", value: string) => {
      if (!token || !orgId) return { exists: false };
      try {
        const res  = await fetch(
          `${API_URL}/api/v1/customers/check_duplicate?field=${field}&value=${encodeURIComponent(value)}`,
          { headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId } },
        );
        const json = await res.json();
        return { exists: !!json.exists, match: json.match };
      } catch {
        return { exists: false };
      }
    },
    [token, orgId],
  );

  const handleSubmit = async (data: CustomerFormData) => {
    if (!token || !orgId) return;
    setLoading(true);
    setErrors([]);
    try {
      const { addresses, contacts, branch_id, route_id, tags, ...rest } = data;

      const body: Record<string, unknown> = {
        ...rest,
        branch_id:            branch_id || defaultBranchId,
        ...(route_id         ? { route_id }         : {}),
        ...(data.sales_rep_id ? { sales_rep_id: data.sales_rep_id } : {}),
        tag_list:             tags,
        addresses_attributes: addresses.map(({ _key, ...a }) => a),
        contacts_attributes:  contacts.map(({ _key, ...c }) => c),
      };

      const res  = await fetch(`${API_URL}/api/v1/customers`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
          "X-Organization-Id": orgId,
        },
        body: JSON.stringify({ customer: body }),
      });
      const json = await res.json();

      if (res.ok) {
        router.push(`/customers/${json.data.id}`);
      } else {
        setErrors(json.errors ?? ["Something went wrong"]);
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <AppShell title="Customers">
      <PageHeader
        title="Add Customer"
        description="Fill in the essentials — you can add more details after creation."
      />
      <div className="mt-6">
        <CustomerForm
          mode="create"
          initial={{ branch_id: defaultBranchId }}
          branches={branches}
          routes={routes}
          onSubmit={handleSubmit}
          submitLabel="Create Customer"
          loading={loading}
          errors={errors}
          onCancel={() => router.push("/customers")}
          checkDuplicate={checkDuplicate}
        />
      </div>
    </AppShell>
  );
}
