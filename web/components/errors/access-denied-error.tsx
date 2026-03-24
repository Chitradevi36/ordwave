'use client';

import { useRouter } from 'next/navigation';
import { AppShell } from '@/components/layout';
import { Button } from '@/components/ui/button';

/**
 * Reusable AccessDeniedError component for detail pages
 * Shows friendly error message when access is denied or resource not found
 * 
 * Usage in any detail page:
 * ```
 * if (error) {
 *   return <AccessDeniedError 
 *     status={error.status} 
 *     message={error.message} 
 *     backLink="/orders" 
 *   />;
 * }
 * ```
 */

interface AccessDeniedErrorProps {
  status: number;
  message: string;
  backLink: string;
  resourceType?: string;
}

export function AccessDeniedError({
  status,
  message,
  backLink,
  resourceType = 'Resource'
}: AccessDeniedErrorProps) {
  const router = useRouter();

  const getErrorTitle = () => {
    switch (status) {
      case 403:
        return 'Access Denied';
      case 404:
        return `${resourceType} Not Found`;
      default:
        return 'Error Loading Resource';
    }
  };

  const getErrorDescription = () => {
    switch (status) {
      case 403:
        return `This ${resourceType.toLowerCase()} belongs to a different organization or you don't have permission to access it.`;
      case 404:
        return `The ${resourceType.toLowerCase()} you're looking for doesn't exist or has been deleted.`;
      default:
        return `An error occurred while loading this ${resourceType.toLowerCase()}. Please try again.`;
    }
  };

  return (
    <AppShell>
      <div className="max-w-2xl mx-auto px-4 py-24">
        <div className="bg-red-50 border border-red-200 rounded-lg p-8 text-center">
          {/* Status Code */}
          <div className="text-5xl font-bold text-red-600 mb-4">
            {status}
          </div>

          {/* Title */}
          <h1 className="text-2xl font-bold text-gray-900 mb-2">
            {getErrorTitle()}
          </h1>

          {/* Message */}
          <p className="text-gray-600 mb-2">
            {message}
          </p>

          {/* Description */}
          <p className="text-sm text-gray-600 mb-6">
            {getErrorDescription()}
          </p>

          {/* Actions */}
          <div className="flex flex-col sm:flex-row gap-3 justify-center">
            <Button 
              variant="outline"
              onClick={() => router.back()}
            >
              Go Back
            </Button>
            <Button 
              onClick={() => router.push(backLink)}
            >
              Back to {resourceType}s
            </Button>
          </div>
        </div>
      </div>
    </AppShell>
  );
}
