'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { ANALYTICS_EVENTS, trackAuthEvent } from '@/lib/analytics';
import Link from 'next/link';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card } from '@/components/ui/card';
import { Alert } from '@/components/ui/alert';
import { API_URL } from "@/lib/api/client";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');

  useEffect(() => {
    trackAuthEvent(ANALYTICS_EVENTS.LOGIN_PAGE_VIEWED);
  }, []);
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(``);
    setLoading(true);

    try {
      const response = await fetch(`${API_URL}/api/v1/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      });

      const data = await response.json();

      if (response.ok) {
        // Store token — organization_id is resolved by OrgBranchProvider after login
        localStorage.setItem('auth_token', data.data.token);
        localStorage.removeItem('organization_id');          // clear stale value so context auto-selects
        localStorage.removeItem('orderlane_profile_cache'); // clear stale role cache from previous user
        localStorage.setItem('user', JSON.stringify(data.data.user));
        // Set a lightweight cookie so middleware.ts can guard server-side routing
        document.cookie = 'auth_present=1; path=/; max-age=86400; SameSite=Lax';

        trackAuthEvent(ANALYTICS_EVENTS.LOGIN_COMPLETED);
        router.push('/dashboard');
      } else {
        const reason = data.errors?.[0] || 'Login failed';
        setError(reason);
        trackAuthEvent(ANALYTICS_EVENTS.LOGIN_FAILED, { error_reason: reason });
      }
    } catch (err) {
      setError('An error occurred. Please try again.');
      trackAuthEvent(ANALYTICS_EVENTS.LOGIN_FAILED, { error_reason: 'network_error' });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-background-subtle px-4 py-8">
      <div className="w-full max-w-md">
        <div className="text-center mb-6 sm:mb-8">
          <h1 className="text-2xl sm:text-3xl font-bold text-text-primary">OrdWave</h1>
          <p className="text-sm sm:text-base text-text-secondary mt-2">Sign in to your account</p>
        </div>

        <Card className="p-6 sm:p-8">
          <form onSubmit={handleSubmit} className="space-y-4 sm:space-y-6">
            {error && (
              <Alert variant="danger" className="bg-red-50 border-red-200 text-red-700">
                {error}
              </Alert>
            )}

            <div>
              <label htmlFor="email" className="block text-sm font-medium text-text-primary mb-2">
                Email address
              </label>
              <Input
                id="email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="your@email.com"
                required
                disabled={loading}
              />
            </div>

            <div>
              <label htmlFor="password" className="block text-sm font-medium text-text-primary mb-2">
                Password
              </label>
              <Input
                id="password"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                required
                disabled={loading}
              />
            </div>

            <div className="flex items-center justify-between">
              <div className="text-sm">
                <Link href="/forgot-password" className="text-primary hover:text-primary-700 font-medium">
                  Forgot password?
                </Link>
              </div>
            </div>

            <Button
              type="submit"
              className="w-full bg-primary hover:bg-primary-700 text-white"
              disabled={loading}
            >
              {loading ? 'Signing in...' : 'Sign in'}
            </Button>
          </form>

          <div className="mt-6 text-center text-sm text-text-secondary">
            Don't have an account?{' '}
            <Link href="/signup" className="text-primary hover:text-primary-700 font-medium">
              Sign up
            </Link>
          </div>
        </Card>

        <div className="mt-8 text-center text-xs text-text-secondary">
          <p>For FMCG distributors to manage orders, inventory & logistics</p>
        </div>
      </div>
    </div>
  );
}
