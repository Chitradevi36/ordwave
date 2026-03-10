"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { FileText, Download, Eye } from "lucide-react";

export interface DocumentItem {
  id: string;
  type: "order" | "invoice" | "pod" | "credit_note";
  name: string;
  url?: string;
  createdAt?: string;
}

const DOCUMENT_TYPE_CONFIG: Record<string, { icon: React.ReactNode; label: string }> = {
  order: { icon: <FileText className="h-5 w-5" />, label: "Sales Order" },
  invoice: { icon: <FileText className="h-5 w-5" />, label: "Invoice" },
  pod: { icon: <FileText className="h-5 w-5" />, label: "Delivery POD" },
  credit_note: { icon: <FileText className="h-5 w-5" />, label: "Credit Note" },
};

export interface DocumentsPanelProps {
  documents: DocumentItem[];
  onDownload?: (docId: string) => void;
  onPreview?: (docId: string) => void;
}

export function DocumentsPanel({
  documents,
  onDownload,
  onPreview,
}: DocumentsPanelProps) {
  if (documents.length === 0) {
    return (
      <Card>
        <CardContent className="pt-6">
          <p className="text-sm text-text-secondary italic">
            No documents available yet.
          </p>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-sm">Documents ({documents.length})</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="space-y-2 sm:space-y-3">
          {documents.map((doc) => {
            const config = DOCUMENT_TYPE_CONFIG[doc.type];
            return (
              <div
                key={doc.id}
                className="flex items-center justify-between p-2 sm:p-3 rounded-lg border border-border hover:bg-background-subtle transition-colors gap-2"
              >
                <div className="flex items-start gap-2 sm:gap-3 flex-1 min-w-0">
                  <div className="text-text-secondary shrink-0 mt-0.5">
                    {config?.icon}
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="text-xs sm:text-sm font-medium text-text-primary">
                      {config?.label || doc.type.replace("_", " ")}
                    </p>
                    <p className="text-xs text-text-secondary truncate">
                      {doc.name}
                    </p>
                    {doc.createdAt && (
                      <p className="text-xs text-text-secondary mt-1">
                        {new Date(doc.createdAt).toLocaleDateString("en-IN")}
                      </p>
                    )}
                  </div>
                </div>

                <div className="flex gap-1 shrink-0">
                  {onPreview && (
                    <Button
                      size="sm"
                      variant="ghost"
                      onClick={() => onPreview(doc.id)}
                      title="Preview"
                    >
                      <Eye className="h-4 w-4" />
                    </Button>
                  )}
                  {onDownload && (
                    <Button
                      size="sm"
                      variant="ghost"
                      onClick={() => onDownload(doc.id)}
                      title="Download"
                    >
                      <Download className="h-4 w-4" />
                    </Button>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </CardContent>
    </Card>
  );
}
