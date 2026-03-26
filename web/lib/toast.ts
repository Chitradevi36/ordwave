// Centralized toast utility wrapping Sonner.
//
// Instead of importing `toast` from 'sonner' everywhere, import from here to
// ensure consistent styling, defaults and future extensibility (e.g. Sentry
// breadcrumb logging on errors).

import { toast as sonnerToast, type ExternalToast } from "sonner";

export type ToastType = "success" | "error" | "info" | "warning";

const DEFAULTS: ExternalToast = {
  duration: 4_000,
  position: "top-right",
};

function success(message: string, opts?: ExternalToast) {
  return sonnerToast.success(message, { ...DEFAULTS, ...opts });
}

function error(message: string, opts?: ExternalToast) {
  return sonnerToast.error(message, { ...DEFAULTS, duration: 6_000, ...opts });
}

function info(message: string, opts?: ExternalToast) {
  return sonnerToast.info(message, { ...DEFAULTS, ...opts });
}

function warning(message: string, opts?: ExternalToast) {
  return sonnerToast.warning(message, { ...DEFAULTS, ...opts });
}

/** Display an API error — extracts `errors[]` from typical Rails JSON body. */
function apiError(err: unknown, fallback = "Something went wrong") {
  let msg = fallback;

  if (err && typeof err === "object") {
    // Axios-style error
    const axiosErr = err as { response?: { data?: { errors?: string[] } } };
    const errors = axiosErr.response?.data?.errors;
    if (errors && errors.length > 0) {
      msg = errors.join(". ");
    } else if ("message" in err && typeof (err as Error).message === "string") {
      msg = (err as Error).message;
    }
  }

  return error(msg);
}

/** Promise-based toast: shows loading → success/error automatically. */
function promise<T>(
  promiseFn: Promise<T> | (() => Promise<T>),
  msgs: { loading: string; success: string; error?: string }
) {
  return sonnerToast.promise(promiseFn, {
    ...DEFAULTS,
    loading: msgs.loading,
    success: msgs.success,
    error: msgs.error ?? "Something went wrong",
  });
}

export const toast = {
  success,
  error,
  info,
  warning,
  apiError,
  promise,
  dismiss: sonnerToast.dismiss,
} as const;
