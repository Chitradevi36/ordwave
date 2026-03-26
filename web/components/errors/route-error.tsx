"use client";

import { useEffect } from "react";
import { Button } from "@/components/ui/button";
import { AlertTriangle, RefreshCcw } from "lucide-react";

/**
 * Shared per-route error boundary. Drop this into any route folder as
 * `error.tsx` to provide a friendly fallback instead of a full-page crash.
 *
 * Next.js automatically wraps the route in a React Error Boundary using
 * this component.
 */
export default function RouteError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error("[RouteError]", error);
  }, [error]);

  return (
    <div className="flex flex-col items-center justify-center gap-4 py-20 px-4 text-center">
      <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-error-50">
        <AlertTriangle className="h-7 w-7 text-error" />
      </div>
      <h2 className="text-lg font-semibold text-text-primary">Something went wrong</h2>
      <p className="text-sm text-text-secondary max-w-sm">
        {error?.message || "An unexpected error occurred while loading this page."}
      </p>
      {error?.digest && (
        <p className="text-xs text-text-tertiary font-mono">Error ID: {error.digest}</p>
      )}
      <Button variant="outline" size="sm" onClick={reset}>
        <RefreshCcw className="h-4 w-4 mr-1.5" />
        Try again
      </Button>
    </div>
  );
}
