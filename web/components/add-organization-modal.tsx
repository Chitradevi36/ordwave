"use client";

import { useState, useEffect } from "react";
import { Modal } from "@/components/ui/modal";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Loader2, Building2, CheckCircle2, X } from "lucide-react";
import { usePincodeLookup } from "@/lib/use-pincode-lookup";
import { useOrgBranch } from "@/lib/org-branch-context";

interface Props {
  open: boolean;
  onClose: () => void;
  onCreated: (orgId: string) => void;
}

interface Form {
  name: string;
  contact_phone: string;
  gst_number: string;
  pan: string;
  pincode: string;
  address: string;
  city: string;
  state: string;
}

const BLANK: Form = {
  name: "", contact_phone: "", gst_number: "", pan: "",
  pincode: "", address: "", city: "", state: "",
};

function validateGSTIN(gstin: string): boolean {
  return /^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$/.test(gstin);
}

export function AddOrganizationModal({ open, onClose, onCreated }: Props) {
  const { token } = useOrgBranch();
  const [form, setForm]           = useState<Form>(BLANK);
  const [saving, setSaving]       = useState(false);
  const [error, setError]         = useState<string | null>(null);
  const [success, setSuccess]     = useState(false);
  const [gstinValid, setGstinValid] = useState<boolean | null>(null);
  const [createdName, setCreatedName] = useState("");

  const { city: pcCity, state: pcState, loading: pincodeLoading } =
    usePincodeLookup(form.pincode);

  useEffect(() => {
    if (pcCity) setForm((f) => ({ ...f, city: pcCity }));
    if (pcState) setForm((f) => ({ ...f, state: pcState }));
  }, [pcCity, pcState]);

  useEffect(() => {
    if (open) { setForm(BLANK); setError(null); setSuccess(false); setGstinValid(null); }
  }, [open]);

  const set = (key: keyof Form, value: string) => setForm((f) => ({ ...f, [key]: value }));

  const handleGSTINChange = (val: string) => {
    const upper = val.toUpperCase();
    setForm((f) => {
      const pan = upper.length >= 12 ? upper.substring(2, 12) : f.pan;
      return { ...f, gst_number: upper, pan };
    });
    if (upper.length === 15) setGstinValid(validateGSTIN(upper));
    else setGstinValid(null);
  };

  const handleSubmit = async () => {
    if (!form.name.trim()) { setError("Organization name is required."); return; }
    if (form.gst_number && !validateGSTIN(form.gst_number)) {
      setError("GSTIN format is invalid. Expected: 22AAAAA00001Az5");
      return;
    }
    setSaving(true);
    setError(null);
    try {
      const res = await fetch("http://localhost:3001/api/v1/organizations", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization:  `Bearer ${token}`,
        },
        body: JSON.stringify({
          organization: {
            name:          form.name.trim(),
            contact_phone: form.contact_phone || undefined,
            gst_number:    form.gst_number || undefined,
            pincode:       form.pincode || undefined,
            address:       form.address || undefined,
            city:          form.city || undefined,
            state:         form.state || undefined,
          },
        }),
      });
      const json = await res.json();
      if (res.ok) {
        setCreatedName(form.name.trim());
        setSuccess(true);
        const newOrgId = String(json.data?.id ?? "");
        setTimeout(() => { onCreated(newOrgId); onClose(); }, 1800);
      } else {
        setError((json.errors ?? []).join(", ") || "Failed to create organization.");
      }
    } catch {
      setError("Network error. Please try again.");
    } finally {
      setSaving(false);
    }
  };

  return (
    <Modal open={open} onClose={onClose} title="Create New Organization" size="md">
      {success ? (
        <div className="flex flex-col items-center gap-3 py-8">
          <div className="flex h-12 w-12 items-center justify-center rounded-full bg-accent/15">
            <CheckCircle2 className="h-6 w-6 text-accent" />
          </div>
          <p className="text-sm font-medium text-text-primary">Organization created!</p>
          <p className="text-xs text-text-secondary text-center">
            <span className="font-medium">{createdName}</span> is ready. Switching now…
          </p>
        </div>
      ) : (
        <div className="space-y-4">
          {/* Name */}
          <Input
            label="Organization Name *"
            placeholder="Sharma Distributors Pvt Ltd"
            value={form.name}
            onChange={(e) => set("name", e.target.value)}
          />

          {/* Phone */}
          <Input
            label="Contact Phone"
            type="tel"
            placeholder="+91 98765 43210"
            value={form.contact_phone}
            onChange={(e) => set("contact_phone", e.target.value)}
          />

          {/* GSTIN + PAN */}
          <div className="grid grid-cols-2 gap-3">
            <div className="relative">
              <Input
                label="GSTIN"
                placeholder="29ABCDE1234F1Z5"
                maxLength={15}
                value={form.gst_number}
                helperText="Auto-fills PAN"
                onChange={(e) => handleGSTINChange(e.target.value)}
              />
              {form.gst_number.length === 15 && (
                <div className="absolute right-3 top-7">
                  {gstinValid
                    ? <CheckCircle2 className="h-4 w-4 text-success" />
                    : <X className="h-4 w-4 text-danger" />}
                </div>
              )}
            </div>
            <Input
              label="PAN"
              placeholder="ABCDE1234F"
              maxLength={10}
              value={form.pan}
              helperText="Auto-filled from GSTIN"
              onChange={(e) => set("pan", e.target.value.toUpperCase())}
            />
          </div>

          {/* PIN Code */}
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
            placeholder="Street address"
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
              <Building2 className="mr-1.5 h-3.5 w-3.5" /> Create Organization
            </Button>
          </div>
        </div>
      )}
    </Modal>
  );
}
