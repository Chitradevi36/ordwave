'use client';

import { useState } from 'react';
import Link from 'next/link';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card } from '@/components/ui/card';
import { Alert } from '@/components/ui/alert';
import { API_URL } from "@/lib/api/client";

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState('');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(``);
    setSuccess(false);
    setLoading(true);

    try {
      const response = await fetch(`${API_URL}/api/v1/passwords/forgot`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email }),
      });

      const data = await response.json();

      if (response.ok) {
        setSuccess(true);
      } else {
        setError(data.errors?.[0] || 'Failed to send reset instructions');
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
        <div className="text-center mb-10">
          <h1 className="text-4xl font-bold text-text-primary mb-2">Forgot your password?</h1>
          <p className="text-text-secondary text-base">
            No problem. Enter your email address and we'll send you a link to reset it.
          </p>
        </div>

        <Card className="p-8 shadow-sm">
          {success ? (
            <div className="text-center space-y-6">
              <div className="space-y-2">
                <div className="flex justify-center mb-4">
                  <div className="w-12 h-12 bg-primary-50 rounded-full flex items-center justify-center">
                    <svg className="w-6 h-6 text-accent" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                    </svg>
                  </div>
                </div>
                <h2 className="text-xl font-semibold text-text-primary">Check your email</h2>
                <p className="text-text-secondary text-sm">
                  We've sent a password reset link to <span className="font-medium">{email}</span>
                </p>
              </div>
              <Alert variant="success" className="bg-primary-50 border-accent text-primary">
                Check your inbox and spam folder for the reset link
              </Alert>
              <br/>
              <Link href="/login">
                <Button className="w-full bg-accent hover:bg-green-600 text-white">
                  Return to login
                </Button>
              </Link>
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="space-y-6">
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
                  placeholder="you@example.com"
                  required
                  disabled={loading}
                  className="h-10"
                />
              </div>

              <Button
                type="submit"
                className="w-full h-10 bg-primary hover:bg-primary-700 text-white text-base font-medium"
                disabled={loading}
              >
                {loading ? 'Sending reset link...' : 'Send reset link'}
              </Button>

              <div className="text-center pt-2">
                <Link href="/login" className="text-sm text-text-secondary hover:text-text-primary font-medium">
                  ← Back to login
                </Link>
              </div>
            </form>
          )}
        </Card>

        <p className="text-center text-xs text-text-secondary mt-6">
          Don't have an account? <Link href="/signup" className="text-primary hover:text-primary-700 font-medium">Sign up</Link>
        </p>
      </div>
    </div>
  );
}
