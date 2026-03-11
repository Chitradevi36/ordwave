'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { onboardingAPI } from '@/lib/onboarding-api';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card } from '@/components/ui/card';
import { 
  CheckCircle2, 
  Wifi,
  CreditCard,
  Receipt,
  TrendingUp,
  Users,
  Package,
  ShoppingCart,
  Building,
  Sparkles,
  ArrowRight,
  ArrowLeft,
  HelpCircle,
  Check,
  X,
  ChevronDown,
  Loader2
} from 'lucide-react';
import { usePincodeLookup } from '@/lib/use-pincode-lookup';
import { ANALYTICS_EVENTS, trackOnboardingEvent } from '@/lib/analytics';

// Reusable Searchable Select Component
interface SelectOption {
  value: string;
  label: string;
}

const SearchableSelect = ({
  options,
  value,
  onChange,
  placeholder = 'Select an option',
}: {
  options: SelectOption[];
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
}) => {
  const [isOpen, setIsOpen] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');

  const filteredOptions = options.filter(opt =>
    opt.label.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const selectedLabel = options.find(opt => opt.value === value)?.label || placeholder;

  return (
    <div className="relative">
      <button
        type="button"
        onClick={() => setIsOpen(!isOpen)}
        className="w-full px-3 py-2 text-xs border border-border rounded-lg focus:outline-none focus:ring-2 focus:ring-primary text-left flex items-center justify-between bg-white hover:bg-background-subtle transition-colors"
      >
        <span className="text-text-primary truncate">{selectedLabel}</span>
        <ChevronDown className={`w-4 h-4 text-text-secondary transition-transform ${isOpen ? 'rotate-180' : ''}`} />
      </button>

      {isOpen && (
        <div className="absolute z-50 w-full mt-1 bg-white border border-border rounded-lg shadow-lg">
          <div className="p-2 border-b border-border">
            <Input
              placeholder="Type to search..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="text-xs h-8"
              autoFocus
            />
          </div>
          <div className="max-h-48 overflow-y-auto">
            {filteredOptions.length > 0 ? (
              filteredOptions.map((option) => (
                <button
                  key={option.value}
                  type="button"
                  onClick={() => {
                    onChange(option.value);
                    setIsOpen(false);
                    setSearchTerm('');
                  }}
                  className={`w-full text-left px-3 py-2 text-xs hover:bg-primary-50 transition-colors ${
                    value === option.value ? 'bg-primary-50 text-primary font-semibold' : 'text-text-primary'
                  }`}
                >
                  {option.label}
                </button>
              ))
            ) : (
              <div className="px-3 py-2 text-xs text-text-secondary">No results found</div>
            )}
          </div>
        </div>
      )}
    </div>
  );
};

type BusinessType = 'rice' | 'fmcg' | 'wholesale' | 'custom';
type OperatingModel = 'credit' | 'cash' | 'mixed';

interface FormData {
  businessType: BusinessType | null;
  orgName: string;
  phone: string;
  state: string;
  gstin: string;
  pan: string;
  branchName: string;
  branchCode: string;
  address: string;
  city: string;
  pincode: string;
  singleBranch: boolean;
  operatingModel: OperatingModel[];
  retailerName: string;
  retailerPhone: string;
  retailerArea: string;
  productName: string;
  productSKU: string;
  productHSN: string;
  productGST: string;
  teamEmails: { role: string; email: string }[];
}

const INDIAN_STATES = [
  'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
  'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 
  'Karnataka', 'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur',
  'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha', 'Punjab',
  'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana', 'Tripura',
  'Uttar Pradesh', 'Uttarakhand', 'West Bengal'
];

const BUSINESS_TYPES = [
  { id: 'rice', label: 'Rice Distributor', icon: Package, iconBg: 'bg-amber-100', iconColor: 'text-amber-600', desc: 'Optimized for rice & grain trading', hint: 'GST 5% pre-configured' },
  { id: 'fmcg', label: 'FMCG Distributor', icon: ShoppingCart, iconBg: 'bg-sky-100', iconColor: 'text-sky-600', desc: 'Fast-moving consumer goods', hint: 'Multi-tax slabs ready' },
  { id: 'wholesale', label: 'Wholesale Grocery', icon: Building, iconBg: 'bg-violet-100', iconColor: 'text-violet-600', desc: 'Bulk grocery distribution', hint: 'Bulk pricing & credit terms' },
  { id: 'custom', label: 'Custom Business', icon: Sparkles, iconBg: 'bg-slate-100', iconColor: 'text-slate-600', desc: 'Any distribution business', hint: 'Configure everything yourself' },
];

export default function OnboardingWizardPage() {
  const router = useRouter();
  const [step, setStep] = useState(1);
  const [loading, setLoading] = useState(false);
  const [gstinValid, setGstinValid] = useState<boolean | null>(null);
  const [showConfetti, setShowConfetti] = useState(false);

  // Step 4: Quick Start toggles
  const [addRetailer, setAddRetailer] = useState(false);
  const [addProduct, setAddProduct] = useState(false);

  const [formData, setFormData] = useState<FormData>({
    businessType: null,
    orgName: '',
    phone: '',
    state: '',
    gstin: '',
    pan: '',
    branchName: '',
    branchCode: '',
    address: '',
    city: '',
    pincode: '',
    singleBranch: false,
    operatingModel: [],
    retailerName: '',
    retailerPhone: '',
    retailerArea: '',
    productName: '',
    productSKU: '',
    productHSN: '',
    productGST: '',
    teamEmails: [],
  });

  const { city: pcCity, state: pcState, loading: pincodeLoading } = usePincodeLookup(formData.pincode);

  useEffect(() => {
    if (pcCity) setFormData((prev) => ({ ...prev, city: pcCity }));
    if (pcState) setFormData((prev) => ({ ...prev, state: pcState }));
  }, [pcCity, pcState]);

  // Track page viewed once on mount
  useEffect(() => {
    trackOnboardingEvent(ANALYTICS_EVENTS.ONBOARDING_PAGE_VIEWED, 0, 'welcome');
  }, []);

  // Track each step advance
  useEffect(() => {
    if (step === 1) return; // welcome already tracked above
    const stepNames: Record<number, string> = {
      2: 'business_type',
      3: 'org_details',
      4: 'catalog_setup',
      5: 'complete',
    };
    trackOnboardingEvent(
      ANALYTICS_EVENTS.ONBOARDING_STEP_COMPLETED,
      step,
      stepNames[step] ?? `step_${step}`,
      { total_steps: 5 },
    );
  }, [step]);

  const TOTAL_STEPS = 5;

  // Phases shown in the top stepper (steps 2-5 map to 4 phases)
  const ONBOARDING_PHASES = [
    { label: 'Business', steps: [2] },
    { label: 'Details',  steps: [3] },
    { label: 'Catalog',  steps: [4] },
    { label: 'Done',     steps: [5] },
  ] as const;

  const validateGSTIN = (value: string) => {
    const gstinRegex = /^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$/;
    const isValid = gstinRegex.test(value);
    setGstinValid(isValid);
    return isValid;
  };

  const handleNext = () => {
    if (step === 3) {
      handleSaveOnboardingSetup();
    } else if (step < TOTAL_STEPS) {
      setStep(step + 1);
      window.scrollTo(0, 0);
    }
  };

  const handleBack = () => {
    if (step > 1) {
      setStep(step - 1);
      window.scrollTo(0, 0);
    }
  };

  const handleSaveOnboardingSetup = async () => {
    setLoading(true);
    try {
      let orgId = localStorage.getItem('organization_id');

      if (!orgId) {
        const userData = localStorage.getItem('user');
        if (!userData) {
          alert('User session not found. Please login again.');
          setLoading(false);
          return;
        }
        const user = JSON.parse(userData);
        const initResult = await onboardingAPI.create({
          org_name: formData.orgName || `${user.first_name} ${user.last_name}'s Business`,
          branch_name: formData.branchName || 'Main Branch',
          branch_code: formData.branchCode || 'MAIN',
          city: formData.city,
          state: formData.state,
          gst_number: formData.gstin,
          contact_phone: user.phone || '',
        });
        if (!initResult.data?.organization?.id) {
          alert('Failed to create organization');
          setLoading(false);
          return;
        }
        orgId = initResult.data.organization.id;
        localStorage.setItem('organization_id', orgId as string);
      }

      await onboardingAPI.setup({
        business_type: formData.businessType || undefined,
        org_details: {
          org_name: formData.orgName,
          gstin: formData.gstin,
          city: formData.city,
          state: formData.state,
          phone: formData.phone,
        },
        branch_details: {
          branch_name: formData.branchName,
          branch_code: formData.branchCode,
          address: formData.address,
          city: formData.city,
          branch_state: formData.state,
          pincode: formData.pincode,
        },
        operating_model: formData.operatingModel,
      });

      setStep(step + 1);
      window.scrollTo(0, 0);
    } catch (error) {
      console.error('Onboarding setup error:', error);
      alert((error as Error).message || 'Failed to save setup details');
    } finally {
      setLoading(false);
    }
  };

  const handleDemoMode = () => {
    router.push('/dashboard?demo=true');
  };

  const handleComplete = () => {
    trackOnboardingEvent(ANALYTICS_EVENTS.ONBOARDING_COMPLETED, 5, 'complete');
    setShowConfetti(true);
    setTimeout(() => {
      window.location.href = '/dashboard';
    }, 2000);
  };

  // Screen 1: Welcome
  const renderWelcome = () => (
    <div className="w-full max-w-5xl mx-auto">
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 lg:gap-12 items-center">

        {/* Left: Hero */}
        <div>
          <div className="inline-flex items-center gap-2 bg-primary/10 text-primary text-xs font-semibold px-3 py-1.5 rounded-full mb-4">
            <Sparkles className="w-3.5 h-3.5" />
            Distribution software built for India
          </div>
          <h1 className="text-3xl sm:text-4xl lg:text-5xl font-bold text-text-primary mb-3 leading-tight">
            Welcome to<br />
            <span className="text-primary">OrdWave</span>
          </h1>
          <p className="text-sm sm:text-base text-text-secondary mb-5 leading-relaxed">
            Manage orders, credit, GST invoicing and deliveries —
            all in one place. Built for Indian distributors.
          </p>

          {/* Stats row */}
          <div className="flex items-center gap-5 mb-6">
            {[
              { label: '4 steps', sub: 'to get started' },
              { label: '~3 min', sub: 'to complete' },
              { label: '30 days', sub: 'free trial' },
            ].map(({ label, sub }) => (
              <div key={label}>
                <div className="font-bold text-text-primary text-sm">{label}</div>
                <div className="text-xs text-text-secondary">{sub}</div>
              </div>
            ))}
          </div>

          {/* CTAs */}
          <div className="flex flex-col sm:flex-row gap-3 mb-6">
            <Button onClick={handleNext} className="px-7 py-2.5 text-sm sm:text-base">
              Start Setup
              <ArrowRight className="ml-2 w-4 h-4" />
            </Button>
            <Button onClick={handleDemoMode} variant="outline" className="px-7 py-2.5 text-sm sm:text-base">
              Explore Demo
            </Button>
          </div>

          {/* Social proof */}
          <div className="flex items-center gap-2">
            <div className="flex -space-x-1.5">
              {['bg-primary', 'bg-sky-500', 'bg-violet-500', 'bg-amber-500'].map((c, i) => (
                <div key={i} className={`w-6 h-6 ${c} rounded-full border-2 border-white`} />
              ))}
            </div>
            <span className="text-xs text-text-secondary">Trusted by 2,000+ distributors</span>
          </div>
        </div>

        {/* Right: Feature list */}
        <div className="space-y-3">
          {[
            { icon: Wifi,       bg: 'bg-primary-50',  color: 'text-primary',    label: 'Offline-First',        desc: 'Keep selling without internet — syncs automatically when back online.' },
            { icon: CreditCard, bg: 'bg-sky-50',      color: 'text-sky-600',    label: 'Credit Management',    desc: 'Set credit limits, track dues and automate payment reminders.' },
            { icon: Receipt,    bg: 'bg-violet-50',   color: 'text-violet-600', label: 'GST-Ready Invoicing',  desc: 'Auto-calculate GST, generate e-invoices and file returns easily.' },
            { icon: TrendingUp, bg: 'bg-amber-50',    color: 'text-amber-600',  label: 'Live Order Tracking',  desc: 'Real-time delivery updates for you and your retailers via mobile.' },
          ].map(({ icon: Icon, bg, color, label, desc }) => (
            <div key={label} className="flex items-start gap-4 p-4 bg-white rounded-xl border border-border hover:shadow-sm transition-shadow">
              <div className={`w-10 h-10 ${bg} rounded-xl flex items-center justify-center flex-shrink-0`}>
                <Icon className={`w-5 h-5 ${color}`} />
              </div>
              <div>
                <p className="text-sm font-semibold text-text-primary mb-0.5">{label}</p>
                <p className="text-xs text-text-secondary leading-relaxed">{desc}</p>
              </div>
            </div>
          ))}
        </div>

      </div>
    </div>
  );

  // â”€â”€ Step 2: Business Setup (type + operating model) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  const renderBusinessSetup = () => (
    <div className="max-w-3xl mx-auto px-4">
      {/* Business type */}
      <div className="mb-5">
        <div className="text-center mb-3">
          <h2 className="text-xl sm:text-2xl font-bold text-text-primary mb-1">
            What type of business do you run?
          </h2>
          <div className="inline-flex items-center justify-center gap-1.5 group relative">
            <p className="text-xs text-text-secondary">
              Your selection pre-configures GST rates, credit terms &amp; workflows
            </p>
            <HelpCircle className="w-3.5 h-3.5 text-text-secondary cursor-help flex-shrink-0" />
            <div className="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 hidden group-hover:block z-50 pointer-events-none">
              <div className="bg-gray-900 text-white text-xs rounded-lg px-3 py-2 w-64 shadow-xl">
                <p className="font-semibold mb-1">What gets pre-configured:</p>
                <ul className="space-y-0.5 text-gray-300">
                  <li>• GST tax slabs &amp; default HSN codes</li>
                  <li>• Credit period &amp; limit defaults</li>
                  <li>• Invoice &amp; order workflow templates</li>
                  <li>• Product category presets</li>
                </ul>
                <div className="absolute top-full left-1/2 -translate-x-1/2 border-4 border-transparent border-t-gray-900" />
              </div>
            </div>
          </div>
        </div>
        <div className="grid grid-cols-2 gap-2 sm:gap-3">
          {BUSINESS_TYPES.map((type) => {
            const Icon = type.icon;
            const isSelected = formData.businessType === type.id;
            return (
              <Card
                key={type.id}
                className={`p-3 sm:p-4 cursor-pointer transition-all duration-200 hover:shadow-md hover:-translate-y-0.5 ${
                  isSelected ? 'border-2 border-primary bg-primary-50 shadow-md' : 'border-2 border-border hover:border-primary/40'
                }`}
                onClick={() => setFormData({ ...formData, businessType: type.id as BusinessType })}
              >
                <div className="flex items-center gap-3">
                  <div className={`w-10 h-10 ${type.iconBg} rounded-xl flex items-center justify-center flex-shrink-0`}>
                    <Icon className={`w-5 h-5 ${type.iconColor}`} />
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-1.5 mb-0.5">
                      <h3 className="text-sm font-semibold text-text-primary">{type.label}</h3>
                      {isSelected && <CheckCircle2 className="w-3.5 h-3.5 text-primary flex-shrink-0" />}
                    </div>
                    <p className="text-xs text-text-secondary">{type.desc}</p>
                    <p className={`text-xs font-medium mt-0.5 ${isSelected ? 'text-primary' : 'text-text-secondary'}`}>{type.hint}</p>
                  </div>
                </div>
              </Card>
            );
          })}
        </div>
      </div>

      {/* Operating model — compact horizontal chips */}
      <div className="mb-5">
        <p className="text-xs font-semibold text-text-primary mb-2">How do you sell? <span className="text-text-secondary font-normal">(pick all that apply)</span></p>
        <div className="flex flex-col sm:flex-row gap-2">
          {[
            { id: 'credit', label: 'Credit sales', desc: '30–90 day terms', icon: CreditCard, iconBg: 'bg-sky-100', iconColor: 'text-sky-600' },
            { id: 'cash', label: 'Cash only', desc: 'Immediate payment', icon: Receipt, iconBg: 'bg-emerald-100', iconColor: 'text-emerald-600' },
            { id: 'mixed', label: 'Mixed', desc: 'Credit & cash', icon: TrendingUp, iconBg: 'bg-violet-100', iconColor: 'text-violet-600' },
          ].map((model) => {
            const Icon = model.icon;
            const isSelected = formData.operatingModel.includes(model.id as OperatingModel);
            return (
              <button
                key={model.id}
                type="button"
                className={`flex-1 flex items-center gap-3 p-3 rounded-xl border-2 text-left transition-all duration-200 ${
                  isSelected ? 'border-primary bg-primary-50' : 'border-border hover:border-primary/40 bg-white'
                }`}
                onClick={() => {
                  const current = formData.operatingModel;
                  const updated = isSelected ? current.filter(m => m !== model.id) : [...current, model.id as OperatingModel];
                  setFormData({ ...formData, operatingModel: updated });
                }}
              >
                <div className={`w-8 h-8 ${model.iconBg} rounded-lg flex items-center justify-center flex-shrink-0`}>
                  <Icon className={`w-4 h-4 ${model.iconColor}`} />
                </div>
                <div className="min-w-0">
                  <p className="text-sm font-semibold text-text-primary">{model.label}</p>
                  <p className="text-xs text-text-secondary">{model.desc}</p>
                </div>
                {isSelected && <CheckCircle2 className="w-4 h-4 text-primary ml-auto flex-shrink-0" />}
              </button>
            );
          })}
        </div>
        {formData.operatingModel.includes('credit') && (
          <div className="mt-2 bg-sky-50 border border-sky-200 rounded-lg px-3 py-2 text-xs text-sky-700">
            Default credit policy: 30-day period · ₹50,000 limit · 2% monthly interest — editable later
          </div>
        )}
      </div>

      <div className="flex justify-between gap-2">
        <Button onClick={handleBack} variant="outline">
          <ArrowLeft className="mr-2 w-4 h-4" />Back
        </Button>
        <Button onClick={handleNext} disabled={!formData.businessType || formData.operatingModel.length === 0}>
          Continue<ArrowRight className="ml-2 w-4 h-4" />
        </Button>
      </div>
    </div>
  );

  // â”€â”€ Step 3: Business Details (org + branch merged) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  const renderBusinessDetails = () => (
    <div className="max-w-2xl mx-auto px-4">
      <div className="mb-3">
        <h2 className="text-xl sm:text-2xl font-bold text-text-primary mb-0.5">Your Business Details</h2>
        <p className="text-xs text-text-secondary">This creates your organisation and first branch</p>
      </div>

      <div className="space-y-3">
        {/* Organisation */}
        <Card className="p-4">
          <p className="text-xs font-bold text-text-secondary uppercase tracking-wide mb-3">Organisation</p>
          <div className="space-y-2.5">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-semibold text-text-primary mb-1">Org Name *</label>
                <Input value={formData.orgName} onChange={(e) => setFormData({ ...formData, orgName: e.target.value })} placeholder="Sharma Distributors" className="text-sm" />
              </div>
              <div>
                <label className="block text-xs font-semibold text-text-primary mb-1">Phone *</label>
                <Input value={formData.phone} onChange={(e) => setFormData({ ...formData, phone: e.target.value })} placeholder="+91 98765 43210" className="text-sm" />
              </div>
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-semibold text-text-primary mb-1">State *</label>
                <SearchableSelect
                  options={INDIAN_STATES.map(s => ({ value: s, label: s }))}
                  value={formData.state}
                  onChange={(value) => setFormData({ ...formData, state: value })}
                  placeholder="Select state"
                />
              </div>
              <div>
                <label className="block text-xs font-semibold text-text-primary mb-1">GSTIN *</label>
                <div className="relative">
                  <Input
                    value={formData.gstin}
                    onChange={(e) => {
                      const value = e.target.value.toUpperCase();
                      if (value.length >= 12) {
                        const pan = value.substring(2, 12);
                        setFormData(prev => ({ ...prev, gstin: value, pan }));
                      } else {
                        setFormData({ ...formData, gstin: value });
                      }
                      if (value.length === 15) validateGSTIN(value);
                    }}
                    placeholder="29ABCDE1234F1Z5"
                    maxLength={15}
                    className="text-sm pr-8"
                  />
                  {formData.gstin.length === 15 && (
                    <div className="absolute right-2 top-1/2 -translate-y-1/2">
                      {gstinValid ? <CheckCircle2 className="w-4 h-4 text-success" /> : <X className="w-4 h-4 text-danger" />}
                    </div>
                  )}
                </div>
                <p className="text-xs text-text-secondary mt-0.5">Format: 29ABCDE1234F1Z5</p>
              </div>
            </div>
            <div>
              <label className="block text-xs font-semibold text-text-primary mb-1">PAN *</label>
              <Input value={formData.pan} onChange={(e) => setFormData({ ...formData, pan: e.target.value.toUpperCase() })} placeholder="ABCDE1234F" maxLength={10} className="text-sm" />
            </div>
          </div>
        </Card>

        {/* Branch */}
        <Card className="p-4">
          <p className="text-xs font-bold text-text-secondary uppercase tracking-wide mb-3">Primary Branch</p>
          <div className="space-y-2.5">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-semibold text-text-primary mb-1">Branch Name *</label>
                <Input value={formData.branchName} onChange={(e) => setFormData({ ...formData, branchName: e.target.value })} placeholder="Head Office" className="text-sm" />
              </div>
              <div>
                <label className="block text-xs font-semibold text-text-primary mb-1">Branch Code *</label>
                <Input value={formData.branchCode} onChange={(e) => setFormData({ ...formData, branchCode: e.target.value.toUpperCase() })} placeholder="HQ-01" className="text-sm" />
              </div>
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div className="relative">
                <label className="block text-xs font-semibold text-text-primary mb-1">Pincode *</label>
                <Input value={formData.pincode} onChange={(e) => setFormData({ ...formData, pincode: e.target.value.replace(/\D/g, '') })} placeholder="400001" maxLength={6} className="text-sm" />
                {pincodeLoading && <Loader2 className="absolute right-3 top-7 h-4 w-4 animate-spin text-text-secondary" />}
              </div>
              <div>
                <label className="block text-xs font-semibold text-text-primary mb-1">City *</label>
                <Input value={formData.city} onChange={(e) => setFormData({ ...formData, city: e.target.value })} placeholder="Auto-filled from pincode" className="text-sm" />
              </div>
            </div>
            <div>
              <label className="block text-xs font-semibold text-text-primary mb-1">Address *</label>
              <Input value={formData.address} onChange={(e) => setFormData({ ...formData, address: e.target.value })} placeholder="Street address" className="text-sm" />
            </div>
          </div>
        </Card>
      </div>

      <div className="flex justify-between gap-2 mt-4">
        <Button onClick={handleBack} variant="outline">
          <ArrowLeft className="mr-2 w-4 h-4" />Back
        </Button>
        <Button
          onClick={handleNext}
          disabled={loading || !formData.orgName || !formData.phone || !formData.state || !formData.gstin || !formData.pan || !formData.branchName || !formData.branchCode || !formData.pincode || !formData.city || !formData.address}
        >
          {loading ? <Loader2 className="mr-2 w-4 h-4 animate-spin" /> : null}
          {loading ? 'Saving...' : 'Continue'}
          {!loading && <ArrowRight className="ml-2 w-4 h-4" />}
        </Button>
      </div>
    </div>
  );

  // â”€â”€ Step 4: Quick Start (optional retailer + product) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  const renderQuickStart = () => (
    <div className="max-w-2xl mx-auto px-4">
      <div className="mb-4">
        <h2 className="text-xl sm:text-2xl font-bold text-text-primary mb-0.5">Quick Start <span className="text-base font-normal text-text-secondary">— optional</span></h2>
        <p className="text-xs text-text-secondary">Add your first retailer and product to hit the ground running. You can do this later too.</p>
      </div>

      <div className="space-y-3">
        {/* Retailer toggle */}
        <Card className={`transition-all duration-200 ${addRetailer ? 'border-primary' : ''}`}>
          <button
            type="button"
            className="w-full p-4 flex items-center gap-3 text-left"
            onClick={() => setAddRetailer(!addRetailer)}
          >
            <div className={`w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0 ${addRetailer ? 'bg-primary-50' : 'bg-background-subtle'}`}>
              <Users className={`w-4 h-4 ${addRetailer ? 'text-primary' : 'text-text-secondary'}`} />
            </div>
            <div className="flex-1">
              <p className="text-sm font-semibold text-text-primary">Add a retailer</p>
              <p className="text-xs text-text-secondary">Your first customer on the platform</p>
            </div>
            <ChevronDown className={`w-4 h-4 text-text-secondary transition-transform ${addRetailer ? 'rotate-180' : ''}`} />
          </button>
          {addRetailer && (
            <div className="px-4 pb-4 space-y-2.5 border-t border-border pt-3">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-semibold text-text-primary mb-1">Name *</label>
                  <Input value={formData.retailerName} onChange={(e) => setFormData({ ...formData, retailerName: e.target.value })} placeholder="Fresh Mart" className="text-sm" />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-text-primary mb-1">Phone *</label>
                  <Input value={formData.retailerPhone} onChange={(e) => setFormData({ ...formData, retailerPhone: e.target.value })} placeholder="+91 98765 43210" className="text-sm" />
                </div>
              </div>
              <div>
                <label className="block text-xs font-semibold text-text-primary mb-1">Area / Location *</label>
                <Input value={formData.retailerArea} onChange={(e) => setFormData({ ...formData, retailerArea: e.target.value })} placeholder="Andheri West" className="text-sm" />
              </div>
            </div>
          )}
        </Card>

        {/* Product toggle */}
        <Card className={`transition-all duration-200 ${addProduct ? 'border-primary' : ''}`}>
          <button
            type="button"
            className="w-full p-4 flex items-center gap-3 text-left"
            onClick={() => setAddProduct(!addProduct)}
          >
            <div className={`w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0 ${addProduct ? 'bg-primary-50' : 'bg-background-subtle'}`}>
              <Package className={`w-4 h-4 ${addProduct ? 'text-primary' : 'text-text-secondary'}`} />
            </div>
            <div className="flex-1">
              <p className="text-sm font-semibold text-text-primary">Add a product</p>
              <p className="text-xs text-text-secondary">Set up your first SKU with GST</p>
            </div>
            <ChevronDown className={`w-4 h-4 text-text-secondary transition-transform ${addProduct ? 'rotate-180' : ''}`} />
          </button>
          {addProduct && (
            <div className="px-4 pb-4 space-y-2.5 border-t border-border pt-3">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-semibold text-text-primary mb-1">Product Name *</label>
                  <Input value={formData.productName} onChange={(e) => setFormData({ ...formData, productName: e.target.value })} placeholder="Basmati Rice 5kg" className="text-sm" />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-text-primary mb-1">SKU Code *</label>
                  <Input value={formData.productSKU} onChange={(e) => setFormData({ ...formData, productSKU: e.target.value.toUpperCase() })} placeholder="RICE-BAS-5KG" className="text-sm" />
                </div>
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-semibold text-text-primary mb-1">HSN Code *</label>
                  <div className="relative">
                    <Input
                      value={formData.productHSN}
                      onChange={(e) => {
                        const val = e.target.value;
                        setFormData(prev => ({ ...prev, productHSN: val, ...(val === '1006' ? { productGST: '5' } : {}) }));
                      }}
                      placeholder="1006"
                      className="text-sm"
                    />
                    {formData.productHSN && <CheckCircle2 className="absolute right-2 top-1/2 -translate-y-1/2 w-4 h-4 text-success" />}
                  </div>
                </div>
                <div>
                  <label className="block text-xs font-semibold text-text-primary mb-1">GST Rate (%) *</label>
                  <Input value={formData.productGST} onChange={(e) => setFormData({ ...formData, productGST: e.target.value })} placeholder="5, 12, 18, 28" disabled={formData.productHSN === '1006'} className="text-sm" />
                </div>
              </div>
            </div>
          )}
        </Card>
      </div>

      <div className="flex justify-between gap-2 mt-4">
        <Button onClick={handleBack} variant="outline">
          <ArrowLeft className="mr-2 w-4 h-4" />Back
        </Button>
        <div className="flex gap-2">
          <Button variant="outline" onClick={handleNext}>
            Skip
          </Button>
          <Button onClick={handleNext}>
            Go to Dashboard
            <ArrowRight className="ml-2 w-4 h-4" />
          </Button>
        </div>
      </div>
    </div>
  );

  // â”€â”€ Step 5: Complete â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  const renderComplete = () => (
    <div className="max-w-lg mx-auto px-4 text-center">
      <div className="mb-6">
        <div className="inline-flex items-center justify-center w-20 h-20 bg-primary-50 rounded-full mb-4">
          <Check className="w-10 h-10 text-primary" />
        </div>
        <h2 className="text-2xl sm:text-3xl font-bold text-text-primary mb-2">You&apos;re all set!</h2>
        <p className="text-text-secondary text-sm">Your business is configured and ready to use.</p>
      </div>

      <div className="grid grid-cols-3 gap-3 mb-8">
        {[
          { icon: Package, label: 'Add more products', color: 'bg-amber-50 text-amber-600' },
          { icon: Users, label: 'Invite your team', color: 'bg-sky-50 text-sky-600' },
          { icon: ShoppingCart, label: 'Place first order', color: 'bg-primary-50 text-primary' },
        ].map(({ icon: Icon, label, color }) => (
          <div key={label} className="text-center p-3 rounded-xl bg-white border border-border">
            <div className={`w-9 h-9 ${color} rounded-lg flex items-center justify-center mx-auto mb-2`}>
              <Icon className="w-4 h-4" />
            </div>
            <p className="text-xs text-text-secondary">{label}</p>
          </div>
        ))}
      </div>

      <Button onClick={handleComplete} className="w-full sm:w-auto px-8">
        Go to Dashboard
        <ArrowRight className="ml-2 w-4 h-4" />
      </Button>
    </div>
  );

  // â”€â”€ Router â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  const renderStep = () => {
    switch (step) {
      case 1: return renderWelcome();
      case 2: return renderBusinessSetup();
      case 3: return renderBusinessDetails();
      case 4: return renderQuickStart();
      case 5: return renderComplete();
      default: return null;
    }
  };

  return (
    <div className="h-screen flex flex-col bg-background-subtle overflow-hidden">
      {/* â”€â”€ Phase Step Indicator â”€â”€ */}
      {step > 1 && (
        <div className="bg-white border-b border-border flex-shrink-0">
          <div className="max-w-4xl mx-auto px-4 sm:px-6 py-3">

            {/* Mobile: progress bar */}
            <div className="flex sm:hidden items-center gap-3">
              <div className="flex-1">
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-xs font-semibold text-primary">
                    {ONBOARDING_PHASES.find(p => p.steps.includes(step as never))?.label}
                  </span>
                  <span className="text-xs text-text-secondary">Step {step - 1} of 4</span>
                </div>
                <div className="h-1.5 bg-border rounded-full overflow-hidden">
                  <div className="h-full bg-primary rounded-full transition-all duration-500" style={{ width: `${((step - 1) / 4) * 100}%` }} />
                </div>
              </div>
            </div>

            {/* Desktop: phase circles */}
            <div className="hidden sm:flex items-center gap-2">
              <span className="text-[11px] font-medium text-text-secondary bg-background-subtle border border-border rounded-full px-2.5 py-0.5 whitespace-nowrap flex-shrink-0">
                {step - 1} / 4
              </span>
              <div className="flex-1 flex items-center">
                {ONBOARDING_PHASES.map((phase, idx) => {
                  const isCompleted = step > Math.max(...phase.steps);
                  const isCurrent   = phase.steps.includes(step as never);
                  const isClickable = isCompleted;
                  const firstStep   = Math.min(...phase.steps);
                  return (
                    <div key={phase.label} className="contents">
                      {idx > 0 && (
                        <div className={`h-0.5 flex-1 mx-2 rounded-full transition-colors duration-300 ${
                          step > Math.max(...ONBOARDING_PHASES[idx - 1].steps) ? 'bg-primary' : 'bg-border'
                        }`} />
                      )}
                      <button
                        title={isCompleted ? `Go back to ${phase.label}` : undefined}
                        onClick={() => { if (isClickable) { setStep(firstStep); window.scrollTo(0, 0); } }}
                        disabled={!isClickable}
                        className={`flex flex-col items-center gap-1 flex-shrink-0 focus:outline-none group ${isClickable ? 'cursor-pointer' : 'cursor-default'}`}
                      >
                        <div className={`flex h-8 w-8 items-center justify-center rounded-full text-xs font-bold transition-all duration-200 ${
                          isCompleted ? 'bg-primary text-white shadow-sm group-hover:scale-110 group-hover:shadow-md'
                            : isCurrent ? 'bg-primary text-white shadow-md ring-4 ring-primary/20'
                            : 'border-2 border-border bg-white text-text-secondary'
                        }`}>
                          {isCompleted ? <Check className="h-3.5 w-3.5" /> : <span>{idx + 1}</span>}
                        </div>
                        <span className={`text-[10px] font-medium whitespace-nowrap transition-colors ${
                          isCurrent ? 'text-primary' : isCompleted ? 'text-text-primary group-hover:text-primary' : 'text-text-secondary'
                        }`}>
                          {phase.label}
                        </span>
                      </button>
                    </div>
                  );
                })}
              </div>
              <div className="w-12 flex-shrink-0" />
            </div>

          </div>
        </div>
      )}

      {/* Content */}
      <div className={`flex-1 px-4 sm:px-6 ${
        step === 1 ? 'overflow-hidden flex items-center' : 'overflow-y-auto py-8 sm:py-10'
      }`}>
        {renderStep()}
      </div>

      {/* Confetti */}
      {showConfetti && (
        <div className="fixed inset-0 pointer-events-none z-50 flex items-center justify-center">
          <div className="text-9xl animate-bounce">🎉</div>
          <div className="absolute top-1/4 left-1/4 text-6xl animate-ping">✨</div>
          <div className="absolute top-1/3 right-1/4 text-6xl animate-ping delay-100">🎊</div>
          <div className="absolute bottom-1/3 left-1/3 text-6xl animate-ping delay-200">⭐</div>
        </div>
      )}
    </div>
  );
}

