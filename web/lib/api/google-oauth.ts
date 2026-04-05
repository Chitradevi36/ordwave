import { apiClient } from "./client";

/**
 * Google OAuth API client
 * Handles communication with backend Google OAuth endpoints
 */

export const googleOauthApi = {
  /**
   * Submit Google ID token to backend for verification and authentication
   * @param idToken - Google ID token from frontend
   * @returns User data and JWT token
   */
  loginWithGoogle: async (idToken: string) => {
    try {
      const response = await apiClient.post("/api/v1/auth/google_login", {
        id_token: idToken,
      });

      if (response.data?.data?.token) {
        // Store token in localStorage
        localStorage.setItem("auth_token", response.data.data.token);

        if (response.data.data.user?.organization_id) {
          localStorage.setItem(
            "organization_id",
            response.data.data.user.organization_id
          );
        }
      }

      return {
        success: true,
        token: response.data.data.token,
        user: response.data.data.user,
      };
    } catch (error: any) {
      const errorData = error.response?.data;
      const hint = errorData?.hint;
      const message =
        errorData?.errors?.[0] || "Google sign-in failed. Please try again.";

      return {
        success: false,
        error: message,
        hint, // Can be used to show specific UI (e.g., "oauth_user_not_found" -> show "contact admin" message)
      };
    }
  },
};
