'use client';

import { GoogleLogin } from '@react-oauth/google';
import { ANALYTICS_EVENTS, trackAuthEvent } from '@/lib/analytics';
import { Alert } from '@/components/ui/alert';
import { useGoogleLogin } from '@/lib/hooks/useGoogleLogin';

export default function GoogleAuthSection() {
  const { handleGoogleSuccess, isLoading: isGoogleLoading, error: googleError } = useGoogleLogin();

  return (
    <>
      {googleError && (
        <Alert variant="danger" className="bg-red-50 border-red-200 text-red-700">
          {googleError}
        </Alert>
      )}

      {/* Google Sign-In Button */}
      <div className="flex justify-center">
        <GoogleLogin
          onSuccess={handleGoogleSuccess}
          onError={() => {
            trackAuthEvent(ANALYTICS_EVENTS.LOGIN_FAILED, { error_reason: 'google_signin_error' });
          }}
          theme="outline"
          size="large"
        />
      </div>

      {/* Divider */}
      <div className="relative">
        <div className="absolute inset-0 flex items-center">
          <div className="w-full border-t border-gray-300"></div>
        </div>
        <div className="relative flex justify-center text-sm">
          <span className="px-2 bg-white text-text-secondary">Or continue with email</span>
        </div>
      </div>
    </>
  );
}
