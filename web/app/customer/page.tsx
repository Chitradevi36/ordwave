"use client"

import React, { useEffect, useState } from 'react'
import CustomerView from '../../components/dashboard/CustomerView'

export default function CustomerPage({ params }: any) {
  const [data, setData] = useState<any>(null)
  const customerId = typeof window !== 'undefined' ? window.localStorage.getItem('current_customer_id') : null

  useEffect(() => {
    async function load() {
      const id = params?.id || customerId
      if (!id) return
      const res = await fetch(`/api/v1/customers/${id}/dashboard`)
      if (res.ok) setData(await res.json())
    }
    load()
  }, [params, customerId])

  if (!data) return <div>Loading customer dashboard…</div>
  return <CustomerView data={data} />
}
