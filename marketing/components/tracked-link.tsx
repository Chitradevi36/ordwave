"use client";

import Link, { type LinkProps } from "next/link";
import type { MouseEvent } from "react";
import { trackCtaClick } from "@/lib/analytics";

type TrackedLinkProps = LinkProps & {
  className?: string;
  label: string;
  section?: string;
  children: React.ReactNode;
  target?: string;
  rel?: string;
  onClick?: (event: MouseEvent<HTMLAnchorElement>) => void;
};

export function TrackedLink({ label, section, href, onClick, children, ...rest }: TrackedLinkProps) {
  const handleClick = (event: MouseEvent<HTMLAnchorElement>) => {
    trackCtaClick({ label, section, href: typeof href === "string" ? href : href.toString() });
    onClick?.(event);
  };

  return (
    <Link href={href} onClick={handleClick} {...rest}>
      {children}
    </Link>
  );
}