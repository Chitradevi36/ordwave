"use client";

import { useState, useEffect } from "react";
import { Modal } from "@/components/ui/modal";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Loader2, GitBranch, CheckCircle2 } from "lucide-react";
import { usePincodeLookup } from "@/lib/use-pincode-lookup";
import { useOrgBranch } from "@/lib/org-branch-context";

interface Props {
  open: boolean;
  onClose: () => void;
  onCreated: () => void;
}

interface Form {
  name: string;
  code: string;
  pincode: string;
  address: string;
  city: string;
  state: string;
}

const BLANK: Form = { name: "", code: "", pincode: "", address: "", city: "", state: "" };

function suggestCode(name: string): string {
  const words = name.trim().toUpperCase().split(/\s+/).filter(Boolean);
  if (!words.length) return "";
  const prefix = words.length === 1
    ? words[0].slice(0, 4)
    : words.map((w) => w[0]).join("").slice(0, 4);
  return `${prefix}-01`;
}

export function AddBranchModal({ open, onClose, onCreated }: Props) {
  const { token, orgId } = useOrgBranch();
  const [form, setForm]       = useState<Form>(BLANK);
  const [saving, setSaving]   = useState(false);
  const [error, setError]     = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  const { city: pcCity, state: pcState, loading: pincodeLoading } =
    usePincodeLookup(form.pincode);

  // Auto-fill city & state from pincode
  useEffect(() => {
    if (pcCity) setForm((f) => ({ ...f, city: pcCity }));
    if (pcState) setForm((f) => ({ ...f, state: pcState }));
  }, [pcCity, pcState]);

  // Reset on open
  useEffect(() => {
    if (open) { setForm(BLANK); setError(null); setSuccess(false); }
  }, [open]);

  const set = (key: keyof Form, value: string) => setForm((f) => ({ ...f, [key]: value }));

  const handleNameChange = (val: string) => {
    setForm((f) => ({
      ...f,
      name: val,
      code: f.code === "" || f.code === suggestCode(f.name) ? suggestCode(val) : f.code,
    }));
  };

  const handleSubmit = async () => {
    if (!form.name.trim() || !form.code.trim()) {
      setError("Branch name and code are required.");
      return;
    }
    setSaving(true);
    setError(null);
    try {
      const res = await fetch("http://localhost:3001/api/v1/branches", {
        method: "POST",
        headers: {
          "Content-Type":      "application/json",
          Authorization:       `Bearer ${token}`,
          "X-Organization-Id": orgId,
        },
        body: JSON.stringify({
          branch: {
            name:    form.name.trim(),
            code:    form.code.trim().toUpperCase(),
            pincode: form.pincode,
            address: form.address,
            city:    form.city,
            state:   form.state,
          },
        }),
      });
      const json = await res.json();
      if (res.ok) {
        setSuccess(true);
        setTimeout(() => { onCreated(); onClose(); }, 1500);
      } else {
        setError((json.errors ?? []).join(", ") || "Failed to create branch.");
      }
    } catch {
      setError("Network error. Please try again.");
    } finally {
      setSaving(false);
    }
  };

  return (
    <Modal open={open} onClose={onClose} title="Add New Branch" size="md">
      {success ? (
        <div className="flex flex-col items-center gap-3 py-8">
          <div className="flex h-12 w-12 items-center justify-center rounded-full bg-accent/15">
            <CheckCircle2 className="h-6 w-6 text-accent" />
          </div>
          <p className="text-sm font-medium text-text-primary">Branch created!</p>
          <p className="text-xs text-text-secondary">
            <span className="font-medium">{form.name}</span> has been added to your organization.
          </p>
        </div>
      ) : (
        <div className="space-y-4">
          {/* Name + Code */}
          <div className="grid grid-cols-2 gap-3">
            <Input
              label="Branch Name *"
              placeholder="Mumbai North"
              value={form.name}
              onChange={(e) => handleNameChange(e.target.value)}
            />
            <Input
              label="Branch Code *"
              placeholder="MBNO-01"
              value={form.code}
              onChange={(e) => set("code", e.target.value.toUpperCase())}
            />
          </div>

          {/* Pincode with spinner */}
          <div className="relative">
            <Input
              label="PIN Code"
              placeholder="400001"
              maxLength={6}
              value={form.pincode}
              onChange={(e) => set("pincode", e.target.value.replace(/\D/g, ""))}
            />
            {pincodeLoading && (
              <Loader2 className="absolute right-3 top-7 h-4 w-4 animate-spin text-text-secondary" />
            )}
          </div>

          {/* Address */}
          <Input
            label="Address"
            placeholder="123 MG Road"
            value={form.address}
            onChange={(e) => set("address", e.target.value)}
          />

          {/* City + State */}
          <div className="grid grid-cols-2 gap-3">
            <Input
              label="City"
              placeholder="Auto-filled from PIN"
              value={form.city}
              onChange={(e) => set("city", e.target.value)}
            />
            <Input
              label="State"
              placeholder="Auto-filled from PIN"
              value={form.state}
              onChange={(e) => set("state", e.target.value)}
            />
          </div>

          {error && (
            <p className="rounded-md bg-danger/10 px-3 py-2 text-xs text-danger">{error}</p>
          )}

          <div className="flex justify-end gap-2 pt-1">
            <Button variant="outline" onClick={onClose} disabled={saving}>Cancel</Button>
            <Button onClick={handleSubmit} isLoading={saving}>
              <GitBranch className="mr-1.5 h-3.5 w-3.5" /> Add Branch
            </Button>
          </div>
        </div>
      )}
    </Modal>
  );
}
