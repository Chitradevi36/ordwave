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
    pan?: string;
    business_type?: string;
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
  }) => {
    const headers: any = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${localStorage.getItem('auth_token')}`,
    };

    const orgId = localStorage.getItem('organization_id');
    if (!orgId) {
      throw new Error('Organization not initialized. Please refresh and try again.');
    }
    
    headers['X-Organization-Id'] = orgId;

    const res = await fetch(`${API_URL}/api/v1/onboarding/quick_create_customer`, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        name: data.name,
        phone: data.phone,
      }),
    });

    if (!res.ok) {
      try {
        const error = await res.json();
        const message = error.errors?.[0] || error.message;
        throw new Error(message || `Failed to create customer (${res.status})`);
      } catch (e) {
        if (e instanceof Error) throw e;
        const text = await res.text();
        throw new Error(`Failed to create customer (${res.status}: ${res.statusText}) - ${text.substring(0, 100)}`);
      }
    }

    try {
      const data = await res.json();
      return data;
    } catch (e) {
      // If response isn't JSON but status is ok, assume success
      const text = await res.text();
      console.warn('Non-JSON response from quick_create_customer:', text);
      return { data: { id: null, message: 'Customer created' } };
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
    if (!orgId) {
      throw new Error('Organization not initialized. Please refresh and try again.');
    }

    headers['X-Organization-Id'] = orgId;

    const res = await fetch(`${API_URL}/api/v1/onboarding/quick_create_product`, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        sku: data.sku,
        name: data.name,
        gst_rate: data.gst_rate,
      }),
    });

    if (!res.ok) {
      try {
        const error = await res.json();
        const message = error.errors?.[0] || error.message;
        throw new Error(message || `Failed to create product (${res.status})`);
      } catch (e) {
        if (e instanceof Error) throw e;
        const text = await res.text();
        throw new Error(`Failed to create product (${res.status}: ${res.statusText}) - ${text.substring(0, 100)}`);
      }
    }

    try {
      const data = await res.json();
      return data;
    } catch (e) {
      // If response isn't JSON but status is ok, assume success
      const text = await res.text();
      console.warn('Non-JSON response from quick_create_product:', text);
      return { data: { id: null, message: 'Product created' } };
    }
  },
};
