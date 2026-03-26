'use client'

import { useRef, useState } from 'react'
import { useBankStatementImports, useUploadBankStatement } from '@/lib/api/hooks/useBankStatementImports'
import { useBankAccounts } from '@/lib/api/hooks/useBankAccounts'
import type { BankStatementImport } from '@/types/bankReconciliation'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { cn, formatDate } from '@/lib/utils'

interface Props {
  onClose: () => void
  onImported: () => void
}

const STATUS_IMPORT_VARIANT: Record<string, 'outline' | 'warning' | 'success' | 'danger' | 'secondary'> = {
  uploaded:   'outline',
  processing: 'warning',
  completed:  'success',
  failed:     'danger',
}

const ACCEPTED_EXTENSIONS = ['.csv', '.xlsx', '.xls', '.pdf']
const ACCEPTED_ATTR = ACCEPTED_EXTENSIONS.join(',')

function isSupportedFile(name: string) {
  return ACCEPTED_EXTENSIONS.some((ext) => name.toLowerCase().endsWith(ext))
}

export function ImportScreen({ onClose, onImported }: Props) {
  const { data: accountsData, isLoading: accountsLoading } = useBankAccounts()
  const accounts = accountsData ?? []

  const [selectedAccountId, setSelectedAccountId] = useState<number | null>(null)

  // Default to the first account once loaded
  const effectiveAccountId =
    selectedAccountId ?? (accounts.length > 0 ? accounts[0].id : null)

  const { data, isLoading } = useBankStatementImports(
    effectiveAccountId ? { bank_account_id: effectiveAccountId, page: 1 } : {}
  )

  const imports = data?.data ?? []

  const uploadMutation = useUploadBankStatement()

  const fileRef                = useRef<HTMLInputElement>(null)
  const [dragging, setDragging]       = useState(false)
  const [uploadError, setUploadError] = useState<string | null>(null)

  async function handleFile(file: File | undefined) {
    if (!file) return
    if (!isSupportedFile(file.name)) {
      setUploadError('Unsupported file type. Please upload a CSV, XLSX, or PDF.')
      return
    }
    if (!effectiveAccountId) {
      setUploadError('Please select a bank account first.')
      return
    }
    setUploadError(null)
    try {
      await uploadMutation.mutateAsync({ bankAccountId: effectiveAccountId, file })
      onImported()
    } catch (err) {
      setUploadError(err instanceof Error ? err.message : 'Upload failed')
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
      <div className="flex w-full max-w-2xl flex-col rounded-xl bg-background shadow-2xl">
        {/* Header */}
        <div className="flex items-center justify-between border-b px-6 py-4">
          <h2 className="text-base font-semibold text-text-primary">Upload Bank Statement</h2>
          <button onClick={onClose} className="text-text-secondary hover:text-text-primary">
            ✕
          </button>
        </div>

        {/* Bank account selector */}
        <div className="px-6 pt-4">
          <label className="mb-1 block text-xs font-medium text-text-secondary">
            Bank Account
          </label>
          {accountsLoading ? (
            <p className="text-sm text-text-secondary">Loading accounts…</p>
          ) : accounts.length === 0 ? (
            <p className="text-sm text-danger">No active bank accounts found. Please add one first.</p>
          ) : (
            <select
              className="w-full rounded-md border border-border px-3 py-2 text-sm focus:border-primary focus:outline-none"
              value={effectiveAccountId ?? ''}
              onChange={(e) => setSelectedAccountId(Number(e.target.value))}
            >
              {accounts.map((acct) => (
                <option key={acct.id} value={acct.id}>
                  {acct.bank_name} — {acct.masked_account_number}
                </option>
              ))}
            </select>
          )}
        </div>

        {/* Upload zone */}
        <div className="px-6 py-4">
          <div
            onDragOver={(e) => { e.preventDefault(); setDragging(true) }}
            onDragLeave={() => setDragging(false)}
            onDrop={(e) => {
              e.preventDefault()
              setDragging(false)
              handleFile(e.dataTransfer.files[0])
            }}
            onClick={() => fileRef.current?.click()}
            className={cn(
              'flex cursor-pointer flex-col items-center justify-center rounded-lg border-2 border-dashed py-10 transition-colors',
              dragging ? 'border-primary bg-primary/5' : 'border-border hover:border-primary/70'
            )}
          >
            <svg className="mb-3 h-10 w-10 text-text-secondary/40" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5}
                d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5" />
            </svg>
            <p className="text-sm font-medium text-text-secondary">
              {uploadMutation.isPending ? 'Uploading…' : 'Drop file here or click to browse'}
            </p>
            <p className="mt-1 text-xs text-text-secondary">
              CSV, XLSX, or text-based PDF · HDFC, ICICI, Axis, SBI formats supported
            </p>
            <input
              ref={fileRef}
              type="file"
              accept={ACCEPTED_ATTR}
              className="hidden"
              onChange={(e) => handleFile(e.target.files?.[0])}
            />
          </div>
          {uploadError && (
            <p className="mt-2 text-sm text-danger">{uploadError}</p>
          )}
          <p className="mt-3 text-xs text-text-secondary">
            Required columns: <code>date</code>, <code>narration</code>, <code>amount</code> (or debit/credit columns).
            The importer auto-detects format.
          </p>
        </div>

        {/* Import history */}
        <div className="border-t px-6 pb-6">
          <p className="mb-3 text-xs font-medium uppercase text-text-secondary">Recent Imports</p>
          {isLoading ? (
            <p className="text-sm text-text-secondary">Loading…</p>
          ) : imports.length === 0 ? (
            <p className="text-sm text-text-secondary">No imports yet.</p>
          ) : (
            <div className="divide-y rounded-lg border">
              {imports.slice(0, 8).map((imp: BankStatementImport) => (
                <div key={imp.id} className="flex items-center justify-between px-4 py-3 text-sm">
                  <div>
                    <p className="font-medium text-text-primary">{imp.file_name}</p>
                    <p className="text-xs text-text-secondary">{formatDate(imp.created_at)}</p>
                  </div>
                  <div className="flex items-center gap-3">
                    {imp.status === 'completed' && (
                      <span className="text-xs text-text-secondary">
                        {imp.new_rows} new · {imp.duplicate_rows} dupes
                      </span>
                    )}
                    <Badge variant={STATUS_IMPORT_VARIANT[imp.status] ?? 'secondary'} className="capitalize">
                      {imp.status}
                    </Badge>
                    {imp.status === 'failed' && imp.error_message && (
                      <span className="max-w-xs truncate text-xs text-danger" title={imp.error_message}>
                        {imp.error_message}
                      </span>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="flex justify-end border-t px-6 py-4">
          <Button variant="outline" onClick={onClose}>
            Close
          </Button>
        </div>
      </div>
    </div>
  )
}
