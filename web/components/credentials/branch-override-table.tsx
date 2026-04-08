import { useState } from "react";
import { useGstSettings } from "@/lib/hooks/useGstSettings";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Alert } from "@/components/ui/alert";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Modal } from "@/components/ui/modal";

export function BranchOverrideTable() {
  const { branchOverrides, setBranchOverride, removeBranchOverride } = useGstSettings();
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [selectedBranch, setSelectedBranch] = useState<any | null>(null);
  const [gstin, setGstin] = useState("");
  const [error, setError] = useState<string | null>(null);

  const handleConfigureClick = (branch: any) => {
    setSelectedBranch(branch);
    setGstin(branch.override_gstin || "");
    setError(null);
    setIsModalOpen(true);
  };

  const handleSave = async () => {
    if (!gstin) {
      setError("Please enter a GSTIN");
      return;
    }

    try {
      await setBranchOverride.mutateAsync({
        branchId: selectedBranch.branch_id,
        gstin,
      });
      setIsModalOpen(false);
      setError(null);
    } catch (err: any) {
      setError(err.message);
    }
  };

  const handleRemoveOverride = async (branch: any) => {
    if (!confirm(`Remove GSTIN override for ${branch.branch_name}?`)) {
      return;
    }

    try {
      await removeBranchOverride.mutateAsync(branch.branch_id);
    } catch (err: any) {
      setError(err.message);
    }
  };

  const getGstinSource = (branch: any) => {
    if (branch.using_override_gstin) {
      return <Badge variant="danger">Branch Override</Badge>;
    } else if (branch.using_state_gstin) {
      return <Badge variant="secondary">State: {branch.state_code}</Badge>;
    } else {
      return <Badge variant="outline">Organization</Badge>;
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle>Branch GSTIN Configuration</CardTitle>
        <p className="text-sm text-text-secondary mt-1">
          View and configure GSTIN for individual branches. Branches use state-level GSTIN by default.
        </p>
      </CardHeader>
      <CardContent className="space-y-4">
        {error && <Alert variant="danger">{error}</Alert>}

        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border">
                <th className="text-left px-3 py-2 font-medium text-text-secondary">Branch</th>
                <th className="text-left px-3 py-2 font-medium text-text-secondary">State</th>
                <th className="text-left px-3 py-2 font-medium text-text-secondary">Effective GSTIN</th>
                <th className="text-left px-3 py-2 font-medium text-text-secondary">Source</th>
                <th className="text-left px-3 py-2 font-medium text-text-secondary">Actions</th>
              </tr>
            </thead>
            <tbody>
              {branchOverrides.map((branch: any) => (
                <tr key={branch.branch_id} className="border-b border-border hover:bg-background-subtle">
                  <td className="px-3 py-2 font-medium">{branch.branch_name}</td>
                  <td className="px-3 py-2">{branch.state_code}</td>
                  <td className="px-3 py-2 font-mono text-xs">{branch.effective_gstin}</td>
                  <td className="px-3 py-2">{getGstinSource(branch)}</td>
                  <td className="px-3 py-2 space-x-2">
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => handleConfigureClick(branch)}
                    >
                      {branch.override_gstin ? "Edit Override" : "Set Override"}
                    </Button>
                    {branch.override_gstin && (
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => handleRemoveOverride(branch)}
                      >
                        Remove
                      </Button>
                    )}
                  </td>
                </tr>
              ))}
              {branchOverrides.length === 0 && (
                <tr>
                  <td colSpan={5} className="text-center text-text-secondary py-8">
                    No branches configured yet
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>

        <Modal open={isModalOpen} onClose={() => setIsModalOpen(false)} title="Configure Branch GSTIN Override">
          <div className="space-y-4">
            <p className="text-sm text-text-secondary">
              Set a branch-specific GSTIN override. Leave empty to use state-level GSTIN.
            </p>
            <div>
              <label className="text-sm font-medium">Branch</label>
              <Input
                disabled
                value={selectedBranch?.branch_name || ""}
                className="mt-1"
              />
            </div>

            <div>
              <label className="text-sm font-medium">GSTIN Override</label>
              <Input
                value={gstin}
                onChange={(e) => setGstin(e.target.value.toUpperCase())}
                placeholder="Leave empty to use state-level GSTIN"
                className="mt-1 font-mono"
              />
            </div>

            <div className="bg-blue-50 p-3 rounded text-sm">
              <p className="font-medium mb-1">Current GSTIN: {selectedBranch?.effective_gstin}</p>
              <p className="text-text-secondary">
                {selectedBranch?.using_state_gstin 
                  ? "Currently using state-level GSTIN"
                  : selectedBranch?.using_override_gstin
                  ? "Currently using branch override"
                  : "Currently using organization GSTIN"}
              </p>
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
                disabled={!gstin}
                isLoading={setBranchOverride.isPending}
              >
                Save Override
              </Button>
            </div>
          </div>
        </Modal>
      </CardContent>
    </Card>
  );
}
