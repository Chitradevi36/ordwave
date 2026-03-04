// API utility functions for onboarding
export const onboardingAPI = {
  create: async (data: {
    org_name: string;
    branch_name: string;
    branch_code: string;
    city?: string;
    state?: string;
    gst_number?: string;
    contact_phone?: string;
  }) => {
    const res = await fetch('http://localhost:3001/api/v1/onboarding/create', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${localStorage.getItem('auth_token')}`,
      },
      body: JSON.stringify(data),
    });

    if (!res.ok) {
      const error = await res.json();
      throw new Error(error.errors?.[0] || 'Failed to initialize onboarding');
    }

    return res.json();
  },

  setup: async (data: {
    business_type?: string;
    org_details?: Record<string, any>;
    branch_details?: Record<string, any>;
    operating_model?: string[];
  }) => {
    const headers: any = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${localStorage.getItem('auth_token')}`,
    };

    const orgId = localStorage.getItem('organization_id');
    if (orgId) {
      headers['X-Organization-Id'] = orgId;
    }

    const res = await fetch('http://localhost:3001/api/v1/onboarding/setup', {
      method: 'POST',
      headers,
      body: JSON.stringify(data),
    });

    if (!res.ok) {
      const error = await res.json();
      throw new Error(error.errors?.[0] || 'Failed to setup onboarding');
    }

    return res.json();
  },

  getProgress: async () => {
    const headers: any = {
      'Authorization': `Bearer ${localStorage.getItem('auth_token')}`,
    };

    const orgId = localStorage.getItem('organization_id');
    if (orgId) {
      headers['X-Organization-Id'] = orgId;
    }

    const res = await fetch('http://localhost:3001/api/v1/onboarding', {
      method: 'GET',
      headers,
    });

    if (!res.ok) {
      const error = await res.json();
      throw new Error(error.errors?.[0] || 'Failed to get onboarding progress');
    }

    return res.json();
  },

  completeStep: async (stepName: string) => {
    const headers: any = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${localStorage.getItem('auth_token')}`,
    };

    const orgId = localStorage.getItem('organization_id');
    if (orgId) {
      headers['X-Organization-Id'] = orgId;
    }

    const res = await fetch('http://localhost:3001/api/v1/onboarding/complete_step', {
      method: 'POST',
      headers,
      body: JSON.stringify({ step_name: stepName }),
    });

    if (!res.ok) {
      const error = await res.json();
      throw new Error(error.errors?.[0] || `Failed to complete step: ${stepName}`);
    }

    return res.json();
  },
};
