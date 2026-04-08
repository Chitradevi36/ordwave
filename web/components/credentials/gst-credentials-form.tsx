import { useState, useEffect } from "react";
import { useGstSettings } from "@/lib/hooks/useGstSettings";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Alert } from "@/components/ui/alert";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

export function GstCredentialsForm() {
  const { gstCredentials, saveGstCredentials, testConnection, isLoading } = useGstSettings();

  const [formData, setFormData] = useState({
    irp_username: "",
    irp_password: "",
    irp_environment: "sandbox",
  });

  const [testingConnection, setTestingConnection] = useState(false);
  const [testMessage, setTestMessage] = useState<{ type: "success" | "danger"; text: string } | null>(null);
  const [saveMessage, setSaveMessage] = useState<{ type: "success" | "danger"; text: string } | null>(null);

  // Initialize form data when gstCredentials loads
  useEffect(() => {
    if (gstCredentials && !isLoading) {
      setFormData({
        irp_username: gstCredentials.irp_username || "",
        irp_password: "", // Don't pre-fill password for security
        irp_environment: gstCredentials.irp_environment || "sandbox",
      });
    }
  }, [gstCredentials, isLoading]);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
  };

  const handleEnvironmentChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    setFormData((prev) => ({ ...prev, irp_environment: e.target.value }));
  };

  const handleTestConnection = async () => {
    if (!formData.irp_username || !formData.irp_password) {
      setTestMessage({ type: "danger", text: "Please enter both username and password to test connection" });
      return;
    }

    setTestingConnection(true);
    setTestMessage(null);

    try {
      await testConnection.mutateAsync(formData);
      setTestMessage({ type: "success", text: "✓ Connection test successful!" });
    } catch (error: any) {
      setTestMessage({ type: "danger", text: `✗ ${error.message}` });
    } finally {
      setTestingConnection(false);
    }
  };

  const handleSave = async () => {
    if (!formData.irp_username || !formData.irp_password) {
      setSaveMessage({ type: "danger", text: "Please enter both username and password" });
      return;
    }

    try {
      await saveGstCredentials.mutateAsync(formData);
      setSaveMessage({ type: "success", text: "✓ Credentials saved successfully!" });
      // Clear password field after save for security
      setFormData((prev) => ({ ...prev, irp_password: "" }));
    } catch (error: any) {
      setSaveMessage({ type: "danger", text: `✗ ${error.message}` });
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-sm font-semibold">E-Invoice (IRP) Credentials</CardTitle>
        <p className="text-xs text-text-secondary mt-0.5">
          Organization-level credentials for GST e-invoice generation
          {gstCredentials?.configured_at && (
            <span className="block mt-1">
              Last configured: {new Date(gstCredentials.configured_at).toLocaleDateString()}
            </span>
          )}
        </p>
      </CardHeader>
      <CardContent className="space-y-4">
        {testMessage && (
          <Alert variant={testMessage.type}>
            {testMessage.text}
          </Alert>
        )}

        {saveMessage && (
          <Alert variant={saveMessage.type}>
            {saveMessage.text}
          </Alert>
        )}

        <div className="space-y-3">
          <Input
            label="IRP Username"
            name="irp_username"
            value={formData.irp_username}
            onChange={handleChange}
            placeholder="Enter your IRP username"
            disabled={isLoading}
          />

          <Input
            type="password"
            label="IRP Password"
            name="irp_password"
            value={formData.irp_password}
            onChange={handleChange}
            placeholder="Enter your IRP password"
            disabled={isLoading}
          />

          <div>
            <label className="block text-sm font-medium text-text-primary mb-1.5">Environment</label>
            <select
              value={formData.irp_environment}
              onChange={handleEnvironmentChange}
              disabled={isLoading}
              className="w-full rounded-md border border-border bg-background px-3 py-2 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent disabled:cursor-not-allowed disabled:opacity-50"
            >
              <option value="sandbox">Sandbox (Development)</option>
              <option value="production">Production</option>
            </select>
          </div>
        </div>

        <div className="flex gap-2 pt-2">
          <Button
            variant="outline"
            onClick={handleTestConnection}
            disabled={!formData.irp_username || !formData.irp_password || testingConnection || isLoading}
            isLoading={testingConnection}
          >
            Test Connection
          </Button>
          <Button
            onClick={handleSave}
            disabled={!formData.irp_username || !formData.irp_password || isLoading || saveGstCredentials.isPending}
            isLoading={saveGstCredentials.isPending}
          >
            Save Credentials
          </Button>
        </div>

        {gstCredentials?.configured && (
          <div className="mt-2 p-2 bg-blue-50 rounded text-xs text-blue-900">
            ✓ Credentials are configured and active
          </div>
        )}
      </CardContent>
    </Card>
  );
}
