## 🔧 PREFERENCES MODULE ACCESS POLICY
## Decision Matrix & Implementation Options

**Created:** March 24, 2026  
**Status:** AWAITING DECISION  
**Owner:** Product Manager  
**Deadline:** March 26, 2026  

---

## 📊 DECISION MATRIX

| Role | Option A: Open All | Option B: Admin Only | Option C: Personal Only |
|------|-------------------|-------------------|------------------------|
| **Owner** | ✅ Full access | ✅ Full access | ✅ Full access |
| **Admin** | ✅ Full access | ✅ Full access | ✅ Full access |
| **Sales Rep** | ✅ Personal settings | ❌ No access | ✅ Personal settings |
| **Driver** | ✅ Personal settings | ❌ No access | ✅ Personal settings |
| **Users Can Manage** | Own settings + see others | Only own settings | Own settings only |

---

## 🎯 RECOMMENDED OPTION: A (Open All)

### Option A: Allow All Roles (RECOMMENDED ✅)

**Description:** All roles can access and modify their personal preferences.

**Implementation:**
```ruby
# app/policies/preference_policy.rb
class PreferencePolicy < ApplicationPolicy
  def index?
    # All users can view their own preferences
    user.id == record.user_id
  end

  def show?
    user.id == record.user_id
  end

  def update?
    user.id == record.user_id
  end

  def create?
    user.id == record.user_id
  end
end
```

**Frontend:**
```tsx
// web/app/preferences/page.tsx
export default function PreferencesPage() {
  const { user } = useAuth();
  // Show preferences for current user
  // All roles can edit: theme, language, notifications, etc.
}
```

**Pros:**
- ✅ Simple implementation
- ✅ User-friendly - everyone can customize
- ✅ No special handling needed
- ✅ Reduces support tickets ("Why can't I change my language?")
- ✅ Works for all roles equally

**Cons:**
- ❌ No restriction on what users can change
- ❌ Drivers/Sales Reps could modify organization-level settings (if exposed)

**Effort:** 2 hours

**Recommendation:** CHOOSE THIS - Balances UX and simplicity

---

## 🔒 ALTERNATIVE OPTIONS

### Option B: Admin Only (Most Restrictive)

**Description:** Only Owner/Admin can access preferences. Sales Rep/Driver cannot.

**Implementation:**
```ruby
# app/policies/preference_policy.rb
class PreferencePolicy < ApplicationPolicy
  def index?
    user.owner? || user.admin?
  end

  def show?
    user.owner? || user.admin?
  end

  def update?
    user.owner? || user.admin?
  end
end
```

**Pros:**
- ✅ Tight control
- ✅ Security-focused
- ✅ Prevents unauthorized changes

**Cons:**
- ❌ Poor UX - drivers can't change language/theme
- ❌ Support tickets asking "How do I change my email?"
- ❌ Feels restrictive, may frustrate users
- ❌ Not aligned with modern SaaS practices

**Effort:** 1.5 hours

**Recommendation:** NOT RECOMMENDED - Too restrictive

---

### Option C: Personal Settings Only (Hybrid)

**Description:** All roles can edit personal settings (profile, notifications) but not organization settings.

**Implementation:**
```ruby
# app/models/preference.rb
class Preference < ApplicationRecord
  PERSONAL_SETTINGS = %w[
    theme language timezone notifications_email notifications_sms
    profile_picture display_name
  ].freeze
  
  ORGANIZATION_SETTINGS = %w[
    company_branding report_formats billing_preferences
  ].freeze
end

# app/policies/preference_policy.rb
class PreferencePolicy < ApplicationPolicy
  def update?
    if preference.organization_setting?
      user.owner? || user.admin?
    else
      user.id == preference.user_id
    end
  end
end
```

**Pros:**
- ✅ Flexible and granular
- ✅ Good UX for all roles
- ✅ Security controls on org-level settings
- ✅ Best of both worlds

**Cons:**
- ❌ More complex implementation (2-4 hours)
- ❌ Requires clear categorization of settings
- ❌ More code to maintain

**Effort:** 3-4 hours

**Recommendation:** CONSIDER FOR FUTURE - Good approach for scaling

---

## 🚦 QUICK DECISION GUIDE

**Choose Option A if:**
- You want simple, user-friendly approach
- You value UX over tight control
- Settings are personal (theme, language, notifications)
- You follow modern SaaS best practices

**Choose Option B if:**
- You want maximum control
- Only admin users should customize
- You're concerned about configuration drift
- Users should contact admin to change settings

**Choose Option C if:**
- You need granular control
- Org-level settings exist and need protection
- You want to scale to custom setting types
- You have time to implement complexity

---

## 📋 IMPLEMENTATION STEPS (Option A)

### Step 1: Create Policy
```bash
# Run in backend
rails generate pundit:policy preference
```

### Step 2: Create Controller
```bash
rails generate controller preferences index show update
```

### Step 3: Update Routes
```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    resources :preferences, only: [:index, :show, :update]
  end
end
```

### Step 4: Create Frontend Component
```bash
# web/app/preferences/page.tsx
# Add preferences form with all user-editable fields
```

### Step 5: Add Tests
```bash
# backend/spec/policies/preference_policy_spec.rb
# backend/spec/controllers/api/v1/preferences_controller_spec.rb
```

---

## ✅ CHECKLIST TO MAKE DECISION

- [ ] Review all 3 options above
- [ ] Discuss with Product Manager
- [ ] Align with Security Lead (if applicable)
- [ ] Get feedback from UX/Design team
- [ ] Make final decision
- [ ] Document in this file
- [ ] Email decision to engineering@orderlane.com
- [ ] Schedule implementation
- [ ] Add to sprint backlog

---

## 📝 DECISION RECORD

**Once you decide, fill in this section:**

```
Decision Maker: [Name]
Date: [Date]
Option Chosen: [ ] A (Open All)  [ ] B (Admin Only)  [ ] C (Personal Only)

Rationale:
[Explain why you chose this option]

Security Considerations:
[Any security notes or requirements]

Implementation Date:
[When should this be implemented]
```

---

## 🔗 RELATED LINKS

- [Preferences API Spec](api-spec-preferences.md) - If exists
- [User Model](backend/app/models/user.rb)
- [Authorization Policies](backend/app/policies/)
- [Frontend Auth Context](web/lib/auth-context.tsx)

---

**Status:** AWAITING DECISION  
**Next Step:** Reply with chosen option + rationale
