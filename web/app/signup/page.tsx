'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { ANALYTICS_EVENTS, trackAuthEvent } from '@/lib/analytics';
import Link from 'next/link';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card } from '@/components/ui/card';
import { Alert } from '@/components/ui/alert';
import { Badge } from '@/components/ui/badge';
import { ArrowRight, Mail, Lock, User, Check } from 'lucide-react';
import { API_URL } from "@/lib/api/client";

type Step = 'email' | 'otp' | 'password' | 'profile';

const STEPS: Step[] = ['email', 'otp', 'password', 'profile'];

const PLANS = [
  {
    id: 'starter',
    name: 'Starter',
    price: '₹999',
    period: '/month',
    features: ['Up to 100 orders/month', '1 branch', '3 team members', 'Basic reports'],
    popular: false,
  },
  {
    id: 'growth',
    name: 'Growth',
    price: '₹2,499',
    period: '/month',
    features: ['Up to 500 orders/month', '5 branches', '10 team members', 'Advanced analytics', 'WhatsApp integration'],
    popular: true,
  },
  {
    id: 'enterprise',
    name: 'Enterprise',
    price: 'Custom',
    period: '',
    features: ['Unlimited orders', 'Unlimited branches', 'Unlimited team members', 'Custom integrations', 'Dedicated support'],
    popular: false,
  },
];

export default function SignupPage() {
  const router = useRouter();
  const [currentStep, setCurrentStep] = useState<Step>('email');
  const [email, setEmail] = useState('');
  const [otpCode, setOtpCode] = useState('');
  const [password, setPassword] = useState('');
  const [passwordConfirmation, setPasswordConfirmation] = useState('');
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [phone, setPhone] = useState('');
  const [plan, setPlan] = useState('growth');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const stepIndex = STEPS.indexOf(currentStep);
  const progress = ((stepIndex + 1) / STEPS.length) * 100;

  // Fire page-view on mount
  useEffect(() => {
    trackAuthEvent(ANALYTICS_EVENTS.SIGNUP_PAGE_VIEWED);
  }, []);

  const handleEmailSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(``);
    setLoading(true);

    try {
      const response = await fetch(`${API_URL}/api/v1/signup/initiate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email }),
      });

      const data = await response.json();

      if (response.ok) {
        if (data.data.otp_code) {
          console.log('DEV OTP:', data.data.otp_code);
        }
        trackAuthEvent(ANALYTICS_EVENTS.SIGNUP_EMAIL_SUBMITTED);
        setCurrentStep('otp');
      } else {
        setError(data.errors?.[0] || 'Failed to send OTP');
      }
    } catch (err) {
      setError('An error occurred. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleOtpSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(``);
    setLoading(true);

    try {
      const response = await fetch(`${API_URL}/api/v1/signup/verify_otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, otp_code: otpCode }),
      });

      const data = await response.json();

      if (response.ok) {
        trackAuthEvent(ANALYTICS_EVENTS.SIGNUP_OTP_VERIFIED);
        setCurrentStep('password');
      } else {
        setError(data.errors?.[0] || 'Invalid OTP');
      }
    } catch (err) {
      setError('An error occurred. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handlePasswordSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    if (password !== passwordConfirmation) {
      setError('Passwords do not match');
      return;
    }

    if (password.length < 8) {
      setError(`Password must be at least 8 characters`);
      return;
    }

    setLoading(true);

    try {
      const response = await fetch(`${API_URL}/api/v1/signup/set_password`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email,
          password,
          password_confirmation: passwordConfirmation,
        }),
      });

      const data = await response.json();

      if (response.ok) {
        trackAuthEvent(ANALYTICS_EVENTS.SIGNUP_PASSWORD_SET);
        setCurrentStep('profile');
      } else {
        setError(data.errors?.[0] || 'Failed to set password');
      }
    } catch (err) {
      setError('An error occurred. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleProfileSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(``);
    setLoading(true);

    try {
      // Complete the signup with plan selection
      const response = await fetch(`${API_URL}/api/v1/signup/choose_plan`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email,
          plan,
          first_name: firstName,
          last_name: lastName,
          phone,
        }),
      });

      const data = await response.json();

      if (response.ok) {
        // Store auth token and user data
        localStorage.setItem('auth_token', data.data.token);
        localStorage.setItem('user', JSON.stringify(data.data.user));

        // Set the auth cookie so middleware allows access to protected routes
        document.cookie = 'auth_present=1; path=/; max-age=86400; SameSite=Lax';

        trackAuthEvent(ANALYTICS_EVENTS.SIGNUP_COMPLETED, { plan });
        // Redirect to comprehensive onboarding wizard
        router.push('/onboarding');
      } else {
        setError(data.errors?.[0] || 'Failed to complete signup');
      }
    } catch (err) {
      setError('An error occurred. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-background-subtle px-4 py-8 sm:py-12">
      <div className="w-full max-w-md">
        {/* Header */}
        <div className="text-center mb-6 sm:mb-8">
          <h1 className="text-2xl sm:text-3xl font-bold text-text-primary mb-2">OrdWave</h1>
          <p className="text-sm sm:text-base text-text-secondary">Create your account in seconds</p>
        </div>

        {/* Progress Bar */}
        <div className="mb-4 sm:mb-6">
          <div className="flex items-center justify-between text-xs sm:text-sm text-text-secondary mb-2">
            <span>Step {stepIndex + 1} of {STEPS.length}</span>
            <span>{Math.round(progress)}% complete</span>
          </div>
          <div className="h-2 bg-background rounded-full overflow-hidden">
            <div
              className="h-full bg-primary transition-all duration-300"
              style={{ width: `${progress}%` }}
            />
          </div>
        </div>

        <Card className="p-6 sm:p-8">
          {error && (
            <Alert variant="danger" className="mb-6">
              {error}
            </Alert>
          )}

          {/* Step 1: Email */}
          {currentStep === 'email' && (
            <form onSubmit={handleEmailSubmit} className="space-y-6">
              <div className="text-center mb-6">
                <div className="inline-flex items-center justify-center w-12 h-12 bg-primary-50 rounded-full mb-4">
                  <Mail className="w-6 h-6 text-primary" />
                </div>
                <h2 className="text-xl font-semibold text-text-primary mb-2">
                  What's your email?
                </h2>
                <p className="text-sm text-text-secondary">
                  We'll send you a verification code
                </p>
              </div>

              <div>
                <Input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="your@email.com"
                  required
                  disabled={loading}
                  className="text-base"
                  autoFocus
                />
              </div>

              <Button type="submit" className="w-full" disabled={loading} isLoading={loading}>
                Continue
                <ArrowRight className="ml-2 w-4 h-4" />
              </Button>

              <p className="text-center text-sm text-text-secondary">
                Already have an account?{' '}
                <Link href="/login" className="text-primary hover:underline font-medium">
                  Sign in
                </Link>
              </p>
            </form>
          )}

          {/* Step 2: OTP Verification */}
          {currentStep === 'otp' && (
            <form onSubmit={handleOtpSubmit} className="space-y-6">
              <div className="text-center mb-6">
                <div className="inline-flex items-center justify-center w-12 h-12 bg-primary-50 rounded-full mb-4">
                  <Mail className="w-6 h-6 text-primary" />
                </div>
                <h2 className="text-xl font-semibold text-text-primary mb-2">
                  Check your email
                </h2>
                <p className="text-sm text-text-secondary">
                  We sent a 6-digit code to <strong>{email}</strong>
                </p>
              </div>

              <div>
                <Input
                  type="text"
                  value={otpCode}
                  onChange={(e) => setOtpCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
                  placeholder="Enter 6-digit code"
                  required
                  disabled={loading}
                  className="text-center text-2xl tracking-widest"
                  maxLength={6}
                  autoFocus
                />
              </div>

              <Button type="submit" className="w-full" disabled={loading || otpCode.length !== 6} isLoading={loading}>
                Verify Code
                <ArrowRight className="ml-2 w-4 h-4" />
              </Button>

              <button
                type="button"
                onClick={() => setCurrentStep('email')}
                className="w-full text-sm text-text-secondary hover:text-primary"
              >
                Change email address
              </button>
            </form>
          )}

          {/* Step 3: Password */}
          {currentStep === 'password' && (
            <form onSubmit={handlePasswordSubmit} className="space-y-6">
              <div className="text-center mb-6">
                <div className="inline-flex items-center justify-center w-12 h-12 bg-primary-50 rounded-full mb-4">
                  <Lock className="w-6 h-6 text-primary" />
                </div>
                <h2 className="text-xl font-semibold text-text-primary mb-2">
                  Create a password
                </h2>
                <p className="text-sm text-text-secondary">
                  Must be at least 8 characters
                </p>
              </div>

              <div>
                <Input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="Enter password"
                  required
                  disabled={loading}
                  autoFocus
                />
              </div>

              <div>
                <Input
                  type="password"
                  value={passwordConfirmation}
                  onChange={(e) => setPasswordConfirmation(e.target.value)}
                  placeholder="Confirm password"
                  required
                  disabled={loading}
                />
              </div>

              <Button type="submit" className="w-full" disabled={loading} isLoading={loading}>
                Continue
                <ArrowRight className="ml-2 w-4 h-4" />
              </Button>

              <button
                type="button"
                onClick={() => setCurrentStep('otp')}
                className="w-full text-sm text-text-secondary hover:text-primary"
                disabled={loading}
              >
                ← Back
              </button>
            </form>
          )}

          {/* Step 4: Profile & Plan */}
          {currentStep === 'profile' && (
            <form onSubmit={handleProfileSubmit} className="space-y-6">
              <div className="text-center mb-6">
                <div className="inline-flex items-center justify-center w-12 h-12 bg-primary-50 rounded-full mb-4">
                  <User className="w-6 h-6 text-primary" />
                </div>
                <h2 className="text-xl font-semibold text-text-primary mb-2">
                  Tell us about yourself
                </h2>
                <p className="text-sm text-text-secondary">
                  Just a few more details
                </p>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-text-primary mb-2">
                    First Name *
                  </label>
                  <Input
                    type="text"
                    value={firstName}
                    onChange={(e) => setFirstName(e.target.value)}
                    placeholder="John"
                    required
                    disabled={loading}
                    autoFocus
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-text-primary mb-2">
                    Last Name *
                  </label>
                  <Input
                    type="text"
                    value={lastName}
                    onChange={(e) => setLastName(e.target.value)}
                    placeholder="Doe"
                    required
                    disabled={loading}
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-text-primary mb-2">
                  Phone Number *
                </label>
                <Input
                  type="tel"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  placeholder="+91 98765 43210"
                  required
                  disabled={loading}
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-text-primary mb-4">
                  Choose a Plan
                </label>
                <div className="space-y-3">
                  {PLANS.map((planOption) => (
                    <div
                      key={planOption.id}
                      onClick={() => setPlan(planOption.id)}
                      className={`relative p-4 border-2 rounded-lg cursor-pointer transition-all ${
                        plan === planOption.id
                          ? 'border-primary bg-primary-50'
                          : 'border-border hover:border-primary-200'
                      }`}
                    >
                      {planOption.popular && (
                        <Badge className="absolute -top-2 right-4 bg-accent text-white">
                          Most Popular
                        </Badge>
                      )}
                      <div className="flex items-start justify-between mb-2">
                        <div>
                          <h3 className="font-semibold text-text-primary">{planOption.name}</h3>
                          <p className="text-sm text-text-secondary mt-1">
                            {planOption.price}
                            <span className="text-xs">{planOption.period}</span>
                          </p>
                        </div>
                        {plan === planOption.id && (
                          <div className="flex items-center justify-center w-6 h-6 bg-primary rounded-full">
                            <Check className="w-4 h-4 text-white" />
                          </div>
                        )}
                      </div>
                      <ul className="text-xs text-text-secondary space-y-1">
                        {planOption.features.slice(0, 3).map((feature, idx) => (
                          <li key={idx}>✓ {feature}</li>
                        ))}
                      </ul>
                    </div>
                  ))}
                </div>
              </div>

              <Button type="submit" className="w-full" disabled={loading} isLoading={loading}>
                Create Account
                <ArrowRight className="ml-2 w-4 h-4" />
              </Button>

              <button
                type="button"
                onClick={() => setCurrentStep('password')}
                className="w-full text-sm text-text-secondary hover:text-primary"
                disabled={loading}
              >
                ← Back
              </button>

              <p className="text-xs text-center text-text-secondary">
                By creating an account, you agree to our{' '}
                <a href="#" className="text-primary hover:underline">Terms of Service</a>
                {' '}and{' '}
                <a href="#" className="text-primary hover:underline">Privacy Policy</a>
              </p>
            </form>
          )}
        </Card>
      </div>
    </div>
  );
}
