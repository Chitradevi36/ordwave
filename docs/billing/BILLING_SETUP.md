# Billing Integration — Setup & Operations Guide

## Overview

OrdeLane Pro uses **Razorpay Subscriptions** for paid plans. The integration is:

- **Provider**: Razorpay (India-first; INR billing)
- **Plans**: Free · Starter (₹1,499/mo) · Pro (₹3,999/mo)
- **Webhook-driven**: org activation happens only after Razorpay confirms payment
- **Idempotent**: duplicate webhook events are safely skipped

---

## Local Setup

### 1. Install dependencies

```bash
cd backend
bundle install    # installs razorpay ~> 3.2
```

### 2. Configure environment variables

Copy `.env.example` to `.env` and fill in:

```bash
RAZORPAY_KEY_ID=rzp_test_xxxx
RAZORPAY_KEY_SECRET=xxxx
RAZORPAY_WEBHOOK_SECRET=xxxx
RAZORPAY_PLAN_ID_STARTER_MONTHLY=plan_xxxx
RAZORPAY_PLAN_ID_PRO_MONTHLY=plan_xxxx
APP_BASE_URL=http://localhost:3000
```

### 3. Create Razorpay Plans

In **Razorpay Dashboard → Products → Subscriptions → Plans**:

| Plan    | Period | Amount   | Currency |
|---------|--------|----------|----------|
| Starter | monthly | ₹1,499 | INR |
| Pro     | monthly | ₹3,999 | INR |

Copy the generated plan IDs into your `.env`.

### 4. Run migrations

```bash
rails db:migrate
```

This creates:
- `billing_status`, `razorpay_customer_id`, `current_period_end`, `trial_ends_at` on `organizations`
- `subscriptions` table
- `billing_events` table

### 5. Configure Razorpay webhook

In **Razorpay Dashboard → Settings → Webhooks → Create**:

- URL: `https://your-domain.com/api/v1/billing/webhooks/razorpay`
- Events to subscribe:
  - `subscription.charged` ✓
  - `subscription.activated` ✓
  - `subscription.cancelled` ✓
  - `subscription.halted` ✓
  - `payment.failed` ✓
- Secret: set `RAZORPAY_WEBHOOK_SECRET` to match

---

## Architecture

```
POST /api/v1/signup/choose_plan
  ↓
Signup::ChoosePlanService
  ├── plan = "free"  → user created, org activated immediately
  └── plan = "starter"|"pro" → user created, requires_payment: true returned

POST /api/v1/billing/checkout   (JWT auth, after org created in onboarding)
  ↓
Billing::Razorpay::SubscriptionCreator
  ├── find/create Razorpay customer
  ├── create Razorpay subscription
  ├── return short_url
  └── persist local Subscription (status: "pending")

Frontend redirects to short_url (Razorpay hosted checkout)

POST /api/v1/billing/webhooks/razorpay  (HMAC auth)
  ↓
Billing::Razorpay::WebhookProcessor
  ├── verify HMAC signature
  ├── idempotency check (razorpay_event_id)
  └── route to event handler:
       subscription.charged   → SubscriptionCharged → activate org + notify
       payment.failed         → PaymentFailed → mark past_due + notify
       subscription.cancelled → SubscriptionCancelled → cancel + notify
       subscription.activated → SubscriptionActivated → update period dates
```

---

## API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/v1/billing/subscription` | JWT | Current plan, usage, all plans |
| POST | `/api/v1/billing/checkout` | JWT | Start Razorpay checkout → short_url |
| POST | `/api/v1/billing/cancel` | JWT (owner) | Cancel at period end |
| GET | `/api/v1/billing/invoices` | JWT | Payment history |
| POST | `/api/v1/billing/webhooks/razorpay` | HMAC | Razorpay event receiver |

---

## Plan Limits

Enforced by `PlanLimits` service at the service layer:

| Limit | Free | Starter | Pro |
|-------|------|---------|-----|
| Branches | 1 | 3 | Unlimited |
| Active users | 3 | 15 | Unlimited |
| Orders/month | 100 | Unlimited | Unlimited |
| Products | 500 | Unlimited | Unlimited |
| Exports | ✗ | ✓ | ✓ |
| API access | ✗ | ✓ | ✓ |
| Advanced analytics | ✗ | ✗ | ✓ |
| Webhooks | ✗ | ✗ | ✓ |
| Custom roles | ✗ | ✗ | ✓ |

---

## Background Jobs

| Job | Schedule | Description |
|-----|----------|-------------|
| `Billing::PastDueReminderJob` | 10 AM daily | Remind past_due orgs to update payment |
| `Billing::PastDueExpiryJob` | 1 AM daily | Downgrade orgs past grace period to free |

---

## Testing

```bash
# Run billing specs
bundle exec rspec spec/models/subscription_spec.rb
bundle exec rspec spec/models/billing_event_spec.rb
bundle exec rspec spec/services/billing/
bundle exec rspec spec/requests/api/v1/billing_spec.rb

# Run all specs
bundle exec rspec
```

---

## Monitoring

- All billing events are logged with `Rails.logger.error("[Billing::...]")`
- Sentry captures exceptions from the webhook processor
- `BillingEvent` table provides a full audit trail
- Check `billing_status` on `organizations` for current state

---

## Common Issues

### Webhook signature fails
- Ensure `RAZORPAY_WEBHOOK_SECRET` matches the webhook secret in Razorpay Dashboard
- In test/dev, set `RAZORPAY_WEBHOOK_SECRET=` (blank) to bypass signature check

### Org not activated after payment
1. Check `billing_events` table for the `subscription.charged` event
2. Check `subscriptions` table — status should be `active`
3. Check `organizations.billing_status` — should be `active`
4. If event is missing, check Razorpay Dashboard → Webhooks → delivery logs

### Plan ID not configured
- Ensure `RAZORPAY_PLAN_ID_STARTER_MONTHLY` / `RAZORPAY_PLAN_ID_PRO_MONTHLY` are set
- Verify the plan IDs exist in Razorpay Dashboard → Subscriptions → Plans
