'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { onboardingAPI } from '@/lib/onboarding-api';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { 
  CheckCircle2, 
  Upload, 
  Download,
  MapPin,
  Wifi,
  CreditCard,
  Receipt,
  TrendingUp,
  Users,
  Package,
  ShoppingCart,
  Building,
  User,
  Truck,
  Calculator,
  FileSpreadsheet,
  Smartphone,
  QrCode,
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
  { id: 'rice', label: 'Rice Distributor', icon: '🌾', desc: 'Optimized for rice & grain trading' },
  { id: 'fmcg', label: 'FMCG Distributor', icon: '🛒', desc: 'Fast-moving consumer goods' },
  { id: 'wholesale', label: 'Wholesale Grocery', icon: '🏪', desc: 'Bulk grocery distribution' },
  { id: 'custom', label: 'Custom', icon: '⚙️', desc: 'Configure from scratch' },
];

const ROLES = [
  { id: 'branch_manager', label: 'Branch Manager', icon: Building, color: 'bg-primary' },
  { id: 'sales_rep', label: 'Sales Rep', icon: User, color: 'bg-accent' },
  { id: 'driver', label: 'Driver', icon: Truck, color: 'bg-secondary' },
  { id: 'accountant', label: 'Accounts', icon: Calculator, color: 'bg-warning' },
];

export default function OnboardingWizardPage() {
  const router = useRouter();
  const [step, setStep] = useState(1);
  const [loading, setLoading] = useState(false);
  const [gstinValid, setGstinValid] = useState<boolean | null>(null);
  const [showConfetti, setShowConfetti] = useState(false);
  const [hasRetailer, setHasRetailer] = useState(false);
  const [hasProduct, setHasProduct] = useState(false);
  
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

  // Auto-fill city & state from pincode lookup
  useEffect(() => {
    if (pcCity) setFormData((prev) => ({ ...prev, city: pcCity }));
    if (pcState) setFormData((prev) => ({ ...prev, state: pcState }));
  }, [pcCity, pcState]);

  const totalSteps = 11;
  const progress = (step / totalSteps) * 100;

  const validateGSTIN = (value: string) => {
    const gstinRegex = /^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$/;
    const isValid = gstinRegex.test(value);
    setGstinValid(isValid);
    return isValid;
  };

  const handleNext = () => {
    if (step < totalSteps) {
      // Call onboarding API when completing branch setup (step 4)
      if (step === 4) {
        handleSaveOnboardingSetup();
      } else {
        proceedToNextStep();
      }
    }
  };

  const handleSaveOnboardingSetup = async () => {
    try {
      // Initialize organization if not already done
      let orgId = localStorage.getItem('organization_id');
      
      if (!orgId) {
        // First time - create organization
        const userData = localStorage.getItem('user');
        if (!userData) {
          alert('User session not found. Please login again.');
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

      // Proceed to next step after successful save
      proceedToNextStep();
    } catch (error) {
      console.error('Onboarding setup error:', error);
      alert((error as Error).message || 'Failed to save onboarding details');
    }
  };

  const proceedToNextStep = () => {
    // Skip step 9 (Create Order) if retailer or product is missing
    if (step === 8 && (!hasRetailer || !hasProduct)) {
      setStep(10); // Skip directly to step 10 (Invite Team)
    } else {
      setStep(step + 1);
    }
    window.scrollTo(0, 0);
  };

  const handleBack = () => {
    if (step > 1) {
      // Skip step 9 when going back if retailer or product is missing
      if (step === 10 && (!hasRetailer || !hasProduct)) {
        setStep(8); // Go back to step 8 (Add Product)
      } else {
        setStep(step - 1);
      }
    }
  };

  const handleDemoMode = () => {
    router.push('/dashboard?demo=true');
  };

  const handleComplete = () => {
    setShowConfetti(true);
    setTimeout(() => {
      router.push('/activation');
    }, 2000);
  };

  // Screen 1: Welcome
  const renderWelcome = () => (
    <div className="max-w-4xl mx-auto text-center px-4 flex flex-col justify-between h-full">
      <div className="mb-4 sm:mb-6">
        <div className="inline-flex items-center justify-center w-16 h-16 sm:w-20 sm:h-20 bg-primary-50 rounded-2xl mb-3 sm:mb-4">
          <Sparkles className="w-8 h-8 sm:w-10 sm:h-10 text-primary" />
        </div>
        <h1 className="text-3xl sm:text-4xl font-bold text-text-primary mb-2 sm:mb-3">
          Welcome to OmniDist OMS
        </h1>
        <p className="text-lg sm:text-lg text-text-secondary mb-1">
          Setup takes 5 minutes
        </p>
        <p className="text-sm text-text-secondary">
          Complete your business setup and start managing orders
        </p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-2 sm:gap-3 mb-4 sm:mb-6 flex-1 flex items-center">
        <Card className="p-3 sm:p-4 text-center hover:shadow-md transition-shadow">
          <Wifi className="w-5 h-5 sm:w-6 sm:h-6 text-primary mx-auto mb-1 sm:mb-2" />
          <p className="text-xs font-semibold text-text-primary mb-1">Offline-First</p>
          <p className="text-xs text-text-secondary hidden sm:block">Works without internet</p>
        </Card>
        <Card className="p-3 sm:p-4 text-center hover:shadow-md transition-shadow">
          <CreditCard className="w-5 h-5 sm:w-6 sm:h-6 text-primary mx-auto mb-1 sm:mb-2" />
          <p className="text-xs font-semibold text-text-primary mb-1">Credit-First</p>
          <p className="text-xs text-text-secondary hidden sm:block">Flexible payment terms</p>
        </Card>
        <Card className="p-3 sm:p-4 text-center hover:shadow-md transition-shadow">
          <Receipt className="w-5 h-5 sm:w-6 sm:h-6 text-primary mx-auto mb-1 sm:mb-2" />
          <p className="text-xs font-semibold text-text-primary mb-1">GST-Ready</p>
          <p className="text-xs text-text-secondary hidden sm:block">Compliant invoicing</p>
        </Card>
        <Card className="p-3 sm:p-4 text-center hover:shadow-md transition-shadow">
          <TrendingUp className="w-5 h-5 sm:w-6 sm:h-6 text-primary mx-auto mb-1 sm:mb-2" />
          <p className="text-xs font-semibold text-text-primary mb-1">Real-Time Tracking</p>
          <p className="text-xs text-text-secondary hidden sm:block">Delivery updates</p>
        </Card>
      </div>

      <div className="flex flex-col sm:flex-row gap-2 sm:gap-3 justify-center mt-auto">
        <Button 
          onClick={handleNext} 
          className="text-sm sm:text-base px-4 sm:px-6 py-2 sm:py-3"
        >
          Start Setup
          <ArrowRight className="ml-2 w-4 h-4" />
        </Button>
        <Button onClick={handleDemoMode} variant="outline" className="text-sm sm:text-base px-4 sm:px-6 py-2 sm:py-3">
          Load Demo Mode
        </Button>
      </div>
    </div>
  );

  // Screen 2: Business Type Selection
  const renderBusinessType = () => (
    <div className="max-w-3xl mx-auto px-4">
      <div className="text-center mb-3 sm:mb-4">
        <h2 className="text-xl sm:text-2xl font-bold text-text-primary mb-1">
          What type of business do you run?
        </h2>
        <p className="text-xs text-text-secondary flex items-center justify-center gap-2">
          This pre-configures GST & credit settings
          <HelpCircle className="w-3 h-3 text-text-secondary cursor-help" />
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-2 sm:gap-3 mb-3 sm:mb-4">
        {BUSINESS_TYPES.map((type) => (
          <Card
            key={type.id}
            className={`p-3 sm:p-4 cursor-pointer transition-all hover:shadow-lg ${
              formData.businessType === type.id
                ? 'border-2 border-primary bg-primary-50'
                : 'border-2 border-transparent'
            }`}
            onClick={() => setFormData({ ...formData, businessType: type.id as BusinessType })}
          >
            <div className="flex items-start gap-3">
              <div className="text-2xl">{type.icon}</div>
              <div className="flex-1">
                <div className="flex items-center gap-2 mb-1">
                  <h3 className="text-sm font-semibold text-text-primary">{type.label}</h3>
                  {formData.businessType === type.id && (
                    <CheckCircle2 className="w-4 h-4 text-primary" />
                  )}
                </div>
                <p className="text-xs text-text-secondary">{type.desc}</p>
              </div>
            </div>
          </Card>
        ))}
      </div>

      <div className="flex flex-col sm:flex-row justify-between gap-2 mt-3">
        <Button onClick={handleBack} variant="outline" size="sm">
          <ArrowLeft className="mr-2 w-4 h-4" />
          Back
        </Button>
        <Button onClick={handleNext} disabled={!formData.businessType} size="sm">
          Continue
          <ArrowRight className="ml-2 w-4 h-4" />
        </Button>
      </div>
    </div>
  );

  // Screen 3: Organization Details
  const renderOrgDetails = () => (
    <div className="max-w-2xl mx-auto px-4">
      <div className="mb-3 sm:mb-4">
        <h2 className="text-xl sm:text-2xl font-bold text-text-primary mb-1">
          Organization Details
        </h2>
      </div>

      <Card className="p-4 sm:p-5">
        <div className="space-y-2 sm:space-y-3">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-semibold text-text-primary mb-1">
                Org Name *
              </label>
              <Input
                value={formData.orgName}
                onChange={(e) => setFormData({ ...formData, orgName: e.target.value })}
                placeholder="Sharma Distributors"
                className="text-sm"
              />
            </div>
            <div>
              <label className="block text-xs font-semibold text-text-primary mb-1">
                Phone *
              </label>
              <Input
                value={formData.phone}
                onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                placeholder="+91 98765 43210"
                className="text-sm"
              />
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-semibold text-text-primary mb-1">
                State *
              </label>
              <SearchableSelect
                options={INDIAN_STATES.map(state => ({ value: state, label: state }))}
                value={formData.state}
                onChange={(value) => setFormData({ ...formData, state: value })}
                placeholder="Select state"
              />
            </div>
            <div>
              <label className="block text-xs font-semibold text-text-primary mb-1">
                GSTIN *
              </label>
              <div className="relative">
                <Input
                  value={formData.gstin}
                  onChange={(e) => {
                    const value = e.target.value.toUpperCase();
                    setFormData({ ...formData, gstin: value });
                    if (value.length === 15) validateGSTIN(value);
                    // Auto-fill PAN from GSTIN (characters 2-12 are the PAN)
                    if (value.length >= 12) {
                      const pan = value.substring(2, 12);
                      setFormData(prev => ({ ...prev, gstin: value, pan }));
                    }
                  }}
                  placeholder="29ABCDE1234F1Z5"
                  maxLength={15}
                  className="text-sm pr-8"
                />
                {formData.gstin.length === 15 && (
                  <div className="absolute right-2 top-1/2 -translate-y-1/2">
                    {gstinValid ? (
                      <CheckCircle2 className="w-4 h-4 text-success" />
                    ) : (
                      <X className="w-4 h-4 text-danger" />
                    )}
                  </div>
                )}
              </div>
              <p className="text-xs text-text-secondary mt-0.5">Format: 22AAAAA00001Az5 (State code + PAN + checksum)</p>
            </div>
          </div>
          
          <div>
            <label className="block text-xs font-semibold text-text-primary mb-1">
              PAN *
            </label>
            <Input
              value={formData.pan}
              onChange={(e) => setFormData({ ...formData, pan: e.target.value.toUpperCase() })}
              placeholder="ABCDE1234F"
              maxLength={10}
              className="text-sm"
            />
          </div>
        </div>
      </Card>

      <div className="flex flex-col sm:flex-row justify-between gap-2 mt-3">
        <Button onClick={handleBack} variant="outline" size="sm">
          <ArrowLeft className="mr-2 w-4 h-4" />
          Back
        </Button>
        <Button 
          onClick={handleNext}
          size="sm"
          disabled={!formData.orgName || !formData.phone || !formData.state || !formData.gstin || !formData.pan}
        >
          Continue
          <ArrowRight className="ml-2 w-4 h-4" />
        </Button>
      </div>
    </div>
  );

  // Screen 4: Branch Setup
  const renderBranchSetup = () => (
    <div className="max-w-2xl mx-auto px-4">
      <div className="mb-3 sm:mb-4">
        <h2 className="text-xl sm:text-2xl font-bold text-text-primary mb-1">
          Branch Setup
        </h2>
      </div>

      <Card className="p-4 sm:p-5">
        <div className="space-y-2 sm:space-y-3">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-semibold text-text-primary mb-1">
                Branch Name *
              </label>
              <Input
                value={formData.branchName}
                onChange={(e) => setFormData({ ...formData, branchName: e.target.value })}
                placeholder="Head Office"
                className="text-sm"
              />
            </div>
            <div>
              <label className="block text-xs font-semibold text-text-primary mb-1">
                Branch Code *
              </label>
              <Input
                value={formData.branchCode}
                onChange={(e) => setFormData({ ...formData, branchCode: e.target.value.toUpperCase() })}
                placeholder="HQ-01"
                className="text-sm"
              />
            </div>
          </div>

          <div className="relative">
            <label className="block text-xs font-semibold text-text-primary mb-1">
              Pincode *
            </label>
            <Input
              value={formData.pincode}
              onChange={(e) => setFormData({ ...formData, pincode: e.target.value.replace(/\D/g, '') })}
              placeholder="400001"
              maxLength={6}
              className="text-sm"
            />
            {pincodeLoading && (
              <Loader2 className="absolute right-3 top-7 h-4 w-4 animate-spin text-text-secondary" />
            )}
          </div>

          <div>
            <label className="block text-xs font-semibold text-text-primary mb-1">
              Address *
            </label>
            <Input
              value={formData.address}
              onChange={(e) => setFormData({ ...formData, address: e.target.value })}
              placeholder="Street address"
              className="text-sm"
            />
          </div>

          <div>
            <label className="block text-xs font-semibold text-text-primary mb-1">
              City *
            </label>
            <Input
              value={formData.city}
              onChange={(e) => setFormData({ ...formData, city: e.target.value })}
              placeholder="Auto-filled from Pincode"
              className="text-sm"
            />
          </div>

          <div className="flex items-center gap-2">
            <input
              type="checkbox"
              id="singleBranch"
              checked={formData.singleBranch}
              onChange={(e) => setFormData({ ...formData, singleBranch: e.target.checked })}
              className="w-4 h-4 text-primary border-border rounded focus:ring-primary"
            />
            <label htmlFor="singleBranch" className="text-xs text-text-primary cursor-pointer">
              Single branch for now
            </label>
          </div>
        </div>
      </Card>

      <div className="flex flex-col sm:flex-row justify-between gap-2 mt-3">
        <Button onClick={handleBack} variant="outline" size="sm">
          <ArrowLeft className="mr-2 w-4 h-4" />
          Back
        </Button>
        <Button 
          onClick={handleNext}
          size="sm"
          disabled={!formData.branchName || !formData.branchCode || !formData.address || !formData.city || !formData.pincode}
        >
          Continue
          <ArrowRight className="ml-2 w-4 h-4" />
        </Button>
      </div>
    </div>
  );

  // Screen 5: Operating Model
  const renderOperatingModel = () => (
    <div className="max-w-2xl mx-auto px-4">
      <div className="mb-2 sm:mb-3">
        <h2 className="text-xl sm:text-2xl font-bold text-text-primary mb-1">
          Operating Model
        </h2>
      </div>

      <Card className="p-3 sm:p-4">
        <div className="space-y-2 sm:space-y-3 mb-2">
          {[
            { id: 'credit', label: 'Credit sales', desc: '30-90 days', icon: CreditCard },
            { id: 'cash', label: 'Cash only', desc: 'Immediate payment', icon: Receipt },
            { id: 'mixed', label: 'Mixed model', desc: 'Both credit & cash', icon: TrendingUp },
          ].map((model) => {
            const Icon = model.icon;
            const isSelected = formData.operatingModel.includes(model.id as OperatingModel);
            
            return (
              <Card
                key={model.id}
                className={`p-3 cursor-pointer transition-all ${
                  isSelected ? 'border-2 border-primary bg-primary-50' : 'border-2 border-transparent hover:border-primary'
                }`}
                onClick={() => {
                  const current = formData.operatingModel;
                  const updated = isSelected
                    ? current.filter(m => m !== model.id)
                    : [...current, model.id as OperatingModel];
                  setFormData({ ...formData, operatingModel: updated });
                }}
              >
                <div className="flex items-center gap-3">
                  <Icon className="w-5 h-5 text-primary flex-shrink-0" />
                  <div className="flex-1 min-w-0">
                    <p className="font-semibold text-text-primary text-sm">{model.label}</p>
                    <p className="text-xs text-text-secondary">{model.desc}</p>
                  </div>
                  {isSelected && <CheckCircle2 className="w-4 h-4 text-primary flex-shrink-0" />}
                </div>
              </Card>
            );
          })}
        </div>

        {formData.operatingModel.includes('credit') && (
          <div className="bg-primary-50 border border-primary-200 rounded-lg p-2 text-xs">
            <p className="font-semibold text-primary-700 mb-1">Default Credit Policy</p>
            <ul className="text-primary-700 space-y-0.5">
              <li>• 30 day period</li>
              <li>• ₹50,000 limit</li>
              <li>• 2% monthly interest</li>
            </ul>
          </div>
        )}
      </Card>

      <div className="flex flex-col sm:flex-row justify-between gap-2 mt-3">
        <Button onClick={handleBack} variant="outline" size="sm">
          <ArrowLeft className="mr-2 w-4 h-4" />
          Back
        </Button>
        <Button onClick={handleNext} size="sm" disabled={formData.operatingModel.length === 0}>
          Continue
          <ArrowRight className="ml-2 w-4 h-4" />
        </Button>
      </div>
    </div>
  );

  // Screen 6: Import Data
  const renderImportData = () => (
    <div className="max-w-2xl mx-auto px-4">
      <div className="mb-2 sm:mb-3">
        <h2 className="text-xl sm:text-2xl font-bold text-text-primary mb-1">
          Import Existing Data
        </h2>
      </div>

      <div className="space-y-2 sm:space-y-3 mb-3">
        <Card className="p-3 sm:p-4">
          <div className="mb-2">
            <h3 className="text-xs font-semibold text-text-primary mb-0.5">Import Retailers</h3>
            <Button variant="outline" size="sm" className="mb-2">
              <Download className="w-3 h-3 mr-1" />
              Sample
            </Button>
          </div>
          <div className="border-2 border-dashed border-border rounded-lg p-4 text-center hover:bg-background-subtle transition-colors cursor-pointer">
            <Upload className="w-6 h-6 text-text-secondary mx-auto mb-1" />
            <p className="text-xs text-text-primary mb-0.5">Drag & drop CSV</p>
            <p className="text-xs text-text-secondary">or click to browse</p>
          </div>
        </Card>

        <Card className="p-3 sm:p-4">
          <div className="mb-2">
            <h3 className="text-xs font-semibold text-text-primary mb-0.5">Import Products</h3>
            <Button variant="outline" size="sm" className="mb-2">
              <Download className="w-3 h-3 mr-1" />
              Sample
            </Button>
          </div>
          <div className="border-2 border-dashed border-border rounded-lg p-4 text-center hover:bg-background-subtle transition-colors cursor-pointer">
            <Upload className="w-6 h-6 text-text-secondary mx-auto mb-1" />
            <p className="text-xs text-text-primary mb-0.5">Drag & drop CSV</p>
            <p className="text-xs text-text-secondary">or click to browse</p>
          </div>
        </Card>
      </div>

      <div className="flex flex-col sm:flex-row justify-between gap-2 mt-3">
        <Button onClick={handleBack} variant="outline" size="sm">
          <ArrowLeft className="mr-2 w-4 h-4" />
          Back
        </Button>
        <Button onClick={handleNext} variant="outline" size="sm">
          Skip for now
        </Button>
      </div>
    </div>
  );

  // Screen 7: Add First Retailer
  const renderAddRetailer = () => (
    <div className="max-w-2xl mx-auto px-4">
      <div className="mb-2 sm:mb-3">
        <h2 className="text-xl sm:text-2xl font-bold text-text-primary mb-1">
          Add Your First Retailer
        </h2>
      </div>

      <Card className="p-3 sm:p-4">
        <div className="space-y-2 sm:space-y-3">
          <div>
            <label className="block text-xs font-semibold text-text-primary mb-1">
              Retailer Name *
            </label>
            <Input
              value={formData.retailerName}
              onChange={(e) => setFormData({ ...formData, retailerName: e.target.value })}
              placeholder="e.g., Fresh Mart"
              className="text-sm"
            />
          </div>

          <div>
            <label className="block text-xs font-semibold text-text-primary mb-1">
              Phone Number *
            </label>
            <Input
              value={formData.retailerPhone}
              onChange={(e) => setFormData({ ...formData, retailerPhone: e.target.value })}
              placeholder="+91 98765 43210"
              className="text-sm"
            />
          </div>

          <div>
            <label className="block text-xs font-semibold text-text-primary mb-1">
              Area/Location *
            </label>
            <Input
              value={formData.retailerArea}
              onChange={(e) => setFormData({ ...formData, retailerArea: e.target.value })}
              placeholder="e.g., Andheri West"
              className="text-sm"
            />
          </div>

          <div className="bg-accent/10 border border-accent rounded-lg p-2 text-xs">
            <p className="text-text-primary">
              💡 <strong>Tip:</strong> Add more details after setup
            </p>
          </div>
        </div>
      </Card>

      <div className="flex flex-col sm:flex-row justify-between gap-2 mt-3">
        <Button onClick={handleBack} variant="outline" size="sm">
          <ArrowLeft className="mr-2 w-4 h-4" />
          Back
        </Button>
        <div className="flex flex-col sm:flex-row gap-2">
          <Button 
            onClick={() => {
              setHasRetailer(false);
              handleNext();
            }} 
            variant="outline"
            size="sm"
          >
            Skip
          </Button>
          <Button 
            onClick={() => {
              setHasRetailer(true);
              handleNext();
            }}
            size="sm"
            disabled={!formData.retailerName || !formData.retailerPhone || !formData.retailerArea}
          >
            Save & Continue
            <ArrowRight className="ml-2 w-4 h-4" />
          </Button>
        </div>
      </div>
    </div>
  );

  // Screen 8: Add First Product
  const renderAddProduct = () => (
    <div className="max-w-2xl mx-auto px-4">
      <div className="mb-2 sm:mb-3">
        <h2 className="text-xl sm:text-2xl font-bold text-text-primary mb-1">
          Add Your First Product
        </h2>
      </div>

      <Card className="p-3 sm:p-4">
        <div className="space-y-2 sm:space-y-3">
          <div>
            <label className="block text-xs font-semibold text-text-primary mb-1">
              Product Name *
            </label>
            <Input
              value={formData.productName}
              onChange={(e) => setFormData({ ...formData, productName: e.target.value })}
              placeholder="e.g., Basmati Rice 5kg"
              className="text-sm"
            />
          </div>

          <div>
            <label className="block text-xs font-semibold text-text-primary mb-1">
              SKU Code *
            </label>
            <Input
              value={formData.productSKU}
              onChange={(e) => setFormData({ ...formData, productSKU: e.target.value.toUpperCase() })}
              placeholder="e.g., RICE-BAS-5KG"
              className="text-sm"
            />
          </div>

          <div>
            <label className="block text-xs font-semibold text-text-primary mb-1">
              HSN Code *
            </label>
            <div className="relative">
              <Input
                value={formData.productHSN}
                onChange={(e) => {
                  const value = e.target.value;
                  setFormData({ ...formData, productHSN: value });
                  if (value === '1006') {
                    setFormData({ ...formData, productHSN: value, productGST: '5' });
                  }
                }}
                placeholder="e.g., 1006"
                className="text-sm"
              />
              {formData.productHSN && (
                <CheckCircle2 className="absolute right-2 top-1/2 -translate-y-1/2 w-4 h-4 text-success" />
              )}
            </div>
            <p className="text-xs text-text-secondary mt-0.5">Auto-suggests GST rate</p>
          </div>

          <div>
            <label className="block text-xs font-semibold text-text-primary mb-1">
              GST Rate (%) *
            </label>
            <Input
              value={formData.productGST}
              onChange={(e) => setFormData({ ...formData, productGST: e.target.value })}
              placeholder="e.g., 5, 12, 18, 28"
              disabled={formData.productHSN === '1006'}
              className="text-sm"
            />
          </div>
        </div>
      </Card>

      <div className="flex flex-col sm:flex-row justify-between gap-2 mt-3">
        <Button onClick={handleBack} variant="outline" size="sm">
          <ArrowLeft className="mr-2 w-4 h-4" />
          Back
        </Button>
        <div className="flex flex-col sm:flex-row gap-2">
          <Button 
            onClick={() => {
              setHasProduct(false);
              handleNext();
            }} 
            variant="outline"
            size="sm"
          >
            Skip
          </Button>
          <Button 
            onClick={() => {
              setHasProduct(true);
              handleNext();
            }}
            size="sm"
            disabled={!formData.productName || !formData.productSKU || !formData.productHSN || !formData.productGST}
          >
            Save & Continue
            <ArrowRight className="ml-2 w-4 h-4" />
          </Button>
        </div>
      </div>
    </div>
  );

  // Screen 9: Create First Order
  const renderCreateOrder = () => (
    <div className="max-w-3xl mx-auto px-4">
      <div className="mb-6 sm:mb-8">
        <h2 className="text-2xl sm:text-3xl font-bold text-text-primary mb-3">
          Create Your First Order
        </h2>
        <p className="text-text-secondary">Follow the guided walkthrough to place an order</p>
      </div>

      <Card className="p-8">
        <div className="space-y-6">
          {/* Step 1: Select Retailer */}
          <div className="relative">
            <div className="absolute -left-4 top-0 w-8 h-8 bg-primary text-white rounded-full flex items-center justify-center text-sm font-bold">
              1
            </div>
            <div className="ml-8">
              <h3 className="font-semibold text-text-primary mb-3">Select Retailer</h3>
              <Card className="p-4 bg-primary-50 border-primary">
                <div className="flex items-center gap-3">
                  <Users className="w-5 h-5 text-primary" />
                  <div>
                    <p className="font-semibold text-text-primary">{formData.retailerName}</p>
                    <p className="text-sm text-text-secondary">{formData.retailerArea}</p>
                  </div>
                  <CheckCircle2 className="w-5 h-5 text-primary ml-auto" />
                </div>
              </Card>
            </div>
          </div>

          {/* Step 2: Add Product */}
          <div className="relative">
            <div className="absolute -left-4 top-0 w-8 h-8 bg-primary text-white rounded-full flex items-center justify-center text-sm font-bold">
              2
            </div>
            <div className="ml-8">
              <h3 className="font-semibold text-text-primary mb-3">Add Product</h3>
              <Card className="p-4 bg-primary-50 border-primary">
                <div className="flex items-center gap-3">
                  <Package className="w-5 h-5 text-primary" />
                  <div className="flex-1">
                    <p className="font-semibold text-text-primary">{formData.productName}</p>
                    <p className="text-sm text-text-secondary">{formData.productSKU}</p>
                  </div>
                  <div className="text-right">
                    <Input
                      type="number"
                      placeholder="Qty"
                      className="w-20 text-center"
                      defaultValue="10"
                    />
                  </div>
                  <CheckCircle2 className="w-5 h-5 text-primary" />
                </div>
              </Card>
            </div>
          </div>

          {/* Step 3: Submit Order */}
          <div className="relative">
            <div className="absolute -left-4 top-0 w-8 h-8 bg-accent text-white rounded-full flex items-center justify-center text-sm font-bold">
              3
            </div>
            <div className="ml-8">
              <h3 className="font-semibold text-text-primary mb-3">Submit Order</h3>
              <div className="bg-background-subtle border border-border rounded-lg p-4">
                <div className="flex justify-between items-center mb-2">
                  <span className="text-text-secondary">Subtotal</span>
                  <span className="font-semibold">₹5,000</span>
                </div>
                <div className="flex justify-between items-center mb-2">
                  <span className="text-text-secondary">GST (5%)</span>
                  <span className="font-semibold">₹250</span>
                </div>
                <div className="border-t border-border pt-2 flex justify-between items-center">
                  <span className="font-bold text-text-primary">Total</span>
                  <span className="font-bold text-primary text-xl">₹5,250</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </Card>

      {showConfetti && (
        <div className="fixed inset-0 pointer-events-none flex items-center justify-center z-50">
          <div className="text-8xl animate-bounce">🎉</div>
        </div>
      )}

      <div className="flex flex-col sm:flex-row justify-between gap-3 mt-6">
        <Button onClick={handleBack} variant="outline">
          <ArrowLeft className="mr-2 w-4 h-4" />
          Back
        </Button>
        <div className="flex flex-col sm:flex-row gap-2 sm:gap-3">
          <Button onClick={handleNext} variant="outline">
            Skip for now
          </Button>
          <Button 
            onClick={() => {
              setShowConfetti(true);
              setTimeout(() => {
                setShowConfetti(false);
                handleNext();
              }, 2000);
            }}
            className="bg-primary"
          >
            Place Order
            <ArrowRight className="ml-2 w-4 h-4" />
          </Button>
        </div>
      </div>
    </div>
  );

  // Screen 10: Invite Team
  const renderInviteTeam = () => (
    <div className="max-w-3xl mx-auto px-4">
      <div className="mb-6 sm:mb-8">
        <h2 className="text-2xl sm:text-3xl font-bold text-text-primary mb-3">
          Invite Your Team
        </h2>
        <p className="text-text-secondary">Add team members to collaborate</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
        {ROLES.map((role) => {
          const Icon = role.icon;
          return (
            <Card key={role.id} className="p-4 text-center hover:shadow-md transition-shadow">
              <div className={`w-12 h-12 ${role.color} rounded-lg flex items-center justify-center mx-auto mb-3`}>
                <Icon className="w-6 h-6 text-white" />
              </div>
              <p className="text-sm font-semibold text-text-primary">{role.label}</p>
            </Card>
          );
        })}
      </div>

      <Card className="p-8">
        <div className="space-y-4">
          {[0, 1, 2].map((index) => (
            <div key={index} className="grid grid-cols-1 sm:grid-cols-3 gap-2 sm:gap-3">
              <SearchableSelect
                options={ROLES.map(role => ({ value: role.id, label: role.label }))}
                value=""
                onChange={() => {}}
                placeholder="Select role"
              />
              <Input
                placeholder="email@example.com"
                type="email"
                className="sm:col-span-2 text-sm"
              />
            </div>
          ))}
        </div>

        <Button variant="outline" className="w-full mt-4">
          <Users className="w-4 h-4 mr-2" />
          Add Another Member
        </Button>
      </Card>

      <div className="flex flex-col sm:flex-row justify-between gap-3 mt-6">
        <Button onClick={handleBack} variant="outline">
          <ArrowLeft className="mr-2 w-4 h-4" />
          Back
        </Button>
        <div className="flex flex-col sm:flex-row gap-2 sm:gap-3">
          <Button onClick={handleNext} variant="outline">
            Skip for now
          </Button>
          <Button onClick={handleNext}>
            Send Invites
            <ArrowRight className="ml-2 w-4 h-4" />
          </Button>
        </div>
      </div>
    </div>
  );

  // Screen 11: Connect Mobile App
  const renderConnectMobile = () => (
    <div className="max-w-2xl mx-auto px-4">
      <div className="mb-6 sm:mb-8">
        <h2 className="text-2xl sm:text-3xl font-bold text-text-primary mb-3">
          Connect Mobile App
        </h2>
        <p className="text-text-secondary">Download and pair your mobile device</p>
      </div>

      <Card className="p-8">
        <div className="text-center mb-8">
          <div className="inline-block p-6 bg-white border-2 border-border rounded-2xl mb-6">
            <QrCode className="w-32 h-32 text-text-primary" />
          </div>
          <p className="text-sm text-text-secondary mb-4">
            Scan this QR code with the OmniDist OMS mobile app
          </p>
          <div className="inline-flex items-center gap-2 px-4 py-2 bg-background-subtle rounded-lg">
            <div className="w-2 h-2 bg-warning rounded-full animate-pulse"></div>
            <span className="text-sm text-text-secondary">Waiting for device pairing...</span>
          </div>
        </div>

        <div className="relative my-8">
          <div className="absolute inset-0 flex items-center">
            <div className="w-full border-t border-border"></div>
          </div>
          <div className="relative flex justify-center text-sm">
            <span className="px-4 bg-white text-text-secondary">or download now</span>
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <Button variant="outline" className="h-12 sm:h-14">
            <Smartphone className="w-4 h-4 sm:w-5 sm:h-5 mr-2" />
            <div className="text-left">
              <div className="text-xs text-text-secondary">Download on</div>
              <div className="text-sm font-semibold">Google Play</div>
            </div>
          </Button>
          <Button variant="outline" className="h-12 sm:h-14">
            <Smartphone className="w-4 h-4 sm:w-5 sm:h-5 mr-2" />
            <div className="text-left">
              <div className="text-xs text-text-secondary">Download on</div>
              <div className="text-sm font-semibold">App Store</div>
            </div>
          </Button>
        </div>
      </Card>

      <div className="flex flex-col sm:flex-row justify-between gap-3 mt-6">
        <Button onClick={handleBack} variant="outline">
          <ArrowLeft className="mr-2 w-4 h-4" />
          Back
        </Button>
        <div className="flex flex-col sm:flex-row gap-2 sm:gap-3">
          <Button onClick={handleComplete} variant="outline">
            Skip for now
          </Button>
          <Button onClick={handleComplete}>
            Complete Setup
            <Check className="ml-2 w-4 h-4" />
          </Button>
        </div>
      </div>
    </div>
  );

  // Render current step
  const renderStep = () => {
    switch (step) {
      case 1: return renderWelcome();
      case 2: return renderBusinessType();
      case 3: return renderOrgDetails();
      case 4: return renderBranchSetup();
      case 5: return renderOperatingModel();
      case 6: return renderImportData();
      case 7: return renderAddRetailer();
      case 8: return renderAddProduct();
      case 9: return renderCreateOrder();
      case 10: return renderInviteTeam();
      case 11: return renderConnectMobile();
      default: return null;
    }
  };

  return (
    <div className="h-screen flex flex-col bg-background-subtle overflow-hidden">
      {/* Progress Bar */}
      {step > 1 && (
        <div className="bg-white border-b border-border flex-shrink-0">
          <div className="max-w-7xl mx-auto px-6 py-4">
            <div className="flex items-center justify-between mb-2">
              <p className="text-sm font-semibold text-text-primary">
                Setup Progress
              </p>
              <p className="text-sm text-text-secondary">
                Step {step} of {totalSteps}
              </p>
            </div>
            <div className="h-2 bg-background-subtle rounded-full overflow-hidden">
              <div
                className="h-full bg-primary transition-all duration-300"
                style={{ width: `${progress}%` }}
              />
            </div>
          </div>
        </div>
      )}

      {/* Content - Scrollable */}
      <div className="flex-1 overflow-y-auto py-8 sm:py-12 px-4 sm:px-6">
        {renderStep()}
      </div>

      {/* Confetti Effect */}
      {showConfetti && (
        <div className="fixed inset-0 pointer-events-none z-50 flex items-center justify-center">
          <div className="text-9xl animate-bounce">🎉</div>
          <div className="absolute top-1/4 left-1/4 text-6xl animate-ping">✨</div>
          <div className="absolute top-1/3 right-1/4 text-6xl animate-ping delay-100">🎊</div>
          <div className="absolute bottom-1/3 left-1/3 text-6xl animate-ping delay-200">⭐</div>
        </div>
      )}
    </div>
  );
}
