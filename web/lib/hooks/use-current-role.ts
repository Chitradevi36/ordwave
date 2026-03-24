import { useState, useEffect } from "react";
import type { UserRole } from "@/components/layout/nav.config";
import { apiClient } from "@/lib/api/client";
import { useOrgBranch } from "@/lib/org-branch-context";

const PROFILE_CACHE_KEY = "orderlane_profile_cache";

interface OrgEntry { id?: number; role?: string }
interface ProfileCache { organizations?: OrgEntry[]; orgs?: OrgEntry[] }

function readCachedRole(orgId: string | null): UserRole | undefined {
  try {
    const raw = localStorage.getItem(PROFILE_CACHE_KEY);
    if (!raw) return undefined;
    const p: ProfileCache = JSON.parse(raw);
    const orgs = p.organizations ?? p.orgs ?? [];
    const match = orgId ? orgs.find((o) => String(o.id) === orgId) : orgs[0];
    return match?.role as UserRole | undefined;
  } catch {
    return undefined;
  }
}

/**
 * Returns the current user's role for the active organisation.
 *
 * Priority:
 *  1. `orderlane_profile_cache` in localStorage (fast, sync)
 *  2. GET /api/v1/profiles   (fetched once per orgId, result cached)
 *  3. undefined — treat as owner (no restrictions)
 */
export function useCurrentRole(): UserRole | undefined {
  const { role } = useCurrentRoleWithLoading();
  return role;
}

/**
 * Same as useCurrentRole but also exposes a `loading` flag that is true
 * while an in-flight profile fetch is pending.  Use this in views that need
 * to avoid flashing the wrong role-specific content.
 *
 * Uses orgId from OrgBranchContext (reactive) so it re-resolves whenever
 * the active organisation changes (e.g. immediately after login).
 */
export function useCurrentRoleWithLoading(): { role: UserRole | undefined; loading: boolean } {
  const { orgId, token } = useOrgBranch();
  const [role, setRole] = useState<UserRole | undefined>(undefined);
  const [loading, setLoading] = useState<boolean>(true);

  useEffect(() => {
    // Timeout fallback: if loading hasn't completed in 5 seconds, assume we're owner/no role
    const timeout = setTimeout(() => {
      if (loading) {
        console.warn("Role loading timed out, treating as no role restriction");
        setRole(undefined);
        setLoading(false);
      }
    }, 5000);

    // Wait until the context has resolved a token and org
    if (!token || !orgId) {
      // Still bootstrapping — keep loading state; role stays undefined
      setLoading(true);
      return () => clearTimeout(timeout);
    }

    setLoading(true);

    // Fast path: cache already has the role for this specific org
    const cached = readCachedRole(orgId);
    if (cached) {
      setRole(cached);
      setLoading(false);
      clearTimeout(timeout);
      return;
    }

    // Slow path: fetch from API and populate the cache
    apiClient
      .get<{ data: ProfileCache }>("/api/v1/profiles")
      .then(({ data }) => {
        const profile = data.data;
        try { localStorage.setItem(PROFILE_CACHE_KEY, JSON.stringify(profile)); } catch { /* noop */ }
        const orgs = profile.organizations ?? profile.orgs ?? [];
        const match = orgId ? orgs.find((o) => String(o.id) === orgId) : orgs[0];
        setRole(match?.role as UserRole | undefined);
      })
      .catch(() => { setRole(undefined); })
      .finally(() => {
        setLoading(false);
        clearTimeout(timeout);
      });

    return () => clearTimeout(timeout);
  }, [token, orgId]);

  return { role, loading };
}
