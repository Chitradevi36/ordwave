'use client'

import { useRef, useState } from 'react'
import { useBankStatementImports, uploadBankStatement } from '@/lib/api/hooks/useBankStatementImports'
import type { BankStatementImport } from '@/types/bankReconciliation'
import { Button } from '@/components/ui/button'
import { cn, formatDate } from '@/lib/utils'

interface Props {
  onClose: () => void
  onImported: () => void
}

const STATUS_CLASS: Record<string, string> = {
  uploaded:   'bg-blue-50 text-blue-600',
  processing: 'bg-yellow-50 text-yellow-600',
  completed:  'bg-green-50 text-green-700',
  failed:     'bg-red-50 text-red-600',
}

export function ImportScreen({ onClose, onImported }: Props) {
  // Hardcode bank_account_id = 1 as a placeholder — real implementation
  // would let the user select a bank account.
  const BANK_ACCOUNT_ID = 1

  const { data, isLoading, mutate } = useBankStatementImports({
    bank_account_id: BANK_ACCOUNT_ID,
    page: 1,
  })

  const imports = data?.data ?? []

  const fileRef             = useRef<HTMLInputElement>(null)
  const [dragging, setDragging] = useState(false)
  const [uploading, setUploading] = useState(false)
  const [uploadError, setUploadError] = useState<string | null>(null)

  async function handleFile(file: File | undefined) {
    if (!file) return
    if (!file.name.endsWith('.csv')) {
      setUploadError('Only CSV files are supported.')
      return
    }
    setUploadError(null)
    setUploading(true)
    try {
      await uploadBankStatement(BANK_ACCOUNT_ID, file)
      await mutate()
      onImported()
    } catch (err) {
      setUploadError(err instanceof Error ? err.message : 'Upload failed')
    } finally {
      setUploading(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
      <div className="flex w-full max-w-2xl flex-col rounded-xl bg-white shadow-2xl">
        {/* Header */}
        <div className="flex items-center justify-between border-b px-6 py-4">
          <h2 className="text-base font-semibold text-gray-900">Upload Bank Statement</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600">
            ✕
          </button>
        </div>

        {/* Upload zone */}
        <div className="px-6 py-6">
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
              dragging ? 'border-indigo-500 bg-indigo-50' : 'border-gray-300 hover:border-indigo-400'
            )}
          >
            <svg className="mb-3 h-10 w-10 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5}
                d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5" />
            </svg>
            <p className="text-sm font-medium text-gray-600">
              {uploading ? 'Uploading…' : 'Drop CSV here or click to browse'}
            </p>
            <p className="mt-1 text-xs text-gray-400">
              Supports standard bank export formats (HDFC, ICICI, Axis, SBI)
            </p>
            <input
              ref={fileRef}
              type="file"
              accept=".csv"
              className="hidden"
              onChange={(e) => handleFile(e.target.files?.[0])}
            />
          </div>
          {uploadError && (
            <p className="mt-2 text-sm text-red-500">{uploadError}</p>
          )}
          <p className="mt-3 text-xs text-gray-400">
            Required columns: <code>date</code>, <code>narration</code>, <code>amount</code> (or debit/credit columns). 
            The importer auto-detects format.
          </p>
        </div>

        {/* Import history */}
        <div className="border-t px-6 pb-6">
          <p className="mb-3 text-xs font-medium uppercase text-gray-400">Recent Imports</p>
          {isLoading ? (
            <p className="text-sm text-gray-400">Loading…</p>
          ) : imports.length === 0 ? (
            <p className="text-sm text-gray-400">No imports yet.</p>
          ) : (
            <div className="divide-y rounded-lg border">
              {imports.slice(0, 8).map((imp: BankStatementImport) => (
                <div key={imp.id} className="flex items-center justify-between px-4 py-3 text-sm">
                  <div>
                    <p className="font-medium text-gray-800">{imp.original_filename}</p>
                    <p className="text-xs text-gray-400">{formatDate(imp.created_at)}</p>
                  </div>
                  <div className="flex items-center gap-3">
                    {imp.status === 'completed' && (
                      <span className="text-xs text-gray-500">
                        {imp.new_rows} new · {imp.duplicate_rows} dupes
                      </span>
                    )}
                    <span
                      className={cn(
                        'rounded-full px-2 py-0.5 text-xs font-medium capitalize',
                        STATUS_CLASS[imp.status] ?? 'bg-gray-100 text-gray-500'
                      )}
                    >
                      {imp.status}
                    </span>
                    {imp.status === 'failed' && imp.error_message && (
                      <span className="max-w-xs truncate text-xs text-red-500" title={imp.error_message}>
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
