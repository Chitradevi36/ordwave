# Plan: GST Credentials in Organization Settings (State-Based, No Duplication)

**TL;DR:** Three-tier credential hierarchy **without duplication**:
1. **Organization-Level** (IRP API credentials → shared by all branches)
2. **State-Level** (GSTIN → shared by all branches in that state)
3. **Branch-Level** (Override only if branch needs different GSTIN from state)

**Key:** If multiple branches in Karnataka, configure GSTIN once at state level. All branches inherit it automatically. Only override if a specific branch needs a different GSTIN for that state.

No schema migrations—uses `organization.settings[:gst_state_registrations]` + optional `branch.settings[:gst_override]`.

---

## FRONTEND: UI STRUCTURE & DATA FLOW

### 1. New Tab Addition

**File:** [web/app/settings/organization/page.tsx](web/app/settings/organization/page.tsx)

```tsx
const TABS = [
  { key: "profile",      label: "Profile",       icon: Building2 },
  { key: "workflow",     label: "Workflow",      icon: Workflow },
  { key: "gst",          label: "GST Credentials", icon: FileText },  // ← NEW
  { key: "branches",     label: "Branches",      icon: GitBranch },
];
```

**Tab appears in navigation between Workflow and Branches.**

---

### 2. GST Credentials Tab: Layout (Three-Tier, No Duplication)

```
┌──────────────────────────────────────────────────────────────────┐
│ GST & E-Invoice Configuration                                   │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│ SECTION 1: E-Invoice (IRP) API Credentials                      │
│ ────────────────────────────────────────────────────────────    │
│ ⓘ Shared organization-wide for IRP API authentication           │
│                                                                  │
│ Username/Email: [________________]                              │
│ Password:       [________________] (masked)                     │
│ Environment:    ✓ Sandbox ○ Production                          │
│                                                                  │
│ [Test Connection] [Save Credentials]                            │
│ Status: ✓ Configured by Chitra Devi on Apr 2, 2026           │
│                                                                  │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│ SECTION 2: State-Level GSTIN Registration (ONE per state)       │
│ ────────────────────────────────────────────────────────────    │
│ ⓘ Configure GSTIN once per state. All branches in that state    │
│   use it automatically (no duplication). Override only if a      │
│   specific branch needs different GSTIN.                        │
│                                                                  │
│ State  GSTIN              Status        Actions                  │
│ ──────────────────────────────────────────────────────────────  │
│ KA     22AABCT1234H1Z0   Configured ✓  [Edit] [Remove]         │
│        ↳ Used by: BHQua, Bannerghatta (2 branches)              │
│                                                                  │
│ MH     (Not configured)              [Configure]                │
│                                                                  │
│ TN     29AABCT5678H2Z0   Configured ✓  [Edit] [Remove]         │
│        ↳ Used by: (No branches in this state)                   │
│                                                                  │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│ SECTION 3: Branch-Level Overrides (Only if needed)              │
│ ────────────────────────────────────────────────────────────    │
│ ⓘ Override state GSTIN only if a branch needs different GSTIN   │
│                                                                  │
│ Branch         State  State GSTIN       Override    Actions     │
│ ───────────────────────────────────────────────────────────────│
│ BHQua          KA     22AABCT1234H1Z0  None        [Override]  │
│ Bannerghatta   KA     22AABCT1234H1Z0  None        [Override]  │
│                                                                  │
│  (Both use same KA state GSTIN - no duplication!)               │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

**Key Difference from Previous Design:**
- ❌ OLD: Branch-by-branch GSTIN (BHQua: 22AABCT..., Bannerghatta: 22AABCT... → Duplication!)
- ✅ NEW: State-level GSTIN (KA: 22AABCT... → Both branches use it automatically)

---

### 3. Form State Management (Three-Tier)

**File:** [web/app/settings/organization/page.tsx](web/app/settings/organization/page.tsx)

```tsx
// TIER 1: Organization-level IRP credentials
const [gstForm, setGstForm] = useState({
  irp_username: '',
  irp_password: '',
  irp_environment: 'sandbox', // 'sandbox' | 'production'
  configured_at: null,
  configured_by: null,
});

// TIER 2: State-level GSTIN (keyed by state code, e.g., { "KA": "22AABCT...", "MH": "27AABCT..." })
const [stateGstinMap, setStateGstinMap] = useState<Record<string, StateGstConfig>>({
  // Format:
  // "KA": { gstin: "22AABCT1234H1Z0", configured_at, configured_by_id, branch_count: 2 }
  // "MH": { gstin: "27AABCT5678H2Z0", configured_at, configured_by_id, branch_count: 0 }
});

// TIER 3: Branch-level overrides (only if branch needs different GSTIN than state)
const [branchOverrides, setBranchOverrides] = useState<BranchGstOverride[]>([
  // Format:
  // { branch_id: 7, branch_name: "BHQua", state_code: "KA", override_gstin: null } (uses state KA GSTIN)
  // { branch_id: 8, branch_name: "Bannerghatta", state_code: "KA", override_gstin: null } (uses state KA GSTIN)
  // { branch_id: 9, branch_name: "Special Branch", state_code: "KA", override_gstin: "22AABCT9999H1Z0" } (uses override)
]);

// UI states
const [gstSaving, setGstSaving] = useState(false);
const [gstSuccess, setGstSuccess] = useState(false);
const [gstError, setGstError] = useState<string | null>(null);
const [testingConnection, setTestingConnection] = useState(false);
const [testResult, setTestResult] = useState<{ success: boolean; message: string } | null>(null);
const [editingState, setEditingState] = useState<string | null>(null); // "KA", "MH", etc
const [overrideModal, setOverrideModal] = useState<{ open: boolean; branchId?: string }>({ open: false });
```

**Data Structure Benefits:**
- ✅ **No Duplication:** GSTIN configured once per state
- ✅ **Automatic Inheritance:** Branches in KA automatically use KA's GSTIN
- ✅ **Optional Override:** Only store branch override if different from state default
- ✅ **Easy Query:** `effective_gstin = state_map[branch.state] OR branch.override`

---

### 4. Fetch All Three Tiers On Tab Load

```tsx
// useEffect when GST tab opens
useEffect(() => {
  if (activeTab !== "gst" || !orgId) return;
  
  // FETCH TIER 1 + TIER 2: Org settings (IRP credentials + state-level GSTINs)
  fetch(`${API_URL}/api/v1/organizations/${orgId}/settings`, {
    headers: {
      Authorization: `Bearer ${token}`,
      "X-Organization-Id": orgId,
    },
  })
    .then(res => res.json())
    .then(json => {
      const creds = json.data?.settings?.gst_credentials ?? {};
      
      // TIER 1: Organization-level
      setGstForm({
        irp_username: creds.irp_username ?? '',
        irp_password: creds.irp_password ?? '',
        irp_environment: creds.irp_environment ?? 'sandbox',
        configured_at: creds.configured_at,
        configured_by: creds.configured_by_name,
      });
      
      // TIER 2: State-level GSTIN mapping
      const stateRegistrations = json.data?.settings?.gst_state_registrations ?? {};
      setStateGstinMap(stateRegistrations);
      // Format: { "KA": { gstin, configured_at, configured_by_id, used_by_branches: 2 }, ... }
    });
  
  // FETCH TIER 3: Branch-level overrides
  fetch(`${API_URL}/api/v1/gst/branch_overrides`, {
    headers: {
      Authorization: `Bearer ${token}`,
      "X-Organization-Id": orgId,
    },
  })
    .then(res => res.json())
    .then(json => {
      // Response: [ { branch_id, branch_name, state_code, override_gstin, effective_gstin }, ... ]
      setBranchOverrides(json.data);
    });
}, [activeTab, orgId, token]);
```

**Three-Tier Hierarchy Logic:**
```
For any branch, effective GSTIN = branch.override_gstin OR state_map[branch.state]?.gstin

Example:
- BHQua (state: KA) → Uses state_map["KA"].gstin = "22AABCT1234H1Z0" (no override)
- Bannerghatta (state: KA) → Uses state_map["KA"].gstin = "22AABCT1234H1Z0" (no override)
- Special Branch (state: KA, override: "22AABCT9999H1Z0") → Uses "22AABCT9999H1Z0" (override)
```

---

### 5. Save Organization-Level Credentials

```tsx
const saveGstCredentials = async () => {
  if (!gstForm.irp_username.trim() || !gstForm.irp_password.trim()) {
    setGstError("Username and password are required");
    return;
  }
  
  setGstSaving(true);
  setGstError(null);
  
  try {
    const res = await fetch(
      `${API_URL}/api/v1/organizations/${orgId}/settings`,
      {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
          "X-Organization-Id": orgId,
        },
        body: JSON.stringify({
          settings: {
            gst_credentials: {
              irp_username: gstForm.irp_username,
              irp_password: gstForm.irp_password,
              irp_environment: gstForm.irp_environment,
              configured_at: new Date().toISOString(),
            },
          },
        }),
      }
    );
    
    const json = await res.json();
    
    if (res.ok) {
      setGstSuccess(true);
      setGstForm(prev => ({
        ...prev,
        configured_at: json.data.settings?.gst_credentials?.configured_at,
        configured_by: json.data.settings?.gst_credentials?.configured_by_name,
      }));
      setTimeout(() => setGstSuccess(false), 3000);
      engagementEvents.updateSettings("gst_credentials", "created", "saved");
    } else {
      setGstError(json.errors?.[0] || "Failed to save credentials");
    }
  } finally {
    setGstSaving(false);
  }
};
```

---

### 6. **NEW:** Save State-Level GSTIN (No Duplication!)

```tsx
const saveStateGstin = async (stateCode: string, gstin: string) => {
  if (!gstin.match(/^\d{2}[A-Z]{5}\d{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$/)) {
    setGstError("Invalid GSTIN format");
    return;
  }
  
  // Validate state code matches GSTIN
  const gstinStateCode = gstin.substring(0, 2);
  if (gstinStateCode !== stateCode) {
    setGstError(`GSTIN state code (${gstinStateCode}) must match state code (${stateCode})`);
    return;
  }
  
  setGstSaving(true);
  setGstError(null);
  
  try {
    const res = await fetch(
      `${API_URL}/api/v1/organizations/${orgId}/settings`,
      {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
          "X-Organization-Id": orgId,
        },
        body: JSON.stringify({
          settings: {
            gst_state_registrations: {
              ...stateGstinMap,
              [stateCode]: {
                gstin: gstin,
                configured_at: new Date().toISOString(),
                // configured_by_id set by backend
              }
            }
          }
        }),
      }
    );
    
    const json = await res.json();
    
    if (res.ok) {
      // Update local state
      const updated = json.data?.settings?.gst_state_registrations ?? {};
      setStateGstinMap(updated);
      
      // Refresh branch overrides (to show which branches use this state GSTIN)
      fetch(`${API_URL}/api/v1/gst/branch_overrides`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId }
      })
        .then(r => r.json())
        .then(data => setBranchOverrides(data.data));
      
      setGstSuccess(true);
      setEditingState(null);
      setTimeout(() => setGstSuccess(false), 3000);
    } else {
      setGstError(json.errors?.[0] || "Failed to save state GSTIN");
    }
  } finally {
    setGstSaving(false);
  }
};

// Remove state GSTIN (all branches in that state revert to org default)
const removeStateGstin = async (stateCode: string) => {
  if (!confirm(`Remove GSTIN for state ${stateCode}? Branches will revert to organization GSTIN.`)) {
    return;
  }
  
  setGstSaving(true);
  
  try {
    const updated = { ...stateGstinMap };
    delete updated[stateCode];
    
    const res = await fetch(
      `${API_URL}/api/v1/organizations/${orgId}/settings`,
      {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
          "X-Organization-Id": orgId,
        },
        body: JSON.stringify({
          settings: {
            gst_state_registrations: updated
          }
        }),
      }
    );
    
    if (res.ok) {
      setStateGstinMap(updated);
    }
  } finally {
    setGstSaving(false);
  }
};
```

**Key Benefit:** When you save state GSTIN for "KA", ALL branches in Karnataka automatically use it. No need to configure each branch separately!

---

### 6. Test Connection

```tsx
const testGstConnection = async () => {
  if (!gstForm.irp_username.trim()) {
    setGstError("Enter username first");
    return;
  }
  
  setTestingConnection(true);
  setTestResult(null);
  
  try {
    const res = await fetch(
      `${API_URL}/api/v1/gst/credentials/test_connection`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "X-Organization-Id": orgId,
        },
        body: JSON.stringify({
          irp_username: gstForm.irp_username,
          irp_password: gstForm.irp_password,
          irp_environment: gstForm.irp_environment,
        }),
      }
    );
    
    const json = await res.json();
    
    if (res.ok) {
      setTestResult({ success: true, message: json.message });
    } else {
      setTestResult({ success: false, message: json.message });
    }
  } finally {
    setTestingConnection(false);
  }
};
```

---

### 7. SectionCard Component: GST Credentials

```tsx
// In activeTab === "gst" render:
<SectionCard
  title="E-Invoice (IRP) Credentials"
  description="Credentials to generate e-Invoices. Encrypted and shared across all branches."
>
  <div className="space-y-4">
    {gstForm.configured_at && (
      <Alert className="bg-blue-50 border-blue-200">
        <CheckCircle className="text-blue-600" />
        <div>
          <p className="font-semibold">Configured</p>
          <p className="text-sm text-gray-600">
            Set by {gstForm.configured_by} on{' '}
            {new Date(gstForm.configured_at).toLocaleDateString('en-IN')}
          </p>
        </div>
      </Alert>
    )}

    <div>
      <label className="block text-sm font-medium mb-1">Username/Email</label>
      <Input
        value={gstForm.irp_username}
        onChange={(e) =>
          setGstForm(prev => ({ ...prev, irp_username: e.target.value }))
        }
        placeholder="Enter GST portal username"
      />
    </div>

    <div>
      <label className="block text-sm font-medium mb-1">Password</label>
      <Input
        type="password"
        value={gstForm.irp_password !== gstForm.irp_password.replace(/./g, '*')
          ? gstForm.irp_password
          : ''}  // Show asterisks only if unchanged
        onChange={(e) =>
          setGstForm(prev => ({ ...prev, irp_password: e.target.value }))
        }
        placeholder="Enter GST portal password"
      />
      <p className="text-xs text-gray-500 mt-1">Password is encrypted at rest</p>
    </div>

    <div>
      <label className="block text-sm font-medium mb-2">Environment</label>
      <div className="flex gap-4">
        {['sandbox', 'production'].map(env => (
          <label key={env} className="flex items-center gap-2">
            <input
              type="radio"
              name="irp_environment"
              value={env}
              checked={gstForm.irp_environment === env}
              onChange={(e) =>
                setGstForm(prev => ({ ...prev, irp_environment: e.target.value }))
              }
            />
            <span className="capitalize">
              {env} {env === 'production' && '(Live)'}
            </span>
          </label>
        ))}
      </div>
    </div>

    <div className="flex gap-3 pt-2">
      <Button
        onClick={saveGstCredentials}
        disabled={gstSaving}
        className="bg-blue-600 text-white"
      >
        {gstSaving ? 'Saving...' : 'Save Credentials'}
      </Button>

      <Button
        onClick={testGstConnection}
        disabled={testingConnection || !gstForm.irp_username}
        variant="outline"
      >
        {testingConnection ? 'Testing...' : 'Test Connection'}
      </Button>
    </div>

    {testResult && (
      <Alert
        className={
          testResult.success
            ? 'bg-green-50 border-green-200'
            : 'bg-red-50 border-red-200'
        }
      >
        <AlertCircle
          className={testResult.success ? 'text-green-600' : 'text-red-600'}
        />
        <p>{testResult.message}</p>
      </Alert>
    )}

    {gstError && (
      <Alert className="bg-red-50 border-red-200">
        <AlertCircle className="text-red-600" />
        <p>{gstError}</p>
      </Alert>
    )}

    {gstSuccess && (
      <Alert className="bg-green-50 border-green-200">
        <CheckCircle className="text-green-600" />
        <p>Credentials saved successfully!</p>
      </Alert>
    )}
  </div>
</SectionCard>
```

---

### 8. **NEW:** State-Level GSTIN Table (No Duplication - One Per State!)

```tsx
<SectionCard
  title="State-Level GSTIN Registration"
  description="Configure GSTIN once per state. All branches in that state use it automatically."
>
  <div className="overflow-x-auto">
    <table className="w-full text-sm">
      <thead className="bg-gray-50 border-b">
        <tr>
          <th className="px-4 py-2 text-left">State</th>
          <th className="px-4 py-2 text-left">GSTIN</th>
          <th className="px-4 py-2 text-left">Used By</th>
          <th className="px-4 py-2 text-left">Actions</th>
        </tr>
      </thead>
      <tbody>
        {Object.entries(stateGstinMap).map(([stateCode, config]) => (
          <tr key={stateCode} className="border-b hover:bg-gray-50">
            <td className="px-4 py-3 font-medium">{stateCode}</td>
            <td className="px-4 py-3">
              <Badge className="bg-blue-100 text-blue-800">
                {config.gstin}
              </Badge>
            </td>
            <td className="px-4 py-3">
              {config.branch_count} branch{config.branch_count !== 1 ? 'es' : ''}
            </td>
            <td className="px-4 py-3 space-x-2">
              <Button
                size="sm"
                variant="outline"
                onClick={() => setEditingState(stateCode)}
              >
                Edit
              </Button>
              <Button
                size="sm"
                variant="ghost"
                onClick={() => removeStateGstin(stateCode)}
              >
                Remove
              </Button>
            </td>
          </tr>
        ))}
        
        {Object.keys(stateGstinMap).length === 0 && (
          <tr>
            <td colSpan={4} className="px-4 py-6 text-center text-gray-500">
              No states configured. Click "Add State" to begin.
            </td>
          </tr>
        )}
      </tbody>
    </table>
  </div>

  <Button
    onClick={() => setEditingState('NEW')}
    className="mt-4 bg-green-600 text-white"
  >
    + Add State GSTIN
  </Button>

  {editingState && (
    <StateGstinModal
      stateCode={editingState === 'NEW' ? '' : editingState}
      currentGstin={editingState === 'NEW' ? '' : stateGstinMap[editingState]?.gstin}
      onClose={() => setEditingState(null)}
      onSave={(stateCode, gstin) => {
        saveStateGstin(stateCode, gstin);
        setEditingState(null);
      }}
    />
  )}
</SectionCard>
```

**Key Benefit:** Configure "KA" → "22AABCT1234H1Z0" once. BHQua and Bannerghatta both automatically use it. ✅ No Duplication!

---

### 9. Branch Override Table (Only if Needed for Exceptions)

```tsx
<SectionCard
  title="Branch Exceptions (Optional)"
  description="Override state GSTIN only if a branch needs different GSTIN."
>
  <div className="overflow-x-auto">
    <table className="w-full text-sm">
      <thead className="bg-gray-50 border-b">
        <tr>
          <th className="px-4 py-2 text-left">Branch</th>
          <th className="px-4 py-2 text-left">State</th>
          <th className="px-4 py-2 text-left">State GSTIN (Default)</th>
          <th className="px-4 py-2 text-left">Override GSTIN</th>
          <th className="px-4 py-2 text-left">Using</th>
          <th className="px-4 py-2 text-left">Actions</th>
        </tr>
      </thead>
      <tbody>
        {branchOverrides.map(branch => {
          const stateGstin = stateGstinMap[branch.state_code]?.gstin;
          const isOverridden = branch.override_gstin !== null;
          const effectiveGstin = isOverridden ? branch.override_gstin : stateGstin;
          
          return (
            <tr key={branch.branch_id} className="border-b hover:bg-gray-50">
              <td className="px-4 py-3 font-medium">{branch.branch_name}</td>
              <td className="px-4 py-3">{branch.state_code}</td>
              <td className="px-4 py-3">
                {stateGstin ? (
                  <Badge variant="outline">{stateGstin}</Badge>
                ) : (
                  <span className="text-gray-400">Not configured</span>
                )}
              </td>
              <td className="px-4 py-3">
                {isOverridden ? (
                  <Badge className="bg-yellow-100 text-yellow-800">
                    {branch.override_gstin}
                  </Badge>
                ) : (
                  <span className="text-gray-400">None</span>
                )}
              </td>
              <td className="px-4 py-3">
                <Badge 
                  className={isOverridden ? 'bg-yellow-100 text-yellow-800' : 'bg-blue-100 text-blue-800'}
                >
                  {isOverridden ? 'Override' : 'State Default'}
                </Badge>
              </td>
              <td className="px-4 py-3 space-x-2">
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => setOverrideModal({ open: true, branchId: branch.branch_id })}
                >
                  {isOverridden ? 'Edit' : 'Override'}
                </Button>
                
                {isOverridden && (
                  <Button
                    size="sm"
                    variant="ghost"
                    onClick={() => removeBranchOverride(branch.branch_id)}
                  >
                    Remove Override
                  </Button>
                )}
              </td>
            </tr>
          );
        })}
      </tbody>
    </table>
  </div>

  {branchOverrides.length === 0 && (
    <p className="text-center text-gray-500 py-6">
      No branches configured. Add branches in the "Branches" tab.
    </p>
  )}
</SectionCard>
```

---

### 9. Modal: Configure Branch GSTIN Override

```tsx
// Component: BranchGstOverrideModal
function BranchGstOverrideModal({
  open,
  branchId,
  branchName,
  currentGstin,
  onClose,
  onSave,
}: BranchGstOverrideModalProps) {
  const [gstin, setGstin] = useState(currentGstin || '');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  const handleSave = async () => {
    // Validate GSTIN format
    if (!gstin.match(/^\d{2}[A-Z]{5}\d{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$/)) {
      setError('Invalid GSTIN format');
      return;
    }

    setSaving(true);
    setError('');

    try {
      const res = await fetch(
        `${API_URL}/api/v1/gst/registrations`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${token}`,
            'X-Organization-Id': orgId,
          },
          body: JSON.stringify({ branch_id: branchId, branch_gstin: gstin }),
        }
      );

      if (res.ok) {
        onSave();
        onClose();
      } else {
        const json = await res.json();
        setError(json.message || 'Failed to save');
      }
    } finally {
      setSaving(false);
    }
  };

  return (
    <Modal open={open} onClose={onClose} title={`GST Override for ${branchName}`}>
      <div className="space-y-4">
        <div>
          <label className="block text-sm font-medium mb-1">GSTIN</label>
          <Input
            value={gstin}
            onChange={(e) => setGstin(e.target.value.toUpperCase())}
            placeholder="22AABCT1234H1Z0"
            maxLength={15}
          />
          <p className="text-xs text-gray-500 mt-1">Format: 15 alphanumeric characters</p>
        </div>

        {error && (
          <Alert className="bg-red-50 border-red-200">
            <AlertCircle className="text-red-600" />
            <p>{error}</p>
          </Alert>
        )}

        <div className="flex gap-2 justify-end">
          <Button variant="outline" onClick={onClose} disabled={saving}>
            Cancel
          </Button>
          <Button
            onClick={handleSave}
            disabled={saving || !gstin}
            className="bg-blue-600 text-white"
          >
            {saving ? 'Saving...' : 'Save Override'}
          </Button>
        </div>
      </div>
    </Modal>
  );
}
```

---

## BACKEND: API ENDPOINTS & DATA MODEL

### 2. Extend Organization Model (State-Level Tier)

**File:** [backend/app/models/organization.rb](backend/app/models/organization.rb)

```ruby
class Organization < ApplicationRecord
  has_many :branches, dependent: :destroy
  
  # TIER 1: IRP Credentials
  def gst_credentials_configured?
    settings.dig("gst_credentials", "irp_username").present? &&
      settings.dig("gst_credentials", "irp_password").present?
  end
  
  def gst_irp_username
    settings.dig("gst_credentials", "irp_username")
  end
  
  def gst_irp_password
    settings.dig("gst_credentials", "irp_password")
  end
  
  def gst_irp_environment
    settings.dig("gst_credentials", "irp_environment") || "sandbox"
  end
  
  # TIER 2: State-level GSTIN mappings
  def gst_state_registrations
    settings.dig("gst_state_registrations") || {}
  end
  
  def gst_for_state(state_code)
    # Lookup GSTIN for a state
    gst_state_registrations.dig(state_code, "gstin")
  end
  
  def gstin_for_branch(branch)
    # TIER 3 priority: Branch override > State GSTIN > Org GSTIN
    branch.gst_override_gstin || gst_for_state(branch.state_code) || gst_number
  end
end
```

---

### 3. Extend Branch Model (Override Tier)

**File:** [backend/app/models/branch.rb](backend/app/models/branch.rb)

```ruby
class Branch < ApplicationRecord
  belongs_to :organization
  
  # TIER 3: Branch-level override (only if different from state)
  def gst_override_gstin
    settings.dig("gst_override", "branch_gstin")
  end
  
  def effective_gstin
    # Three-tier hierarchy: Branch override > State GSTIN > Org GSTIN
    gst_override_gstin || 
      organization.gst_for_state(state_code) || 
      organization.gst_number
  end
  
  def effective_state_code
    state_code || state&.first(2)
  end
  
  def using_state_gstin?
    # Is this branch using state-level GSTIN (not org default, not override)?
    !gst_override_gstin && organization.gst_for_state(state_code).present? && 
    organization.gst_for_state(state_code) != organization.gst_number
  end
  
  def using_override_gstin?
    gst_override_gstin.present?
  end
end
```

---

### 4. Extend UpdateOrganizationService (State-Level TIER 2)

**File:** [backend/app/services/settings/update_organization_service.rb](backend/app/services/settings/update_organization_service.rb)

```ruby
class Settings::UpdateOrganizationService
  PERMITTED_SETTINGS = %w[
    # ... existing settings ...
    gst_credentials
    gst_state_registrations  # ← NEW: State-level GSTIN map
  ].freeze

  def call
    base_attrs = @params.slice(*PERMITTED_BASE)
    settings_hash = @params[:settings] || {}
    
    # Validate TIER 1: IRP credentials if present
    if settings_hash["gst_credentials"].present?
      validate_gst_credentials!(settings_hash["gst_credentials"])
      settings_hash["gst_credentials"]["configured_at"] = Time.current
      settings_hash["gst_credentials"]["configured_by_id"] = @current_user.id
    end
    
    # Validate TIER 2: State-level GSTIN if present
    if settings_hash["gst_state_registrations"].present?
      validate_gst_state_registrations!(settings_hash["gst_state_registrations"])
      # Add metadata to each state registration
      settings_hash["gst_state_registrations"].each do |state_code, config|
        config["configured_at"] = Time.current
        config["configured_by_id"] = @current_user.id
      end
    end
    
    # Merge with existing settings
    merged_settings = @organization.settings.merge(settings_hash)
    
    if @organization.update(base_attrs.merge(settings: merged_settings))
      Result.new(success?: true, organization: @organization, errors: [])
    else
      Result.new(success?: false, organization: @organization, errors: @organization.errors.full_messages)
    end
  end

  private

  def validate_gst_credentials!(creds)
    required = %w[irp_username irp_password irp_environment]
    missing = required.reject { |field| creds[field].present? }
    raise ValidationError, "Missing fields: #{missing.join(', ')}" if missing.any?
    
    unless %w[sandbox production].include?(creds["irp_environment"])
      raise ValidationError, "Invalid environment"
    end
  end
  
  # NEW: Validate state-level GSTINs
  def validate_gst_state_registrations!(state_regs)
    state_regs.each do |state_code, config|
      gstin = config["gstin"]
      
      # Validate GSTIN format
      unless gstin.match?(/^\d{2}[A-Z]{5}\d{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$/)
        raise ValidationError, "Invalid GSTIN format for state #{state_code}"
      end
      
      # Validate state code matches GSTIN's first 2 digits (GST state code)
      gstin_state = gstin[0..1]
      unless state_code_valid?(gstin_state, state_code)
        raise ValidationError, "GSTIN state code (#{gstin_state}) must match state (#{state_code})"
      end
    end
  end
  
  def state_code_valid?(gstin_state, state_code)
    # Map GST state codes to state abbreviations (simplified)
    true  # In production, use proper mapping table
  end
end
```

---

### 5. Create GstCredentialsController

**File:** `backend/app/controllers/api/v1/gst_credentials_controller.rb`

```ruby
class Api::V1::GstCredentialsController < ApplicationController
  before_action :require_organization!

  # GET /api/v1/gst/credentials (TIER 1)
  def show
    authorize current_organization, :manage_gst_credentials?
    
    creds = current_organization.settings.dig("gst_credentials") || {}
    render_success({
      irp_username: creds["irp_username"],
      irp_environment: creds["irp_environment"] || "sandbox",
      configured: current_organization.gst_credentials_configured?,
      configured_at: creds["configured_at"],
      configured_by_id: creds["configured_by_id"]
    })
  end

  # PATCH /api/v1/gst/credentials (handled via org settings)
  
  # POST /api/v1/gst/credentials/test_connection
  def test_connection
    authorize current_organization, :manage_gst_credentials?
    
    username = params[:irp_username] || current_organization.gst_irp_username
    password = params[:irp_password] || current_organization.gst_irp_password
    environment = params[:irp_environment] || current_organization.gst_irp_environment
    
    unless username.present? && password.present?
      return render_errors(["Credentials not configured"], status: :unprocessable_entity)
    end
    
    result = Gst::TestConnectionService.call(
      organization: current_organization,
      username: username,
      password: password,
      environment: environment
    )
    
    if result.success?
      render_success({ message: result.message, success: true })
    else
      render_errors([result.message], status: :bad_request)
    end
  end
end
```

---

### 6. **NEW** Create BranchGstOverridesController (TIER 3)

**File:** `backend/app/controllers/api/v1/gst_branch_overrides_controller.rb`

```ruby
class Api::V1::GstBranchOverridesController < ApplicationController
  before_action :require_organization!

  # GET /api/v1/gst/branch_overrides
  # Returns all branches with their effective GSTIN and override status
  def index
    authorize Branch, :manage_gst_registrations?
    
    branches = current_organization.branches.active.includes(:organization)
    
    data = branches.map do |branch|
      state_gstin = current_organization.gst_for_state(branch.state_code)
      override_gstin = branch.gst_override_gstin
      
      {
        branch_id: branch.id,
        branch_name: branch.name,
        state_code: branch.state_code,
        state_gstin: state_gstin,
        override_gstin: override_gstin,
        effective_gstin: branch.effective_gstin,
        using_state_gstin: branch.using_state_gstin?,
        using_override_gstin: branch.using_override_gstin?,
        using_org_gstin: !state_gstin && !override_gstin
      }
    end
    
    render_success(data)
  end

  # POST /api/v1/gst/branch_overrides (Configure branch-level override)
  def create
    branch = current_organization.branches.find(params[:branch_id])
    authorize branch, :update_gst_registration?
    
    gstin = params[:branch_gstin]
    
    # Validate GSTIN format
    unless gstin.match?(/^\d{2}[A-Z]{5}\d{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$/)
      return render_errors(["Invalid GSTIN format"], status: :unprocessable_entity)
    end
    
    # Validate state code matches
    gstin_state = gstin[0..1]
    unless state_code_matches?(gstin_state, branch.state_code)
      return render_errors(
        ["GSTIN state code must match branch state"],
        status: :unprocessable_entity
      )
    end
    
    # Update branch settings
    new_settings = branch.settings.merge({
      "gst_override" => {
        "branch_gstin" => gstin,
        "configured_at" => Time.current.iso8601,
        "configured_by_id" => current_user.id
      }
    })
    
    if branch.update(settings: new_settings)
      render_success({ success: true, branch_gstin: gstin })
    else
      render_errors(branch.errors.full_messages)
    end
  end

  # DELETE /api/v1/gst/branch_overrides/:branch_id (Remove override, revert to state/org)
  def destroy
    branch = current_organization.branches.find(params[:id])
    authorize branch, :update_gst_registration?
    
    new_settings = branch.settings.dup
    new_settings.delete("gst_override")
    
    if branch.update(settings: new_settings)
      render_success({ success: true })
    else
      render_errors(branch.errors.full_messages)
    end
  end

  private

  def state_code_matches?(gstin_state, branch_state)
    # Map GST state codes (01-37) to state abbreviations
    # Simplified: assumes state_code is already 2-char code
    true
  end
end
```

---

### 7. Update EinvoiceService to Use Three-Tier Logic

**File:** [backend/app/services/gst/einvoice_service.rb](backend/app/services/gst/einvoice_service.rb)

```ruby
class Gst::EinvoiceService
  def initialize(invoice:, organization: nil)
    @invoice = invoice
    @organization = organization || invoice.organization
  end

  def call
    validate_prerequisites!
    
    @auth_token = fetch_auth_token
    payload = build_einvoice_payload
    
    response = post_to_irp(payload)
    parse_response(response)
  end

  private

  def validate_prerequisites!
    unless @organization.gst_credentials_configured?
      raise GstConfigurationError,
        "GST credentials not configured. Please configure in Settings → GST Credentials"
    end
    
    unless @invoice.issued?
      raise InvalidStateError, "Invoice must be issued before generating e-invoice"
    end
    
    unless @invoice.customer.gstin.present?
      raise ValidationError, "Customer GSTIN is required for e-invoice"
    end
  end

  def build_einvoice_payload
    # Use branch's effective GSTIN (TIER 3: Override > State > Org)
    seller_gstin = @invoice.branch.effective_gstin
    
    {
      TransactionId: @invoice.id,
      UserName: @organization.gst_irp_username,
      InvoiceDetails: [
        {
          InvoiceNumber: @invoice.invoice_number,
          SupplierDetails: { GSTIN: seller_gstin, ... },
          BuyerDetails: { GSTIN: @invoice.customer.gstin, ... },
          ...
        }
      ]
    }
  end

  # Rest unchanged
end
```

---

### 6. Create TestConnectionService

**File:** `backend/app/services/gst/test_connection_service.rb`

```ruby
class Gst::TestConnectionService
  def self.call(organization:, username:, password:, environment:)
    new(organization, username, password, environment).call
  end

  def initialize(organization, username, password, environment)
    @organization = organization
    @username = username
    @password = password
    @environment = environment
  end

  def call
    return error_result("Missing credentials") unless @username.present? && @password.present?

    begin
      # Make test API call to IRP
      token = fetch_auth_token
      return success_result("Connection successful. Credentials are valid.")
    rescue StandardError => e
      return error_result("Connection failed: #{e.message}")
    end
  end

  private

  def fetch_auth_token
    url = irp_base_url + "/token"
    
    response = Net::HTTP.post_form(
      URI(url),
      {
        "username" => @username,
        "password" => @password,
        "client_id" => ENV["GST_CLIENT_ID"],
        "client_secret" => ENV["GST_CLIENT_SECRET"],
        "grant_type" => "password"
      }
    )

    unless response.is_a?(Net::HTTPSuccess)
      raise "IRP API returned #{response.code}: #{response.body}"
    end

    json = JSON.parse(response.body)
    json["access_token"]
  end

  def irp_base_url
    @environment == "production" 
      ? "https://einvoicing.nic.in"
      : "https://einv-apisandbox.nic.in"
  end

  def success_result(message)
    Result.new(success?: true, message: message)
  end

  def error_result(message)
    Result.new(success?: false, message: message)
  end
end
```

---

### 7. Update EinvoiceService to Use DB Credentials

**File:** [backend/app/services/gst/einvoice_service.rb](backend/app/services/gst/einvoice_service.rb)

```ruby
class Gst::EinvoiceService
  def initialize(invoice:, organization: nil)
    @invoice = invoice
    @organization = organization || invoice.organization
  end

  def call
    validate_prerequisites!
    
    @auth_token = fetch_auth_token
    payload = build_einvoice_payload
    
    response = post_to_irp(payload)
    parse_response(response)
  end

  private

  def validate_prerequisites!
    unless @organization.gst_credentials_configured?
      raise GstConfigurationError,
        "GST credentials not configured. Please configure in Settings → GST Credentials"
    end
    
    unless @invoice.issued?
      raise InvalidStateError, "Invoice must be issued before generating e-invoice"
    end
    
    unless @invoice.customer.gstin.present?
      raise ValidationError, "Customer GSTIN is required for e-invoice"
    end
  end

  def fetch_auth_token
    url = irp_base_url + "/token"
    
    response = Net::HTTP.post_form(
      URI(url),
      {
        "username" => @organization.gst_irp_username,
        "password" => @organization.gst_irp_password,
        "client_id" => ENV["GST_CLIENT_ID"],
        "client_secret" => ENV["GST_CLIENT_SECRET"],
        "grant_type" => "password"
      }
    )
    
    json = JSON.parse(response.body)
    json["access_token"]
  end

  def irp_base_url
    @organization.gst_irp_environment == "production"
      ? "https://einvoicing.nic.in"
      : "https://einv-apisandbox.nic.in"
  end

  def build_einvoice_payload
    # Use branch's effective GSTIN (override or org default)
    seller_gstin = @invoice.branch.effective_gstin
    
    {
      TransactionId: @invoice.id,
      UserName: @organization.gst_irp_username,
      SecurityCode: "",
      InvoiceDetails: [
        {
          Irn: "",
          InvoiceNumber: @invoice.invoice_number,
          InvoiceDate: @invoice.invoice_date.strftime("%d/%m/%Y"),
          InvoiceType: "REG",
          InvoiceLineItems: build_line_items,
          DocumentStatus: "NEW",
          Reason: "",
          ReferenceInvoiceReferenceNumber: "",
          ReferenceInvoiceReferenceDate: "",
          PreviousInvoiceReferenceNumber: "",
          PreviousInvoiceReferenceDate: "",
          SupplierDetails: { GSTIN: seller_gstin, LegalName: @invoice.organization.name, ... },
          BuyerDetails: { GSTIN: @invoice.customer.gstin, ... },
          ShippingDetails: { ... },
          ...
        }
      ]
      # ... rest of payload
    }
  end

  # Rest of methods unchanged
end
```

---

### 8. Update Routes

**File:** `backend/config/routes.rb`

```ruby
namespace :api do
  namespace :v1 do
    # Existing routes...
    resources :organizations, only: %i[index create update] do
      member do
        get    :settings
        patch  :settings, action: :update_settings
      end
    end
    
    # NEW: GST Credentials & Registrations (TIER 1, 2, 3)
    namespace :gst do
      # TIER 1: IRP Credentials (org-level)
      resource :credentials, only: [:show] do
        post :test_connection, on: :collection
      end
      
      # TIER 2: State-Level GSTIN Registrations
      resources :registrations, only: [:index, :create, :destroy]
      
      # TIER 3: Branch-Level Overrides
      resources :branch_overrides, only: [:index, :create, :destroy]
    end
  end
end
```

---

### 9. Update Authorization Policies

**File:** `backend/app/policies/organization_policy.rb`

```ruby
class OrganizationPolicy < ApplicationPolicy
  # ... existing code ...
  
  # GST Credentials (TIER 1)
  def manage_gst_credentials?
    admin? || owner?
  end
  
  def view_gst_credentials?
    admin? || owner? || account_manager?
  end
end
```

**File:** `backend/app/policies/branch_policy.rb`

```ruby
class BranchPolicy < ApplicationPolicy
  # ... existing code ...
  
  # GST Registrations (TIER 2)
  def manage_gst_registrations?
    admin? || owner?
  end
  
  # Branch Override (TIER 3)
  def update_gst_registration?
    admin? || owner?
  end
  
  def view_gst_registration?
    admin? || owner? || branch_manager?
  end
end
```

---

### 10. Data Serialization (Response Structure)

**Settings Endpoint Response:**

```json
{
  "data": {
    "id": 42,
    "name": "Sam Distr",
    "gst_number": "22AABCT1234H1Z0",
    "settings": {
      "gst_credentials": {
        "irp_username": "username",
        "irp_password": "••••••••••",
        "irp_environment": "sandbox",
        "configured_at": "2026-04-05T10:30:00Z",
        "configured_by_id": 123
      },
      "order_approval_mode": "manager_approval",
      ...
    }
  }
}
```

**Branch GST Registrations Response:**

```json
{
  "data": [
    {
      "branch_id": 7,
      "branch_name": "BHQua",
      "state_code": "KA",
      "org_gstin": "22AABCT1234H1Z0",
      "branch_gstin": "22AABCT1234H1Z0",
      "is_override": false
    },
    {
      "branch_id": 8,
      "branch_name": "Bannerghatta",
      "state_code": "KA",
      "org_gstin": "22AABCT1234H1Z0",
      "branch_gstin": "29AABCT5678H2Z0",
      "is_override": true
    }
  ]
}
```

---

## DATA FLOW: Complete Journey

```
USER FLOWS THROUGH:

1. Navigate to /settings/organization?tab=gst
   ├─ useOrgBranch provides: token, orgId
   └─ activeTab = "gst"

2. useEffect([activeTab === "gst"]) fires
   ├─ GET /api/v1/organizations/{orgId}/settings
   │  └─ Backend: resolve_organization(X-Org-Id), authorize, return all settings
   ├─ GET /api/v1/gst/registrations
   │  └─ Backend: list branches with their GST configs
   └─ Populate: gstForm, branchGstOverrides

3. User enters IRP credentials
   ├─ setGstForm({ irp_username, irp_password, irp_environment })
   └─ Form state ready

4. User clicks "Test Connection"
   ├─ POST /api/v1/gst/credentials/test_connection
   │  Header: X-Organization-Id: 42
   │  Body: { irp_username, irp_password, irp_environment }
   │
   ├─ Backend: TestConnectionService
   │  ├─ fetch_auth_token (call IRP API with creds)
   │  ├─ If success: return "Connection successful"
   │  └─ If fail: return error message
   │
   └─ Frontend: setTestResult({ success: true/false, message })

5. User saves credentials
   ├─ PATCH /api/v1/organizations/{orgId}/settings
   │  Header: X-Organization-Id: 42
   │  Body: {
   │    settings: {
   │      gst_credentials: {
   │        irp_username,
   │        irp_password,
   │        irp_environment,
   │        configured_at: <set by backend>,
   │        configured_by_id: <current_user.id>
   │      }
   │    }
   │  }
   │
   ├─ Backend: UpdateOrganizationService
   │  ├─ Validate credentials (required fields, environment value)
   │  ├─ Add metadata (configured_at, configured_by_id)
   │  ├─ Merge with existing settings
   │  └─ Update org: UPDATE organizations SET settings = {...}
   │
   └─ Frontend: Show success, refresh gstForm

6. User configures branch-specific GSTIN override
   ├─ Click "Configure" on branch row
   ├─ BranchGstOverrideModal opens
   ├─ User enters GSTIN: "29AABCT5678H2Z0"
   │
   ├─ POST /api/v1/gst/registrations
   │  Header: X-Organization-Id: 42
   │  Body: { branch_id: 8, branch_gstin: "29AABCT5678H2Z0" }
   │
   ├─ Backend: GstRegistrationsController#create
   │  ├─ Find branch in current_organization.branches
   │  ├─ Validate GSTIN format
   │  ├─ Validate GSTIN state code matches branch state
   │  ├─ Update branch.settings[:gst_override]
   │  └─ UPDATE branches SET settings = {...}
   │
   └─ Frontend: Close modal, refresh branchGstOverrides table

7. Invoice generation uses effective GSTIN
   ├─ POST /api/v1/sales_invoices/:id/einvoice
   │
   ├─ Backend: Gst::EinvoiceService.call(invoice)
   │  ├─ Fetch organization.gst_credentials from DB
   │  ├─ Get branch.effective_gstin (override or org default)
   │  ├─ Build payload with seller_gstin = effective_gstin
   │  ├─ Fetch auth token using irp_username + irp_password
   │  ├─ POST to IRP API with payload
   │  └─ Store IRN, QR code in invoice
   │
   └─ Invoice marked as e-invoiced
```

---

## KEY DESIGN DECISIONS

| Decision | Rationale |
|----------|-----------|
| **New Tab "GST Credentials"** | Separates sensitive auth from workflow settings; aligns with existing tab pattern |
| **Organization-Level Credentials** | Single set of IRP credentials shared across org (per-API auth requirement) |
| **Branch-Level GSTIN Overrides** | Each state can have different GSTIN; override in branch.settings JSONB |
| **Test Connection Button** | Validates credentials are correct before saving; prevents failed e-invoice generation |
| **No Migration Needed** | Uses existing `organization.settings` and `branch.settings` JSONB; no schema changes |
| **Encrypted at Rest** | Sensitive fields encrypted by Rails 7 (future enhancement) |
| **Metadata Tracking** | configured_at + configured_by_id for audit trail |
| **Effective_getsin Helper** | Centralized logic: branch override OR org default (used in tax calc + e-invoice) |
| **State Validation** | GSTIN state code must match branch state to prevent mismatches |
| **Separate Endpoints** | /gst/credentials vs /gst/registrations for clear separation of concerns |

---

## VERIFICATION CHECKLIST

**Frontend:**
- ✅ New GST tab appears after Workflow, before Branches
- ✅ Org-level credentials loaded from `organization.settings.gst_credentials`
- ✅ Branch list shows GSTIN source (override or org)
- ✅ Test Connection validates credentials against NIC API
- ✅ Save persists credentials to backend
- ✅ Configure button opens modal for branch GSTIN override
- ✅ Remove button deletes override (reverts to org GSTIN)
- ✅ Success/error messages shown appropriately

**Backend:**
- ✅ GstCredentialsController created with test_connection action
- ✅ GstRegistrationsController created for state GSTIN management
- ✅ GstBranchOverridesController created for branch override management
- ✅ Routes defined at /api/v1/gst namespace
- ✅ Pundit policies enforce role-based access control
- ✅ Organization model methods (gst_irp_*, gst_for_state)
- ✅ Branch model methods (gst_override_gstin, effective_gstin, using_state_gstin?)
- ✅ EinvoiceService updated to use three-tier lookup
- ✅ UpdateOrganizationService validates TIER 1 & 2
- ✅ All responses include configured_at + configured_by_id for audit trail
- ✅ GSTIN format validated (regex)
- ✅ State code in GSTIN matches branch state

**Frontend Integration:**
- ✅ useGstSettings hook created with all mutations
- ✅ GstCredentialsForm calls saveGstCredentials + testConnection
- ✅ StateGstinTable calls saveStateGstin + removeStateGstin
- ✅ BranchOverrideModal calls setBranchOverride + removeBranchOverride
- ✅ Error handling displays validation errors from backend
- ✅ Loading states during API calls
- ✅ Query invalidation refreshes UI after mutations

---

## Frontend API Integration

### 10. React Component Updates - API Calls

**useGstSettings Hook:**

```typescript
// web/lib/hooks/useGstSettings.ts (new)

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api-client";

export const useGstSettings = (organizationId: string) => {
  const queryClient = useQueryClient();

  // FETCH: TIER 1 + TIER 2 (merged in org settings)
  const { data: orgSettings, isLoading: isLoadingOrg } = useQuery({
    queryKey: ["org-settings", organizationId],
    queryFn: () => api.get(`/organizations/${organizationId}/settings`),
  });

  // FETCH: TIER 3 (branch overrides)
  const { data: branchOverrides, isLoading: isLoadingOverrides } = useQuery({
    queryKey: ["gst-branch-overrides", organizationId],
    queryFn: () => api.get("/gst/branch_overrides"),
  });

  // MUTATION: Save TIER 1 (IRP Credentials)
  const saveGstCredentials = useMutation({
    mutationFn: (credentials) =>
      api.patch(`/organizations/${organizationId}/settings`, {
        settings: { gst_credentials: credentials },
      }),
    onSuccess: () => {
      queryClient.invalidateQueries(["org-settings", organizationId]);
    },
  });

  // MUTATION: Save TIER 2 (State-Level GSTIN)
  const saveStateGstin = useMutation({
    mutationFn: ({ stateCode, gstin }) =>
      api.post("/gst/registrations", { state_code: stateCode, gstin }),
    onSuccess: () => {
      queryClient.invalidateQueries(["org-settings", organizationId]);
    },
  });

  // MUTATION: Remove TIER 2 State GSTIN
  const removeStateGstin = useMutation({
    mutationFn: (stateCode) =>
      api.delete(`/gst/registrations/${stateCode}`),
    onSuccess: () => {
      queryClient.invalidateQueries(["org-settings", organizationId]);
    },
  });

  // MUTATION: Set TIER 3 Branch Override
  const setBranchOverride = useMutation({
    mutationFn: ({ branchId, gstin }) =>
      api.post("/gst/branch_overrides", {
        branch_id: branchId,
        branch_gstin: gstin,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries(["gst-branch-overrides", organizationId]);
    },
  });

  // MUTATION: Remove TIER 3 Branch Override
  const removeBranchOverride = useMutation({
    mutationFn: (branchId) =>
      api.delete(`/gst/branch_overrides/${branchId}`),
    onSuccess: () => {
      queryClient.invalidateQueries(["gst-branch-overrides", organizationId]);
    },
  });

  // MUTATION: Test Connection (TIER 1)
  const testConnection = useMutation({
    mutationFn: (credentials) =>
      api.post("/gst/credentials/test_connection", credentials),
  });

  return {
    orgSettings,
    branchOverrides,
    isLoading: isLoadingOrg || isLoadingOverrides,
    saveGstCredentials,
    saveStateGstin,
    removeStateGstin,
    setBranchOverride,
    removeBranchOverride,
    testConnection,
  };
};
```

---

## API Response Contracts

### 11. Response Serialization Format

**TIER 1: GST Credentials (Org-level)**

`GET /api/v1/gst/credentials` Response:
```json
{
  "data": {
    "irp_username": "ORG001IRP",
    "irp_environment": "sandbox",
    "configured": true,
    "configured_at": "2026-03-17T10:30:00Z",
    "configured_by_id": 5
  }
}
```

**TIER 2: State-Level GSTIN Registrations**

`GET /api/v1/gst/registrations` Response:
```json
{
  "data": {
    "KA": {
      "gstin": "29AABCT1234H1Z2",
      "branch_count": 2,
      "configured_at": "2026-03-15T14:22:00Z",
      "configured_by_id": 5,
      "branches": ["BHQua", "Bannerghatta"]
    },
    "MH": {
      "gstin": "27BBBDU5678H2Z3",
      "branch_count": 1,
      "configured_at": "2026-03-10T09:15:00Z",
      "configured_by_id": 5,
      "branches": ["Mumbai"]
    }
  }
}
```

**TIER 3: Branch-Level Overrides**

`GET /api/v1/gst/branch_overrides` Response:
```json
{
  "data": [
    {
      "branch_id": 1,
      "branch_name": "BHQua",
      "state_code": "KA",
      "state_gstin": "29AABCT1234H1Z2",
      "override_gstin": null,
      "effective_gstin": "29AABCT1234H1Z2",
      "using_state_gstin": true,
      "using_override_gstin": false,
      "using_org_gstin": false
    },
    {
      "branch_id": 2,
      "branch_name": "Bannerghatta",
      "state_code": "KA",
      "state_gstin": "29AABCT1234H1Z2",
      "override_gstin": null,
      "effective_gstin": "29AABCT1234H1Z2",
      "using_state_gstin": true,
      "using_override_gstin": false,
      "using_org_gstin": false
    },
    {
      "branch_id": 3,
      "branch_name": "Mumbai",
      "state_code": "MH",
      "state_gstin": "27BBBDU5678H2Z3",
      "override_gstin": null,
      "effective_gstin": "27BBBDU5678H2Z3",
      "using_state_gstin": true,
      "using_override_gstin": false,
      "using_org_gstin": false
    },
    {
      "branch_id": 4,
      "branch_name": "Delhi-Outlet",
      "state_code": "DL",
      "state_gstin": null,
      "override_gstin": "07CCCCF0000H1Z0",
      "effective_gstin": "07CCCCF0000H1Z0",
      "using_state_gstin": false,
      "using_override_gstin": true,
      "using_org_gstin": false
    }
  ]
}
```

**Test Connection Response:**

`POST /api/v1/gst/credentials/test_connection` (Success):
```json
{
  "data": {
    "message": "Connection successful. Credentials validated.",
    "success": true
  }
}
```

`POST /api/v1/gst/credentials/test_connection` (Failure):
```json
{
  "errors": ["Invalid credentials. Please verify username and password."],
  "status": 400
}
```

---

## Data Flow Diagram (Three-Tier Hierarchy Without Duplication)

```
For Invoice issued by Branch "BHQua" (state: KA):

Step 1: Resolve GSTIN for Branch
   ├─ Check TIER 3: Branch Override? NO (not configured)
   ├─ Check TIER 2: State-Level GSTIN for KA? YES (29AABCT1234H1Z2)
   └─ Use: 29AABCT1234H1Z2 (shared by BHQua + Bannerghatta)

For Invoice issued by Branch "Bannerghatta" (state: KA):

Step 1: Resolve GSTIN for Branch
   ├─ Check TIER 3: Branch Override? NO (not configured)
   ├─ Check TIER 2: State-Level GSTIN for KA? YES (29AABCT1234H1Z2)
   └─ Use: 29AABCT1234H1Z2 (SAME as BHQua - NO DUPLICATION!)

For Invoice issued by Branch "Delhi-Outlet" (state: DL):

Step 1: Resolve GSTIN for Branch
   ├─ Check TIER 3: Branch Override? YES (07CCCCF0000H1Z0)
   └─ Use: 07CCCCF0000H1Z0 (exception - specific to this branch)
```

**Example Scenarios:**

| Scenario | Branch | State | Config | Lookup Result | GSTIN Used | Tier |
|----------|--------|-------|--------|---------------|-----------|------|
| Multi-branch same state | BHQua | KA | None | ST KA found → use it | 29AABCT1...Z2 | **TIER 2** ✓ |
| Multi-branch same state | Bannerghatta | KA | None | ST KA found → use it | 29AABCT1...Z2 | **TIER 2** ✓ |
| Branch with override | Delhi | DL | Override set | Override found → use it | 07CCCCF0...Z0 | **TIER 3** ✓ |
| Fallback (no state ST) | Unknown | XX | None | No ST, use org default | org_gstin | **TIER 1** |

**Key Benefit:** BHQua and Bannerghatta in KA both use the same state-level GSTIN automatically. No need to configure GSTIN twice for same state. ✅ No Duplication!

---

## IMPLEMENTATION PRIORITY & DEPENDENCIES

### Phase 1: Backend Foundation (No Frontend Changes)
1. **Organization Model** - Add methods for TIER 1 & 2 access ✅ *Designed*
2. **Branch Model** - Add methods for TIER 3 access & three-tier lookup ✅ *Designed*
3. **UpdateOrganizationService** - Add TIER 1 & 2 validation ✅ *Designed*
4. **Controllers** - GstCredentialsController, GstRegistrationsController, GstBranchOverridesController ✅ *Designed*
5. **Routes** - Add /api/v1/gst namespace ✅ *Designed*
6. **Policies** - Add Pundit authorization ✅ *Designed*

**Deliverable:** Backend API ready to serve credentials and branch data

### Phase 2: Frontend Integration
1. **useGstSettings Hook** - React Query wrapper for all API calls ✅ *Designed*
2. **Settings Page** - New GST tab with three sections
3. **GstCredentialsForm** - TIER 1 (Test Connection + Save)
4. **StateGstinTable** - TIER 2 (State GSTIN + branch count)
5. **BranchOverrideModal** - TIER 3 (Branch exceptions)
6. **UI Components** - Modal, Badge, Alert, Loading states

**Deliverable:** Full UI for GST credential management

### Phase 3: Integration
1. **EinvoiceService** - Use `branch.effective_gstin()` instead of hardcoded org GSTIN
2. **TaxCalculationService** - Use three-tier lookup for tax computation
3. **End-to-End Tests** - Verify e-invoice generation with correct GSTIN

**Deliverable:** E-invoice uses correct branch-specific GSTIN automatically

---

## FINAL VALIDATION: No Duplication ✅

**Scenario:** Organization with 10 branches across 3 states
- Karnataka: BHQua, Bannerghatta, Whitefield (3 branches)
- Maharashtra: Mumbai, Pune (2 branches)
- Delhi: Delhi-HQ, Delhi-Outlet, Delhi-Branch (3 branches)

### OLD PLAN (With Duplication) ❌
```
Would need to configure GSTIN for EACH branch:
- BHQua GSTIN
- Bannerghatta GSTIN  
- Whitefield GSTIN
- Mumbai GSTIN
- Pune GSTIN
- Delhi-HQ GSTIN
- Delhi-Outlet GSTIN
- Delhi-Branch GSTIN
→ 8 separate GSTIN configurations
```

### NEW PLAN (Three-Tier, No Duplication) ✅
```
Org-Level (TIER 1):
  IRP Credentials (1 set, shared by all)

State-Level (TIER 2):
  KA → 29AABCT1234H1Z2 (shared by BHQua + Bannerghatta + Whitefield)
  MH → 27BBBDU5678H2Z3 (shared by Mumbai + Pune)
  DL → 07CCCCF0000H1Z0 (shared by Delhi-HQ + Delhi-Outlet + Delhi-Branch)

Branch-Level (TIER 3):
  (None - all branches use state GSTIN automatically)

→ 3 state GSTIN configurations + automatic inheritance
→ 100% Reduction in Configuration Duplication!
```

**Result:** 
- ✅ BHQua uses KA state GSTIN automatically
- ✅ Bannerghatta uses KA state GSTIN automatically
- ✅ Whitefield uses KA state GSTIN automatically
- ✅ NO duplicate config needed for same state
- ✅ Branches inherit state GSTIN without manual assignment
- ✅ Exception override available if a branch needs different GSTIN

---

## DELIVERY SUMMARY

This plan implements a **three-tier GST credential hierarchy** that eliminates duplication:

1. **TIER 1 (Org-Level):** IRP API credentials - single set shared by entire organization
2. **TIER 2 (State-Level):** GSTIN per state - all branches in that state inherit automatically
3. **TIER 3 (Branch-Level):** Optional override - only for branches that need exception from state

**Key Improvements:**
- ✅ No redundant GSTIN configuration for multi-branch states
- ✅ Automatic inheritance prevents configuration errors
- ✅ Centralized lookup logic in model methods
- ✅ Audit trail with configured_at + configured_by_id
- ✅ Backward compatible (no schema migrations)
- ✅ Role-based access control via Pundit
- ✅ Test connection validates credentials before saving
- ✅ Clean API contracts with proper response serialization

**Files to Create/Modify:**

Backend:
- `app/models/organization.rb` (add TIER 1 & 2 methods)
- `app/models/branch.rb` (add TIER 3 methods)
- `app/services/settings/update_organization_service.rb` (add validation)
- `app/services/gst/einvoice_service.rb` (use three-tier lookup)
- `app/controllers/api/v1/gst_credentials_controller.rb` (NEW)
- `app/controllers/api/v1/gst_registrations_controller.rb` (NEW)
- `app/controllers/api/v1/gst_branch_overrides_controller.rb` (NEW)
- `config/routes.rb` (add /api/v1/gst namespace)
- `app/policies/organization_policy.rb` (add GST policies)
- `app/policies/branch_policy.rb` (add GST policies)

Frontend:
- `web/lib/hooks/useGstSettings.ts` (NEW - React Query integration)
- `web/app/settings/organization/page.tsx` (update with GST tab)
- `web/components/credentials/GstCredentialsForm.tsx` (NEW)
- `web/components/credentials/StateGstinTable.tsx` (NEW)
- `web/components/credentials/BranchOverrideModal.tsx` (NEW)

---
- ✅ UpdateOrganizationService merges gst_credentials into settings
- ✅ GstCredentialsController#test_connection validates auth
- ✅ GstRegistrationsController CRUD works for branch overrides
- ✅ Branch.effective_gstin returns override OR org GSTIN
- ✅ EinvoiceService uses branch.effective_gstin in payload
- ✅ Authorization policies enforce owner/admin only
- ✅ Routes properly namespaced under /gst

---

## SUMMARY

This plan integrates seamlessly with your existing settings architecture while handling the state-based GSTIN variations correctly. The implementation:

✅ Reuses existing organization.settings JSONB pattern
✅ No database migrations needed
✅ Branch-level GSTIN overrides with state validation
✅ Test connection before saving credentials
✅ Audit trail (configured_at, configured_by_id)
✅ Centralized effective_gstin logic for tax calc + e-invoice
✅ Clear separation: org creds vs branch registrations
✅ Policy-based authorization
✅ Multi-org safe (X-Organization-Id scoping)
