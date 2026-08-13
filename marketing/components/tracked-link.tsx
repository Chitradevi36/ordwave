"use client";

import Link, { type LinkProps } from "next/link";
import type { MouseEvent } from "react";
import { trackCtaClick, trackEvent } from "@/lib/analytics";

type TrackedLinkProps = LinkProps & {
  className?: string;
  label: string;
  section?: string;
  eventName?: string;
  eventParams?: Record<string, unknown>;
  children: React.ReactNode;
  target?: string;
  rel?: string;
  onClick?: (event: MouseEvent<HTMLAnchorElement>) => void;
};

export function TrackedLink({ label, section, href, eventName, eventParams, onClick, children, ...rest }: TrackedLinkProps) {
  const handleClick = (event: MouseEvent<HTMLAnchorElement>) => {
    trackCtaClick({ label, section, href: typeof href === "string" ? href : href.toString() });
    if (eventName) {
      trackEvent(eventName, {
        label,
        section: section ?? "",
        href: typeof href === "string" ? href : href.toString(),
        ...(eventParams ?? {}),
      });
    }
    onClick?.(event);
  };

  return (
    <Link href={href} onClick={handleClick} {...rest}>
      {children}
    </Link>
  );
}
