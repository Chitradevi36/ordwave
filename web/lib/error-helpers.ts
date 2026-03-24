/**
 * Error Helper Functions
 * Use these helpers in client components to create proper error URLs for redirects
 */

export function createErrorPageUrl(options: {
  resource?: string;
  reason?: string;
  userRole?: string;
  suggestedAction?: string;
}): string {
  const params = new URLSearchParams();
  
  if (options.resource) params.append('resource', options.resource);
  if (options.reason) params.append('reason', options.reason);
  if (options.userRole) params.append('role', options.userRole);
  if (options.suggestedAction) params.append('action', options.suggestedAction);

  return `/errors/403?${params.toString()}`;
}

/**
 * Redirect helper for access denied scenarios
 * Use in server actions or API handlers to redirect to friendly error page
 * 
 * Example:
 * ```
 * import { createErrorPageUrl } from '@/lib/error-helpers';
 * import { redirect } from 'next/navigation';
 * 
 * try {
 *   // forbidden check
 *   if (!hasPermission) {
 *     redirect(createErrorPageUrl({
 *       resource: 'Admin Dashboard',
 *       reason: 'Only admins can access this feature',
 *       userRole: 'sales_rep',
 *       suggestedAction: 'Contact your organization admin'
 *     }));
 *   }
 * } catch (error) {
 *   // error handling
 * }
 * ```
 */
export const errorMessages = {
  accessDenied: (resource: string) => 
    `You don't have permission to access ${resource}`,
  adminOnly: (feature: string) =>
    `${feature} is restricted to administrators`,
  organizationOnly: (resource: string) =>
    `${resource} is restricted to your organization`,
  roleRequired: (role: string) =>
    `This action requires ${role} role`,
};
