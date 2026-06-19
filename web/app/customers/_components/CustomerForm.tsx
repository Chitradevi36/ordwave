"use client";

import { useState, useEffect, useCallback, useRef, useId } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent } from "@/components/ui/card";
import { ChevronDown, ChevronRight, Plus, Trash2, Star, MapPin, X, AlertCircle, CheckCircle2, Loader2 } from "lucide-react";

const CHANNELS = [
  { value: "general_trade", label: "General Trade" },
  { value: "modern_trade",  label: "Modern Trade"  },
  { value: "horeca",        label: "HoReCa"        },
  { value: "pharmacy",      label: "Pharmacy"       },
  { value: "electronics",   label: "Electronics"   },
  { value: "wholesale",     label: "Wholesale"     },
  { value: "distributor",   label: "Distributor"   },
];

const TIERS = [
  { value: "platinum", label: "Platinum" },
  { value: "gold",     label: "Gold"     },
  { value: "silver",   label: "Silver"   },
  { value: "bronze",   label: "Bronze"   },
];

const CUSTOMER_TYPES = [
  { value: "retailer",    label: "Retailer"    },
  { value: "wholesaler",  label: "Wholesaler"  },
  { value: "distributor", label: "Distributor" },
  { value: "institution", label: "Institution" },
  { value: "horeca",      label: "HoReCa"      },
  { value: "online",      label: "Online"      },
  { value: "other",       label: "Other"       },
];

const VISIT_FREQUENCIES = [
  { value: "",          label: "Not set"   },
  { value: "daily",     label: "Daily"     },
  { value: "weekly",    label: "Weekly"    },
  { value: "biweekly",  label: "Bi-weekly" },
  { value: "monthly",   label: "Monthly"   },
  { value: "quarterly", label: "Quarterly" },
];

const CREDIT_BLOCK_RULES = [
  { value: "none",       label: "No block (allow orders always)"  },
  { value: "soft_block", label: "Soft block (warn salesperson)"   },
  { value: "hard_block", label: "Hard block (reject new orders)"  },
];

const ADDRESS_LABELS = ["billing", "shipping", "other"];

// Validation regexes
const GSTIN_RE = /^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$/;
const PHONE_RE = /^(\+91)?[6-9]\d{9}$|^\+[1-9]\d{7,14}$/;
const PAN_RE   = /^[A-Z]{5}[0-9]{4}[A-Z]$/;
const INDIA_STATES = [
  "Andhra Pradesh","Arunachal Pradesh","Assam","Bihar","Chhattisgarh","Goa","Gujarat",
  "Haryana","Himachal Pradesh","Jharkhand","Karnataka","Kerala","Madhya Pradesh","Maharashtra",
  "Manipur","Meghalaya","Mizoram","Nagaland","Odisha","Punjab","Rajasthan","Sikkim",
  "Tamil Nadu","Telangana","Tripura","Uttar Pradesh","Uttarakhand","West Bengal",
  "Andaman and Nicobar Islands","Chandigarh","Dadra & Nagar Haveli and Daman & Diu",
  "Delhi","Jammu and Kashmir","Ladakh","Lakshadweep","Puducherry",
];

// ─── Types ────────────────────────────────────────────────────────────────────
export interface AddressRow {
  _key:        string;
  id?:         number;
  label:       string;
  line1:       string;
  line2:       string;
  city:        string;
  state:       string;
  postal_code: string;
  country:     string;
  latitude?:   string;
  longitude?:  string;
  _destroy?:   boolean;
}

export interface ContactRow {
  _key:        string;
  id?:         number;
  name:        string;
  phone:       string;
  email:       string;
  designation: string;
  is_primary:  boolean;
  _destroy?:   boolean;
}

export interface CustomerFormData {
  // Basic Info
  name:              string;
  code:              string;
  customer_type:     string;
  status?:           string;
  phone:             string;
  email:             string;
  tags:              string[];
  // Classification
  channel:           string;
  tier:              string;
  branch_id:         string;
  route_id:          string;
  sales_rep_id:      string;
  visit_frequency:   string;
  // Credit Policy
  credit_limit:      string;
  credit_days:       string;
  credit_block_rule: string;
  opening_balance:   string;
  // Tax & Compliance
  gstin:             string;
  pan:               string;
  // Nested
  addresses:         AddressRow[];
  contacts:          ContactRow[];
}

export interface SalesRep { id: number; name: string; email: string; }
interface Branch          { id: number; name: string; code: string; }
interface Route           { id: number; name: string; code: string; }

type DupResult = { exists: boolean; match?: string };

interface CustomerFormProps {
  mode?:           "create" | "edit";
  initial?:        Partial<CustomerFormData>;
  branches:        Branch[];
  routes:          Route[];
  salesReps?:      SalesRep[];
  onSubmit:        (data: CustomerFormData) => Promise<void>;
  submitLabel:     string;
  loading:         boolean;
  errors:          string[];
  onCancel?:       () => void;
  checkDuplicate?: (field: "name" | "phone" | "gstin", value: string) => Promise<DupResult>;
}

// ─── Field primitives ─────────────────────────────────────────────────────────
function FieldLabel({ text, required }: { text: string; required?: boolean }) {
  return (
    <label className="text-sm font-medium text-text-primary">
      {text}{required && <span className="text-danger ml-0.5">*</span>}
    </label>
  );
}

function SelectField({
  label, value, onChange, children, required, disabled,
}: {
  label: string; value: string; onChange: (v: string) => void;
  children: React.ReactNode; required?: boolean; disabled?: boolean;
}) {
  return (
    <div className="space-y-1">
      <FieldLabel text={label} required={required} />
      <select
        required={required}
        disabled={disabled}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="w-full h-9 rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent disabled:opacity-60 disabled:cursor-not-allowed"
      >
        {children}
      </select>
    </div>
  );
}

function TextField({
  label, value, onChange, placeholder, required, type = "text", hint, status,
}: {
  label: string; value: string; onChange: (v: string) => void;
  placeholder?: string; required?: boolean; type?: string; hint?: string;
  status?: "ok" | "warn" | "error" | "checking";
}) {
  return (
    <div className="space-y-1">
      <FieldLabel text={label} required={required} />
      <Input
        type={type}
        required={required}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className={
          status === "error" ? "border-danger focus-visible:ring-danger/40" :
          status === "warn"  ? "border-warning focus-visible:ring-warning/40" :
          status === "ok"    ? "border-accent focus-visible:ring-accent/40" : ""
        }
      />
      {hint && <p className="text-xs text-text-secondary">{hint}</p>}
    </div>
  );
}

// ─── Inline status badge ──────────────────────────────────────────────────────
function InlineStatus({ status, message }: { status: "ok" | "warn" | "error" | "checking"; message: string }) {
  if (!message) return null;
  return (
    <div className={`flex items-center gap-1 text-xs mt-1 ${
      status === "error"    ? "text-danger"           :
      status === "warn"     ? "text-warning"          :
      status === "ok"       ? "text-accent"           :
      "text-text-secondary"
    }`}>
      {status === "checking" && <Loader2 className="h-3 w-3 animate-spin" />}
      {status === "ok"       && <CheckCircle2 className="h-3 w-3" />}
      {(status === "warn" || status === "error") && <AlertCircle className="h-3 w-3" />}
      {message}
    </div>
  );
}

// ─── Collapsible section card ─────────────────────────────────────────────────
function CollapsibleSection({
  title, description, children, defaultOpen = true, badge,
}: {
  title: string; description?: string;
  children: React.ReactNode; defaultOpen?: boolean; badge?: number;
}) {
  const [open, setOpen] = useState(defaultOpen);
  return (
    <Card>
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        className="w-full flex items-center justify-between px-4 py-3 text-left hover:bg-muted/30 transition-colors rounded-t-lg"
        aria-expanded={open}
      >
        <div className="flex items-start gap-3">
          <div className="mt-0.5">
            {open
              ? <ChevronDown  className="h-4 w-4 text-text-secondary" />
              : <ChevronRight className="h-4 w-4 text-text-secondary" />}
          </div>
          <div>
            <div className="flex items-center gap-2">
              <span className="text-sm font-semibold text-text-primary">{title}</span>
              {badge !== undefined && badge > 0 && (
                <span className="text-xs font-medium bg-accent/10 text-accent rounded-full px-2 py-0.5">
                  {badge}
                </span>
              )}
            </div>
            {description && <p className="text-xs text-text-secondary mt-0.5">{description}</p>}
          </div>
        </div>
      </button>
      {open && (
        <CardContent className="pt-0 pb-5 px-4 border-t border-border">
          <div className="pt-4">{children}</div>
        </CardContent>
      )}
    </Card>
  );
}

// ─── Tag input ────────────────────────────────────────────────────────────────
function TagInput({ tags, onChange }: { tags: string[]; onChange: (t: string[]) => void }) {
  const [input, setInput] = useState("");

  const commit = () => {
    const trimmed = input.trim().replace(/,+$/, "");
    if (trimmed && !tags.includes(trimmed)) onChange([...tags, trimmed]);
    setInput("");
  };

  return (
    <div className="space-y-1">
      <FieldLabel text="Tags" />
      <div
        className="flex flex-wrap gap-1.5 min-h-9 rounded-md border border-border bg-background px-2 py-1.5 focus-within:ring-2 focus-within:ring-accent cursor-text"
        onClick={(e) => (e.currentTarget.querySelector("input") as HTMLInputElement)?.focus()}
      >
        {tags.map((t) => (
          <span
            key={t}
            className="inline-flex items-center gap-1 text-xs bg-accent/10 text-accent rounded-full px-2 py-0.5 font-medium"
          >
            {t}
            <button
              type="button"
              onClick={() => onChange(tags.filter((x) => x !== t))}
              className="hover:text-danger"
            >
              <X className="h-2.5 w-2.5" />
            </button>
          </span>
        ))}
        <input
          className="flex-1 min-w-[5rem] text-sm outline-none bg-transparent"
          placeholder={tags.length === 0 ? "Type a tag and press Enter…" : ""}
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter" || e.key === "," || e.key === "Tab") {
              e.preventDefault();
              commit();
            }
            if (e.key === "Backspace" && !input && tags.length > 0) {
              onChange(tags.slice(0, -1));
            }
          }}
          onBlur={commit}
        />
      </div>
      <p className="text-xs text-text-secondary">Press Enter or comma to add · Backspace to remove last</p>
    </div>
  );
}

// ─── Address editor ───────────────────────────────────────────────────────────
function AddressEditor({
  address, onChange, onRemove, index,
}: {
  address: AddressRow; onChange: (u: AddressRow) => void; onRemove: () => void; index: number;
}) {
  const [geoLoading, setGeoLoading] = useState(false);
  const [geoError,   setGeoError]   = useState("");

  const s = (field: keyof AddressRow) => (v: string) => onChange({ ...address, [field]: v });

  const detectLocation = () => {
    if (!navigator.geolocation) { setGeoError("Geolocation not supported by this browser"); return; }
    setGeoLoading(true);
    setGeoError("");
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setGeoLoading(false);
        onChange({
          ...address,
          latitude:  String(pos.coords.latitude.toFixed(6)),
          longitude: String(pos.coords.longitude.toFixed(6)),
        });
      },
      () => {
        setGeoLoading(false);
        setGeoError("Unable to detect location. Check browser permissions.");
      },
      { timeout: 8000 },
    );
  };

  return (
    <div className="rounded-lg border border-border bg-background/50 p-4 space-y-3">
      <div className="flex items-center justify-between">
        <span className="text-xs font-semibold uppercase tracking-wide text-text-secondary">
          Address {index + 1}
        </span>
        <button
          type="button" onClick={onRemove}
          className="text-text-secondary hover:text-danger transition-colors" title="Remove address"
        >
          <Trash2 className="h-3.5 w-3.5" />
        </button>
      </div>

      <div className="grid gap-3 sm:grid-cols-2">
        <SelectField label="Label" value={address.label} onChange={s("label")}>
          {ADDRESS_LABELS.map((l) => (
            <option key={l} value={l}>{l.charAt(0).toUpperCase() + l.slice(1)}</option>
          ))}
        </SelectField>
        <TextField label="Line 1"  value={address.line1}       onChange={s("line1")}       placeholder="Street / area" required />
        <TextField label="Line 2"  value={address.line2}       onChange={s("line2")}       placeholder="Landmark (optional)" />
        <TextField label="City"    value={address.city}        onChange={s("city")}        placeholder="City" required />
        <div className="space-y-1">
          <FieldLabel text="State" required />
          <select
            value={address.state}
            onChange={(e) => s("state")(e.target.value)}
            className="w-full h-9 rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent"
          >
            <option value="">Select state</option>
            {INDIA_STATES.map((st) => <option key={st} value={st}>{st}</option>)}
          </select>
        </div>
        <TextField label="PIN Code" value={address.postal_code} onChange={s("postal_code")} placeholder="400001" />
      </div>

      {/* Geo-location picker */}
      <div className="pt-2 border-t border-border/50 space-y-2">
        <div className="flex items-center justify-between">
          <span className="text-xs font-medium text-text-secondary flex items-center gap-1">
            <MapPin className="h-3 w-3" /> Geo Location
          </span>
          <button
            type="button"
            onClick={detectLocation}
            disabled={geoLoading}
            className="inline-flex items-center gap-1 text-xs text-accent hover:underline disabled:opacity-60"
          >
            {geoLoading
              ? <><Loader2 className="h-3 w-3 animate-spin" />Detecting…</>
              : <><MapPin className="h-3 w-3" />Detect my location</>
            }
          </button>
        </div>
        {geoError && <p className="text-xs text-danger">{geoError}</p>}
        <div className="grid gap-3 sm:grid-cols-2">
          <div className="space-y-1">
            <FieldLabel text="Latitude" />
            <Input
              value={address.latitude ?? ""}
              onChange={(e) => s("latitude")(e.target.value)}
              placeholder="e.g. 19.076090"
              type="number"
              step="any"
            />
          </div>
          <div className="space-y-1">
            <FieldLabel text="Longitude" />
            <Input
              value={address.longitude ?? ""}
              onChange={(e) => s("longitude")(e.target.value)}
              placeholder="e.g. 72.877426"
              type="number"
              step="any"
            />
          </div>
        </div>
        {address.latitude && address.longitude && (
          <a
            href={`https://www.google.com/maps?q=${address.latitude},${address.longitude}`}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1 text-xs text-accent hover:underline"
          >
            <MapPin className="h-3 w-3" /> View on Google Maps ↗
          </a>
        )}
      </div>
    </div>
  );
}

// ─── Contact editor ───────────────────────────────────────────────────────────
function ContactEditor({
  contact, onChange, onRemove, onSetPrimary, index, canSetPrimary,
}: {
  contact: ContactRow; onChange: (u: ContactRow) => void; onRemove: () => void;
  onSetPrimary: () => void; index: number; canSetPrimary: boolean;
}) {
  const s = (field: keyof ContactRow) => (v: string) => onChange({ ...contact, [field]: v });
  return (
    <div className={`rounded-lg border bg-background/50 p-4 space-y-3 ${contact.is_primary ? "border-accent" : "border-border"}`}>
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="text-xs font-semibold uppercase tracking-wide text-text-secondary">Contact {index + 1}</span>
          {contact.is_primary && (
            <span className="inline-flex items-center gap-1 text-xs font-medium text-accent bg-accent/10 rounded-full px-2 py-0.5">
              <Star className="h-3 w-3 fill-accent" /> Primary
            </span>
          )}
        </div>
        <div className="flex items-center gap-3">
          {canSetPrimary && !contact.is_primary && (
            <button type="button" onClick={onSetPrimary}
              className="text-xs text-text-secondary hover:text-accent transition-colors">
              Set primary
            </button>
          )}
          <button type="button" onClick={onRemove}
            className="text-text-secondary hover:text-danger transition-colors" title="Remove contact">
            <Trash2 className="h-3.5 w-3.5" />
          </button>
        </div>
      </div>
      <div className="grid gap-3 sm:grid-cols-2">
        <TextField label="Name"        value={contact.name}        onChange={s("name")}        placeholder="Contact person name" required />
        <TextField label="Phone"       value={contact.phone}       onChange={s("phone")}       placeholder="+91 9876543210" />
        <TextField label="Email"       value={contact.email}       onChange={s("email")}       placeholder="contact@store.com" type="email" />
        <TextField label="Designation" value={contact.designation} onChange={s("designation")} placeholder="Owner / Manager" />
      </div>
    </div>
  );
}

// ─── Main Form ────────────────────────────────────────────────────────────────
export function CustomerForm({
  mode = "edit", initial, branches, routes, salesReps = [], onSubmit, submitLabel, loading, errors, onCancel, checkDuplicate,
}: CustomerFormProps) {
  const isCreate = mode === "create";
  const uid = useId();

  const defaultBranchId = branches[0] ? String(branches[0].id) : "";

  const EMPTY: CustomerFormData = {
    name: "", code: "", customer_type: "retailer", status: "active",
    phone: "", email: "", tags: [],
    channel: "general_trade", tier: "bronze",
    branch_id: defaultBranchId, route_id: "", sales_rep_id: "",
    visit_frequency: "",
    credit_limit: "0", credit_days: "30", credit_block_rule: "none", opening_balance: "0",
    gstin: "", pan: "",
    addresses: [], contacts: [],
  };

  const [form, setForm] = useState<CustomerFormData>({ ...EMPTY, ...initial });

  // Duplicate detection state
  const [dupName,  setDupName]  = useState<DupResult | null>(null);
  const [dupPhone, setDupPhone] = useState<DupResult | null>(null);
  const [dupGstin, setDupGstin] = useState<DupResult | null>(null);
  const [dupCheckingField, setDupCheckingField] = useState<Set<string>>(new Set());

  // Inline validation errors
  const [validationErrors, setValidationErrors] = useState<Record<string, string>>({});

  // Re-seed form when initial changes async (edit page)
  useEffect(() => {
    if (!initial) return;
    setForm((prev) => ({
      ...prev,
      ...initial,
      tags:      initial.tags      ?? prev.tags,
      addresses: initial.addresses ?? prev.addresses,
      contacts:  initial.contacts  ?? prev.contacts,
    }));
  }, [initial]); // eslint-disable-line react-hooks/exhaustive-deps

  // Default branch_id once branches load
  useEffect(() => {
    if (branches.length > 0 && !form.branch_id) {
      setForm((prev) => ({ ...prev, branch_id: String(branches[0].id) }));
    }
  }, [branches]); // eslint-disable-line react-hooks/exhaustive-deps

  const set = (field: keyof CustomerFormData) => (v: string) =>
    setForm((prev) => ({ ...prev, [field]: v }));

  // ── Duplicate check (debounced) ────────────────────────────────────────────
  const dupTimers = useRef<Record<string, ReturnType<typeof setTimeout>>>({});

  const scheduleCheck = useCallback(
    (field: "name" | "phone" | "gstin", value: string) => {
      if (!checkDuplicate || !value.trim()) return;
      clearTimeout(dupTimers.current[field]);
      setDupCheckingField((s) => new Set(s).add(field));
      dupTimers.current[field] = setTimeout(async () => {
        const result = await checkDuplicate(field, value.trim());
        setDupCheckingField((s) => { const n = new Set(s); n.delete(field); return n; });
        if (field === "name")  setDupName(result);
        if (field === "phone") setDupPhone(result);
        if (field === "gstin") setDupGstin(result);
      }, 600);
    },
    [checkDuplicate],
  );

  // ── Field change handlers ─────────────────────────────────────────────────
  const handleNameChange = (v: string) => {
    setForm((prev) => ({
      ...prev,
      name: v,
      code: prev.code
        ? prev.code
        : v.toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 8),
    }));
    setDupName(null);
    scheduleCheck("name", v);
  };

  const handlePhoneChange = (v: string) => {
    const clean = v.replace(/\s/g, "");
    setForm((prev) => ({ ...prev, phone: clean }));
    if (clean && !PHONE_RE.test(clean)) {
      setValidationErrors((e) => ({ ...e, phone: "Enter a valid 10-digit Indian or international number" }));
    } else {
      setValidationErrors((e) => { const n = { ...e }; delete n.phone; return n; });
    }
    setDupPhone(null);
    scheduleCheck("phone", clean);
  };

  const handleGstinChange = (v: string) => {
    const upper = v.toUpperCase().replace(/\s/g, "");
    setForm((prev) => ({
      ...prev,
      gstin: upper,
      pan:   upper.length >= 12 && !prev.pan ? upper.slice(2, 12) : prev.pan,
    }));
    if (upper && upper.length === 15 && !GSTIN_RE.test(upper)) {
      setValidationErrors((e) => ({ ...e, gstin: "Invalid GSTIN format" }));
    } else {
      setValidationErrors((e) => { const n = { ...e }; delete n.gstin; return n; });
    }
    setDupGstin(null);
    if (upper.length === 15) scheduleCheck("gstin", upper);
  };

  const handlePanChange = (v: string) => {
    const upper = v.toUpperCase();
    setForm((prev) => ({ ...prev, pan: upper }));
    if (upper && upper.length === 10 && !PAN_RE.test(upper)) {
      setValidationErrors((e) => ({ ...e, pan: "Invalid PAN format (e.g. AAAAA0000A)" }));
    } else {
      setValidationErrors((e) => { const n = { ...e }; delete n.pan; return n; });
    }
  };

  // ── Address helpers ────────────────────────────────────────────────────────
  const addAddress = () =>
    setForm((prev) => ({
      ...prev,
      addresses: [
        ...prev.addresses,
        {
          _key: `${uid}-a-${Date.now()}`,
          label: "billing", line1: "", line2: "", city: "",
          state: "", postal_code: "", country: "India",
          latitude: "", longitude: "",
        },
      ],
    }));

  const updateAddress = (i: number, updated: AddressRow) =>
    setForm((prev) => { const a = [...prev.addresses]; a[i] = updated; return { ...prev, addresses: a }; });

  const removeAddress = (i: number) =>
    setForm((prev) => {
      const a = [...prev.addresses];
      a[i].id ? (a[i] = { ...a[i], _destroy: true }) : a.splice(i, 1);
      return { ...prev, addresses: a };
    });

  // ── Contact helpers ────────────────────────────────────────────────────────
  const addContact = () => {
    const hasPrimary = form.contacts.some((c) => c.is_primary && !c._destroy);
    setForm((prev) => ({
      ...prev,
      contacts: [
        ...prev.contacts,
        { _key: `${uid}-c-${Date.now()}`, name: "", phone: "", email: "", designation: "", is_primary: !hasPrimary },
      ],
    }));
  };

  const updateContact = (i: number, updated: ContactRow) =>
    setForm((prev) => { const c = [...prev.contacts]; c[i] = updated; return { ...prev, contacts: c }; });

  const removeContact = (i: number) =>
    setForm((prev) => {
      const c = [...prev.contacts];
      c[i].id ? (c[i] = { ...c[i], _destroy: true }) : c.splice(i, 1);
      return { ...prev, contacts: c };
    });

  const setPrimaryContact = (i: number) =>
    setForm((prev) => ({
      ...prev,
      contacts: prev.contacts.map((c, idx) => ({ ...c, is_primary: idx === i })),
    }));

  const visibleAddresses = form.addresses.filter((a) => !a._destroy);
  const visibleContacts  = form.contacts.filter((c)  => !c._destroy);

  const canSubmit =
    !!form.branch_id &&
    !loading &&
    Object.keys(validationErrors).length === 0 &&
    // When creating a new customer, require phone to be present
    (!isCreate || (form.phone && form.phone.trim().length > 0));

  // ── Dup badge helper ────────────────────────────────────────────────────────
  const dupBadge = (field: "name" | "phone" | "gstin", result: DupResult | null) => {
    if (dupCheckingField.has(field)) return <InlineStatus status="checking" message="Checking for duplicates…" />;
    if (!result) return null;
    if (result.exists) {
      return <InlineStatus status="warn" message={`Possible duplicate: "${result.match ?? "existing customer"}"`} />;
    }
    return <InlineStatus status="ok" message="No duplicate found" />;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!canSubmit) return;
    await onSubmit(form);
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4 max-w-2xl pb-16">

      {/* API error banner */}
      {errors.length > 0 && (
        <div className="rounded-md bg-danger/10 border border-danger/20 px-4 py-3">
          <div className="flex items-start gap-2">
            <AlertCircle className="h-4 w-4 text-danger mt-0.5 shrink-0" />
            <ul className="space-y-0.5">
              {errors.map((err, i) => (
                <li key={i} className="text-sm text-danger">{err}</li>
              ))}
            </ul>
          </div>
        </div>
      )}

      {/* ── 1. Basic Information ─────────────────────────────────────────── */}
      <CollapsibleSection
        title="Basic Information"
        description="Name, code, type and primary contact details."
        defaultOpen
      >
        <div className="grid gap-4 sm:grid-cols-2">
          <div className="space-y-1">
            <FieldLabel text="Retailer Name" required />
            <Input
              required
              value={form.name}
              onChange={(e) => handleNameChange(e.target.value)}
              placeholder="e.g. Rajan General Store"
            />
            {dupBadge("name", dupName)}
          </div>

          <div className="space-y-1">
            <FieldLabel text="Retailer Code" required />
            <Input
              required
              value={form.code}
              onChange={(e) => set("code")(e.target.value.toUpperCase())}
              placeholder="e.g. RAJAN001"
            />
            <p className="text-xs text-text-secondary">Auto-generated from name · Must be unique</p>
          </div>

          <SelectField label="Retailer Type" value={form.customer_type} onChange={set("customer_type")} required>
            {CUSTOMER_TYPES.map((t) => <option key={t.value} value={t.value}>{t.label}</option>)}
          </SelectField>

          <div className="space-y-1">
            <FieldLabel text="Phone" required={isCreate} />
            <Input
              required={isCreate}
              value={form.phone}
              onChange={(e) => handlePhoneChange(e.target.value)}
              placeholder="+91 9876543210"
              type="tel"
            />
            {validationErrors.phone
              ? <InlineStatus status="error" message={validationErrors.phone} />
              : dupBadge("phone", dupPhone)
            }
          </div>

          {!isCreate && (
            <TextField label="Email" value={form.email} onChange={set("email")} placeholder="owner@store.com" type="email" />
          )}

          {!isCreate && (
            <SelectField label="Status" value={form.status ?? "active"} onChange={set("status")}>
              <option value="active">Active</option>
              <option value="inactive">Inactive</option>
            </SelectField>
          )}

          {!isCreate && (
            <div className="sm:col-span-2">
              <TagInput tags={form.tags} onChange={(t) => setForm((prev) => ({ ...prev, tags: t }))} />
            </div>
          )}
        </div>
      </CollapsibleSection>

      {/* ── 2. Business Classification ───────────────────────────────────── */}
      <CollapsibleSection
        title="Business Classification"
        description={isCreate ? "Channel, tier and branch." : "Channel, tier, route, sales rep and visit frequency."}
        defaultOpen
      >
        <div className="grid gap-4 sm:grid-cols-2">
          <SelectField label="Channel" value={form.channel} onChange={set("channel")} required>
            {CHANNELS.map((c) => <option key={c.value} value={c.value}>{c.label}</option>)}
          </SelectField>

          <SelectField label="Tier" value={form.tier} onChange={set("tier")} required>
            {TIERS.map((t) => <option key={t.value} value={t.value}>{t.label}</option>)}
          </SelectField>

          <SelectField label="Branch" value={form.branch_id} onChange={set("branch_id")} required disabled={branches.length === 0}>
            <option value="">Select branch</option>
            {branches.map((b) => (
              <option key={b.id} value={String(b.id)}>{b.name} ({b.code})</option>
            ))}
          </SelectField>

          {!isCreate && (
            <SelectField label="Route" value={form.route_id} onChange={set("route_id")}>
              <option value="">No route assigned</option>
              {routes.map((r) => (
                <option key={r.id} value={String(r.id)}>{r.name} ({r.code})</option>
              ))}
            </SelectField>
          )}

          {!isCreate && (
            <SelectField label="Sales Representative" value={form.sales_rep_id} onChange={set("sales_rep_id")}>
              <option value="">Not assigned</option>
              {salesReps.map((u) => (
                <option key={u.id} value={String(u.id)}>{u.name} — {u.email}</option>
              ))}
            </SelectField>
          )}

          {!isCreate && (
            <SelectField label="Visit Frequency" value={form.visit_frequency} onChange={set("visit_frequency")}>
              {VISIT_FREQUENCIES.map((v) => <option key={v.value} value={v.value}>{v.label}</option>)}
            </SelectField>
          )}
        </div>
      </CollapsibleSection>

      {/* ── 3–6. Extended sections (edit mode only) ───────────────────── */}
      {!isCreate && (<>
      <CollapsibleSection
        title="Credit Policy"
        description="Credit limit, payment terms and block behaviour."
        defaultOpen
      >
        <div className="grid gap-4 sm:grid-cols-2">
          <TextField
            label="Credit Limit (₹)" value={form.credit_limit}
            onChange={set("credit_limit")} placeholder="50000" type="number"
            hint="0 = no credit facility"
          />

          <TextField
            label="Credit Days" value={form.credit_days}
            onChange={set("credit_days")} placeholder="30" type="number"
            hint="Payment due within this many days"
          />

          <div className="sm:col-span-2">
            <SelectField label="Credit Block Rule" value={form.credit_block_rule} onChange={set("credit_block_rule")}>
              {CREDIT_BLOCK_RULES.map((r) => <option key={r.value} value={r.value}>{r.label}</option>)}
            </SelectField>
          </div>

          <TextField
            label="Opening Balance (₹)" value={form.opening_balance}
            onChange={set("opening_balance")} placeholder="0" type="number"
            hint="Outstanding amount as of account creation"
          />
        </div>
      </CollapsibleSection>

      {/* ── 4. Tax & Compliance ──────────────────────────────────────────── */}
      <CollapsibleSection
        title="Tax & Compliance"
        description="GSTIN auto-fills PAN. Leave blank if not applicable."
      >
        <div className="grid gap-4 sm:grid-cols-2">
          <div className="space-y-1">
            <FieldLabel text="GSTIN" />
            <Input
              value={form.gstin}
              onChange={(e) => handleGstinChange(e.target.value)}
              placeholder="22AAAAA0000A1Z5"
              maxLength={15}
              className={validationErrors.gstin ? "border-danger focus-visible:ring-danger/40" : ""}
            />
            {validationErrors.gstin
              ? <InlineStatus status="error" message={validationErrors.gstin} />
              : form.gstin.length === 15 && GSTIN_RE.test(form.gstin)
                ? <InlineStatus status="ok" message="Valid GSTIN" />
                : dupBadge("gstin", dupGstin)
            }
            <p className="text-xs text-text-secondary">PAN auto-filled when GSTIN is 15 chars</p>
          </div>

          <div className="space-y-1">
            <FieldLabel text="PAN" />
            <Input
              value={form.pan}
              onChange={(e) => handlePanChange(e.target.value)}
              placeholder="AAAAA0000A"
              maxLength={10}
              className={validationErrors.pan ? "border-danger focus-visible:ring-danger/40" : ""}
            />
            {validationErrors.pan
              ? <InlineStatus status="error" message={validationErrors.pan} />
              : form.pan.length === 10 && PAN_RE.test(form.pan)
                ? <InlineStatus status="ok" message="Valid PAN" />
                : null
            }
          </div>
        </div>
      </CollapsibleSection>

      {/* ── 5. Addresses ─────────────────────────────────────────────────── */}
      <CollapsibleSection
        title="Addresses"
        description="Billing, shipping, or other addresses. Supports geo-coordinates."
        badge={visibleAddresses.length}
      >
        <div className="space-y-3">
          {visibleAddresses.length === 0 ? (
            <div className="rounded-lg border border-dashed border-border p-6 text-center">
              <p className="text-sm text-text-secondary">No addresses yet.</p>
              <button type="button" onClick={addAddress} className="mt-1.5 text-xs text-accent hover:underline">
                Add an address
              </button>
            </div>
          ) : (
            form.addresses.map((addr, i) => {
              if (addr._destroy) return null;
              const visIdx = form.addresses.slice(0, i + 1).filter((a) => !a._destroy).length - 1;
              return (
                <AddressEditor
                  key={addr._key ?? addr.id ?? i}
                  address={addr} index={visIdx}
                  onChange={(u) => updateAddress(i, u)}
                  onRemove={() => removeAddress(i)}
                />
              );
            })
          )}
          <Button type="button" variant="outline" size="sm" onClick={addAddress} className="w-full">
            <Plus className="h-3.5 w-3.5 mr-1.5" /> Add Address
          </Button>
        </div>
      </CollapsibleSection>

      {/* ── 6. Contacts ──────────────────────────────────────────────────── */}
      <CollapsibleSection
        title="Contacts"
        description="People at this customer location. Mark one as primary."
        badge={visibleContacts.length}
      >
        <div className="space-y-3">
          {visibleContacts.length === 0 ? (
            <div className="rounded-lg border border-dashed border-border p-6 text-center">
              <p className="text-sm text-text-secondary">No contacts yet.</p>
              <button type="button" onClick={addContact} className="mt-1.5 text-xs text-accent hover:underline">
                Add a contact
              </button>
            </div>
          ) : (
            form.contacts.map((contact, i) => {
              if (contact._destroy) return null;
              const visIdx = form.contacts.slice(0, i + 1).filter((c) => !c._destroy).length - 1;
              return (
                <ContactEditor
                  key={contact._key ?? contact.id ?? i}
                  contact={contact} index={visIdx}
                  onChange={(u) => updateContact(i, u)}
                  onRemove={() => removeContact(i)}
                  onSetPrimary={() => setPrimaryContact(i)}
                  canSetPrimary={visibleContacts.length > 1}
                />
              );
            })
          )}
          <Button type="button" variant="outline" size="sm" onClick={addContact} className="w-full">
            <Plus className="h-3.5 w-3.5 mr-1.5" /> Add Contact
          </Button>
        </div>
      </CollapsibleSection>
      </>)}

      {/* ── Actions ──────────────────────────────────────────────────────── */}
      <div className="flex gap-3 pt-2">
        <Button type="submit" disabled={!canSubmit}>
          {loading
            ? <><Loader2 className="h-4 w-4 animate-spin mr-1.5" />Saving…</>
            : submitLabel}
        </Button>
        {onCancel && (
          <Button type="button" variant="outline" onClick={onCancel} disabled={loading}>
            Cancel
          </Button>
        )}
      </div>
    </form>
  );
}