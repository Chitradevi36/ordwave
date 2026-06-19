import { useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import { useOrgBranch } from '@/lib/org-branch-context';

/**
 * Hook to ensure user has completed onboarding initialization (org/branch creation)
 * Returns true only when user is authenticated, has organization, AND context has initialized
 * Redirects immediately if checks fail (returns false, page shouldn't render)
 */
export function useOnboardingGuard(): boolean {
  const router = useRouter();
  const { isInitialized, organizations } = useOrgBranch();
  const [isReady, setIsReady] = useState<boolean>(false);
  const [hasChecked, setHasChecked] = useState<boolean>(false);

  useEffect(() => {
    // Perform check after mount (after browser's next tick)
    const checkAndRedirect = () => {
      // Get stored data
      const token = localStorage.getItem('auth_token');
      const orgId = localStorage.getItem('organization_id');
      const storedUser = localStorage.getItem('user');
      const userObj = storedUser ? JSON.parse(storedUser) : null;

      // If user is logged in but no organization, redirect to onboarding
      // EXCEPTION: if user has a membership with role 'customer' (retailer contact), skip onboarding
      const hasCustomerMembership = userObj && userObj.membership && userObj.membership.role && userObj.membership.role.name === 'customer';
      if (token && !orgId && !hasCustomerMembership) {
        // Redirect and don't set ready
        router.replace('/onboarding');
        setHasChecked(true);
        return;
      }

      // If user is not logged in, redirect to signup
      if (!token) {
        router.replace('/signup');
        setHasChecked(true);
        return;
      }

      // User is properly authenticated with organization initialized
      setIsReady(true);
      setHasChecked(true);
    };

    checkAndRedirect();
  }, [router]);

  // Wait for BOTH localStorage check AND context initialization
  // This prevents rendering before organizations are fetched from API
  const isFullyReady = hasChecked && isReady && isInitialized && organizations.length > 0;

  // Return false while checking to prevent render
  // Return true only when fully initialized (context data available)
  return isFullyReady;
}
