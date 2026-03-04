# Signup & Onboarding Flow - Backend Fix Summary

## Problem Analysis

The original flow had several issues:
1. **Duplicate Data Entry**: Organization and branch details were entered in signup but asked again in onboarding
2. **Missing Backend Support**: Onboarding wizard collected data but had no backend endpoints to persist it
3. **Incomplete Integration**: After onboarding completion, data wasn't saved to the database
4. **No Business Type Tracking**: Business type selected in onboarding wasn't stored anywhere

## Solution Implemented

### 1. **Database Schema Updates**
- Added `address` and `pincode` fields to `branches` table
- Migration: `20260304_add_address_and_pincode_to_branches.rb`

### 2. **Model Updates**
- **Branch Model**: Added validations for address (max 255 chars) and pincode (6-digit format)
- **OnboardingProgress Model**: Added 'setup_details' to CHECKLIST_STEPS

### 3. **Backend Endpoints**

#### Updated Endpoints
- `PUT /api/v1/organizations/:id` - Already supports: name, plan, gst_number, address, city, state, pincode, contact_email, contact_phone, active
- `PUT /api/v1/branches/:id` - Now supports: name, code, city, state, address, pincode, active

#### New Endpoints
- `POST /api/v1/onboarding/setup` - Handles bulk onboarding setup

```ruby
POST /api/v1/onboarding/setup
{
  "business_type": "fmcg",
  "org_details": {
    "org_name": "Sharma Distributors",
    "gstin": "29ABCDE1234F1Z5",
    "city": "Mumbai",
    "state": "Maharashtra",
    "phone": "+91 98765 43210"
  },
  "branch_details": {
    "branch_name": "Main Branch",
    "branch_code": "MAIN",
    "address": "123 Business Park, Andheri",
    "city": "Mumbai",
    "branch_state": "Maharashtra",
    "pincode": "400001"
  },
  "operating_model": ["credit", "cash"]
}
```

### 4. **Service Layer**
- **Onboarding::SetupService**: Handles updating organization and branch details with transaction support
  - Location: `app/services/onboarding/setup_service.rb`
  - Validates and updates organization details
  - Validates and updates first branch with address/pincode
  - Returns success/failure with error messages

### 5. **Controller Updates**
- **OnboardingController#setup**: New action to process onboarding setup and mark steps complete
- **BranchesController**: Updated serialization to include address and pincode

## Frontend Changes Needed

### Signup Flow (Simplified)
1. Email verification
2. Password setting
3. Profile (first name, last name, phone)
4. Plan selection
5. Auto-creates user, organization, and branch with defaults
6. Redirects to onboarding

### Onboarding Wizard (Complete Details)
1. Welcome screen
2. Business type selection
3. Organization details → **Call `/api/v1/onboarding/setup` with org_details**
4. Branch setup → **Send branch_details in same setup call**
5. Operating model selection → Store for future use
6. Optional: Import retailers/products
7. Optional: Add first retailer
8. Optional: Add first product
9. Optional: Add team members
10. Completion → Marks 'setup_details' step as complete

## Data Flow Summary

```
Signup (Creates basic entities)
├── User with email, password, name, phone
├── Organization (name from auto-gen, plan selected)
├── Branch (Main Branch, code MAIN)
└── OnboardingProgress (to track steps)

      ↓

Onboarding Wizard (Completes details)
├── Business Type (display-only for now)
├── Organization Details (via setup endpoint)
├── Branch Details (via setup endpoint)
├── Operating Model (store for later use)
├── Optional: Retailers setup
├── Optional: Products setup  
├── Optional: Team members
└── Completion (marks steps, redirects to activation)
```

## Key Improvements

1. **Single Source of Truth**: Organization and branch created in signup, updated in onboarding
2. **Backward Compatible**: Existing update endpoints still work
3. **Extensible**: Can add more onboarding steps without changing flow
4. **Proper Validation**: Address (255 char) and pincode (Indian 6-digit) validation
5. **Transaction Support**: All updates in setup happen together or rollback
6. **Progress Tracking**: OnboardingProgress accurately tracks completion

## Testing Checklist

- [ ] Run migration to add address/pincode to branches
- [ ] Test organization update endpoint
- [ ] Test branch update endpoint with address/pincode
- [ ] Test onboarding/setup endpoint
- [ ] Update frontend signup to work with new flow
- [ ] Update frontend onboarding to call setup endpoint
- [ ] Verify onboarding progress completion
- [ ] Test full signup → onboarding → activation flow
