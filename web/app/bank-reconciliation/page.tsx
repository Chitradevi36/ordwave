'use client'

import { useState } from 'react'
import { useBankTransactions } from '@/lib/api/hooks/useBankTransactions'
import type { BankTransaction, TxnTab, TxnStatus } from '@/types/bankReconciliation'
import { ReviewDrawer } from '@/components/bank-reconciliation/ReviewDrawer'
import { ImportScreen } from '@/components/bank-reconciliation/ImportScreen'
import { Button } from '@/components/ui/button'
import { cn, formatCurrency, formatDate } from '@/lib/utils'

const TABS: { key: TxnTab; label: string; status: TxnStatus | TxnStatus[] }[] = [
  { key: 'auto_matched', label: 'Auto Matched',    status: 'auto_matched' },
  { key: 'suggested',    label: 'Needs Review',     status: 'suggested'   },
  { key: 'unmatched',    label: 'Unmatched',        status: 'unmatched'   },
  { key: 'matched',      label: 'History',          status: 'matched'     },
  { key: 'ignored',      label: 'Ignored',          status: 'ignored'     },
]

const STATUS_BADGE: Record<string, string> = {
  auto_matched: 'bg-blue-100 text-blue-700',
  suggested:    'bg-yellow-100 text-yellow-700',
  unmatched:    'bg-red-100 text-red-700',
  matched:      'bg-green-100 text-green-700',
  ignored:      'bg-gray-100 text-gray-500',
}

export default function BankReconciliationPage() {
  const [activeTab, setActiveTab] = useState<TxnTab>('suggested')
  const [page, setPage]           = useState(1)
  const [selectedTxn, setSelectedTxn] = useState<BankTransaction | null>(null)
  const [showImport, setShowImport]   = useState(false)

  const statusFilter = TABS.find((t) => t.key === activeTab)?.status
  const statusParam  = Array.isArray(statusFilter) ? statusFilter[0] : statusFilter

  const { data, isLoading, mutate } = useBankTransactions({
    status: statusParam,
    page,
    per_page: 25,
  })

  const transactions = data?.data ?? []
  const meta         = data?.meta

  function handleTabChange(tab: TxnTab) {
    setActiveTab(tab)
    setPage(1)
  }

  function handleReviewSaved() {
    setSelectedTxn(null)
    mutate()
  }

  return (
    <div className="flex h-full flex-col">
      {/* Header */}
      <div className="flex items-center justify-between border-b px-6 py-4">
        <div>
          <h1 className="text-xl font-semibold text-gray-900">Bank Reconciliation</h1>
          <p className="mt-0.5 text-sm text-gray-500">
            Match incoming bank credits to invoices and customer payments.
          </p>
        </div>
        <Button onClick={() => setShowImport(true)}>Upload Statement</Button>
      </div>

      {/* Tabs */}
      <div className="flex gap-0 border-b px-6">
        {TABS.map((tab) => (
          <button
            key={tab.key}
            onClick={() => handleTabChange(tab.key)}
            className={cn(
              'px-4 py-3 text-sm font-medium border-b-2 transition-colors',
              activeTab === tab.key
                ? 'border-indigo-600 text-indigo-600'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            )}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Table */}
      <div className="flex-1 overflow-auto">
        {isLoading ? (
          <div className="flex h-48 items-center justify-center text-sm text-gray-400">
            Loading transactions…
          </div>
        ) : transactions.length === 0 ? (
          <div className="flex h-48 items-center justify-center text-sm text-gray-400">
            No transactions in this category.
          </div>
        ) : (
          <table className="min-w-full divide-y divide-gray-100 text-sm">
            <thead className="bg-gray-50 text-xs font-medium uppercase text-gray-500">
              <tr>
                <th className="px-4 py-3 text-left">Date</th>
                <th className="px-4 py-3 text-left">Narration</th>
                <th className="px-4 py-3 text-right">Amount</th>
                <th className="px-4 py-3 text-left">Status</th>
                <th className="px-4 py-3 text-left">Suggested Match</th>
                <th className="px-4 py-3 text-left">Score</th>
                <th className="px-4 py-3" />
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50 bg-white">
              {transactions.map((txn) => {
                const best = txn.candidates.find((c) => c.selected)
                return (
                  <tr
                    key={txn.id}
                    className="cursor-pointer hover:bg-gray-50"
                    onClick={() => setSelectedTxn(txn)}
                  >
                    <td className="px-4 py-3 whitespace-nowrap">
                      {formatDate(txn.txn_date)}
                    </td>
                    <td className="max-w-xs truncate px-4 py-3" title={txn.narration}>
                      {txn.narration}
                    </td>
                    <td className="px-4 py-3 text-right font-medium text-gray-900">
                      {formatCurrency(txn.amount)}
                    </td>
                    <td className="px-4 py-3">
                      <span
                        className={cn(
                          'inline-flex rounded-full px-2 py-0.5 text-xs font-medium',
                          STATUS_BADGE[txn.status] ?? 'bg-gray-100 text-gray-600'
                        )}
                      >
                        {txn.status.replace('_', ' ')}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-gray-700">
                      {best ? (
                        <span>
                          {best.customer_name && (
                            <span className="font-medium">{best.customer_name}</span>
                          )}
                          {best.invoice_number && (
                            <span className="ml-1 text-gray-400">· {best.invoice_number}</span>
                          )}
                        </span>
                      ) : (
                        <span className="text-gray-400">—</span>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      {best ? (
                        <span
                          className={cn(
                            'font-medium',
                            best.score >= 95
                              ? 'text-green-600'
                              : best.score >= 80
                              ? 'text-yellow-600'
                              : 'text-red-500'
                          )}
                        >
                          {best.score.toFixed(0)}
                        </span>
                      ) : (
                        <span className="text-gray-400">—</span>
                      )}
                    </td>
                    <td className="px-4 py-3 text-right">
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={(e) => {
                          e.stopPropagation()
                          setSelectedTxn(txn)
                        }}
                      >
                        Review
                      </Button>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        )}
      </div>

      {/* Pagination */}
      {meta && meta.total_pages > 1 && (
        <div className="flex items-center justify-between border-t px-6 py-3 text-sm text-gray-500">
          <span>
            {meta.total_count} transactions · Page {meta.current_page} of {meta.total_pages}
          </span>
          <div className="flex gap-2">
            <Button
              size="sm"
              variant="outline"
              disabled={page <= 1}
              onClick={() => setPage((p) => p - 1)}
            >
              Previous
            </Button>
            <Button
              size="sm"
              variant="outline"
              disabled={page >= meta.total_pages}
              onClick={() => setPage((p) => p + 1)}
            >
              Next
            </Button>
          </div>
        </div>
      )}

      {/* Review Drawer */}
      {selectedTxn && (
        <ReviewDrawer
          txn={selectedTxn}
          onClose={() => setSelectedTxn(null)}
          onSaved={handleReviewSaved}
        />
      )}

      {/* Import Screen */}
      {showImport && (
        <ImportScreen onClose={() => setShowImport(false)} onImported={() => mutate()} />
      )}
    </div>
  )
}
