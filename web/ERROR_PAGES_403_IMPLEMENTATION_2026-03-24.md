## 📊 ENHANCED ERROR PAGES (403 Unauthorized)
## Production-Ready Implementation

**Status:** READY TO IMPLEMENT  
**Estimated Effort:** 2-3 hours  
**Owner:** Frontend Engineer  
**Target Date:** April 7, 2026  

---

## 📋 IMPLEMENTATION PLAN

### Step 1: Create 403 Error Component
```tsx
// web/components/errors/access-denied-error.tsx

import { AlertTriangle, ArrowLeft, Home, HelpCircle } from 'lucide-react';
import Link from 'next/link';
import { Button } from '@/components/ui/button';

interface AccessDeniedErrorProps {
  resource?: string;
  reason?: string;
  userRole?: string;
  suggestedAction?: string;
}

export function AccessDeniedError({
  resource = 'resource',
  reason,
  userRole,
  suggestedAction,
}: AccessDeniedErrorProps) {
  return (
    <div className="min-h-screen flex flex-col items-center justify-center bg-gradient-to-b from-red-50 to-white p-6">
      {/* Error Header */}
      <div className="text-center mb-8">
        <div className="inline-flex items-center justify-center w-16 h-16 bg-red-100 rounded-full mb-4">
          <AlertTriangle className="h-8 w-8 text-red-600" />
        </div>
        
        <h1 className="text-4xl font-bold text-gray-900 mb-2">Access Denied</h1>
        <p className="text-lg text-gray-600 mb-4">
          You don't have permission to access this {resource}
        </p>
      </div>

      {/* Error Details Card */}
      <div className="bg-white rounded-lg shadow-lg p-8 max-w-md w-full mb-8">
        <div className="space-y-4">
          {/* What Happened */}
          <div>
            <h2 className="font-semibold text-gray-900 mb-2">What Happened?</h2>
            <p className="text-sm text-gray-600">
              {reason || 'Your account does not have permission to view this page.'}
            </p>
          </div>

          {/* Your Role */}
          {userRole && (
            <div>
              <h2 className="font-semibold text-gray-900 mb-2">Your Role</h2>
              <div className="inline-block px-3 py-1 bg-blue-100 text-blue-700 rounded-full text-sm font-medium">
                {userRole}
              </div>
            </div>
          )}

          {/* Why This Might Happen */}
          <div>
            <h2 className="font-semibold text-gray-900 mb-2">Why This Happens</h2>
            <ul className="text-sm text-gray-600 space-y-1 list-disc list-inside">
              <li>Your user role doesn't have access to this feature</li>
              <li>The resource belongs to a different organization</li>
              <li>Your permissions were recently changed</li>
              <li>Your session may have expired</li>
            </ul>
          </div>

          {/* What You Can Do */}
          <div>
            <h2 className="font-semibold text-gray-900 mb-2">What You Can Do</h2>
            <ul className="text-sm text-gray-600 space-y-1 list-disc list-inside">
              {suggestedAction ? (
                <li>{suggestedAction}</li>
              ) : (
                <>
                  <li>Go back to the previous page</li>
                  <li>Contact your administrator for access</li>
                  <li>Check your organization settings</li>
                </>
              )}
            </ul>
          </div>
        </div>
      </div>

      {/* Action Buttons */}
      <div className="flex gap-4 mb-8">
        <Button
          variant="ghost"
          className="flex items-center gap-2"
          onClick={() => window.history.back()}
        >
          <ArrowLeft className="h-4 w-4" />
          Go Back
        </Button>
        <Link href="/">
          <Button className="flex items-center gap-2">
            <Home className="h-4 w-4" />
            Home
          </Button>
        </Link>
      </div>

      {/* Help Section */}
      <div className="bg-blue-50 rounded-lg p-4 max-w-md w-full">
        <div className="flex gap-3">
          <HelpCircle className="h-5 w-5 text-blue-600 flex-shrink-0 mt-0.5" />
          <div>
            <p className="text-sm font-semibold text-blue-900 mb-1">Need Help?</p>
            <p className="text-sm text-blue-700 mb-2">
              If you believe you should have access to this resource, please contact your administrator.
            </p>
            <a href="mailto:support@orderlane.com" className="text-sm text-blue-600 hover:text-blue-800 font-medium">
              Contact Support →
            </a>
          </div>
        </div>
      </div>

      {/* Error Code Footer */}
      <div className="mt-8 text-center text-sm text-gray-500">
        <p>Error Code: 403 FORBIDDEN</p>
        <p>If this persists, please contact support with this error code</p>
      </div>
    </div>
  );
}
```

### Step 2: Create Error Page Component
```tsx
// web/app/errors/403/page.tsx

import { AccessDeniedError } from '@/components/errors/access-denied-error';
import { useSearchParams } from 'next/navigation';

export default function ErrorPage403() {
  const searchParams = useSearchParams();
  
  const resource = searchParams.get('resource') || 'page';
  const reason = searchParams.get('reason');
  const userRole = searchParams.get('role');
  const suggestedAction = searchParams.get('action');

  return (
    <AccessDeniedError
      resource={resource}
      reason={reason}
      userRole={userRole}
      suggestedAction={suggestedAction}
    />
  );
}
```

### Step 3: Update API Error Handling
```tsx
// web/lib/api-client.ts

export const apiClient = {
  async request(endpoint: string, options: RequestInit = {}) {
    try {
      const res = await fetch(`${API_URL}${endpoint}`, {
        ...options,
        headers: {
          'Authorization': `Bearer ${getToken()}`,
          'X-Organization-Id': getOrgId(),
          ...options.headers,
        },
      });

      if (res.status === 403) {
        // Extract error details from response
        const data = await res.json();
        
        // Redirect to error page with context
        const errorParams = new URLSearchParams({
          resource: data.resource || 'resource',
          reason: data.message || 'Access denied',
          role: data.user_role || 'Unknown',
          action: data.suggested_action || '',
        });

        window.location.href = `/errors/403?${errorParams}`;
        return;
      }

      if (res.status === 401) {
        // Handle authentication errors
        localStorage.removeItem('auth_token');
        window.location.href = '/login';
        return;
      }

      if (!res.ok) {
        const error = await res.json();
        throw new Error(error.message || 'Request failed');
      }

      return await res.json();
    } catch (error) {
      console.error('API Error:', error);
      throw error;
    }
  },
};
```

### Step 4: Update API Controllers to Return Better Error Info
```ruby
# backend/app/controllers/api/base_controller.rb

module Api
  class BaseController < ApplicationController
    rescue_from Pundit::NotAuthorizedError, with: :handle_authorization_error

    private

    def handle_authorization_error(error)
      resource_name = error.context&.keys&.first&.to_s&.humanize || 'resource'
      
      render json: {
        errors: ['Access denied'],
        message: "You don't have permission to access this #{resource_name}",
        resource: resource_name,
        user_role: current_user&.role,
        suggested_action: suggest_action_for_role(current_user),
        error_code: 'AUTHORIZATION_DENIED',
      }, status: :forbidden
    end

    def suggest_action_for_role(user)
      case user&.role
      when 'driver'
        'Drivers can only view delivery and trip information. Contact your manager for access to other modules.'
      when 'sales_rep'
        'Sales representatives have limited module access. Contact your manager if you need access to Finance or Inventory.'
      when 'admin'
        'As an admin, you should have access to most resources. If this persists, contact your organization owner.'
      else
        'Contact your administrator for access to this resource.'
      end
    end
  end
end
```

### Step 5: Create Middleware for Global 403 Handling
```typescript
// web/middleware.ts

import { NextRequest, NextResponse } from 'next/server';

export function middleware(request: NextRequest) {
  // Catch 403 responses and redirect to error page
  return async (response: NextResponse) => {
    if (response.status === 403) {
      const errorUrl = new URL('/errors/403', request.url);
      errorUrl.searchParams.set('resource', new URL(request.url).pathname);
      
      return NextResponse.redirect(errorUrl);
    }

    return response;
  };
}

export const config = {
  matcher: ['/api/:path*', '/orders/:path*', '/customers/:path*'],
};
```

### Step 6: Add Route Protection HOC
```tsx
// web/lib/hooks/use-route-protection.ts

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { useCurrentRole } from './use-current-role';

interface RequiredPermission {
  module: string;
  permission?: string;
}

export function useRouteProtection(required: RequiredPermission) {
  const router = useRouter();
  const { role, hasPermission } = useCurrentRole();
  const [authorized, setAuthorized] = useState(false);

  useEffect(() => {
    if (!hasPermission(required.module, required.permission)) {
      const errorParams = new URLSearchParams({
        resource: required.module,
        reason: `Your ${role} role does not have access to ${required.module}`,
        role: role || 'unknown',
      });

      router.push(`/errors/403?${errorParams}`);
    } else {
      setAuthorized(true);
    }
  }, [role, required, router]);

  return authorized;
}

// Usage in component:
export function OrdersPage() {
  const authorized = useRouteProtection({ module: 'Orders', permission: 'read' });

  if (!authorized) {
    return <div>Loading...</div>;
  }

  return <OrdersList />;
}
```

### Step 7: Create Admin Panel for 403 Monitoring
```tsx
// web/app/admin/error-monitoring/page.tsx

'use client';

import { useEffect, useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip } from 'recharts';

export default function ErrorMonitoringPage() {
  const [data, setData] = useState();
  const [topErrors, setTopErrors] = useState();

  useEffect(() => {
    async function fetchData() {
      const res = await fetch('/api/v1/admin/error-statistics?period=24h');
      const json = await res.json();
      setData(json.errors_by_hour);
      setTopErrors(json.top_403_errors);
    }

    fetchData();
  }, []);

  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-bold">Error Monitoring</h1>

      {/* 403 Trends */}
      <Card>
        <CardHeader>
          <CardTitle>403 Errors (Last 24h)</CardTitle>
        </CardHeader>
        <CardContent>
          <LineChart width={800} height={300} data={data}>
            <CartesianGrid />
            <XAxis dataKey="hour" />
            <YAxis />
            <Tooltip />
            <Line type="monotone" dataKey="count" stroke="#ef4444" />
          </LineChart>
        </CardContent>
      </Card>

      {/* Top 403 Errors */}
      <Card>
        <CardHeader>
          <CardTitle>Top 403 Errors</CardTitle>
        </CardHeader>
        <CardContent>
          <table className="w-full">
            <thead>
              <tr className="border-b">
                <th className="text-left py-2">Resource</th>
                <th className="text-left py-2">User Role</th>
                <th className="text-left py-2">Count</th>
                <th className="text-left py-2">Last Occurrence</th>
              </tr>
            </thead>
            <tbody>
              {topErrors?.map((error, i) => (
                <tr key={i} className="border-b hover:bg-gray-50">
                  <td className="py-2">{error.resource}</td>
                  <td className="py-2">{error.user_role}</td>
                  <td className="py-2">{error.count}</td>
                  <td className="py-2">{error.last_occurrence}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </CardContent>
      </Card>
    </div>
  );
}
```

---

## 📋 DEPLOYMENT CHECKLIST

- [ ] Create AccessDeniedError component
- [ ] Create /errors/403 page
- [ ] Update API error handling
- [ ] Add error details to API responses
- [ ] Create middleware for global 403 handling
- [ ] Add route protection hook
- [ ] Create admin monitoring dashboard
- [ ] Write tests for error page
- [ ] Deploy to staging
- [ ] Test with different roles
- [ ] Deploy to production
- [ ] Monitor error logs

---

## ✅ TESTING CHECKLIST

- [ ] Test as Owner (should have full access)
- [ ] Test as Admin (should have full access)
- [ ] Test as Sales Rep (trigger 403 on Finance module)
- [ ] Test as Driver (trigger 403 on Inventory module)
- [ ] Verify error page displays correctly
- [ ] Verify suggested actions are helpful
- [ ] Test "Go Back" button
- [ ] Test "Contact Support" link
- [ ] Verify error details in admin dashboard

---

**Status:** READY TO IMPLEMENT  
**Next Step:** Create PR with this code
