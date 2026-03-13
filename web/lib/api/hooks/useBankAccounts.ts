import useSWR from 'swr'
import type { BankAccount } from '@/types/bankReconciliation'

const API = process.env.NEXT_PUBLIC_API_URL ?? ''

function authHeaders(): Record<string, string> {
  if (typeof window === 'undefined') return {}
  const token = localStorage.getItem('auth_token')
  const orgId = localStorage.getItem('organization_id')
  return {
    Authorization: `Bearer ${token ?? ''}`,
    'Content-Type': 'application/json',
    ...(orgId ? { 'X-Organization-Id': orgId } : {}),
  }
}

async function fetcher<T>(url: string): Promise<T> {
  const res = await fetch(`${API}${url}`, { headers: authHeaders() })
  if (!res.ok) throw new Error(`API error ${res.status}`)
  return res.json()
}

/** Returns all active bank accounts for the current organisation. */
export function useBankAccounts() {
  return useSWR<BankAccount[]>('/api/v1/bank_accounts', fetcher)
}
