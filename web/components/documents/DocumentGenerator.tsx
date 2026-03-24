// ── Document Generator Component ──────────────────────────────────────────
// UI for generating and managing documents

'use client';

import React, { useEffect, useState } from 'react';
import { useDocumentGenerator, DocumentType, type Document as DocType } from '@/lib/hooks/useDocumentGenerator';
import { Card } from '@/components/ui/card';
import { Alert } from '@/components/ui/alert';
import {
  Loader2,
  Download,
  Archive,
  RefreshCw,
  FileText,
  Calendar,
  AlertTriangle,
} from 'lucide-react';

export interface DocumentGeneratorProps {
  onDocumentGenerated?: (doc: DocType) => void;
  showStats?: boolean;
}

/**
 * DocumentGenerator Component
 *
 * Provides UI for:
 * - Generating invoices, waybills, receipts, credit notes
 * - Downloading generated documents
 * - Viewing document history
 * - Managing document lifecycle
 */
export const DocumentGenerator: React.FC<DocumentGeneratorProps> = ({
  onDocumentGenerated,
  showStats = true,
}) => {
  const {
    isLoading,
    error,
    documents,
    stats,
    generateDocument,
    listDocuments,
    downloadDocument,
    archiveDocument,
    getStatistics,
    clearError,
  } = useDocumentGenerator();

  const [selectedType, setSelectedType] = useState<DocumentType>('invoice');
  const [showForm, setShowForm] = useState(false);

  // Load documents and stats on mount
  useEffect(() => {
    listDocuments();
    if (showStats) {
      getStatistics();
    }
  }, []);

  const handleGenerateClick = () => {
    setShowForm(true);
  };

  const handleDownloadDocument = async (doc: DocType) => {
    await downloadDocument(doc.id);
  };

  const handleArchiveDocument = async (doc: DocType) => {
    if (confirm('Are you sure you want to archive this document?')) {
      await archiveDocument(doc.id);
      // Refresh list
      listDocuments();
    }
  };

  const getDocumentIcon = (type: string) => {
    switch (type) {
      case 'invoice':
        return '📄';
      case 'waybill':
      case 'ewaybill':
        return '📦';
      case 'delivery_receipt':
        return '✓';
      case 'credit_note':
        return '↩️';
      default:
        return '📄';
    }
  };

  const getDocumentLabel = (type: string): string => {
    const labels: Record<string, string> = {
      invoice: 'Invoice',
      waybill: 'Waybill',
      ewaybill: 'E-Waybill',
      delivery_receipt: 'Delivery Receipt',
      credit_note: 'Credit Note',
    };
    return labels[type] || type;
  };

  return (
    <div className="space-y-6">
      {error && (
        <Alert variant="danger" className="mb-4">
          <div className="flex items-center gap-2">
            <AlertTriangle className="h-4 w-4 flex-shrink-0" />
            <span>{error}</span>
          </div>
        </Alert>
      )}

      {/* Stats Section */}
      {showStats && stats && (
        <div className="grid grid-cols-4 gap-4">
          <Card className="p-4">
            <div className="text-sm text-gray-600">Total Documents</div>
            <div className="text-2xl font-bold text-blue-600">{stats.total_count}</div>
          </Card>
          <Card className="p-4">
            <div className="text-sm text-gray-600">This Month</div>
            <div className="text-2xl font-bold text-green-600">{stats.created_this_month}</div>
          </Card>
          <Card className="p-4">
            <div className="text-sm text-gray-600">Total Size</div>
            <div className="text-2xl font-bold text-purple-600">{stats.total_size_mb} MB</div>
          </Card>
          <Card className="p-4">
            <div className="text-sm text-gray-600">Avg Size</div>
            <div className="text-2xl font-bold text-orange-600">{stats.average_size_kb.toFixed(0)} KB</div>
          </Card>
        </div>
      )}

      {/* Generate Button */}
      <Card className="p-6">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-lg font-semibold mb-2">Generate New Document</h3>
            <p className="text-sm text-gray-600">Create invoices, waybills, receipts, and more</p>
          </div>
          <button
            onClick={handleGenerateClick}
            disabled={isLoading}
            className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 flex items-center gap-2"
          >
            {isLoading ? <Loader2 className="w-4 h-4 animate-spin" /> : <FileText className="w-4 h-4" />}
            Generate
          </button>
        </div>

        {showForm && (
          <div className="mt-4 p-4 bg-gray-50 rounded border">
            <label className="block mb-3">
              <span className="text-sm font-semibold">Document Type</span>
              <select
                value={selectedType}
                onChange={(e) => setSelectedType(e.target.value as DocumentType)}
                className="w-full mt-1 px-3 py-2 border rounded"
              >
                <option value="invoice">Invoice</option>
                <option value="waybill">Waybill</option>
                <option value="ewaybill">E-Waybill (GST)</option>
                <option value="delivery_receipt">Delivery Receipt</option>
                <option value="credit_note">Credit Note</option>
              </select>
            </label>
            <p className="text-xs text-gray-600 italic">
              Select document type and open detailed form to fill in document data
            </p>
          </div>
        )}
      </Card>

      {/* Documents List */}
      <Card className="p-6">
        <h3 className="text-lg font-semibold mb-4">Recent Documents</h3>

        {isLoading && documents.length === 0 ? (
          <div className="flex justify-center py-8">
            <Loader2 className="w-8 h-8 animate-spin text-blue-600" />
          </div>
        ) : documents.length === 0 ? (
          <div className="text-center py-8">
            <FileText className="w-12 h-12 mx-auto text-gray-400 mb-3" />
            <p className="text-gray-500">No documents generated yet</p>
          </div>
        ) : (
          <div className="space-y-2">
            {documents.map((doc) => (
              <div key={doc.id} className="flex items-center justify-between p-3 bg-gray-50 rounded hover:bg-gray-100">
                <div className="flex items-center gap-3 flex-1">
                  <span className="text-xl">{getDocumentIcon(doc.type)}</span>
                  <div className="flex-1">
                    <div className="font-medium text-sm">{doc.filename}</div>
                    <div className="text-xs text-gray-600 flex items-center gap-2">
                      <span>{getDocumentLabel(doc.type)}</span>
                      <span>•</span>
                      <Calendar className="w-3 h-3" />
                      <span>{new Date(doc.created_at).toLocaleDateString()}</span>
                      <span>•</span>
                      <span>{doc.size_formatted}</span>
                    </div>
                  </div>
                </div>

                <div className="flex items-center gap-2">
                  <button
                    onClick={() => handleDownloadDocument(doc)}
                    disabled={isLoading}
                    className="p-2 hover:bg-blue-100 rounded text-blue-600 disabled:opacity-50"
                    title="Download"
                  >
                    <Download className="w-4 h-4" />
                  </button>
                  <button
                    onClick={() => handleArchiveDocument(doc)}
                    disabled={isLoading}
                    className="p-2 hover:bg-red-100 rounded text-red-600 disabled:opacity-50"
                    title="Archive"
                  >
                    <Archive className="w-4 h-4" />
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </Card>
    </div>
  );
};

export default DocumentGenerator;
