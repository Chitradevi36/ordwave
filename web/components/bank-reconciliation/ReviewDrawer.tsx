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
import { Badge } from '@/components/ui/badge'
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
      <div className="relative flex h-full w-full max-w-xl flex-col bg-background shadow-xl">
        {/* Header */}
        <div className="flex items-center justify-between border-b px-6 py-4">
          <h2 className="text-base font-semibold text-text-primary">Review Transaction</h2>
          <button onClick={onClose} className="text-text-secondary hover:text-text-primary">
            ✕
          </button>
        </div>

        {/* Transaction details */}
        <div className="border-b bg-background-subtle px-6 py-4 text-sm">
          <div className="grid grid-cols-2 gap-x-6 gap-y-1">
            <Detail label="Date"          value={formatDate(txn.txn_date)} />
            <Detail label="Amount"        value={formatCurrency(txn.amount)}       highlight />
            <Detail label="Direction"     value={txn.direction}                    />
            <Detail label="Status"        value={txn.status.replace('_', ' ')}     />
            <Detail label="UTR / Ref"     value={txn.utr_number ?? txn.reference_number ?? '—'} />
            <Detail label="Match Score"   value={best ? `${best.score.toFixed(0)} (${best.rule_code})` : '—'} />
          </div>
          <div className="mt-2">
            <span className="text-xs text-text-secondary">Narration</span>
            <p className="mt-0.5 text-text-primary">{txn.narration}</p>
          </div>
        </div>

        {/* Suggested candidates */}
        {txn.candidates.length > 0 && (
          <div className="border-b px-6 py-4">
            <p className="mb-2 text-xs font-medium uppercase text-text-secondary">Match Candidates</p>
            <div className="space-y-2">
              {txn.candidates.map((c) => (
                <div
                  key={c.id}
                  className={cn(
                    'flex items-center justify-between rounded-lg border px-3 py-2 text-sm',
                    c.selected ? 'border-primary/40 bg-primary/5' : 'border-border'
                  )}
                >
                  <div>
                    <p className="font-medium text-text-primary">{c.customer_name ?? 'Unknown customer'}</p>
                    <p className="text-xs text-text-secondary">
                      {c.invoice_number ? `Invoice ${c.invoice_number}` : 'No invoice'}
                      {c.invoice_outstanding != null &&
                        ` · Outstanding ${formatCurrency(c.invoice_outstanding)}`}
                    </p>
                  </div>
                  <Badge
                    variant={c.score >= 95 ? 'success' : c.score >= 80 ? 'warning' : 'secondary'}
                  >
                    {c.score.toFixed(0)}
                  </Badge>
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
                  ? 'bg-primary text-white'
                  : 'bg-background-subtle text-text-secondary hover:bg-border/40'
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
              <p className="text-sm text-text-secondary">
                Allocate the full transaction amount to the matched invoice.
              </p>
              {allocations.map((alloc, idx) => (
                <div key={idx} className="flex gap-2">
                  <div className="flex-1">
                    <label className="mb-1 block text-xs text-text-secondary">Invoice ID</label>
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
                    <label className="mb-1 block text-xs text-text-secondary">Amount</label>
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
              <p className="text-sm text-text-secondary">
                Split across multiple invoices. Total must not exceed{' '}
                <strong>{formatCurrency(txn.amount)}</strong>.
              </p>
              {allocations.map((alloc, idx) => (
                <div key={idx} className="flex gap-2">
                  <div className="flex-1">
                    <label className="mb-1 block text-xs text-text-secondary">Invoice ID</label>
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
                    <label className="mb-1 block text-xs text-text-secondary">Amount</label>
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
                      className="mt-5 text-danger/60 hover:text-danger"
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
              <p className="text-sm text-text-secondary">
                Record the full amount as an advance payment for the customer.
              </p>
              <div>
                <label className="mb-1 block text-xs text-text-secondary">Customer ID</label>
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
            <p className="mt-4 rounded-md bg-red-50 px-3 py-2 text-sm text-danger">
              {getErrorMsg(confirmMut.error ?? advanceMut.error ?? ignoreMut.error ?? retryMut.error)}
            </p>
          )}
        </div>

        {/* Footer actions */}
        <div className="flex items-center justify-between border-t px-6 py-4">
          <div className="flex gap-2">
            <Button size="sm" variant="ghost" className="text-text-secondary" disabled={isBusy} onClick={handleIgnore}>
              Ignore
            </Button>
            <Button size="sm" variant="ghost" className="text-text-secondary" disabled={isBusy} onClick={handleRetry}>
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

function Detail({ label, value, highlight }: { label: string; value: string; highlight?: boolean }) {
  return (
    <div>
      <span className="text-xs text-text-secondary">{label}</span>
      <p className={cn('mt-0.5 text-sm', highlight ? 'font-semibold text-text-primary' : 'text-text-primary')}>
        {value}
      </p>
    </div>
  )
}
