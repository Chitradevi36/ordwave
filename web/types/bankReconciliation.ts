// Types for the Bank Reconciliation module

export type BankAccountStatus = 'active' | 'inactive'

export interface BankAccount {
  id: number
  organization_id: number
  branch_id: number | null
  bank_name: string
  account_holder_name: string
  masked_account_number: string
  ifsc_code: string
  account_type: string
  currency: string
  status: BankAccountStatus
  created_at: string
  updated_at: string
}

export type ImportStatus = 'uploaded' | 'processing' | 'completed' | 'failed'
export type ImportSourceType = 'csv' | 'xlsx' | 'pdf' | 'manual' | 'api'

export interface BankStatementImport {
  id: number
  organization_id: number
  bank_account_id: number
  bank_account: BankAccount
  source_type: ImportSourceType
  status: ImportStatus
  file_name: string
  total_rows: number | null
  new_rows: number | null
  duplicate_rows: number | null
  failed_rows: number | null
  error_message: string | null
  uploaded_by_id: number
  created_at: string
  updated_at: string
}

export type TxnStatus =
  | 'unmatched'
  | 'suggested'
  | 'auto_matched'
  | 'matched'
  | 'ignored'
  | 'reversed'

export type TxnDirection = 'credit' | 'debit'

export interface BankTransactionMatch {
  id: number
  bank_transaction_id: number
  customer_id: number | null
  sales_invoice_id: number | null
  score: number
  rule_code: string
  explanation: Record<string, unknown>
  selected: boolean
  created_at: string
  // denormalized
  customer_name: string | null
  invoice_number: string | null
  invoice_amount: number | null
  invoice_outstanding: number | null
}

export interface BankTransaction {
  id: number
  bank_account_id: number
  bank_statement_import_id: number | null
  txn_date: string
  value_date: string | null
  amount: number
  direction: TxnDirection
  narration: string
  utr_number: string | null
  reference_number: string | null
  status: TxnStatus
  match_score: number | null
  match_rule: string | null
  matched_customer_id: number | null
  matched_invoice_id: number | null
  matched_payment_id: number | null
  reviewed_by_id: number | null
  processed_at: string | null
  match_meta: {
    invoice_numbers?: string[]
    customer_codes?: string[]
    utr_candidates?: string[]
    tokens?: string[]
  } | null
  // denormalized
  matched_customer_name: string | null
  matched_invoice_number: string | null
  candidates: BankTransactionMatch[]
  created_at: string
  updated_at: string
}

export interface AllocationInput {
  invoice_id: number
  amount: number
}

export interface ConfirmMatchPayload {
  allocations: AllocationInput[]
}

export interface MarkAsAdvancePayload {
  customer_id: number
}

export interface PaginationMeta {
  current_page: number
  total_pages: number
  total_count: number
  per_page: number
}

export interface PaginatedResponse<T> {
  data: T[]
  meta: PaginationMeta
}

export type TxnTab = 'auto_matched' | 'suggested' | 'unmatched' | 'matched' | 'ignored'

export interface BankDashboard {
  total_credits_imported: number
  total_amount_imported: string
  status_counts: Record<string, number>
  status_amounts: Record<string, string>
  duplicates_count: number
  recent_imports: BankStatementImport[]
}
