import { useState, useCallback } from "react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";

export interface OTPResponse {
  otp_sent: boolean;
  message: string;
  expires_in_seconds: number;
  attempts_remaining: number;
}

export interface OTPVerifyResponse {
  verified: boolean;
  message: string;
  proof_id: number;
}

export interface OTPErrorResponse {
  error: string;
}

/**
 * Hook for managing OTP delivery verification flow
 * Handles: sending OTP to driver, verifying OTP code
 */
export function useDeliveryOTP(stopId: number | null) {
  const { token, orgId } = useOrgBranch();
  const [otpSending, setOtpSending] = useState(false);
  const [otpVerifying, setOtpVerifying] = useState(false);
  const [otpError, setOtpError] = useState<string | null>(null);
  const [otpSentAt, setOtpSentAt] = useState<Date | null>(null);
  const [attemptsRemaining, setAttemptsRemaining] = useState(5);

  /**
   * Send OTP to driver's phone
   * @returns true if OTP sent successfully
   */
  const sendOTP = useCallback(async () => {
    if (!stopId || !token || !orgId) {
      setOtpError("Missing required information");
      return false;
    }

    setOtpSending(true);
    setOtpError(null);

    try {
      const res = await fetch(
        `${API_URL}/api/v1/delivery_trips/trip_stops/${stopId}/send_otp`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${token}`,
            "X-Organization-Id": orgId,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            reason: "delivery_verification",
          }),
        }
      );

      const json = (await res.json()) as OTPResponse | OTPErrorResponse;

      if (res.ok && "otp_sent" in json) {
        setOtpSentAt(new Date());
        setAttemptsRemaining(json.attempts_remaining);
        return true;
      } else if ("error" in json) {
        setOtpError(json.error);
        return false;
      } else {
        setOtpError("Failed to send OTP");
        return false;
      }
    } catch (e) {
      const errorMsg = e instanceof Error ? e.message : "Network error";
      setOtpError(errorMsg);
      return false;
    } finally {
      setOtpSending(false);
    }
  }, [stopId, token, orgId]);

  /**
   * Verify OTP code submitted by driver
   * @param code 6-digit OTP code
   * @returns true if OTP verified successfully
   */
  const verifyOTP = useCallback(
    async (code: string) => {
      if (!stopId || !token || !orgId) {
        setOtpError("Missing required information");
        return false;
      }

      if (!code || code.length !== 6) {
        setOtpError("OTP must be 6 digits");
        return false;
      }

      setOtpVerifying(true);
      setOtpError(null);

      try {
        const res = await fetch(
          `${API_URL}/api/v1/delivery_trips/trip_stops/${stopId}/verify_otp`,
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${token}`,
              "X-Organization-Id": orgId,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({ otp: code }),
          }
        );

        const json = (await res.json()) as
          | OTPVerifyResponse
          | OTPErrorResponse;

        if (res.ok && "verified" in json) {
          return true;
        } else if ("error" in json) {
          // Extract attempts remaining from error message if available
          const match = json.error.match(/(\d+)\s+attempts? remaining/);
          if (match) {
            setAttemptsRemaining(parseInt(match[1], 10));
          }
          setOtpError(json.error);
          return false;
        } else {
          setOtpError("Failed to verify OTP");
          return false;
        }
      } catch (e) {
        const errorMsg = e instanceof Error ? e.message : "Network error";
        setOtpError(errorMsg);
        return false;
      } finally {
        setOtpVerifying(false);
      }
    },
    [stopId, token, orgId]
  );

  /**
   * Reset OTP state (e.g., when closing modal)
   */
  const resetOTP = useCallback(() => {
    setOtpError(null);
    setOtpSentAt(null);
    setAttemptsRemaining(5);
  }, []);

  /**
   * Check if OTP has expired (10 minutes)
   */
  const isOTPExpired = useCallback(() => {
    if (!otpSentAt) return false;
    const now = new Date();
    const diff = (now.getTime() - otpSentAt.getTime()) / 1000 / 60; // minutes
    return diff > 10;
  }, [otpSentAt]);

  /**
   * Get remaining OTP validity time in seconds
   */
  const getOTPTimeRemaining = useCallback(() => {
    if (!otpSentAt) return 0;
    const now = new Date();
    const diff = (otpSentAt.getTime() + 10 * 60 * 1000 - now.getTime()) / 1000;
    return Math.max(0, Math.ceil(diff));
  }, [otpSentAt]);

  return {
    // States
    otpSending,
    otpVerifying,
    otpError,
    otpSentAt,
    attemptsRemaining,

    // Methods
    sendOTP,
    verifyOTP,
    resetOTP,
    isOTPExpired,
    getOTPTimeRemaining,
  };
}
