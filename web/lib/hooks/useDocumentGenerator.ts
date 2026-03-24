// ── Document Generation Hook ───────────────────────────────────────────────
// Manages document generation, retrieval, and batch operations

import { useCallback, useState } from 'react';
import { apiClient } from '@/lib/api/client';

export type DocumentType = 'invoice' | 'waybill' | 'ewaybill' | 'delivery_receipt' | 'credit_note';

export interface DocumentData {
  type: DocumentType;
  reference_id?: string;
  data: Record<string, any>;
}

export interface Document {
  id: string;
  type: string;
  filename: string;
  size: number;
  size_formatted: string;
  status: string;
  created_at: string;
  download_url: string;
  metadata?: Record<string, any>;
  archived_at?: string;
  regenerated?: boolean;
}

export interface DocumentStats {
  total_count: number;
  by_type: Record<string, number>;
  total_size_mb: number;
  average_size_kb: number;
  created_this_month: number;
}

export interface UseDocumentGeneratorReturn {
  // State
  isLoading: boolean;
  error: string | null;
  documents: Document[];
  stats: DocumentStats | null;

  // Methods
  generateDocument: (documentData: DocumentData) => Promise<Document | null>;
  batchGenerateDocuments: (
    type: DocumentType,
    documentsData: Array<{ data: Record<string, any> }>
  ) => Promise<{ generated: number; failed: number; documents: Document[] } | null>;
  listDocuments: (filters?: {
    type?: DocumentType;
    startDate?: string;
    endDate?: string;
  }) => Promise<Document[]>;
  downloadDocument: (documentId: string) => Promise<void>;
  regenerateDocument: (documentId: string, updatedData?: Record<string, any>) => Promise<Document | null>;
  archiveDocument: (documentId: string) => Promise<void>;
  getStatistics: () => Promise<DocumentStats | null>;
  clearError: () => void;
}

export const useDocumentGenerator = (): UseDocumentGeneratorReturn => {
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [documents, setDocuments] = useState<Document[]>([]);
  const [stats, setStats] = useState<DocumentStats | null>(null);

  const clearError = useCallback(() => {
    setError(null);
  }, []);

  const handleError = useCallback(
    (err: any, message: string) => {
      console.error(`[DocumentGenerator] ${message}:`, err);
      const errorMsg = err?.response?.data?.errors?.[0] || err?.message || message;
      setError(errorMsg);
      setIsLoading(false);
    },
    []
  );

  // ── Generate Single Document ───────────────────────────────────────────────
  const generateDocument = useCallback(
    async (documentData: DocumentData): Promise<Document | null> => {
      setIsLoading(true);
      clearError();

      try {
        const response = await apiClient.post('/api/v1/documents/generate', documentData);

        return response.data || null;
      } catch (err: any) {
        handleError(err, `Failed to generate ${documentData.type} document`);
        return null;
      } finally {
        setIsLoading(false);
      }
    },
    [clearError, handleError]
  );

  // ── Generate Multiple Documents in Batch ─────────────────────────────────
  const batchGenerateDocuments = useCallback(
    async (
      type: DocumentType,
      documentsData: Array<{ data: Record<string, any> }>
    ): Promise<{ generated: number; failed: number; documents: Document[] } | null> => {
      setIsLoading(true);
      clearError();

      try {
        const response = await apiClient.post('/api/v1/documents/batch_generate', {
          type,
          documents: documentsData,
        });

        const result = response.data || { generated: 0, failed: 0, documents: [] };
        return result;
      } catch (err: any) {
        handleError(err, `Batch generation failed for ${type} documents`);
        return null;
      } finally {
        setIsLoading(false);
      }
    },
    [clearError, handleError]
  );

  // ── List Documents with Filters ────────────────────────────────────────────
  const listDocuments = useCallback(
    async (filters?: { type?: DocumentType; startDate?: string; endDate?: string }): Promise<Document[]> => {
      setIsLoading(true);
      clearError();

      try {
        const params = new URLSearchParams();
        if (filters?.type) params.append('type', filters.type);
        if (filters?.startDate) params.append('start_date', filters.startDate);
        if (filters?.endDate) params.append('end_date', filters.endDate);

        const response = await apiClient.get(`/api/v1/documents?${params.toString()}`);

        const docs = response.data || [];
        setDocuments(docs);
        return docs;
      } catch (err: any) {
        handleError(err, 'Failed to fetch documents');
        return [];
      } finally {
        setIsLoading(false);
      }
    },
    [clearError, handleError]
  );

  // ── Download Document ──────────────────────────────────────────────────────
  const downloadDocument = useCallback(
    async (documentId: string): Promise<void> => {
      setIsLoading(true);
      clearError();

      try {
        const response = await apiClient.get(`/api/v1/documents/${documentId}/download`, {
          responseType: 'blob',
        });

        // Get filename from Content-Disposition header or use default
        const contentDisposition = response.headers['content-disposition'];
        const filename = contentDisposition
          ? contentDisposition.split('filename=')[1]?.replace(/"/g, '')
          : `document-${documentId}.pdf`;

        // Create blob URL and trigger download
        const url = window.URL.createObjectURL(new Blob([response.data]));
        const link = document.createElement('a');
        link.href = url;
        link.setAttribute('download', filename);
        document.body.appendChild(link);
        link.click();
        link.parentNode?.removeChild(link);
        window.URL.revokeObjectURL(url);
      } catch (err: any) {
        handleError(err, 'Failed to download document');
      } finally {
        setIsLoading(false);
      }
    },
    [clearError, handleError]
  );

  // ── Regenerate Document ────────────────────────────────────────────────────
  const regenerateDocument = useCallback(
    async (documentId: string, updatedData?: Record<string, any>): Promise<Document | null> => {
      setIsLoading(true);
      clearError();

      try {
        const response = await apiClient.patch(`/api/v1/documents/${documentId}/regenerate`, {
          data: updatedData,
        });

        return response.data || null;
      } catch (err: any) {
        handleError(err, 'Failed to regenerate document');
        return null;
      } finally {
        setIsLoading(false);
      }
    },
    [clearError, handleError]
  );

  // ── Archive Document ───────────────────────────────────────────────────────
  const archiveDocument = useCallback(
    async (documentId: string): Promise<void> => {
      setIsLoading(true);
      clearError();

      try {
        await apiClient.delete(`/api/v1/documents/${documentId}/archive`);

        // Remove from local state
        setDocuments((prev) => prev.filter((doc) => doc.id !== documentId));
      } catch (err: any) {
        handleError(err, 'Failed to archive document');
      } finally {
        setIsLoading(false);
      }
    },
    [clearError, handleError]
  );

  // ── Get Statistics ──────────────────────────────────────────────────────────
  const getStatistics = useCallback(
    async (): Promise<DocumentStats | null> => {
      setIsLoading(true);
      clearError();

      try {
        const response = await apiClient.get('/api/v1/documents/statistics');

        const statsData = response.data || null;
        setStats(statsData);
        return statsData;
      } catch (err: any) {
        handleError(err, 'Failed to fetch document statistics');
        return null;
      } finally {
        setIsLoading(false);
      }
    },
    [clearError, handleError]
  );

  return {
    isLoading,
    error,
    documents,
    stats,
    generateDocument,
    batchGenerateDocuments,
    listDocuments,
    downloadDocument,
    regenerateDocument,
    archiveDocument,
    getStatistics,
    clearError,
  };
};
