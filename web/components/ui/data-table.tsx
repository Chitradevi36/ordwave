"use client";

import React from "react";
import { ChevronUp, ChevronDown, ArrowUpDown } from "lucide-react";
import { cn } from "@/lib/utils";

export interface Column<T> {
  key: keyof T | string;
  header: string;
  render?: (value: unknown, row: T) => React.ReactNode;
  className?: string;
  sortable?: boolean;
}

export interface DataTableProps<T> {
  columns: Column<T>[];
  data: T[];
  className?: string;
  emptyMessage?: string;
  emptyContent?: React.ReactNode;
  isLoading?: boolean;
  onRowClick?: (row: T) => void;
  rowClassName?: (row: T) => string | undefined;
  sortBy?: string;
  sortDir?: "asc" | "desc";
  onSort?: (key: string) => void;
}

export function DataTable<T extends { id?: string | number }>({
  columns,
  data,
  className,
  emptyMessage = "No data available",
  emptyContent,
  isLoading = false,
  onRowClick,
  rowClassName,
  sortBy,
  sortDir,
  onSort,
}: DataTableProps<T>) {
  if (isLoading) {
    return (
      <div className={cn("w-full overflow-auto rounded-lg border border-border", className)}>
        <table className="w-full min-w-[760px] text-sm">
          <thead className="bg-background-subtle">
            <tr>
              {columns.map((col) => (
                <th
                  key={String(col.key)}
                  className={cn(
                    "px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-text-secondary",
                    col.className
                  )}
                >
                  {col.header}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-border bg-background">
            {Array.from({ length: 6 }).map((_, idx) => (
              <tr key={idx}>
                {columns.map((col) => (
                  <td key={`${String(col.key)}-${idx}`} className={cn("px-4 py-3", col.className)}>
                    <div className="h-4 w-3/4 animate-pulse rounded bg-background-subtle" />
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    );
  }

  return (
    <div className={cn("w-full overflow-auto rounded-lg border border-border", className)}>
      <table className="w-full min-w-[760px] text-sm">
        <thead className="bg-background-subtle sticky top-0 z-10">
          <tr>
            {columns.map((col) => (
              <th
                key={String(col.key)}
                className={cn(
                  "px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-text-secondary",
                  col.sortable && "cursor-pointer select-none",
                  col.className
                )}
                onClick={() => col.sortable && onSort?.(String(col.key))}
              >
                {col.sortable ? (
                  <span className="inline-flex items-center gap-1 hover:text-text-primary transition-colors">
                    {col.header}
                    {sortBy === String(col.key)
                      ? sortDir === "asc" ? <ChevronUp className="h-3 w-3" /> : <ChevronDown className="h-3 w-3" />
                      : <ArrowUpDown className="h-3 w-3 opacity-40" />}
                  </span>
                ) : col.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody className="divide-y divide-border bg-background">
          {data.length === 0 ? (
            <tr>
              <td
                colSpan={columns.length}
                className="py-12 text-center text-text-secondary"
              >
                {emptyContent ?? emptyMessage}
              </td>
            </tr>
          ) : (
            data.map((row, idx) => (
              <tr
                key={row.id ?? idx}
                onClick={() => onRowClick?.(row)}
                className={cn(
                  "hover:bg-background-subtle transition-colors",
                  onRowClick && "cursor-pointer",
                  rowClassName?.(row)
                )}
              >
                {columns.map((col) => (
                  <td
                    key={String(col.key)}
                    className={cn("px-4 py-3 text-text-primary", col.className)}
                  >
                    {col.render
                      ? col.render(row[col.key as keyof T] as unknown, row)
                      : String(row[col.key as keyof T] ?? "")}
                  </td>
                ))}
              </tr>
            ))
          )}
        </tbody>
      </table>
    </div>
  );
}
