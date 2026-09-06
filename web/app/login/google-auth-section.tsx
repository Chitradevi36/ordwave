'use client';

import { GoogleLogin } from '@react-oauth/google';
import { ANALYTICS_EVENTS, trackAuthEvent } from '@/lib/analytics';
import { Alert } from '@/components/ui/alert';
import { useGoogleLogin } from '@/lib/hooks/useGoogleLogin';
import { useEffect, useState } from 'react';

export default function GoogleAuthSection() {
  const { handleGoogleSuccess, isLoading: isGoogleLoading, error: googleError } = useGoogleLogin();
  const [clientId, setClientId] = useState('');
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
    const id = process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID || '';
    setClientId(id);
    
    if (!id) {
      console.error('❌ NEXT_PUBLIC_GOOGLE_CLIENT_ID not set in environment');
    } else {
      console.log('✅ Google OAuth Client ID loaded:', id.substring(0, 20) + '...');
    }
  }, []);

  if (!mounted) return null;

  return (
    <>
      {googleError && (
        <Alert variant="danger" className="bg-red-50 border-red-200 text-red-700">
          {googleError}
        </Alert>
      )}

      {/* Google Sign-In Button */}
      <div className="flex justify-center">
        {clientId ? (
          <GoogleLogin
            onSuccess={handleGoogleSuccess}
            onError={() => {
              trackAuthEvent(ANALYTICS_EVENTS.LOGIN_FAILED, { error_reason: 'google_signin_error' });
            }}
            theme="outline"
            size="large"
          />
        ) : (
          <div className="w-full bg-yellow-50 border border-yellow-200 rounded-lg p-3 text-center">
            <p className="text-sm text-yellow-800 font-medium">
              Google Sign-in temporarily unavailable
            </p>
          </div>
        )}
      </div>

      {/* Divider */}
      <div className="relative">
        <div className="absolute inset-0 flex items-center">
          <div className="w-full border-t border-gray-300"></div>
        </div>
        <div className="relative flex justify-center text-sm">
          {/* <span className="px-2 bg-white text-text-secondary">Or use email / phone number</span> */}
          <span className="px-2 bg-white text-text-secondary">Or </span>
        </div>
      </div>
    </>
  );
}
