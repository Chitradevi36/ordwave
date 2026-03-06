"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
} from "react";
import { useRouter } from "next/navigation";
import { API_URL } from "@/lib/api/client";

// ─── Types ───────────────────────────────────────────────────────────────────

export interface Org {
  id: number;
  name: string;
  slug?: string;
}

export interface Branch {
  id: number;
  name: string;
  code: string;
  city?: string;
}

interface OrgBranchContextValue {
  token: string;
  orgId: string;
  branchId: string; // "" = All Branches
  organizations: Org[];
  branches: Branch[];
  orgsLoading: boolean;
  branchesLoading: boolean;
  switchOrg: (id: string) => void;
  switchBranch: (id: string) => void;
  refetchOrganizations: () => void;
  refetchBranches: () => void;
}

// ─── Context ─────────────────────────────────────────────────────────────────

const OrgBranchContext = createContext<OrgBranchContextValue>({
  token: "",
  orgId: "",
  branchId: "",
  organizations: [],
  branches: [],
  orgsLoading: false,
  branchesLoading: false,
  switchOrg: () => {},
  switchBranch: () => {},
  refetchOrganizations: () => {},
  refetchBranches: () => {},
});

export function useOrgBranch() {
  return useContext(OrgBranchContext);
}

// ─── Provider ────────────────────────────────────────────────────────────────

export function OrgBranchProvider({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const [token, setToken]       = useState("");
  const [orgId, setOrgIdState]  = useState("");
  const [branchId, setBranchId] = useState("");
  const [organizations, setOrganizations] = useState<Org[]>([]);
  const [branches, setBranches]           = useState<Branch[]>([]);
  const [orgsLoading, setOrgsLoading]       = useState(false);
  const [branchesLoading, setBranchesLoading] = useState(false);

  // Track previous orgId to avoid re-fetching branches unnecessarily
  const prevOrgIdRef = useRef<string>("");

  // ── Clears auth state and redirects to login (called on 401 responses) ──
  const clearAuth = useCallback(() => {
    localStorage.removeItem("auth_token");
    localStorage.removeItem("organization_id");
    setToken("");
    setOrgIdState("");
    router.replace("/login");
  }, [router]);

  // ── Bootstrap from localStorage ──────────────────────────────────────────
  useEffect(() => {
    const t   = localStorage.getItem("auth_token")    ?? "";
    const org = localStorage.getItem("organization_id") ?? "";
    // Guard against stale "undefined" / "null" strings written by older code
    const validToken = t && t !== "null" && t !== "undefined" ? t : "";
    setToken(validToken);
    setOrgIdState(/^\d+$/.test(org) ? org : "");
  }, []);

  // ── Fetch organizations ──────────────────────────────────────────────────
  const fetchOrganizations = useCallback(async (tok: string) => {
    if (!tok) return;
    setOrgsLoading(true);
    try {
      const res  = await fetch(`${API_URL}/api/v1/organizations`, {
        headers: { Authorization: `Bearer ${tok}` },
      });
      if (res.status === 401) { clearAuth(); return; }
      const json = await res.json();
      if (res.ok) {
        const orgs: Org[] = Array.isArray(json.data) ? json.data : [];
        setOrganizations(orgs);
        // If stored orgId is not in the list, default to first
        setOrgIdState((prev) => {
          if (!prev || !orgs.find((o) => String(o.id) === prev)) {
            const first = String(orgs[0]?.id ?? "");
            if (first) localStorage.setItem("organization_id", first);
            return first;
          }
          return prev;
        });
      }
    } catch {
      // silently ignore
    } finally {
      setOrgsLoading(false);
    }
  }, [clearAuth]);

  useEffect(() => {
    if (token) fetchOrganizations(token);
  }, [token, fetchOrganizations]);

  // ── Fetch branches when orgId changes ────────────────────────────────────
  const fetchBranches = useCallback(async (tok: string, org: string) => {
    if (!tok || !org) return;
    setBranchesLoading(true);
    try {
      const res  = await fetch(`${API_URL}/api/v1/branches?per_page=100`, {
        headers: {
          Authorization:       `Bearer ${tok}`,
          "X-Organization-Id": org,
        },
      });
      const json = await res.json();
      if (res.ok) {
        setBranches(json.data ?? []);
      }
    } catch {
      // silently ignore
    } finally {
      setBranchesLoading(false);
    }
  }, []);

  useEffect(() => {
    if (orgId && orgId !== prevOrgIdRef.current) {
      prevOrgIdRef.current = orgId;
      setBranchId(""); // reset branch on org change
      fetchBranches(token, orgId);
    }
  }, [orgId, token, fetchBranches]);

  // ── Switch helpers ────────────────────────────────────────────────────────
  const switchOrg = useCallback((id: string) => {
    localStorage.setItem("organization_id", id);
    setOrgIdState(id);
  }, []);

  const switchBranch = useCallback((id: string) => {
    setBranchId(id);
  }, []);

  const refetchOrganizations = useCallback(() => {
    if (token) fetchOrganizations(token);
  }, [token, fetchOrganizations]);

  const refetchBranches = useCallback(() => {
    if (token && orgId) fetchBranches(token, orgId);
  }, [token, orgId, fetchBranches]);

  return (
    <OrgBranchContext.Provider
      value={{
        token,
        orgId,
        branchId,
        organizations,
        branches,
        orgsLoading,
        branchesLoading,
        switchOrg,
        switchBranch,
        refetchOrganizations,
        refetchBranches,
      }}
    >
      {children}
    </OrgBranchContext.Provider>
  );
}
