import { useState } from "react";
import { useGstSettings } from "@/lib/hooks/useGstSettings";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Alert } from "@/components/ui/alert";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Modal } from "@/components/ui/modal";

const STATE_CODES = {
  "AN": "Andaman and Nicobar",
  "AP": "Andhra Pradesh",
  "AR": "Arunachal Pradesh",
  "AS": "Assam",
  "BR": "Bihar",
  "CG": "Chhattisgarh",
  "CH": "Chandigarh",
  "CT": "Chhattisgarh",
  "DL": "Delhi",
  "DN": "Dadra and Nagar Haveli",
  "GA": "Goa",
  "GJ": "Gujarat",
  "HR": "Haryana",
  "HP": "Himachal Pradesh",
  "JK": "Jammu and Kashmir",
  "JH": "Jharkhand",
  "KA": "Karnataka",
  "KL": "Kerala",
  "LA": "Ladakh",
  "LD": "Lakshadweep",
  "MP": "Madhya Pradesh",
  "MH": "Maharashtra",
  "MN": "Manipur",
  "ML": "Meghalaya",
  "MZ": "Mizoram",
  "OD": "Odisha",
  "PD": "Puducherry",
  "PB": "Punjab",
  "RJ": "Rajasthan",
  "SK": "Sikkim",
  "TN": "Tamil Nadu",
  "TR": "Telangana",
  "TS": "Tripura",
  "UK": "Uttarakhand",
  "UP": "Uttar Pradesh",
  "UT": "Uttar Pradesh",
  "WB": "West Bengal",
};

export function StateGstinTable() {
  const { stateRegistrations, saveStateGstin, removeStateGstin } = useGstSettings();
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [selectedState, setSelectedState] = useState<string | null>(null);
  const [gstin, setGstin] = useState("");
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);

  const handleAddClick = () => {
    setSelectedState(null);
    setGstin("");
    setUsername("");
    setPassword("");
    setError(null);
    setIsModalOpen(true);
  };

  const handleEditClick = (stateCode: string) => {
    setSelectedState(stateCode);
    setGstin(stateRegistrations[stateCode]?.gstin || "");
    setUsername(stateRegistrations[stateCode]?.username || "");
    setPassword(""); // Don't pre-fill password for security
    setError(null);
    setIsModalOpen(true);
  };

  const handleSave = async () => {
    if (!selectedState || !gstin || !username) {
      setError("Please fill in required fields");
      return;
    }

    // Password is required for new entries, optional for edits
    const isNewEntry = !stateRegistrations[selectedState];
    if (isNewEntry && !password) {
      setError("Password is required for new state registrations");
      return;
    }

    try {
      await saveStateGstin.mutateAsync({
        stateCode: selectedState,
        gstin,
        username,
        password,
      });
      setIsModalOpen(false);
      setError(null);
    } catch (err: any) {
      setError(err.message);
    }
  };

  const handleDelete = async (stateCode: string) => {
    if (!confirm(`Remove GSTIN for ${STATE_CODES[stateCode as keyof typeof STATE_CODES]}?`)) {
      return;
    }

    try {
      await removeStateGstin.mutateAsync(stateCode);
    } catch (err: any) {
      setError(err.message);
    }
  };

  const states = Object.keys(STATE_CODES) as Array<keyof typeof STATE_CODES>;

  return (
    <Card>
      <CardHeader>
        <CardTitle>State-Level GSTIN Registration</CardTitle>
        <p className="text-sm text-text-secondary mt-1">
          Configure GSTIN per state. All branches in a state automatically use the configured GSTIN.
        </p>
      </CardHeader>
      <CardContent className="space-y-4">
        {error && <Alert variant="danger">{error}</Alert>}

        <Button onClick={handleAddClick}>Add State GSTIN</Button>

        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border">
                <th className="text-left px-3 py-2 font-medium text-text-secondary">State</th>
                <th className="text-left px-3 py-2 font-medium text-text-secondary">GSTIN</th>
                <th className="text-left px-3 py-2 font-medium text-text-secondary">Branches</th>
                <th className="text-left px-3 py-2 font-medium text-text-secondary">Configured</th>
                <th className="text-left px-3 py-2 font-medium text-text-secondary">Actions</th>
              </tr>
            </thead>
            <tbody>
              {Object.entries(stateRegistrations).map(([stateCode, reg]: [string, any]) => (
                <tr key={stateCode} className="border-b border-border hover:bg-background-subtle">
                  <td className="px-3 py-2">{STATE_CODES[stateCode as keyof typeof STATE_CODES] || stateCode}</td>
                  <td className="px-3 py-2 font-mono text-xs">{reg.gstin}</td>
                  <td className="px-3 py-2">{reg.branch_count} branch(es)</td>
                  <td className="px-3 py-2 text-text-secondary">
                    {new Date(reg.configured_at).toLocaleDateString()}
                  </td>
                  <td className="px-3 py-2 space-x-2">
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => handleEditClick(stateCode)}
                    >
                      Edit
                    </Button>
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => handleDelete(stateCode)}
                    >
                      Delete
                    </Button>
                  </td>
                </tr>
              ))}
              {Object.keys(stateRegistrations).length === 0 && (
                <tr>
                  <td colSpan={5} className="text-center text-text-secondary py-8">
                    No state GSTINs configured yet
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>

        <Modal open={isModalOpen} onClose={() => setIsModalOpen(false)} title={selectedState ? "Edit State GSTIN" : "Add State GSTIN"}>
          <div className="space-y-4">
            <p className="text-sm text-text-secondary">
              Configure GSTIN and credentials for a state. All branches in this state will automatically use this GSTIN.
            </p>

            {!selectedState && (
              <div>
                <label className="text-sm font-medium">State</label>
                <select
                  value={selectedState || ""}
                  onChange={(e) => setSelectedState(e.target.value)}
                  className="w-full mt-1 px-3 py-2 border rounded-md"
                >
                  <option value="">Select a state</option>
                  {states.map((state) => (
                    <option key={state} value={state}>
                      {STATE_CODES[state]} ({state})
                    </option>
                  ))}
                </select>
              </div>
            )}

            {selectedState && (
              <div>
                <label className="text-sm font-medium">State</label>
                <Input
                  disabled
                  value={`${STATE_CODES[selectedState as keyof typeof STATE_CODES]} (${selectedState})`}
                  className="mt-1"
                />
              </div>
            )}

            <div>
              <label className="text-sm font-medium">GSTIN</label>
              <Input
                value={gstin}
                onChange={(e) => setGstin(e.target.value.toUpperCase())}
                placeholder="29AABCT1234H1Z2"
                className="mt-1 font-mono"
              />
            </div>

            <div>
              <label className="text-sm font-medium">State GST Username</label>
              <Input
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                placeholder="State GST portal username"
                className="mt-1"
              />
            </div>

            <div>
              <label className="text-sm font-medium">State GST Password</label>
              <Input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder={selectedState && stateRegistrations[selectedState] ? "Enter new password to update" : "State GST portal password"}
                className="mt-1"
              />
              {selectedState && stateRegistrations[selectedState] && (
                <p className="text-xs text-text-secondary mt-1">
                  Leave blank to keep existing password
                </p>
              )}
            </div>

            {error && (
              <Alert variant="danger">{error}</Alert>
            )}

            <div className="flex gap-2 justify-end">
              <Button variant="outline" onClick={() => setIsModalOpen(false)}>
                Cancel
              </Button>
              <Button 
                onClick={handleSave} 
                disabled={!!(!selectedState || !gstin || !username || (selectedState && !stateRegistrations[selectedState] && !password))}
              >
                Save
              </Button>
            </div>
          </div>
        </Modal>
      </CardContent>
    </Card>
  );
}
