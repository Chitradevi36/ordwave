# Plan: Per-API Per-User Rate Limiter

## What exists

A flat global throttle of `100 req/min per JWT user` across all `/api/*` endpoints, plus auth/export/sync-specific limits. Every API shares the same 100/min bucket — heavy analytics calls eat the same quota as lightweight GET requests.

## What this adds

Granular per-user buckets keyed to **endpoint groups**, plus a shared JWT helper to eliminate the repeated decode boilerplate. The global `api/user` 100/min remains as the outer safety net.

---

## Steps

1. **Extract a reusable JWT helper** inside `class Rack::Attack` at the top of `config/initializers/rack_attack.rb` — a private `self.extract_user_id(req)` method that decodes the Bearer token and returns `payload["sub"]`. Replace the 3× inline decode blocks in `api/user`, `sync/push/user`, and `exports/user` with calls to this helper.

2. **Add write-mutation throttle** — `api/user/writes` — 30 POST/PATCH/PUT/DELETE requests per minute per user across all `/api/v1/*`. Prevents bulk abuse of write operations while leaving GETs unrestricted.

3. **Add analytics/reports throttle** — `api/user/analytics` — 20 req/min per user on paths matching `/api/v1/analytics`, `/api/v1/reports`, or `/api/v1/dashboard`. These trigger expensive DB aggregations.

4. **Add payment/financial throttle** — `api/user/payments` — 20 req/min per user on `/api/v1/payments`, `/api/v1/advance_payments`, `/api/v1/collection_schedules`, `/api/v1/credit_accounts`. Limits financial mutation velocity.

5. **Add accounting throttle** — `api/user/accounting` — 10 req/min per user on `/api/v1/accounting/`. Accounting sync calls are expensive and infrequent.

6. **Add compliance throttle** — `api/user/compliance` — 5 req/min per user on `/api/v1/compliance/`. GST report generation is very expensive.

7. **Enhance the 429 response** to include the throttle name in the JSON body (`match: "api/user/writes"`) so clients can distinguish which limit was hit and display a meaningful message.

8. **Enhance the log subscription** to also log the `match_data` (limit, period, count) for observability.

---

## Throttle summary table (new additions)

| Name | Limit | Period | Scope |
|---|---|---|---|
| `api/user/writes` | 30 | 1 min | Any non-GET on `/api/v1/*` per JWT user |
| `api/user/analytics` | 20 | 1 min | Any method on `/api/v1/analytics\|reports\|dashboard` per user |
| `api/user/payments` | 20 | 1 min | Any method on payment/credit paths per user |
| `api/user/accounting` | 10 | 1 min | Any method on `/api/v1/accounting/*` per user |
| `api/user/compliance` | 5 | 1 min | Any method on `/api/v1/compliance/*` per user |

Existing global `api/user` (100/min) stays as the catch-all ceiling.

---

## Verification

- `curl -X POST /api/v1/sales_orders` 31 times rapidly → expect 429 with `match: "api/user/writes"`
- `curl /api/v1/analytics` 21 times rapidly → expect 429 with `match: "api/user/analytics"`
- `curl /api/v1/customers` (GET) 100+ times → only hits `api/ip` / `api/user` global, not halted early
- Check Rails logs for `[Rack::Attack] throttled` entries with match details

---

## Decisions

- Throttle body identifies the bucket name so mobile/web clients can show targeted errors
- Writes capped at 30/min (not per-resource) to stay simple — per-resource limits would require path parsing and add complexity without much gain
- No changes to auth endpoints (`logins/ip`, `logins/email`) — already correctly tuned
