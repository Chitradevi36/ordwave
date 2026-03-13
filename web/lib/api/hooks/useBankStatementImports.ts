import useSWR from 'swr'
import type { BankStatementImport, PaginatedResponse } from '@/types/bankReconciliation'

const API = process.env.NEXT_PUBLIC_API_URL ?? ''

function authHeaders(contentType?: string): Record<string, string> {
  if (typeof window === 'undefined') return {}
  const token = localStorage.getItem('auth_token')
  const orgId = localStorage.getItem('organization_id')
  return {
    Authorization: `Bearer ${token ?? ''}`,
    ...(contentType ? { 'Content-Type': contentType } : {}),
    ...(orgId ? { 'X-Organization-Id': orgId } : {}),
  }
}

async function fetcher<T>(url: string): Promise<T> {
  const res = await fetch(`${API}${url}`, { headers: authHeaders() })
  if (!res.ok) throw new Error(`API error ${res.status}`)
  return res.json()
}

export function useBankStatementImports(params: { bank_account_id?: number; page?: number } = {}) {
  const qs = new URLSearchParams(
    Object.entries(params)
      .filter(([, v]) => v !== undefined)
      .map(([k, v]) => [k, String(v)])
  ).toString()

  return useSWR<PaginatedResponse<BankStatementImport>>(
    `/api/v1/bank_statement_imports?${qs}`,
    fetcher
  )
}

export function useBankStatementImport(id: number | null) {
  return useSWR<{ data: BankStatementImport }>(
    id ? `/api/v1/bank_statement_imports/${id}` : null,
    fetcher
  )
}

export async function uploadBankStatement(
  bankAccountId: number,
  file: File
): Promise<BankStatementImport> {
  const form = new FormData()
  form.append('file', file)
  form.append('bank_account_id', String(bankAccountId))

  // Note: do NOT set Content-Type here — browser sets multipart boundary automatically
  const res = await fetch(`${API}/api/v1/bank_statement_imports`, {
    method: 'POST',
    headers: authHeaders(),   // includes Authorization + X-Organization-Id
    body: form,
  })
  if (!res.ok) {
    const body = await res.json().catch(() => ({}))
    throw new Error(
      (body as { errors?: string[] }).errors?.join(', ') ?? `Upload failed ${res.status}`
    )
  }
  const json = await res.json()
  return json.data ?? json
}
