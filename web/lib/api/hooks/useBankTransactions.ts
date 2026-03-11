import useSWR from 'swr'
import useSWRMutation from 'swr/mutation'
import type {
  BankTransaction,
  PaginatedResponse,
  ConfirmMatchPayload,
  MarkAsAdvancePayload,
} from '@/types/bankReconciliation'

const API = process.env.NEXT_PUBLIC_API_URL ?? ''

async function fetcher<T>(url: string): Promise<T> {
  const token = typeof window !== 'undefined' ? localStorage.getItem('auth_token') : null
  const res = await fetch(`${API}${url}`, {
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
  })
  if (!res.ok) throw new Error(`API error ${res.status}`)
  return res.json()
}

async function poster<T>(url: string, { arg }: { arg: unknown }): Promise<T> {
  const token = typeof window !== 'undefined' ? localStorage.getItem('auth_token') : null
  const res = await fetch(`${API}${url}`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(arg),
  })
  if (!res.ok) {
    const body = await res.json().catch(() => ({}))
    throw new Error((body as { errors?: string[] }).errors?.join(', ') ?? `API error ${res.status}`)
  }
  return res.json()
}

// ── Hooks ──────────────────────────────────────────────────────────────────

export function useBankTransactions(params: {
  status?: string
  bank_account_id?: number
  direction?: string
  page?: number
  per_page?: number
}) {
  const qs = new URLSearchParams(
    Object.entries(params)
      .filter(([, v]) => v !== undefined && v !== '')
      .map(([k, v]) => [k, String(v)])
  ).toString()

  return useSWR<PaginatedResponse<BankTransaction>>(
    `/api/v1/bank_transactions?${qs}`,
    fetcher
  )
}

export function useBankTransaction(id: number | null) {
  return useSWR<{ data: BankTransaction }>(
    id ? `/api/v1/bank_transactions/${id}` : null,
    fetcher
  )
}

export function useConfirmMatch(txnId: number) {
  return useSWRMutation<{ data: BankTransaction }, Error, string, ConfirmMatchPayload>(
    `/api/v1/bank_transactions/${txnId}/confirm_match`,
    poster
  )
}

export function useMarkAsAdvance(txnId: number) {
  return useSWRMutation<{ data: BankTransaction }, Error, string, MarkAsAdvancePayload>(
    `/api/v1/bank_transactions/${txnId}/mark_as_advance`,
    poster
  )
}

export function useIgnoreTransaction(txnId: number) {
  return useSWRMutation<{ data: BankTransaction }, Error, string, Record<string, never>>(
    `/api/v1/bank_transactions/${txnId}/ignore`,
    poster
  )
}

export function useRetryMatch(txnId: number) {
  return useSWRMutation<{ data: BankTransaction }, Error, string, Record<string, never>>(
    `/api/v1/bank_transactions/${txnId}/retry_match`,
    poster
  )
}
