// API utility functions for onboarding
import { API_URL } from "@/lib/api/client";

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
    const res = await fetch(`${API_URL}/api/v1/onboarding/create`, {
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
      headers[`X-Organization-Id`] = orgId;
    }

    const res = await fetch(`${API_URL}/api/v1/onboarding/setup`, {
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
      headers[`X-Organization-Id`] = orgId;
    }

    const res = await fetch(`${API_URL}/api/v1/onboarding`, {
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
      headers[`X-Organization-Id`] = orgId;
    }

    const res = await fetch(`${API_URL}/api/v1/onboarding/complete_step`, {
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

  createCustomer: async (data: {
    name: string;
    phone: string;
    branch_id?: string;
  }) => {
    const headers: any = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${localStorage.getItem('auth_token')}`,
    };

    const orgId = localStorage.getItem('organization_id');
    if (orgId) {
      headers[`X-Organization-Id`] = orgId;
    }

    // Get first branch if not provided
    let branchId = data.branch_id;
    if (!branchId) {
      try {
        const branchRes = await fetch(`${API_URL}/api/v1/branches`, {
          method: 'GET',
          headers: {
            'Authorization': `Bearer ${localStorage.getItem('auth_token')}`,
            'X-Organization-Id': orgId || '',
          }
        });
        if (branchRes.ok) {
          const branches = await branchRes.json();
          branchId = branches.data?.[0]?.id;
        }
      } catch {
        // Continue without branch_id if lookup fails
      }
    }

    const res = await fetch(`${API_URL}/api/v1/customers`, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        customer: {
          name: data.name,
          phone: data.phone,
          branch_id: branchId,
          customer_type: 'regular',
        }
      }),
    });

    if (!res.ok) {
      try {
        const error = await res.json();
        throw new Error(error.errors?.[0] || 'Failed to create customer');
      } catch {
        throw new Error(`Failed to create customer (${res.status}: ${res.statusText})`);
      }
    }

    try {
      return await res.json();
    } catch {
      return {};
    }
  },

  createProduct: async (data: {
    sku: string;
    name: string;
    gst_rate: number;
  }) => {
    const headers: any = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${localStorage.getItem('auth_token')}`,
    };

    const orgId = localStorage.getItem('organization_id');
    if (orgId) {
      headers[`X-Organization-Id`] = orgId;
    }

    const res = await fetch(`${API_URL}/api/v1/products`, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        product: {
          sku: data.sku,
          name: data.name,
          gst_rate: data.gst_rate,
          status: 'active',
        }
      }),
    });

    if (!res.ok) {
      try {
        const error = await res.json();
        throw new Error(error.errors?.[0] || 'Failed to create product');
      } catch {
        throw new Error(`Failed to create product (${res.status}: ${res.statusText})`);
      }
    }

    try {
      return await res.json();
    } catch {
      return {};
    }
  },
};
