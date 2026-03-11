# OrdWave - Enterprise Onboarding Flow

## Overview

A complete enterprise-grade onboarding wizard designed for Indian B2B distributors. The flow guides new users through a comprehensive 11-step setup process, optimized for FMCG, Rice, and Wholesale distribution businesses.

## Design Philosophy

### Visual Identity
- **Primary Color**: Deep Green (#1B4332) - Professional, trustworthy
- **Typography**: Inter font family for clean, readable enterprise UI
- **Layout**: Card-based, information-dense, structured
- **Market**: Indian-specific (₹ currency, GST, PAN, state dropdowns)

### UX Principles
- ✅ One primary CTA per screen
- ✅ Clear progress indicators
- ✅ Contextual help tooltips
- ✅ Real-time validation with visual feedback
- ✅ Skip options where appropriate
- ✅ Demo mode for exploration

## Onboarding Flow (11 Steps)

### Step 1: Welcome Screen
**Purpose**: Set expectations and showcase value proposition

**Elements**:
- Welcome headline with animated icon
- "Setup takes 5 minutes" time estimate
- Two action buttons:
  - **Start Setup** (primary) - Begins the wizard
  - **Load Demo Mode** (outline) - Pre-populated demo data
- Four benefit cards:
  - 🌐 Offline-First (works without internet)
  - 💳 Credit-First (flexible payment terms)
  - 🧾 GST-Ready (compliant invoicing)
  - 📈 Real-Time Tracking (delivery updates)

**User Decision**: Start full setup or explore demo

---

### Step 2: Business Type Selection
**Purpose**: Pre-configure industry-specific settings

**Elements**:
- 4 business type cards with emoji icons:
  - 🌾 **Rice Distributor** - Optimized for rice & grain trading
  - 🛒 **FMCG Distributor** - Fast-moving consumer goods
  - 🏪 **Wholesale Grocery** - Bulk grocery distribution
  - ⚙️ **Custom** - Configure from scratch
- Tooltip explaining auto-configuration of GST & credit settings
- Visual selection with checkmark indicator

**Impact**: Sets default credit policies, GST rates, and product templates

---

### Step 3: Organization Details
**Purpose**: Capture legal business information

**Form Fields**:
- Organization Name * (required)
- Phone Number * (required)
- State * (dropdown with all 28 Indian states)
- GSTIN * (15-character validation with green check)
  - Format: 22AAAAA0000A1Z5
  - Real-time regex validation
  - Visual feedback (✓ or ✗)
- PAN * (10-character format)

**Validation**:
- GSTIN format: `/^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$/`
- State code in GSTIN must match selected state
- All fields required before continuing

---

### Step 4: Branch Setup
**Purpose**: Configure first warehouse/branch location

**Form Fields**:
- Branch Name * (e.g., "Head Office")
- Branch Code * (e.g., "HQ-01", auto-uppercase)
- Address * (street address)
- City * (city name)
- Pincode * (6 digits)
- Checkbox: "Single branch for now"

**Features**:
- Map preview placeholder for location
- Promise to add more branches later
- Auto-suggests branch codes based on city

---

### Step 5: Operating Model
**Purpose**: Configure payment and credit policies

**Options** (multi-select):
- ✅ We allow credit sales
  - Shows default: 30 days, ₹50,000 limit, 2% interest
- ✅ Cash-only business
- ✅ Mixed model (both credit and cash)

**Dynamic Preview**:
- If "credit" selected → Shows default credit policy card
- Can customize policies later in settings

**Color Coding**:
- Green: Healthy credit
- Amber: Approaching limit
- Red: Overdue payments

---

### Step 6: Import Data
**Purpose**: Bulk data onboarding via CSV

**Tabs**:
1. **Import Retailers** (customers)
   - Drag & drop CSV upload
   - Sample file download link
   - Shows expected columns
2. **Import Products** (catalog)
   - Drag & drop CSV upload
   - Sample file download link
   - Shows expected columns
3. **Skip for now** (manual entry)

**Sample Files**:
- Retailers: name, phone, area, credit_limit, payment_terms
- Products: sku, name, hsn_code, gst_rate, price

---

### Step 7: Add First Retailer (Mandatory)
**Purpose**: Create at least one customer record

**Form Fields**:
- Retailer Name * (e.g., "Fresh Mart")
- Phone Number * (e.g., "+91 98765 43210")
- Area/Location * (e.g., "Andheri West")

**Microcopy**:
- Help icon: "Retailers are your customers"
- Tip: "You can add credit limits later"

**Rationale**: Ensures users understand customer management

---

### Step 8: Add First Product (Mandatory)
**Purpose**: Create at least one inventory item

**Form Fields**:
- Product Name * (e.g., "Basmati Rice 5kg")
- SKU Code * (e.g., "RICE-BAS-5KG", auto-uppercase)
- HSN Code * (e.g., "1006" for rice)
- GST Rate (%) * (auto-populated from HSN)

**Smart Features**:
- HSN code lookup with auto-suggest
- Auto-populate GST rate based on HSN
- Green checkmark on valid HSN
- Example format shown below each field

**Example**:
- HSN: 1006 → GST: 5% (rice)
- HSN: 1701 → GST: 0% (sugar)

---

### Step 9: Create First Order (Guided Walkthrough)
**Purpose**: Teach order creation with real data

**3-Step Flow**:
1. **Select Retailer** ✓
   - Shows previously created retailer
   - Card with name, area, checkmark
2. **Add Product** ✓
   - Shows previously created product
   - Quantity input field (default: 10)
   - Real-time price calculation
3. **Submit Order** 
   - Order summary:
     - Subtotal: ₹5,000
     - GST (5%): ₹250
     - **Total: ₹5,250**
   - Primary button: "Place Order"

**Success Animation**:
- 🎉 Confetti effect on order submission
- Celebration message
- Auto-advances after 2 seconds

---

### Step 10: Invite Team
**Purpose**: Onboard collaborators with role-based access

**Role Cards**:
- 🏢 **Branch Manager** - Full branch control
- 👤 **Sales Rep** - Order creation, customer management
- 🚚 **Driver** - Delivery updates, route tracking
- 🧮 **Accounts** - Payment recording, invoice generation

**Invite Form**:
- 3 rows of: [Role Dropdown] [Email Input]
- "Add Another Member" button
- Skip option available

**Features**:
- Email validation
- Duplicate prevention
- Sends automated invite emails
- Role-based permission preview

---

### Step 11: Connect Mobile App
**Purpose**: Enable offline-first mobile access

**Elements**:
1. **QR Code Pairing**
   - Large QR code display
   - "Waiting for device pairing..." status
   - Animated pulse indicator
2. **Direct Downloads**
   - Google Play button
   - App Store button
   - Links to respective stores

**Device Pairing Flow**:
1. User scans QR with mobile app
2. Mobile app registers with API
3. Web shows "Device paired ✓"
4. Auto-advances to completion

**Skip Option**: Available for desktop-only users

---

## Final Screen: Activation Dashboard

After completing the wizard, users see a comprehensive activation checklist:

### Checklist Items
- ✅ **Add retailer** - Completed in wizard
- ✅ **Add product** - Completed in wizard
- ✅ **Place order** - Completed in wizard
- ✅ **Generate invoice** - Pending (can do from dashboard)
- ☐ **Record payment** - Pending (can do from dashboard)

### Visual Elements
- **Progress Bar**: Animated gradient (primary → accent)
- **Percentage**: Large display (e.g., "80%")
- **Item Cards**: 
  - Green background + accent border for completed
  - White background + grey border for pending
  - Checkmarks for completed items
  - "Complete" button for pending items

### Actions
- **Go to Dashboard** (primary button)
- Help links: "View Documentation", "Contact Support"

---

## Technical Implementation

### Component Structure
```
app/
├── onboarding-wizard/
│   └── page.tsx              # Main wizard with 11 steps
├── activation/
│   └── page.tsx              # Final checklist dashboard
└── dashboard/
    └── page.tsx              # Main app dashboard
```

### State Management
```typescript
interface FormData {
  businessType: 'rice' | 'fmcg' | 'wholesale' | 'custom';
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
  operatingModel: ('credit' | 'cash' | 'mixed')[];
  retailerName: string;
  retailerPhone: string;
  retailerArea: string;
  productName: string;
  productSKU: string;
  productHSN: string;
  productGST: string;
  teamEmails: { role: string; email: string }[];
}
```

### Validation Functions
```typescript
// GSTIN Validation
const validateGSTIN = (value: string): boolean => {
  const regex = /^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$/;
  return regex.test(value);
};

// Progress Calculation
const progress = (currentStep / totalSteps) * 100;
```

### API Integration Points
- `POST /api/v1/signup/complete` - Submit full wizard data
- `POST /api/v1/retailers` - Create retailer
- `POST /api/v1/products` - Create product
- `POST /api/v1/orders` - Create first order
- `POST /api/v1/invites` - Send team invites
- `GET /api/v1/onboarding/status` - Check activation progress

---

## Design Tokens

### Colors
```css
--primary: #1B4332;        /* Deep Green */
--primary-50: #E8F5EE;
--primary-100: #C6E6D3;
--primary-700: #163727;

--accent: #52B788;         /* Success Green */
--success: #52B788;
--warning: #D97706;        /* Amber */
--danger: #DC2626;         /* Red */

--background: #FFFFFF;
--background-subtle: #F8FAF8;

--text-primary: #1E293B;
--text-secondary: #64748B;

--border: #E2E8F0;
```

### Typography
```css
font-family: 'Inter', sans-serif;

/* Headings */
h1: 2.25rem (36px) font-bold
h2: 1.875rem (30px) font-bold
h3: 1.5rem (24px) font-semibold

/* Body */
body: 1rem (16px) font-normal
small: 0.875rem (14px) font-normal
```

### Spacing
```css
--space-2: 8px;
--space-3: 12px;
--space-4: 16px;
--space-6: 24px;
--space-8: 32px;
```

---

## User Flows

### Happy Path (Complete Setup)
1. User signs up → Redirected to `/onboarding-wizard`
2. Completes all 11 steps (5 minutes)
3. Redirected to `/activation` with 80% progress
4. Completes remaining 2 tasks
5. Clicks "Go to Dashboard" → Full access

### Skip Flow (Quick Start)
1. User clicks "Load Demo Mode" on welcome screen
2. Instantly redirected to `/dashboard?demo=true`
3. Pre-populated with sample data
4. Banner shows: "You're using demo data. Set up real business →"

### Partial Completion (Resume Later)
1. User completes steps 1-6
2. Closes browser
3. Returns later → Resumes at step 7
4. Progress saved in localStorage or backend

---

## Accessibility

- ✅ Keyboard navigation (Tab, Enter, Escape)
- ✅ ARIA labels on all interactive elements
- ✅ Focus indicators on form fields
- ✅ Screen reader announcements for validation
- ✅ High contrast mode support
- ✅ Minimum touch target: 44x44px

---

## Performance

- Initial bundle size: ~150KB (gzipped)
- Lazy load confetti animation
- Progressive image loading for icons
- Optimized re-renders with React.memo
- Form validation debounced (300ms)

---

## Analytics Events

Track user progress with these events:

```javascript
// Step completion
analytics.track('Onboarding Step Completed', {
  step: 3,
  step_name: 'Organization Details',
  time_taken: 45, // seconds
});

// Drop-off tracking
analytics.track('Onboarding Abandoned', {
  last_completed_step: 5,
  completion_percentage: 45,
});

// Full completion
analytics.track('Onboarding Completed', {
  total_time: 312, // seconds
  skipped_steps: ['invite_team', 'mobile_app'],
});
```

---

## Future Enhancements

### Phase 2
- [ ] Video tutorials embedded in each step
- [ ] Live chat support widget
- [ ] Progress auto-save to backend
- [ ] Multi-language support (Hindi, Tamil, Telugu)
- [ ] WhatsApp integration for invites

### Phase 3
- [ ] AI-powered product HSN code lookup
- [ ] Bank account integration for payments
- [ ] GST return filing integration
- [ ] Advanced credit scoring for retailers
- [ ] Route optimization for drivers

---

## Support & Documentation

- 📚 **Knowledge Base**: https://docs.orderlanepro.com/onboarding
- 💬 **Live Chat**: Available in-app (bottom-right)
- 📧 **Email**: support@orderlanepro.com
- 📞 **Phone**: +91-XXXX-XXXXXX (9 AM - 6 PM IST)

---

**Last Updated**: March 3, 2026  
**Version**: 1.0.0  
**Maintained by**: OrdWave Product Team
