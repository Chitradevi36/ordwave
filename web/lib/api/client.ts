import axios, { AxiosError, InternalAxiosRequestConfig } from "axios";

export const API_URL =
  process.env.NEXT_PUBLIC_API_URL?.replace(/\/$/, "") ?? "http://localhost:3001";

export const apiClient = axios.create({
  baseURL: API_URL,
  headers: { "Content-Type": "application/json" },
  timeout: 15_000,
});

// ── Request: attach JWT + org header ────────────────────────────────────────
apiClient.interceptors.request.use((config) => {
  if (typeof window === "undefined") return config;
  const token = localStorage.getItem("auth_token");
  const orgId = localStorage.getItem("organization_id");
  if (token) config.headers.Authorization = `Bearer ${token}`;
  if (orgId) config.headers["X-Organization-Id"] = orgId;
  return config;
});

// ── Token refresh logic ─────────────────────────────────────────────────────
let isRefreshing = false;
let failedQueue: Array<{
  resolve: (token: string) => void;
  reject: (err: unknown) => void;
}> = [];

function processQueue(error: unknown, token: string | null = null) {
  failedQueue.forEach((p) => {
    if (error) p.reject(error);
    else p.resolve(token!);
  });
  failedQueue = [];
}

async function attemptTokenRefresh(): Promise<string | null> {
  const currentToken = localStorage.getItem("auth_token");
  if (!currentToken) return null;

  try {
    const { data } = await axios.post(
      `${API_URL}/api/v1/auth/refresh`,
      {},
      { headers: { Authorization: `Bearer ${currentToken}` } }
    );
    const newToken = data?.data?.token;
    if (newToken) {
      localStorage.setItem("auth_token", newToken);
      if (data?.data?.user) {
        localStorage.setItem("user", JSON.stringify(data.data.user));
      }
      return newToken;
    }
    return null;
  } catch {
    return null;
  }
}

// ── Response: auto-refresh on 401, emit plan limit on 402 ──────────────────
apiClient.interceptors.response.use(
  (res) => res,
  async (error: AxiosError<{ errors?: string[]; limit_type?: string; current?: number; max?: number; upgrade_to?: string | null }>) => {
    if (typeof window === "undefined") return Promise.reject(error);

    const originalRequest = error.config as InternalAxiosRequestConfig & { _retry?: boolean };

    // ── 401: attempt silent refresh before redirecting ──────────────────
    if (error.response?.status === 401 && !originalRequest._retry) {
      // Don't try to refresh the refresh request itself
      if (originalRequest.url?.includes("/auth/refresh") || originalRequest.url?.includes("/auth/login")) {
        localStorage.removeItem("auth_token");
        localStorage.removeItem("user");
        localStorage.removeItem("organization_id");
        window.location.href = "/login";
        return Promise.reject(error);
      }

      if (isRefreshing) {
        // Queue this request until the refresh completes
        return new Promise((resolve, reject) => {
          failedQueue.push({
            resolve: (token: string) => {
              originalRequest.headers.Authorization = `Bearer ${token}`;
              resolve(apiClient(originalRequest));
            },
            reject,
          });
        });
      }

      originalRequest._retry = true;
      isRefreshing = true;

      try {
        const newToken = await attemptTokenRefresh();
        if (newToken) {
          processQueue(null, newToken);
          originalRequest.headers.Authorization = `Bearer ${newToken}`;
          return apiClient(originalRequest);
        }
        // Refresh failed — redirect to login
        processQueue(error, null);
        localStorage.removeItem("auth_token");
        localStorage.removeItem("user");
        localStorage.removeItem("organization_id");
        window.location.href = "/login";
      } catch (refreshError) {
        processQueue(refreshError, null);
        localStorage.removeItem("auth_token");
        localStorage.removeItem("user");
        localStorage.removeItem("organization_id");
        window.location.href = "/login";
      } finally {
        isRefreshing = false;
      }
    }

    // ── 402: plan limit exceeded ──────────────────────────────────────
    if (error.response?.status === 402) {
      const d = error.response.data;
      window.dispatchEvent(
        new CustomEvent("plan:limit_exceeded", {
          detail: {
            message:    d?.errors?.[0] ?? "Plan limit reached.",
            limit_type: d?.limit_type ?? "unknown",
            current:    d?.current,
            max:        d?.max,
            upgrade_to: d?.upgrade_to ?? null,
          },
        })
      );
    }

    return Promise.reject(error);
  }
);
