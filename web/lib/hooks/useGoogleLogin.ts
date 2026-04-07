import { useState, useCallback } from "react";
import { useRouter } from "next/navigation";
import { googleOauthApi } from "@/lib/api/google-oauth";
import { ANALYTICS_EVENTS, trackAuthEvent } from "@/lib/analytics";
import { toast } from "sonner";

interface UseGoogleLoginReturn {
  handleGoogleSuccess: (credentialResponse: any) => Promise<void>;
  isLoading: boolean;
  error: string | null;
}

/**
 * Hook to handle Google OAuth login
 * Integrates with @react-oauth/google and handles token exchange with backend
 */
export function useGoogleLogin(): UseGoogleLoginReturn {
  const router = useRouter();
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleGoogleSuccess = useCallback(
    async (credentialResponse: any) => {
      setIsLoading(true);
      setError(null);

      try {
        const idToken = credentialResponse?.credential;

        if (!idToken) {
          throw new Error("No credential received from Google");
        }

        // Send token to backend for verification
        const result = await googleOauthApi.loginWithGoogle(idToken);

        if (result.success) {
          // Store user data in localStorage (same as email/password login)
          localStorage.setItem('user', JSON.stringify(result.user));
          
          // Store organization_id from user data to prevent onboarding redirect
          const orgId = result.user?.organization_id || result.user?.current_organization_id;
          if (orgId) {
            localStorage.setItem('organization_id', String(orgId));
          } else {
            localStorage.removeItem('organization_id');
          }
          
          localStorage.removeItem('orderlane_profile_cache'); // clear stale role cache from previous user
          
          // Set a lightweight cookie so middleware.ts can guard server-side routing
          document.cookie = 'auth_present=1; path=/; max-age=86400; SameSite=Lax';
          
          toast.success("Signed in successfully!");
          trackAuthEvent(ANALYTICS_EVENTS.LOGIN_COMPLETED);

          // Force full page reload to clear React Query cache and prevent stale user data
          window.location.href = '/dashboard';
        } else {
          const errorMessage = result.error || "Sign-in failed";

          // Handle specific error cases
          if (result.hint === "oauth_user_not_found") {
            setError(
              "Your account was not found. Please contact an administrator to be added to the system."
            );
          } else {
            setError(errorMessage);
          }

          toast.error(errorMessage);
          trackAuthEvent(ANALYTICS_EVENTS.LOGIN_FAILED, { error_reason: errorMessage });
        }
      } catch (err) {
        const message =
          err instanceof Error ? err.message : "An error occurred during sign-in";
        setError(message);
        toast.error(message);
        trackAuthEvent(ANALYTICS_EVENTS.LOGIN_FAILED, { error_reason: 'network_error' });
      } finally {
        setIsLoading(false);
      }
    },
    [router]
  );

  return {
    handleGoogleSuccess,
    isLoading,
    error,
  };
}
