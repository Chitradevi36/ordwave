import React from "react";
import { cn } from "@/lib/utils";
import { Button } from "./button";
import { LucideIcon } from "lucide-react";

export interface EmptyStateProps {
  /** Accepts a Lucide component reference (`Truck`) or a pre-rendered JSX element (`<Truck className="..." />`). */
  icon?: LucideIcon | React.ReactNode;
  title: string;
  description?: string;
  /** Accepts `{ label, onClick }` or a pre-rendered ReactNode (e.g. `<Button>…</Button>`). */
  action?: { label: string; onClick: () => void } | React.ReactNode;
  className?: string;
}

export function EmptyState({ icon, title, description, action, className }: EmptyStateProps) {
  const iconNode = icon
    ? React.isValidElement(icon)
      ? icon
      : React.createElement(icon as LucideIcon, { className: "h-8 w-8 text-text-secondary" })
    : null;

  const actionNode = action
    ? React.isValidElement(action)
      ? action
      : (
        <Button
          className="mt-4"
          onClick={(action as { label: string; onClick: () => void }).onClick}
        >
          {(action as { label: string; onClick: () => void }).label}
        </Button>
      )
    : null;

  return (
    <div className={cn("flex flex-col items-center justify-center py-16 text-center", className)}>
      {iconNode && (
        <div className="mb-4 rounded-full bg-background-subtle p-4">
          {iconNode}
        </div>
      )}
      <h3 className="text-base font-semibold text-text-primary">{title}</h3>
      {description && (
        <p className="mt-1 text-sm text-text-secondary max-w-sm">{description}</p>
      )}
      {actionNode && <div className="mt-4">{actionNode}</div>}
    </div>
  );
}
