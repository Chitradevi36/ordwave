"use client";

import { Bell, Search, User } from "lucide-react";

export interface TopBarProps {
  title?: string;
}

export function TopBar({ title }: TopBarProps) {
  return (
    <header className="flex h-16 items-center justify-between border-b border-border bg-background px-6">
      {title && (
        <h1 className="text-lg font-semibold text-text-primary">{title}</h1>
      )}
      <div className="ml-auto flex items-center gap-3">
        <button className="flex h-9 w-9 items-center justify-center rounded-lg border border-border hover:bg-background-subtle transition-colors">
          <Search className="h-4 w-4 text-text-secondary" />
        </button>
        <button className="relative flex h-9 w-9 items-center justify-center rounded-lg border border-border hover:bg-background-subtle transition-colors">
          <Bell className="h-4 w-4 text-text-secondary" />
          <span className="absolute right-1.5 top-1.5 h-2 w-2 rounded-full bg-danger" />
        </button>
        <button className="flex h-9 w-9 items-center justify-center rounded-full bg-primary text-white hover:bg-primary-700 transition-colors">
          <User className="h-4 w-4" />
        </button>
      </div>
    </header>
  );
}
