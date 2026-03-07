import { useState, useEffect } from "react";
import type { UserRole } from "@/components/layout/nav.config";

/**
 * Derives the current user's role from localStorage.
 *
 * Priority order:
 *  1. `orderlane_profile_cache`  → orgs[].role  (set when profile is fetched)
 *  2. `user`                      → role field   (set at login)
 *  3. undefined                   (treat as owner — no restrictions)
 */
export function useCurrentRole(): UserRole | undefined {
  const [role, setRole] = useState<UserRole | undefined>(undefined);

  useEffect(() => {
    try {
      // 1. Try profile cache first (most up-to-date)
      const profileRaw = localStorage.getItem("orderlane_profile_cache");
      if (profileRaw) {
        const profile = JSON.parse(profileRaw);
        // Find role in the orgs array for the current org
        const orgId = localStorage.getItem("organization_id");
        const orgs: Array<{ id?: number; role?: string }> = profile?.organizations ?? profile?.orgs ?? [];
        const match = orgId
          ? orgs.find((o) => String(o.id) === orgId)
          : orgs[0];
        if (match?.role) {
          setRole(match.role as UserRole);
          return;
        }
      }

      // 2. Fall back to user object from login response
      const userRaw = localStorage.getItem("user");
      if (userRaw) {
        const user = JSON.parse(userRaw);
        if (user?.role) {
          setRole(user.role as UserRole);
          return;
        }
      }
    } catch {
      // Ignore parse errors — treat as no role (unrestricted)
    }

    setRole(undefined);
  }, []);

  return role;
}
