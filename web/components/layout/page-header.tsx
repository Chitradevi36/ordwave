import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { LucideIcon } from "lucide-react";
import React from "react";

export interface PageAction {
  label: string;
  onClick: () => void;
  variant?: "default" | "outline" | "ghost" | "danger";
  disabled?: boolean;
  /** Pass either a Lucide component reference (`Plus`) or a JSX element (`<Plus className="h-4 w-4" />`). */
  icon?: LucideIcon | React.ReactNode;
}

export interface PageHeaderProps {
  title: string;
  /** Body text or ReactNode shown beneath the title. */
  description?: React.ReactNode;
  /** Alias for description — accepted for convenience. */
  subtitle?: string;
  actions?: PageAction[];
  className?: string;
}

export function PageHeader({ title, description, subtitle, actions, className }: PageHeaderProps) {
  const subText = description ?? subtitle;
  return (
    <div className={cn("mb-6 flex flex-col gap-4 md:flex-row md:items-start md:justify-between", className)}>
      <div className="min-w-0">
        <h1 className="text-2xl font-bold text-text-primary">{title}</h1>
        {subText && (
          <p className="mt-1 text-sm text-text-secondary break-words">{subText}</p>
        )}
      </div>
      {actions && actions.length > 0 && (
        <div className="flex w-full flex-wrap items-center gap-2 md:w-auto md:justify-end">
          {actions.map((action) => {
            const icon = action.icon;
            // Support both a Lucide component ref and a pre-rendered ReactNode
            const iconNode = icon
              ? React.isValidElement(icon)
                ? icon
                : React.createElement(icon as LucideIcon, { className: "mr-2 h-4 w-4" })
              : null;
            return (
              <Button
                key={action.label}
                variant={action.variant ?? "default"}
                onClick={action.onClick}
                disabled={action.disabled}
                className="w-full sm:w-auto"
              >
                {iconNode}
                {action.label}
              </Button>
            );
          })}
        </div>
      )}
    </div>
  );
}
