'use client';

import { useState, useEffect } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import Link from 'next/link';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card } from '@/components/ui/card';
import { Alert } from '@/components/ui/alert';
import { API_URL } from "@/lib/api/client";

export default function ResetPasswordPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const token = searchParams.get('token');
  
  const [password, setPassword] = useState('');
  const [passwordConfirmation, setPasswordConfirmation] = useState('');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const [loading, setLoading] = useState(false);
  const [validatingToken, setValidatingToken] = useState(true);
  const [tokenValid, setTokenValid] = useState(false);

  useEffect(() => {
    if (!token) {
      setError(`Invalid reset link`);
      setValidatingToken(false);
      return;
    }

    // Validate token
    fetch(`${API_URL}/api/v1/passwords/validate_token`, {
      method: `POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ reset_token: token }),
    })
      .then((res) => res.json())
      .then((data) => {
        if (data.data?.valid) {
          setTokenValid(true);
        } else {
          setError('Invalid or expired reset link');
        }
      })
      .catch(() => {
        setError('An error occurred validating the reset link');
      })
      .finally(() => {
        setValidatingToken(false);
      });
  }, [token]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(``);
    setLoading(true);

    try {
      const response = await fetch(`${API_URL}/api/v1/passwords/reset`, {
        method: `POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          reset_token: token,
          password,
          password_confirmation: passwordConfirmation,
        }),
      });

      const data = await response.json();

      if (response.ok) {
        setSuccess(true);
        setTimeout(() => router.push('/login'), 2000);
      } else {
        setError(data.errors?.[0] || 'Failed to reset password');
      }
    } catch (err) {
      setError('An error occurred. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-background-subtle px-4 py-8">
      <div className="w-full max-w-md">
        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold text-text-primary">Set New Password</h1>
          <p className="text-text-secondary mt-2">Choose a new password for your account</p>
        </div>

        <Card className="p-8">
          {validatingToken ? (
            <div className="text-center py-8">
              <p className="text-text-secondary">Validating reset link...</p>
            </div>
          ) : !tokenValid ? (
            <div className="space-y-4">
              <Alert variant="danger" className="bg-red-50 border-red-200 text-red-700">
                {error || 'Invalid or expired reset link'}
              </Alert>
              <Link href="/forgot-password">
                <Button className="w-full bg-primary hover:bg-primary-700 text-white">Request a new reset link</Button>
              </Link>
            </div>
          ) : success ? (
            <div className="space-y-4">
              <Alert variant="success" className="bg-primary-50 border-accent text-primary">
                Password reset successfully! Redirecting to login...
              </Alert>
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="space-y-6">
              {error && (
                <Alert variant="danger" className="bg-red-50 border-red-200 text-red-700">
                  {error}
                </Alert>
              )}

              <div>
                <label htmlFor="password" className="block text-sm font-medium text-text-primary mb-2">
                  New password
                </label>
                <Input
                  id="password"
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  required
                  minLength={8}
                  disabled={loading}
                />
                <p className="text-xs text-text-secondary mt-1">At least 8 characters</p>
              </div>

              <div>
                <label htmlFor="passwordConfirmation" className="block text-sm font-medium text-text-primary mb-2">
                  Confirm new password
                </label>
                <Input
                  id="passwordConfirmation"
                  type="password"
                  value={passwordConfirmation}
                  onChange={(e) => setPasswordConfirmation(e.target.value)}
                  placeholder="••••••••"
                  required
                  minLength={8}
                  disabled={loading}
                />
              </div>

              <Button
                type="submit"
                className="w-full bg-primary hover:bg-primary-700 text-white"
                disabled={loading}
              >
                {loading ? 'Resetting...' : 'Reset password'}
              </Button>

              <div className="text-center text-sm">
                <Link href="/login" className="text-primary hover:text-primary-700 font-medium">
                  Back to login
                </Link>
              </div>
            </form>
          )}
        </Card>
      </div>
    </div>
  );
}
