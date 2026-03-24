## 💰 SALES REP PRICING PERMISSIONS DECISION
## Analysis & Implementation Options

**Created:** March 24, 2026  
**Status:** AWAITING DECISION  
**Owner:** Product Manager + Finance  
**Deadline:** March 27, 2026  
**Impact:** Revenue control, Sales flexibility  

---

## 📊 BUSINESS ANALYSIS

### Current State
- Sales Reps CAN create price lists
- Sales Reps CAN edit pricing
- Sales Reps CAN modify prices per customer
- No audit trail of pricing changes
- No approval workflow

### Risk Assessment
```
🔴 HIGH RISK if Sales Rep has:
   ├─ Access to premium/high-margin products
   ├─ Ability to discount >30%
   ├─ No approval needed for discounts
   └─ No audit trail of changes

🟡 MEDIUM RISK if Sales Rep can:
   ├─ Create new price lists
   ├─ Modify existing price lists
   └─ Price items below cost

🟢 LOW RISK if Sales Rep:
   ├─ Uses pre-approved price lists
   ├─ Can only assign existing prices
   └─ Cannot create new pricing
```

---

## 🎯 DECISION MATRIX

| Aspect | Option A: Full Access | Option B: Read-Only | Option C: Category-Based |
|--------|-------------------|-----------|--------------------------|
| **Create Price Lists** | ✅ Yes | ❌ No | ⚠️ Limited |
| **Edit Prices** | ✅ Yes | ❌ No | ⚠️ Category-specific |
| **Discount Capability** | ✅ Any % | ❌ None | ⚠️ Capped % |
| **High-Value Products** | ✅ Can modify | ❌ Cannot | ❌ Cannot |
| **Audit Trail** | ❌ None | N/A | ✅ Full |
| **Sales Flexibility** | 🟢 Maximum | 🔴 Minimum | 🟡 Balanced |
| **Revenue Protection** | 🔴 Minimum | 🟢 Maximum | 🟡 Good |

---

## 💡 OPTION A: FULL ACCESS (Current)

### Description
Sales Reps can freely create and edit all prices without restrictions.

### Implementation
```ruby
# app/policies/price_list_policy.rb
class PriceListPolicy < ApplicationPolicy
  def create?
    user.sales_rep? || user.owner? || user.admin?
  end

  def update?
    user.sales_rep? || user.owner? || user.admin?
  end

  def destroy?
    user.owner? || user.admin?
  end
end
```

### Pros ✅
- Maximum sales flexibility
- Reps can respond quickly to market conditions
- Simple implementation
- No approval delays
- Sales team happy

### Cons ❌
- HIGH: Unauthorized discounting risk
- Revenue leakage potential
- No audit trail
- Competitors could demand discounts
- Finance loses visibility
- Could impact margins significantly

### Risk Level: 🔴 **HIGH**

### Effort: 0 hours (already implemented)

### Recommendation: ⚠️ **NOT RECOMMENDED** - Too risky for margin-sensitive business

---

## 🔒 OPTION B: READ-ONLY ACCESS (Most Restrictive)

### Description
Sales Reps can VIEW pricing but cannot modify. Only Owner/Admin can create/edit prices.

### Implementation
```ruby
# app/policies/price_list_policy.rb
class PriceListPolicy < ApplicationPolicy
  def index?
    true  # Everyone can view
  end

  def show?
    user.sales_rep? || user.owner? || user.admin?
  end

  def create?
    user.owner? || user.admin?
  end

  def update?
    user.owner? || user.admin?
  end

  def destroy?
    user.owner? || user.admin?
  end
end

# Frontend
# Sales reps see "View" button instead of "Edit"
# Pricing locked for their role
```

### Implementation Steps
```bash
# 1. Update policy (1 hour)
# 2. Update frontend to hide edit buttons for sales reps (1 hour)
# 3. Add API authorization checks (30 min)
# 4. Test with sales rep account (30 min)
```

### Pros ✅
- MAXIMUM revenue protection
- Clear authority hierarchy
- Full audit trail (only admin changes)
- Prevents unauthorized discounting
- Finance happy 😊

### Cons ❌
- POOR UX - Sales reps frustrated ("I can't respond to competitor")
- Support tickets ("Why can't I change prices?")
- Less flexibility in market
- May lose deals due to slow pricing approval
- Sales team morale impact

### Risk Level: 🟢 **MINIMUM** (but high morale risk)

### Effort: 2-3 hours

### Recommendation: ⚠️ **NOT RECOMMENDED** - Too restrictive, hurts sales

---

## ⚖️ OPTION C: CATEGORY-BASED ACCESS (BALANCED) 🌟

### Description
Sales Reps can edit prices for non-premium categories. Premium/high-margin products restricted to Admin.

### Pricing Categories
```
🟢 Category 1: Commodity (Sales Rep CAN edit)
   ├─ Basic products
   ├─ Low margin (<15%)
   ├─ High volume
   └─ Discount cap: 25%

🟡 Category 2: Standard (Sales Rep CAN edit with limits)
   ├─ Regular products
   ├─ Medium margin (15-30%)
   ├─ Normal volume
   └─ Discount cap: 15%

🔴 Category 3: Premium (Admin ONLY)
   ├─ High-value products
   ├─ High margin (>30%)
   ├─ Strategic deals only
   └─ Requires approval
```

### Implementation
```ruby
# app/models/price_list_item.rb
class PriceListItem < ApplicationRecord
  PRICING_CATEGORIES = {
    commodity: { max_discount: 25, editable_by: [:sales_rep, :admin] },
    standard:  { max_discount: 15, editable_by: [:sales_rep, :admin] },
    premium:   { max_discount: 0,  editable_by: [:admin] }
  }.freeze

  validates :pricing_category, inclusion: { in: PRICING_CATEGORIES.keys }
end

# app/policies/price_list_item_policy.rb
class PriceListItemPolicy < ApplicationPolicy
  def update?
    if record.premium_pricing?
      user.owner? || user.admin?
    else
      user.sales_rep? || user.owner? || user.admin?
    end
  end

  def update_discount?
    return false if record.premium_pricing?
    
    category = record.pricing_category.to_sym
    max_discount = PRICING_CATEGORIES[category][:max_discount]
    
    new_discount = params[:discount_percent]
    new_discount <= max_discount
  end
end

# db/migrate/xxx_add_pricing_category_to_price_list_items.rb
class AddPricingCategoryToPriceListItems < ActiveRecord::Migration[7.1]
  def change
    add_column :price_list_items, :pricing_category, :string, 
               default: 'standard'
    add_index :price_list_items, :pricing_category
    
    # Add audit logging
    add_column :price_list_items, :last_modified_by_user_id, :bigint
    add_column :price_list_items, :last_modified_at, :datetime
  end
end
```

### Frontend Implementation
```tsx
// web/components/pricing/price-list-editor.tsx
export function PriceListItemRow({ item, user }) {
  const isEditable = canEditPrice(item, user);
  const maxDiscount = getMaxDiscount(item, user);

  return (
    <tr>
      <td>{item.product_name}</td>
      <td>{item.base_price}</td>
      <td className={`category-${item.pricing_category}`}>
        {item.pricing_category}
      </td>
      <td>
        {isEditable ? (
          <input
            type="number"
            value={item.discount}
            onChange={(e) => handleDiscountChange(e, maxDiscount)}
            max={maxDiscount}
          />
        ) : (
          <span className="text-orange-600">Admin Only</span>
        )}
      </td>
    </tr>
  );
}
```

### Audit Logging
```ruby
# Track all pricing changes
after_update :log_pricing_change

def log_pricing_change
  if price_changed? || discount_changed?
    AuditLog.create!(
      action: 'pricing_updated',
      resource_type: 'PriceListItem',
      resource_id: id,
      user: current_user,
      changes: saved_changes,
      timestamp: Time.current
    )
  end
end
```

### Pros ✅
- BALANCED - Gives sales flexibility where needed
- Revenue protection on high-value items
- Audit trail of all changes
- Scales as business grows
- Good UX - "I can modify commodity items"
- Finance visibility
- Reduces support tickets

### Cons ❌
- More complex implementation (4-6 hours)
- Need to categorize all products
- Rules might feel arbitrary to sales
- Requires training on what's editable

### Risk Level: 🟡 **MEDIUM-LOW**

### Effort: 4-6 hours

### Implementation Timeline
```
Day 1 (2h):   Database migration + model updates
Day 2 (2h):   API policy + controller logic
Day 3 (1h):   Frontend UI updates
Day 4 (1h):   Testing + training docs
```

### Recommendation: ✅ **STRONGLY RECOMMENDED**
Best balance of sales flexibility and revenue protection.

---

## 🚦 DECISION GUIDE

**Choose Option A (Full Access) if:**
- You trust sales team completely
- Margins are large (can absorb discounts)
- Revenue protection not a priority
- Want maximum sales flexibility

**Choose Option B (Read-Only) if:**
- You want ZERO risk of pricing changes
- Only finance/admin should manage prices
- You can afford slower approval process
- Sales morale is not a concern

**Choose Option C (Category-Based) if:** ✅ **RECOMMENDED**
- You want balanced flexibility + control
- Different product categories have different margins
- You need audit trail
- You want to scale sustainably
- You value both sales performance AND revenue

---

## 📋 DECISION CHECKLIST

- [ ] Review all 3 options with Finance Lead
- [ ] Discuss with Sales Manager
- [ ] Get input from top sales performer
- [ ] Consider customer feedback
- [ ] Estimate revenue impact
- [ ] Make final decision
- [ ] Document rationale
- [ ] Email to engineering@orderlane.com
- [ ] Schedule implementation
- [ ] Plan team training

---

## 📝 DECISION RECORD

**Fill in once you decide:**

```
Decision Maker: [Finance Lead / Product Manager]
Date: [Date]
Option Chosen: [ ] A (Full Access)  [ ] B (Read-Only)  [ ] C (Category-Based) ✅

Rationale:
[Explain business rationale]

Risk Tolerance:
[Your comfort level with pricing changes]

Timeline:
[When implement this]

Success Metrics:
[How will we measure if this works]
```

---

## 🎯 RECOMMENDED PATH FORWARD

### Week 1: Implement Category-Based (Option C)
1. Set up pricing categories
2. Tag existing products
3. Create audit logging
4. Deploy with safeguards

### Week 2-3: Monitor & Adjust
1. Watch discount patterns
2. Adjust category thresholds if needed
3. Train sales team
4. Gather feedback

### Month 2: Refine
1. Adjust discount caps based on data
2. Add approval workflow for edge cases
3. Create pricing strategy dashboard

---

**Status:** AWAITING DECISION  
**Next Step:** Reply with chosen option + business justification  
**Follow-up:** Implementation planning once decision received
