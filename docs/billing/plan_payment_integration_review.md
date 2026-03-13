# Billing & Payment Integration Review
## OrdeLane Pro — Razorpay / Free-Starter-Pro Plans

**Date:** 2025-06  
**Scope:** Full billing integration replacing any prior incomplete Stripe work  
**Provider:** Razorpay (Subscriptions API)  
**Plans:** Free · Starter · Pro

---

## 1. Codebase Audit

### 1.1 Existing Billing-Related Code

| Area | File | Status | Notes |
|---|---|---|---|
| Plan constants | `app/models/user.rb` L2 | **Needs change** | `PLANS = %w[starter growth enterprise]` → must become `%w[free starter pro]` |
| Plan mirror | `app/models/organization.rb` L4 | Derived | `PLANS = User::PLANS` — will auto-update |
| Plan enforcement | `app/services/plan_limits.rb` | **Needs rewrite** | Has starter/growth/enterprise limits — needs free/starter/pro |
| Plan selection | `app/services/signup/choose_plan_service.rb` | **Needs extension** | Creates user with plan but no payment gate; free plan can pass through, paid plans must initiate Razorpay subscription |
| Signup steps | `app/models/pending_registration.rb` L2 | **Needs extension** | STEPS ends at `choose_plan`; needs `billing_pending` for checkout-in-progress recovery |
| Billing tables | `db/schema.rb` | **Missing** | No subscription / billing_event / billing fields on organizations |
| Razorpay gem | `Gemfile` | **Missing** | `gem 'razorpay'` not added |
| Billing routes | `config/routes.rb` | **Missing** | No `/api/billing` or webhook routes |
| Billing services | `app/services/billing/` | **Missing** | Entire directory absent |
| Plan catalog | `app/lib/billing/` | **Missing** | Entire directory absent |
| Razorpay initializer | `config/initializers/razorpay.rb` | **Missing** | |
| Frontend billing page | `web/app/settings/billing/` | **Missing** | Nav link exists but no page |

### 1.2 Existing Infrastructure Available for Reuse

| Service/Module | Path | How Used |
|---|---|---|
| `AuditLog` | `app/models/audit_log.rb` | Record plan changes, payment events |
| `Notifications::CreateService` | `app/services/notifications/create_service.rb` | Payment success, trial ending, payment failed |
| `Notifications::PushService` | `app/services/notifications/push_service.rb` | Push alerts for billing events |
| `OnboardingProgress` | `app/models/onboarding_progress.rb` | Tracks checklist; billing activation could set an onboarding step |
| `PendingRegistration` | `app/models/pending_registration.rb` | Signup state machine — extend with `billing_pending` |
| `PlanLimits` | `app/services/plan_limits.rb` | Already used in `BaseController` for gate enforcement — just update limits |
| Sidekiq | `config/sidekiq.yml` | For async billing jobs (trial expiry, payment retry)  |
| Devise + JWT | `app/controllers/api/v1/base_controller.rb` | Auth — all billing endpoints reuse `authenticate_user!` |
| `ApplicationRecord` | `app/models/application_record.rb` | Base for new models |

### 1.3 What Is Confirmed ABSENT (clean start)

- No `app/models/subscription.rb`
- No `app/models/billing_event.rb`
- No `app/services/billing/` directory
- No `app/lib/billing/` directory
- No billing migrations in `db/migrate/`
- No billing columns in `db/schema.rb`
- No Stripe or Razorpay gem in Gemfile
- No webhook controller

---

## 2. Plan Design

### 2.1 Plan Matrix

| Feature | Free | Starter | Pro |
|---|---|---|---|
| **Price/month** | ₹0 | ₹1,499 | ₹3,999 |
| **Branches** | 1 | 3 | Unlimited |
| **Active users** | 3 | 15 | Unlimited |
| **Orders/month** | 100 | Unlimited | Unlimited |
| **Products** | 500 | Unlimited | Unlimited |
| **Exports (CSV/PDF)** | ✗ | ✓ | ✓ |
| **Advanced analytics** | ✗ | ✗ | ✓ |
| **Webhooks** | ✗ | ✗ | ✓ |
| **Custom roles** | ✗ | ✗ | ✓ |
| **GST / e-Invoice** | ✓ | ✓ | ✓ |
| **API access** | ✗ | ✓ | ✓ |
| **Priority support** | ✗ | ✗ | ✓ |

### 2.2 Activation Rules

| Plan | Payment Required | Activation Trigger |
|---|---|---|
| Free | ❌ | Immediate on `choose_plan` |
| Starter | ✓ | Razorpay `subscription.charged` webhook |
| Pro | ✓ | Razorpay `subscription.charged` webhook |

---

## 3. Data Model Design

### 3.1 New Columns on `organizations`

```
billing_status        string   default: "inactive"  # inactive | trialing | active | past_due | cancelled
razorpay_customer_id  string   (nullable)
current_period_end    datetime (nullable)
trial_ends_at         datetime (nullable)
```

### 3.2 New `subscriptions` Table

```
id                         bigint PK
organization_id            bigint FK
plan                       string    # free | starter | pro
status                     string    # pending | trialing | active | past_due | cancelled | expired
razorpay_subscription_id   string    (nullable, unique)
razorpay_plan_id           string    (nullable)
quantity                   integer   default: 1
current_period_start       datetime
current_period_end         datetime
trial_ends_at              datetime  (nullable)
cancelled_at               datetime  (nullable)
ends_at                    datetime  (nullable)
metadata                   jsonb     default: {}
created_at / updated_at
```

### 3.3 New `billing_events` Table

```
id                     bigint PK
organization_id        bigint FK
subscription_id        bigint FK (nullable)
event_type             string   # subscription.charged | payment.failed | subscription.cancelled | ...
razorpay_event_id      string   (unique — idempotency)
payload                jsonb    default: {}
processed_at           datetime
error_message          text     (nullable)
created_at / updated_at
```

---

## 4. Razorpay Integration Design

### 4.1 Flow — Free Plan

```
choose_plan(free)
  → ChoosePlanService: create User, activate org immediately
  → return JWT token to frontend
  → frontend → /onboarding
```

### 4.2 Flow — Paid Plans (Starter / Pro)

```
choose_plan(starter|pro)
  → ChoosePlanService: create User, create PendingSubscription record
  → return { requires_payment: true, subscription_short_url: "..." }
  → frontend redirects to Razorpay hosted page (short_url)
  → Customer pays on Razorpay
  → Razorpay fires: POST /api/billing/webhooks/razorpay
       event: "subscription.charged"
  → Billing::Razorpay::WebhookProcessor:
       verify HMAC signature
       find/create Subscription record
       set org billing_status = "active"
       create BillingEvent
       send activation notification
  → Customer returns via success_url → frontend activates
```

### 4.3 Flow — Subscription Lifecycle

```
payment.failed  → set org.billing_status = "past_due", send notification
subscription.cancelled → set billing_status = "cancelled", ends_at = now
subscription.activated → update period dates
subscription.charged   → extend current_period_end, set active
```

### 4.4 Razorpay Services Architecture

```
app/lib/billing/
  plan_catalog.rb          # Plan definitions, Razorpay plan IDs, limits

app/services/billing/razorpay/
  customer_creator.rb      # Find-or-create Razorpay customer
  subscription_creator.rb  # Create Razorpay subscription → return short_url
  webhook_processor.rb     # Verify + route webhook events
  event_handlers/
    subscription_charged.rb
    payment_failed.rb
    subscription_cancelled.rb
    subscription_activated.rb

app/jobs/billing/
  trial_expiry_job.rb      # Scheduled: check trial_ends_at, downgrade if unpaid
  past_due_reminder_job.rb # Scheduled: remind orgs in past_due
```

---

## 5. API Endpoints

### Billing Namespace (`/api/v1/billing`)

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/api/v1/billing/subscription` | JWT | Current subscription + usage summary |
| POST | `/api/v1/billing/checkout` | JWT | Create Razorpay subscription, return short_url |
| POST | `/api/v1/billing/cancel` | JWT + owner | Cancel subscription at period end |
| GET | `/api/v1/billing/invoices` | JWT | List payment history (from billing_events) |
| POST | `/api/billing/webhooks/razorpay` | HMAC sig | Razorpay webhook receiver (no auth) |

### Signup Extension

| Method | Path | Change |
|---|---|---|
| POST | `/api/v1/signup/choose_plan` | Returns `requires_payment`, `subscription_short_url` for paid plans |

---

## 6. Security Considerations

1. **Webhook signature verification**: All webhook events verified using `Razorpay::Utility.verify_webhook_signature` before processing. Raw body must be preserved (middleware).
2. **Idempotency**: `billing_events.razorpay_event_id` is unique-indexed — re-delivered webhooks are safely skipped.
3. **No billing data in logs**: `RAZORPAY_KEY_SECRET` and webhook secret never logged. 
4. **Owner-only cancel**: Pundit policy on `BillingPolicy#cancel?` checks `record.owner == user`.
5. **HMAC-first**: Webhook controller inherits from `ActionController::Base` (not API base) to get raw body; webhook validation happens before any DB access.

---

## 7. Environment Variables

```bash
# Razorpay credentials
RAZORPAY_KEY_ID=rzp_live_xxxx
RAZORPAY_KEY_SECRET=xxxx
RAZORPAY_WEBHOOK_SECRET=xxxx

# Razorpay Plan IDs (created in Razorpay dashboard)
RAZORPAY_PLAN_ID_STARTER_MONTHLY=plan_xxxx
RAZORPAY_PLAN_ID_PRO_MONTHLY=plan_xxxx

# App URLs (for Razorpay callback)
APP_BASE_URL=https://app.orderlane.in
```

---

## 8. Frontend Changes

### Pages / Components Needed

| File | Change |
|---|---|
| `web/app/settings/billing/page.tsx` | Full billing UI: current plan card, usage meters, upgrade/cancel CTA |
| `web/lib/api/billing.ts` | API client for billing endpoints |
| `web/lib/api/hooks/useBilling.ts` | React Query hook for billing data |
| `web/app/onboarding/page.tsx` | Handle `requires_payment` response → redirect to short_url |
| `web/components/layout/Sidebar.tsx` | Billing nav item (may already exist) |

---

## 9. Testing Plan

| Layer | What to Test |
|---|---|
| Model | `Subscription` state transitions, validations |
| Service | `Billing::PlanCatalog`, `Billing::Razorpay::SubscriptionCreator`, `Billing::Razorpay::WebhookProcessor` |
| Request spec | `GET /api/v1/billing/subscription`, `POST /api/billing/webhooks/razorpay` (valid + invalid sig) |
| Policy | `BillingPolicy#cancel?` owner vs non-owner |
| Job | `Billing::TrialExpiryJob` — demotes past-due orgs |
| Factory | `subscription` factory with `:active`, `:past_due`, `:cancelled` traits |

---

## 10. Implementation Phases

| Phase | Work |
|---|---|
| ✅ **Phase 1** | Repo inspection + this review doc |
| **Phase 2** | Update `User::PLANS` → `%w[free starter pro]`, update `Organization::PLANS`, `PlanLimits` |
| **Phase 3** | Add `gem 'razorpay'`, create `config/initializers/razorpay.rb` |
| **Phase 4** | Write billing migrations, run `db:migrate` |
| **Phase 5** | `app/lib/billing/plan_catalog.rb` + `entitlement_resolver.rb` |
| **Phase 6** | Razorpay services: customer_creator, subscription_creator, webhook_processor + event handlers |
| **Phase 7** | Billing webhook route + controller |
| **Phase 8** | Extend `ChoosePlanService`, extend `PendingRegistration::STEPS` |
| **Phase 9** | `BillingController` (subscription, checkout, cancel, invoices) + routes |
| **Phase 10** | Sidekiq jobs: `TrialExpiryJob`, `PastDueReminderJob` |
| **Phase 11** | Tests (factories, model specs, service specs, request specs) |
| **Phase 12** | Frontend billing page + hooks |
| **Phase 13** | `.env.example` + README updates |
