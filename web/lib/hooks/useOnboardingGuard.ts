import { useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';

/**
 * Hook to ensure user has completed onboarding initialization (org/branch creation)
 * Returns true only when user is authenticated and has initialized organization
 * Redirects immediately if checks fail (returns false, page shouldn't render)
 */
export function useOnboardingGuard(): boolean {
  const router = useRouter();
  const [isReady, setIsReady] = useState<boolean>(false);
  const [hasChecked, setHasChecked] = useState<boolean>(false);

  useEffect(() => {
    // Perform check after mount (after browser's next tick)
    const checkAndRedirect = () => {
      // Get stored data
      const token = localStorage.getItem('auth_token');
      const orgId = localStorage.getItem('organization_id');

      // If user is logged in but no organization, redirect to onboarding
      if (token && !orgId) {
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

  // Return false while checking to prevent render
  // Return true only when check is complete AND user is authenticated+initialized
  return hasChecked && isReady;
}
