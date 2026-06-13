"use client"

import React from 'react'
import Link from 'next/link'

export default function CustomerView({ data, isLoading = false, isError = false }: any) {
  // Guard against missing data from parent; show loading / fallback UI
  if (isLoading) {
    return (
      <div className="p-4 max-w-3xl mx-auto">
        <div className="animate-pulse space-y-3">
          <div className="h-6 w-1/3 bg-gray-200 rounded" />
          <div className="h-4 w-1/4 bg-gray-200 rounded" />
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="h-28 bg-gray-100 rounded" />
            <div className="h-28 bg-gray-100 rounded md:col-span-2" />
          </div>
        </div>
      </div>
    )
  }

  const safeData = data ?? {};
  const {
    customer,
    credit = {},
    recent_orders = [],
    outstanding_invoices = { count: 0, total_outstanding: 0 },
    notifications = 0,
  } = safeData;

  if (!customer) {
    if (isError) {
      return (
        <div className="p-4 max-w-3xl mx-auto text-center text-sm text-red-600">
          Unable to load customer data.
        </div>
      );
    }
    return (
      <div className="p-4 max-w-3xl mx-auto text-center text-sm text-text-secondary">
        No customer data available.
      </div>
    );
  }

  const lowCredit = credit && credit.available != null && credit.limit && credit.available / (credit.limit || 1) < 0.2

  return (
    <div className="p-4 max-w-3xl mx-auto">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold">{customer.name}</h1>
          <p className="text-sm text-gray-600">Phone: {customer.phone}</p>
        </div>
        <div className="flex gap-2">
          <Link href={`/orders/new?customer_id=${customer.id}`} className="px-3 py-2 bg-primary text-white rounded">Create Order</Link>
          <Link href="/notifications" className="px-3 py-2 border rounded">Notifications ({notifications})</Link>
        </div>
      </div>

      <section className="mt-6 grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="p-4 border rounded">
          <h3 className="font-medium">Credit</h3>
          <div className="mt-2">Limit: ₹{credit.limit ?? '—'}</div>
          <div>Available: ₹{credit.available ?? '—'}</div>
          <div>Current balance: ₹{credit.current_balance ?? '—'}</div>
          {credit.blocked && <div className="text-red-600 mt-2 font-semibold">Account blocked by policy</div>}
          {lowCredit && !credit.blocked && <div className="text-amber-600 mt-2">Low available credit — please contact your rep</div>}
        </div>

        <div className="p-4 border rounded md:col-span-2">
          <h3 className="font-medium">Recent Orders</h3>
          <ul className="mt-2 divide-y">
            {recent_orders.map((o: any) => (
              <li key={o.id} className="py-2 flex justify-between">
                <div>
                  <div className="font-semibold">{o.order_number}</div>
                  <div className="text-sm text-gray-600">{o.status} • ₹{o.total_amount}</div>
                </div>
                <div className="flex items-center gap-2">
                  <Link href={`/orders/${o.id}`} className="text-sm text-primary">View</Link>
                </div>
              </li>
            ))}
          </ul>
        </div>
      </section>

      <section className="mt-6 p-4 border rounded">
        <h3 className="font-medium">Outstanding Invoices</h3>
        <div className="mt-2">Count: {outstanding_invoices.count}</div>
        <div>Total: ₹{outstanding_invoices.total_outstanding}</div>
      </section>
    </div>
  )
}

// Also export as a named export for environments that import { CustomerView }
export { CustomerView };
