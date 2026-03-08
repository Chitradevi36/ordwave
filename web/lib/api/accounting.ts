import { apiClient } from "./client";

// ── Types ─────────────────────────────────────────────────────────────────────

export interface AccountingIntegration {
  id: number;
  provider: string;
  status: string;
  sync_mode: string;
  last_synced_at: string | null;
  last_error_message: string | null;
  connected_at: string | null;
  config_json: Record<string, string | null>;
  created_at: string;
  updated_at: string;
}

export interface AccountingMapping {
  id: number;
  mapping_key: string;
  mapping_value: string;
  notes: string | null;
  display_key: string;
  created_at: string;
}

export interface AccountingSyncRecord {
  id: number;
  provider: string;
  entity_type: string;
  entity_id: number;
  entity_version: string;
  event_type: string;
  direction: string;
  status: string;
  priority: string;
  attempt_count: number;
  max_retries: number;
  idempotency_key: string;
  external_reference: string | null;
  error_message: string | null;
  payload_json: Record<string, unknown> | null;
  response_body: Record<string, unknown> | null;
  last_attempted_at: string | null;
  succeeded_at: string | null;
  created_at: string;
  updated_at: string;
  accounting_integration: { id: number; provider: string } | null;
}

export interface SyncDashboardStats {
  pending: number;
  processing: number;
  success_today: number;
  failed: number;
  last_sync_at: string | null;
}

export interface AccountingExportFile {
  id: number;
  provider: string;
  export_type: string;
  status: string;
  date_from: string | null;
  date_to: string | null;
  file_path: string | null;
  error_message: string | null;
  downloadable: boolean;
  created_at: string;
  updated_at: string;
  accounting_integration: { id: number; provider: string } | null;
  generated_by: { id: number; email: string; first_name: string; last_name: string } | null;
  branch: { id: number; name: string } | null;
}

export interface PaginationMeta {
  current_page: number;
  total_pages: number;
  total_count: number;
  per_page: number;
}

// ── Integrations ──────────────────────────────────────────────────────────────

export async function fetchIntegrations(token: string, orgId: string): Promise<AccountingIntegration[]> {
  const res = await apiClient.get("/api/v1/accounting/integrations", {
    headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
  });
  return res.data.data ?? [];
}

export async function fetchIntegration(id: number, token: string, orgId: string): Promise<AccountingIntegration> {
  const res = await apiClient.get(`/api/v1/accounting/integrations/${id}`, {
    headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
  });
  return res.data.data;
}

export async function createIntegration(
  payload: { provider: string; sync_mode?: string },
  token: string,
  orgId: string
): Promise<AccountingIntegration> {
  const res = await apiClient.post("/api/v1/accounting/integrations",
    { accounting_integration: payload },
    { headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId } }
  );
  return res.data.data;
}

export async function updateIntegration(
  id: number,
  payload: { sync_mode?: string; config_json?: Record<string, string | null> },
  token: string,
  orgId: string
): Promise<AccountingIntegration> {
  const res = await apiClient.patch(`/api/v1/accounting/integrations/${id}`, payload, {
    headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
  });
  return res.data.data;
}

export async function testIntegrationConfig(id: number, token: string, orgId: string): Promise<{ valid: boolean; message: string }> {
  const res = await apiClient.post(`/api/v1/accounting/integrations/${id}/test_configuration`, {}, {
    headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
  });
  return res.data.data;
}

export async function markIntegrationConnected(id: number, token: string, orgId: string): Promise<void> {
  await apiClient.post(`/api/v1/accounting/integrations/${id}/mark_connected`, {}, {
    headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
  });
}

export async function markIntegrationDisconnected(id: number, token: string, orgId: string): Promise<void> {
  await apiClient.post(`/api/v1/accounting/integrations/${id}/mark_disconnected`, {}, {
    headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
  });
}

// ── Mappings ──────────────────────────────────────────────────────────────────

export async function fetchMappings(integrationId: number, token: string, orgId: string): Promise<AccountingMapping[]> {
  const res = await apiClient.get(`/api/v1/accounting/integrations/${integrationId}/mappings`, {
    headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
  });
  return res.data.data ?? [];
}

export async function upsertMapping(
  integrationId: number,
  payload: { mapping_key: string; mapping_value: string; notes?: string },
  token: string,
  orgId: string
): Promise<AccountingMapping> {
  const res = await apiClient.post(`/api/v1/accounting/integrations/${integrationId}/mappings`, payload, {
    headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
  });
  return res.data.data;
}

export async function deleteMapping(
  integrationId: number,
  mappingId: number,
  token: string,
  orgId: string
): Promise<void> {
  await apiClient.delete(`/api/v1/accounting/integrations/${integrationId}/mappings/${mappingId}`, {
    headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
  });
}

// ── Sync Records ──────────────────────────────────────────────────────────────

export interface SyncRecordFilters {
  status?: string;
  priority?: string;
  provider?: string;
  entity_type?: string;
  event_type?: string;
  integration_id?: string;
  date_from?: string;
  date_to?: string;
  q?: string;
  page?: number;
  per_page?: number;
}

export async function fetchSyncRecords(
  filters: SyncRecordFilters,
  token: string,
  orgId: string
): Promise<{ data: AccountingSyncRecord[]; meta: PaginationMeta; stats: SyncDashboardStats }> {
  const params = new URLSearchParams();
  Object.entries(filters).forEach(([k, v]) => { if (v !== undefined && v !== "") params.set(k, String(v)); });
  const res = await apiClient.get(`/api/v1/accounting/sync_records?${params}`, {
    headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
  });
  return { data: res.data.data ?? [], meta: res.data.meta, stats: res.data.stats };
}

export async function fetchSyncRecord(id: number, token: string, orgId: string): Promise<AccountingSyncRecord> {
  const res = await apiClient.get(`/api/v1/accounting/sync_records/${id}`, {
    headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
  });
  return res.data.data;
}

export async function retrySyncRecord(id: number, token: string, orgId: string): Promise<{ result: string; message: string }> {
  const res = await apiClient.post(`/api/v1/accounting/sync_records/${id}/retry`, {}, {
    headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
  });
  return res.data.data;
}

// ── Export Files ──────────────────────────────────────────────────────────────

export async function fetchExportFiles(
  filters: { page?: number; provider?: string },
  token: string,
  orgId: string
): Promise<{ data: AccountingExportFile[]; meta: PaginationMeta }> {
  const params = new URLSearchParams();
  Object.entries(filters).forEach(([k, v]) => { if (v !== undefined && v !== "") params.set(k, String(v)); });
  const res = await apiClient.get(`/api/v1/accounting/export_files?${params}`, {
    headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
  });
  return { data: res.data.data ?? [], meta: res.data.meta };
}

export async function fetchExportFile(id: number, token: string, orgId: string): Promise<AccountingExportFile> {
  const res = await apiClient.get(`/api/v1/accounting/export_files/${id}`, {
    headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
  });
  return res.data.data;
}

export async function createExportFile(
  payload: {
    accounting_integration_id: number;
    export_type: string;
    date_from?: string;
    date_to?: string;
    branch_id?: number;
  },
  token: string,
  orgId: string
): Promise<AccountingExportFile> {
  const res = await apiClient.post("/api/v1/accounting/export_files", payload, {
    headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
  });
  return res.data.data;
}

export async function downloadExportFileUrl(id: number, token: string, orgId: string): Promise<string> {
  const res = await apiClient.get(`/api/v1/accounting/export_files/${id}/download_url`, {
    headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
  });
  return res.data.data?.url ?? "";
}
