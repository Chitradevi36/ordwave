import axios, { AxiosError } from "axios";

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

// ── Response: redirect to /login on 401; emit plan limit event on 402 ───────
apiClient.interceptors.response.use(
  (res) => res,
  (error: AxiosError<{ errors?: string[]; limit_type?: string; current?: number; max?: number; upgrade_to?: string | null }>) => {
    if (typeof window === "undefined") return Promise.reject(error);

    if (error.response?.status === 401) {
      localStorage.removeItem("auth_token");
      localStorage.removeItem("user");
      localStorage.removeItem("organization_id");
      window.location.href = "/login";
    }

    if (error.response?.status === 402) {
      const d = error.response.data;
      window.dispatchEvent(
        new CustomEvent("plan:limit_exceeded", {
          detail: {
            message:    d.errors?.[0] ?? "Plan limit reached.",
            limit_type: d.limit_type ?? "unknown",
            current:    d.current,
            max:        d.max,
            upgrade_to: d.upgrade_to ?? null,
          },
        })
      );
    }

    return Promise.reject(error);
  }
);
