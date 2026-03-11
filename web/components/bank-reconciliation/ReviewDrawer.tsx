'use client'

import { useState } from 'react'
import type { BankTransaction, AllocationInput } from '@/types/bankReconciliation'
import {
  useConfirmMatch,
  useMarkAsAdvance,
  useIgnoreTransaction,
  useRetryMatch,
} from '@/lib/api/hooks/useBankTransactions'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { cn, formatCurrency, formatDate } from '@/lib/utils'

interface Props {
  txn: BankTransaction
  onClose: () => void
  onSaved: () => void
}

export function ReviewDrawer({ txn, onClose, onSaved }: Props) {
  const [mode, setMode] = useState<'confirm' | 'advance' | 'split'>('confirm')
  const [customerId, setCustomerId] = useState('')
  const [allocations, setAllocations] = useState<AllocationInput[]>(() => {
    const best = txn.candidates.find((c) => c.selected)
    if (best?.sales_invoice_id) {
      return [{ invoice_id: best.sales_invoice_id, amount: txn.amount }]
    }
    return [{ invoice_id: 0, amount: txn.amount }]
  })

  const confirmMut  = useConfirmMatch(txn.id)
  const advanceMut  = useMarkAsAdvance(txn.id)
  const ignoreMut   = useIgnoreTransaction(txn.id)
  const retryMut    = useRetryMatch(txn.id)

  const isBusy =
    confirmMut.isMutating || advanceMut.isMutating || ignoreMut.isMutating || retryMut.isMutating

  function getErrorMsg(err: unknown) {
    if (err instanceof Error) return err.message
    return 'An error occurred'
  }

  async function handleConfirm() {
    await confirmMut.trigger({ allocations })
    onSaved()
  }

  async function handleAdvance() {
    await advanceMut.trigger({ customer_id: Number(customerId) })
    onSaved()
  }

  async function handleIgnore() {
    await ignoreMut.trigger({})
    onSaved()
  }

  async function handleRetry() {
    await retryMut.trigger({})
    onSaved()
  }

  const best = txn.candidates.find((c) => c.selected)

  return (
    // Backdrop
    <div className="fixed inset-0 z-40 flex justify-end bg-black/30">
      {/* Drawer panel */}
      <div className="relative flex h-full w-full max-w-xl flex-col bg-white shadow-xl">
        {/* Header */}
        <div className="flex items-center justify-between border-b px-6 py-4">
          <h2 className="text-base font-semibold text-gray-900">Review Transaction</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600">
            ✕
          </button>
        </div>

        {/* Transaction details */}
        <div className="border-b bg-gray-50 px-6 py-4 text-sm">
          <div className="grid grid-cols-2 gap-x-6 gap-y-1">
            <Detail label="Date"          value={formatDate(txn.txn_date)} />
            <Detail label="Amount"        value={formatCurrency(txn.amount)}       highlight />
            <Detail label="Direction"     value={txn.direction}                    />
            <Detail label="Status"        value={txn.status.replace('_', ' ')}     />
            <Detail label="UTR / Ref"     value={txn.utr_number ?? txn.reference_number ?? '—'} />
            <Detail label="Match Score"   value={best ? `${best.score.toFixed(0)} (${best.rule_code})` : '—'} />
          </div>
          <div className="mt-2">
            <span className="text-xs text-gray-400">Narration</span>
            <p className="mt-0.5 text-gray-700">{txn.narration}</p>
          </div>
        </div>

        {/* Suggested candidates */}
        {txn.candidates.length > 0 && (
          <div className="border-b px-6 py-4">
            <p className="mb-2 text-xs font-medium uppercase text-gray-400">Match Candidates</p>
            <div className="space-y-2">
              {txn.candidates.map((c) => (
                <div
                  key={c.id}
                  className={cn(
                    'flex items-center justify-between rounded-lg border px-3 py-2 text-sm',
                    c.selected ? 'border-indigo-400 bg-indigo-50' : 'border-gray-200'
                  )}
                >
                  <div>
                    <p className="font-medium">{c.customer_name ?? 'Unknown customer'}</p>
                    <p className="text-xs text-gray-500">
                      {c.invoice_number ? `Invoice ${c.invoice_number}` : 'No invoice'}
                      {c.invoice_outstanding != null &&
                        ` · Outstanding ${formatCurrency(c.invoice_outstanding)}`}
                    </p>
                  </div>
                  <span
                    className={cn(
                      'rounded-full px-2 py-0.5 text-xs font-medium',
                      c.score >= 95
                        ? 'bg-green-100 text-green-700'
                        : c.score >= 80
                        ? 'bg-yellow-100 text-yellow-700'
                        : 'bg-gray-100 text-gray-600'
                    )}
                  >
                    {c.score.toFixed(0)}
                  </span>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Action selector */}
        <div className="flex gap-2 border-b px-6 py-3">
          {(['confirm', 'split', 'advance'] as const).map((m) => (
            <button
              key={m}
              onClick={() => setMode(m)}
              className={cn(
                'rounded-md px-3 py-1.5 text-xs font-medium capitalize transition-colors',
                mode === m
                  ? 'bg-indigo-600 text-white'
                  : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
              )}
            >
              {m === 'confirm' ? 'Confirm Match' : m === 'split' ? 'Split Allocation' : 'Mark Advance'}
            </button>
          ))}
        </div>

        {/* Action body */}
        <div className="flex-1 overflow-y-auto px-6 py-4">
          {mode === 'confirm' && (
            <div className="space-y-4">
              <p className="text-sm text-gray-600">
                Allocate the full transaction amount to the matched invoice.
              </p>
              {allocations.map((alloc, idx) => (
                <div key={idx} className="flex gap-2">
                  <div className="flex-1">
                    <label className="mb-1 block text-xs text-gray-500">Invoice ID</label>
                    <Input
                      type="number"
                      value={alloc.invoice_id || ''}
                      onChange={(e) => {
                        const updated = [...allocations]
                        updated[idx] = { ...updated[idx], invoice_id: Number(e.target.value) }
                        setAllocations(updated)
                      }}
                      placeholder="Invoice ID"
                    />
                  </div>
                  <div className="w-36">
                    <label className="mb-1 block text-xs text-gray-500">Amount</label>
                    <Input
                      type="number"
                      step="0.01"
                      value={alloc.amount}
                      onChange={(e) => {
                        const updated = [...allocations]
                        updated[idx] = { ...updated[idx], amount: Number(e.target.value) }
                        setAllocations(updated)
                      }}
                    />
                  </div>
                </div>
              ))}
            </div>
          )}

          {mode === 'split' && (
            <div className="space-y-4">
              <p className="text-sm text-gray-600">
                Split across multiple invoices. Total must not exceed{' '}
                <strong>{formatCurrency(txn.amount)}</strong>.
              </p>
              {allocations.map((alloc, idx) => (
                <div key={idx} className="flex gap-2">
                  <div className="flex-1">
                    <label className="mb-1 block text-xs text-gray-500">Invoice ID</label>
                    <Input
                      type="number"
                      value={alloc.invoice_id || ''}
                      onChange={(e) => {
                        const updated = [...allocations]
                        updated[idx] = { ...updated[idx], invoice_id: Number(e.target.value) }
                        setAllocations(updated)
                      }}
                    />
                  </div>
                  <div className="w-36">
                    <label className="mb-1 block text-xs text-gray-500">Amount</label>
                    <Input
                      type="number"
                      step="0.01"
                      value={alloc.amount}
                      onChange={(e) => {
                        const updated = [...allocations]
                        updated[idx] = { ...updated[idx], amount: Number(e.target.value) }
                        setAllocations(updated)
                      }}
                    />
                  </div>
                  {allocations.length > 1 && (
                    <button
                      className="mt-5 text-red-400 hover:text-red-600"
                      onClick={() => setAllocations((a) => a.filter((_, i) => i !== idx))}
                    >
                      ✕
                    </button>
                  )}
                </div>
              ))}
              <Button
                size="sm"
                variant="outline"
                onClick={() => setAllocations((a) => [...a, { invoice_id: 0, amount: 0 }])}
              >
                + Add line
              </Button>
            </div>
          )}

          {mode === 'advance' && (
            <div className="space-y-4">
              <p className="text-sm text-gray-600">
                Record the full amount as an advance payment for the customer.
              </p>
              <div>
                <label className="mb-1 block text-xs text-gray-500">Customer ID</label>
                <Input
                  type="number"
                  value={customerId}
                  onChange={(e) => setCustomerId(e.target.value)}
                  placeholder="Customer ID"
                />
              </div>
            </div>
          )}

          {/* Error display */}
          {(confirmMut.error || advanceMut.error || ignoreMut.error || retryMut.error) && (
            <p className="mt-4 rounded-md bg-red-50 px-3 py-2 text-sm text-red-600">
              {getErrorMsg(confirmMut.error ?? advanceMut.error ?? ignoreMut.error ?? retryMut.error)}
            </p>
          )}
        </div>

        {/* Footer actions */}
        <div className="flex items-center justify-between border-t px-6 py-4">
          <div className="flex gap-2">
            <Button
              size="sm"
              variant="ghost"
              className="text-gray-500"
              disabled={isBusy}
              onClick={handleIgnore}
            >
              Ignore
            </Button>
            <Button
              size="sm"
              variant="ghost"
              className="text-gray-500"
              disabled={isBusy}
              onClick={handleRetry}
            >
              Re-run Matcher
            </Button>
          </div>
          <div className="flex gap-2">
            <Button variant="outline" size="sm" onClick={onClose} disabled={isBusy}>
              Cancel
            </Button>
            <Button
              size="sm"
              disabled={isBusy}
              onClick={mode === 'advance' ? handleAdvance : handleConfirm}
            >
              {isBusy ? 'Saving…' : mode === 'advance' ? 'Post Advance' : 'Post Payment'}
            </Button>
          </div>
        </div>
      </div>
    </div>
  )
}

function Detail({
  label,
  value,
  highlight,
}: {
  label: string
  value: string
  highlight?: boolean
}) {
  return (
    <div>
      <span className="text-xs text-gray-400">{label}</span>
      <p className={cn('mt-0.5 text-sm', highlight ? 'font-semibold text-gray-900' : 'text-gray-700')}>
        {value}
      </p>
    </div>
  )
}
