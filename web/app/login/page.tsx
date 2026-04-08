'use client';

import { useState, useEffect, useRef } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { Eye, EyeOff } from 'lucide-react';
import { ANALYTICS_EVENTS, trackAuthEvent } from '@/lib/analytics';
import Link from 'next/link';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card } from '@/components/ui/card';
import { Alert } from '@/components/ui/alert';
import { API_URL } from "@/lib/api/client";
import GoogleAuthSection from './google-auth-section';

type AuthMethod = 'none' | 'otp' | 'password';
type IdentifierType = 'email' | 'phone' | 'unknown';

export default function LoginPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const redirect = searchParams.get('redirect') ?? '/dashboard';
  
  // Identifier detection
  const [identifier, setIdentifier] = useState('');
  const [identifierType, setIdentifierType] = useState<IdentifierType>('unknown');
  const [validationError, setValidationError] = useState('');
  
  // Auth method selection
  const [authMethod, setAuthMethod] = useState<AuthMethod>('none');
  
  // Password flow
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  
  // OTP flow
  const [otpCode, setOtpCode] = useState('');
  const [otpRequestId, setOtpRequestId] = useState('');
  const [otpSent, setOtpSent] = useState(false);
  
  // UI state
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    try {
      trackAuthEvent(ANALYTICS_EVENTS.LOGIN_PAGE_VIEWED);
    } catch (e) {
      console.warn('Analytics not available');
    }
  }, []);

  // ==================== IDENTIFIER DETECTION ====================
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  const phoneRegex = /^[6-9]\d{9}$/;

  const detectIdentifierType = (value: string): IdentifierType => {
    if (emailRegex.test(value)) return 'email';
    if (phoneRegex.test(value)) return 'phone';
    return 'unknown';
  };

  const handleIdentifierChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    setIdentifier(value);
    setValidationError('');
    setError('');

    if (value) {
      const type = detectIdentifierType(value);
      setIdentifierType(type);
      
      if (type === 'unknown' && value.length > 3) {
        setValidationError('Enter a valid email or 10-digit phone number');
      }
    } else {
      setIdentifierType('unknown');
    }
  };

  // ==================== PASSWORD LOGIN ====================
  const handlePasswordLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!identifier || !password) {
      setError('Please fill in all fields');
      return;
    }

    setLoading(true);
    setError('');

    try {
      const response = await fetch(`${API_URL}/api/v1/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
          [identifierType === 'phone' ? 'phone' : 'email']: identifier, 
          password 
        }),
      });

      const data = await response.json();

      if (response.ok) {
        // Store session
        localStorage.setItem('auth_token', data.data.token);
        localStorage.setItem('user', JSON.stringify(data.data.user));
        
        const orgId = data.data.user?.organization_id || data.data.user?.current_organization_id;
        if (orgId) {
          localStorage.setItem('organization_id', String(orgId));
        } else {
          localStorage.removeItem('organization_id');
        }
        
        localStorage.removeItem('orderlane_profile_cache');
        document.cookie = 'auth_present=1; path=/; max-age=86400; SameSite=Lax';

        trackAuthEvent(ANALYTICS_EVENTS.LOGIN_COMPLETED, { method: 'password' });
        // Force full page reload to clear React Query cache and prevent stale user data
        window.location.href = redirect;
      } else {
        const reason = data.errors?.[0] || 'Login failed';
        setError(reason);
        trackAuthEvent(ANALYTICS_EVENTS.LOGIN_FAILED, { error_reason: reason, method: 'password' });
      }
    } catch (err) {
      setError('Network error. Please try again.');
      trackAuthEvent(ANALYTICS_EVENTS.LOGIN_FAILED, { error_reason: 'network_error', method: 'password' });
    } finally {
      setLoading(false);
    }
  };

  // ==================== OTP FLOW ====================
  const handleRequestOtp = async () => {
    if (!identifier) {
      setError('Please enter your email or phone number');
      return;
    }

    if (identifierType === 'unknown') {
      setValidationError('Invalid email or phone number');
      return;
    }

    setLoading(true);
    setError('');

    try {
      const response = await fetch(`${API_URL}/api/v1/auth/request_otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ identifier }),
      });

      const data = await response.json();

      if (response.ok) {
        setAuthMethod('otp');
        setOtpRequestId(data.data?.request_id || '');
        setOtpSent(true);
        setError('');
        trackAuthEvent(ANALYTICS_EVENTS.LOGIN_PAGE_VIEWED, { step: 'otp' });
      } else {
        const reason = data.errors?.[0] || 'Failed to send OTP';
        setError(reason);
        trackAuthEvent(ANALYTICS_EVENTS.LOGIN_FAILED, { error_reason: reason, method: 'otp_request' });
      }
    } catch (err) {
      setError('Network error. Please check your connection.');
      trackAuthEvent(ANALYTICS_EVENTS.LOGIN_FAILED, { error_reason: 'network_error', method: 'otp_request' });
    } finally {
      setLoading(false);
    }
  };

  const handleVerifyOtp = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!otpCode || otpCode.length !== 6) {
      setError('Please enter the 6-digit code');
      return;
    }

    setLoading(true);
    setError('');

    try {
      const response = await fetch(`${API_URL}/api/v1/auth/verify_otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ identifier, code: otpCode, request_id: otpRequestId }),
      });

      const data = await response.json();

      if (response.ok) {
        // Store session
        localStorage.setItem('auth_token', data.data.token);
        localStorage.setItem('user', JSON.stringify(data.data.user));
        
        const orgId = data.data.user?.organization_id || data.data.user?.current_organization_id;
        if (orgId) {
          localStorage.setItem('organization_id', String(orgId));
        } else {
          localStorage.removeItem('organization_id');
        }
        
        localStorage.removeItem('orderlane_profile_cache');
        document.cookie = 'auth_present=1; path=/; max-age=86400; SameSite=Lax';

        trackAuthEvent(ANALYTICS_EVENTS.LOGIN_COMPLETED, { method: 'otp' });
        // Force full page reload to clear React Query cache and prevent stale user data
        window.location.href = redirect;
      } else {
        const reason = data.errors?.[0] || 'Invalid code';
        setError(reason);
        trackAuthEvent(ANALYTICS_EVENTS.LOGIN_FAILED, { error_reason: reason, method: 'otp_verify' });
      }
    } catch (err) {
      setError('Network error. Please try again.');
      trackAuthEvent(ANALYTICS_EVENTS.LOGIN_FAILED, { error_reason: 'network_error', method: 'otp_verify' });
    } finally {
      setLoading(false);
    }
  };

  const handleReset = () => {
    setAuthMethod('none');
    setIdentifier('');
    setIdentifierType('unknown');
    setPassword('');
    setShowPassword(false);
    setOtpCode('');
    setOtpRequestId('');
    setOtpSent(false);
    setError('');
    setValidationError('');
  };



  // ==================== RENDER: MAIN LOGIN PAGE ====================
  return (
    <div className="min-h-screen flex items-center justify-center bg-white px-4 py-8">
      <div className="w-full max-w-md">
        {/* Header */}
        <div className="text-center mb-6 sm:mb-8">
          <h1 className="text-2xl sm:text-3xl font-bold text-slate-900">OrdWave</h1>
          <p className="text-sm sm:text-base text-slate-600 mt-2">Sign in to your account</p>
        </div>

        <Card className="p-6 sm:p-8 border border-slate-200 shadow-sm">
          <div className="space-y-4 sm:space-y-6">
            {error && (
              <Alert variant="danger" className="bg-red-50 border-red-200 text-red-700">
                {error}
              </Alert>
            )}

            {/* Google OAuth Section */}
            <GoogleAuthSection />

            {/* Email/Phone Input & Buttons (always visible when authMethod is 'none') */}
            {authMethod === 'none' && (
              <>
                <div>
                  <label htmlFor="identifier" className="block text-sm font-medium text-slate-900 mb-2">
                    Email or phone number
                  </label>
                  <Input
                    id="identifier"
                    type="text"
                    value={identifier}
                    onChange={handleIdentifierChange}
                    placeholder="hello@company.com or 9876543210"
                    disabled={loading}
                    className="text-base border-slate-300 focus:border-slate-900"
                  />
                  {validationError && (
                    <p className="mt-2 text-sm text-red-600">{validationError}</p>
                  )}
                  <p className="mt-2 text-xs text-slate-500">
                    Enter your registered email or 10-digit phone number
                  </p>
                </div>

                {/* CTA Buttons (visible immediately) */}
                <div className="space-y-3">
                  {/* Primary: Get OTP */}
                  <Button
                    onClick={handleRequestOtp}
                    disabled={loading || !identifier || identifierType === 'unknown'}
                    className="w-full disabled:bg-gray-300 disabled:cursor-not-allowed"
                  >
                    {identifierType === 'phone' ? 'Get OTP' : 'Get OTP'}
                  </Button>

                  {/* Secondary: Password Link (always visible) */}
                  <button
                    onClick={() => {
                      setAuthMethod('password');
                      setError('');
                    }}
                    disabled={identifierType === 'unknown' || !identifier}
                    className="w-full text-sm font-medium py-2 disabled:text-slate-400 disabled:cursor-not-allowed hover:text-slate-900 text-slate-600"
                  >
                    Login with Password
                  </button>
                </div>
              </>
            )}

            {/* Step 2: OTP Input */}
            {authMethod === 'otp' && otpSent && (
              <form onSubmit={handleVerifyOtp} className="space-y-4 sm:space-y-6">
                <div className="bg-blue-50 border border-blue-200 rounded-lg p-3">
                  <p className="text-sm text-blue-900">
                    Code sent to <span className="font-medium">{identifier}</span>
                  </p>
                </div>

                <div>
                  <label className="block text-sm font-medium text-slate-900 mb-2">
                    6-digit code
                  </label>
                  <Input
                    type="text"
                    value={otpCode}
                    onChange={(e) => setOtpCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
                    placeholder="Enter 6-digit code"
                    required
                    disabled={loading}
                    className="text-center text-2xl tracking-widest border-slate-300 focus:border-slate-900"
                    maxLength={6}
                    inputMode="numeric"
                    autoFocus
                  />
                  <p className="text-xs text-slate-500 text-center mt-2">
                    Check your {identifierType === 'phone' ? 'SMS' : 'email'} for the code
                  </p>
                </div>

                <Button
                  type="submit"
                  className="w-full"
                  disabled={loading || otpCode.length !== 6}
                >
                  {loading ? 'Verifying...' : 'Verify Code'}
                </Button>

                <button
                  type="button"
                  onClick={() => {
                    setOtpCode('');
                    setError('');
                  }}
                  disabled={loading}
                  className="w-full text-slate-600 hover:text-slate-900 text-sm disabled:text-slate-400"
                >
                  Didn't receive it? Request new code
                </button>

                <button
                  type="button"
                  onClick={handleReset}
                  className="w-full text-slate-500 hover:text-slate-700 text-sm py-2 border-t border-slate-200 pt-4 mt-2"
                >
                  ← Back to options
                </button>
              </form>
            )}

            {/* Step 2: Password Input */}
            {authMethod === 'password' && (
              <form onSubmit={handlePasswordLogin} className="space-y-4 sm:space-y-6">
                <div className="bg-slate-50 border border-slate-200 rounded-lg p-3">
                  <p className="text-sm text-slate-700">
                    Signing in as <span className="font-medium">{identifier}</span>
                  </p>
                </div>

                <div>
                  <label htmlFor="password" className="block text-sm font-medium text-slate-900 mb-2">
                    Password
                  </label>
                  <div className="relative">
                    <Input
                      id="password"
                      type={showPassword ? 'text' : 'password'}
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      placeholder="••••••••"
                      disabled={loading}
                      autoComplete="off"
                      className="text-base border-slate-300 focus:border-slate-900 pr-10"
                    />
                    <button
                      type="button"
                      onClick={() => setShowPassword(!showPassword)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-500 hover:text-slate-700 p-1"
                    >
                      {showPassword ? <EyeOff size={20} /> : <Eye size={20} />}
                    </button>
                  </div>
                </div>

                <div className="flex items-center justify-between">
                  <Link 
                    href="/forgot-password" 
                    className="text-sm text-slate-600 hover:text-slate-900 font-medium"
                  >
                    Forgot password?
                  </Link>
                </div>

                <Button
                  type="submit"
                  className="w-full"
                  disabled={loading}
                >
                  {loading ? 'Signing in...' : 'Sign in'}
                </Button>

                <button
                  type="button"
                  onClick={handleReset}
                  className="w-full text-slate-500 hover:text-slate-700 text-sm py-2 border-t border-slate-200 pt-4 mt-2"
                >
                  ← Back to options
                </button>
              </form>
            )}
          </div>

          {/* Footer Links */}
          {authMethod === 'none' && (
            <div className="mt-6 text-center text-sm text-slate-600">
              Don't have an account?{' '}
              <Link href="/signup" className="text-slate-900 hover:text-slate-700 font-semibold">
                Sign up
              </Link>
            </div>
          )}
        </Card>

        {/* Footer Text */}
        <div className="mt-8 text-center text-xs text-slate-500">
          <p>For FMCG distributors to manage orders, inventory & logistics</p>
        </div>
      </div>
    </div>
  );
}
