"use client";

import { usePathname } from "next/navigation";
import Link from "next/link";
import type { WorkspaceConfig } from "./workspace.config";
import { getTabsForRole } from "./workspace.config";
import type { UserRole } from "@/components/layout/nav.config";

//  WorkspaceHeader 
interface WorkspaceHeaderProps {
  config: WorkspaceConfig;
  role?: UserRole;
  actions?: React.ReactNode;
}

export function WorkspaceHeader({ config, role, actions }: WorkspaceHeaderProps) {
  const Icon = config.icon;
  return (
    <div className="bg-background border-b border-border shadow-sm">
      <div className="max-w-[1400px] mx-auto px-4 md:px-6">
        {/* Identity row */}
        <div className="flex items-center gap-4 py-5">
          <div className={`w-11 h-11 rounded-xl flex items-center justify-center shrink-0 ${config.iconBg}`}>
            <Icon size={22} className={config.iconColor} />
          </div>
          <div className="flex-1 min-w-0">
            <h1 className="text-xl font-bold text-text-primary leading-tight">{config.title}</h1>
            <p className="text-sm text-text-secondary mt-0.5 hidden sm:block">{config.description}</p>
          </div>
          {actions && (
            <div className="flex items-center gap-2 shrink-0">{actions}</div>
          )}
        </div>
        {/* Tabs row */}
        <WorkspaceTabs config={config} role={role} />
      </div>
    </div>
  );
}

//  WorkspaceTabs 
interface WorkspaceTabsProps {
  config: WorkspaceConfig;
  role?: UserRole;
}

export function WorkspaceTabs({ config, role }: WorkspaceTabsProps) {
  const pathname = usePathname();
  const tabs = getTabsForRole(config, role);

  if (tabs.length === 0) return null;

  return (
    <div
      className="flex gap-0 overflow-x-auto scrollbar-none -mb-px"
      role="tablist"
      aria-label={`${config.title} sections`}
    >
      {tabs.map((tab) => {
        const active = pathname === tab.href || pathname.startsWith(tab.href + "/");
        return (
          <Link
            key={tab.key}
            href={tab.href}
            role="tab"
            aria-selected={active}
            className={[
              "shrink-0 px-4 py-3 text-sm font-medium border-b-2 transition-colors whitespace-nowrap",
              active
                ? "border-accent text-accent"
                : "border-transparent text-text-secondary hover:text-text-primary hover:border-border",
            ].join(" ")}
          >
            {tab.label}
          </Link>
        );
      })}
    </div>
  );
}