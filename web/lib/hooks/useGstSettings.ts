import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useOrgBranch } from "@/lib/org-branch-context";

export const useGstSettings = () => {
  const { orgId, token } = useOrgBranch();
  const queryClient = useQueryClient();

  // FETCH: TIER 1 + TIER 2 (organization settings)
  const { data: orgSettings, isLoading: isLoadingOrgSettings, error: orgSettingsError } = useQuery({
    queryKey: ["org-settings", orgId],
    queryFn: async () => {
      const res = await fetch(`/api/v1/organizations/${orgId}/settings`, {
        headers: {
          "Authorization": `Bearer ${token}`,
          "X-Organization-Id": orgId || "",
        },
      });
      if (!res.ok) throw new Error("Failed to fetch org settings");
      return res.json();
    },
    enabled: !!orgId && !!token,
  });

  // FETCH: Dedicated credentials endpoint (TIER 1)
  const { data: credentialsData, isLoading: isLoadingCredentials } = useQuery({
    queryKey: ["gst-credentials", orgId],
    queryFn: async () => {
      const res = await fetch("/api/v1/gst/credentials", {
        headers: {
          "Authorization": `Bearer ${token}`,
          "X-Organization-Id": orgId || "",
        },
      });
      if (!res.ok) throw new Error("Failed to fetch GST credentials");
      return res.json();
    },
    enabled: !!orgId && !!token,
  });

  // FETCH: TIER 2 (state registrations - includes username/password)
  const { data: stateRegistrationsData, isLoading: isLoadingStateRegistrations } = useQuery({
    queryKey: ["gst-state-registrations", orgId],
    queryFn: async () => {
      const res = await fetch("/api/v1/gst/registrations", {
        headers: {
          "Authorization": `Bearer ${token}`,
          "X-Organization-Id": orgId || "",
        },
      });
      if (!res.ok) throw new Error("Failed to fetch state registrations");
      return res.json();
    },
    enabled: !!orgId && !!token,
  });

  // FETCH: TIER 3 (branch overrides)
  const { data: branchOverridesData, isLoading: isLoadingOverrides, error: overridesError } = useQuery({
    queryKey: ["gst-branch-overrides", orgId],
    queryFn: async () => {
      const res = await fetch("/api/v1/gst/branch_overrides", {
        headers: {
          "Authorization": `Bearer ${token}`,
          "X-Organization-Id": orgId || "",
        },
      });
      if (!res.ok) throw new Error("Failed to fetch branch overrides");
      return res.json();
    },
    enabled: !!orgId && !!token,
  });

  // Extract TIER 1 credentials - from dedicated endpoint
  const gstCredentials = credentialsData?.data || {
    irp_username: "",
    irp_environment: "sandbox",
    configured: false,
  };
  
  // Extract TIER 2 state registrations - from dedicated endpoint
  const stateRegistrations = stateRegistrationsData?.data || {};

  // Extract TIER 3 branch overrides
  const branchOverrides = branchOverridesData?.data || [];

  // MUTATION: Save TIER 1 (IRP Credentials)
  const saveGstCredentials = useMutation({
    mutationFn: async (credentials: { irp_username: string; irp_password: string; irp_environment: string }) => {
      const res = await fetch(`/api/v1/organizations/${orgId}/settings`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${token}`,
          "X-Organization-Id": orgId || "",
        },
        body: JSON.stringify({
          settings: {
            gst_credentials: credentials,
          },
        }),
      });
      if (!res.ok) throw new Error("Failed to save GST credentials");
      return res.json();
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["gst-credentials", orgId] });
      queryClient.invalidateQueries({ queryKey: ["org-settings", orgId] });
    },
  });

  // MUTATION: Save TIER 2 (State-Level GSTIN)
  const saveStateGstin = useMutation({
    mutationFn: async ({ stateCode, gstin, username, password }: { stateCode: string; gstin: string; username: string; password: string }) => {
      const res = await fetch("/api/v1/gst/registrations", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${token}`,
          "X-Organization-Id": orgId || "",
        },
        body: JSON.stringify({
          state_code: stateCode,
          gstin: gstin,
          username: username,
          password: password,
        }),
      });
      if (!res.ok) {
        const error = await res.json();
        throw new Error(error.errors?.[0] || "Failed to save state GSTIN");
      }
      return res.json();
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["org-settings", orgId] });
      queryClient.invalidateQueries({ queryKey: ["gst-state-registrations", orgId] });
    },
  });

  // MUTATION: Remove TIER 2 State GSTIN
  const removeStateGstin = useMutation({
    mutationFn: async (stateCode: string) => {
      const res = await fetch(`/api/v1/gst/registrations/${stateCode}`, {
        method: "DELETE",
        headers: {
          "Authorization": `Bearer ${token}`,
          "X-Organization-Id": orgId || "",
        },
      });
      if (!res.ok) throw new Error("Failed to remove state GSTIN");
      return res.json();
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["org-settings", orgId] });
      queryClient.invalidateQueries({ queryKey: ["gst-state-registrations", orgId] });
    },
  });

  // MUTATION: Set TIER 3 Branch Override
  const setBranchOverride = useMutation({
    mutationFn: async ({ branchId, gstin }: { branchId: string | number; gstin: string }) => {
      const res = await fetch("/api/v1/gst/branch_overrides", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${token}`,
          "X-Organization-Id": orgId || "",
        },
        body: JSON.stringify({
          branch_id: branchId,
          branch_gstin: gstin,
        }),
      });
      if (!res.ok) {
        const error = await res.json();
        throw new Error(error.errors?.[0] || "Failed to set branch override");
      }
      return res.json();
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["gst-branch-overrides", orgId] });
    },
  });

  // MUTATION: Remove TIER 3 Branch Override
  const removeBranchOverride = useMutation({
    mutationFn: async (branchId: string | number) => {
      const res = await fetch(`/api/v1/gst/branch_overrides/${branchId}`, {
        method: "DELETE",
        headers: {
          "Authorization": `Bearer ${token}`,
          "X-Organization-Id": orgId || "",
        },
      });
      if (!res.ok) throw new Error("Failed to remove branch override");
      return res.json();
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["gst-branch-overrides", orgId] });
    },
  });

  // MUTATION: Test Connection (TIER 1)
  const testConnection = useMutation({
    mutationFn: async (credentials: { irp_username?: string; irp_password?: string; irp_environment?: string }) => {
      const res = await fetch("/api/v1/gst/credentials/test_connection", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${token}`,
          "X-Organization-Id": orgId || "",
        },
        body: JSON.stringify(credentials),
      });
      if (!res.ok) {
        const error = await res.json();
        throw new Error(error.errors?.[0] || "Connection test failed");
      }
      return res.json();
    },
  });

  return {
    gstCredentials,
    stateRegistrations,
    branchOverrides,
    isLoading: isLoadingOrgSettings || isLoadingOverrides || isLoadingCredentials || isLoadingStateRegistrations,
    error: orgSettingsError || overridesError,
    saveGstCredentials,
    saveStateGstin,
    removeStateGstin,
    setBranchOverride,
    removeBranchOverride,
    testConnection,
  };
};
