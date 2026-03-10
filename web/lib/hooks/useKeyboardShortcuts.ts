"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

/**
 * Global keyboard shortcut handler.
 *
 * Shortcuts:
 *   Ctrl/Cmd + K  → dispatch "open-command-palette" event (consumed by CommandPalette overlay)
 *   Ctrl/Cmd + N  → navigate to /orders/new
 *   Escape        → dispatch "close-modal" event (consumed by Modal components)
 */
export function useKeyboardShortcuts() {
  const router = useRouter();

  useEffect(() => {
    function handleKeyDown(e: KeyboardEvent) {
      const meta = e.ctrlKey || e.metaKey;

      // Ctrl/Cmd + K — open command palette
      if (meta && e.key === "k") {
        e.preventDefault();
        window.dispatchEvent(new CustomEvent("open-command-palette"));
        return;
      }

      // Ctrl/Cmd + N — new order
      if (meta && e.key === "n") {
        e.preventDefault();
        router.push("/orders/new");
        return;
      }

      // Escape — close top-most modal / drawer
      if (e.key === "Escape") {
        window.dispatchEvent(new CustomEvent("close-modal"));
        return;
      }
    }

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [router]);
}
