'use client';

import { AlertTriangle, ArrowLeft, Home, HelpCircle } from 'lucide-react';
import Link from 'next/link';
import { useRouter, useSearchParams } from 'next/navigation';
import { Button } from '@/components/ui/button';
import { Suspense } from 'react';

interface AccessDeniedErrorContentProps {
  resource?: string;
  reason?: string;
  userRole?: string;
  suggestedAction?: string;
}

function AccessDeniedErrorContent({
  resource = 'resource',
  reason,
  userRole,
  suggestedAction,
}: AccessDeniedErrorContentProps) {
  const router = useRouter();

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
              <div className="inline-block px-3 py-1 bg-blue-100 text-blue-700 rounded-full text-sm font-medium capitalize">
                {userRole.replace(/_/g, ' ')}
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
          variant="outline"
          className="flex items-center gap-2"
          onClick={() => router.back()}
        >
          <ArrowLeft className="h-4 w-4" />
          Go Back
        </Button>
        <Link href="/dashboard">
          <Button className="flex items-center gap-2">
            <Home className="h-4 w-4" />
            Dashboard
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
            <a 
              href="mailto:support@orderlane.com" 
              className="text-sm text-blue-600 hover:text-blue-800 font-medium underline"
            >
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

export default function Error403Page() {
  const searchParams = useSearchParams();
  
  const resource = searchParams.get('resource') || 'page';
  const reason = searchParams.get('reason') || undefined;
  const userRole = searchParams.get('role') || undefined;
  const suggestedAction = searchParams.get('action') || undefined;

  return (
    <Suspense fallback={<div>Loading...</div>}>
      <AccessDeniedErrorContent
        resource={resource}
        reason={reason}
        userRole={userRole}
        suggestedAction={suggestedAction}
      />
    </Suspense>
  );
}
