# OrderLane Pro — Web Dashboard
## Functional Requirements Document (FRD)

**Version:** 1.0  
**Date:** March 2026  
**Classification:** Investor Distribution  
**Product:** OrderLane Pro Web Application

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Product Vision & Market Context](#2-product-vision--market-context)
3. [System Architecture](#3-system-architecture)
4. [User Roles & Access Control](#4-user-roles--access-control)
5. [Authentication & Onboarding](#5-authentication--onboarding)
6. [Module: Dashboard & KPIs](#6-module-dashboard--kpis)
7. [Module: Sales Order Management](#7-module-sales-order-management)
8. [Module: Retailer CRM (Customers)](#8-module-retailer-crm-customers)
9. [Module: Inventory Management](#9-module-inventory-management)
10. [Module: Dispatch & Delivery](#10-module-dispatch--delivery)
11. [Module: Finance & Collections](#11-module-finance--collections)
12. [Module: Approvals & Credit Engine](#12-module-approvals--credit-engine)
13. [Module: Insights & Analytics](#13-module-insights--analytics)
14. [Module: Purchases & Supplier Management](#14-module-purchases--supplier-management)
15. [Module: Returns & Credit Notes](#15-module-returns--credit-notes)
16. [Module: Trade Promotions & Schemes](#16-module-trade-promotions--schemes)
17. [Module: Compliance & GST](#17-module-compliance--gst)
18. [Module: Accounting Integration](#18-module-accounting-integration)
19. [Setup & Configuration](#19-setup--configuration)
20. [Notifications & Audit Trail](#20-notifications--audit-trail)
21. [Security Model](#21-security-model)
22. [Performance & Infrastructure](#22-performance--infrastructure)
23. [API Design & Mobile Parity](#23-api-design--mobile-parity)
24. [Analytics Instrumentation](#24-analytics-instrumentation)

---

## 1. Executive Summary

OrderLane Pro is a **cloud-native, offline-first, credit-first B2B Distribution Management Platform** purpose-built for FMCG distributors in India. The web dashboard is the primary management interface used by distributor owners, managers, accountants, and warehouse staff to run every dimension of their business — from generating sales orders to recording collections, managing inventory, and filing GST returns.

**Key differentiators:**

| Differentiator | Description |
|---|---|
| **Offline-First** | Field sales reps on the mobile app continue taking orders without internet; data syncs on reconnect via a delta-sync engine |
| **Credit-First** | Every order is evaluated against retailer credit limits in real time; the credit engine enforces SLAs and auto-flags breaches |
| **GST-Native** | HSN/SAC master, GSTR-1 preview and export, e-Invoice and e-Way Bill generation built into the invoicing module |
| **Multi-Tenant / Multi-Branch** | A single platform instance hosts hundreds of distributor organizations, each with multiple branches and role-based access |
| **Role-Differentiated UX** | Dashboard, navigation, and data views are personalized per role (owner, manager, sales rep, accountant, warehouse staff, driver) |

---

## 2. Product Vision & Market Context

**Target Market:** Mid-market FMCG, packaged foods, beverages, pharma, and household goods distributors in India with 2–200 field sales reps, 100–10,000 active retail outlets, and ₹1 Cr – ₹500 Cr annual turnover.

**Core problem being solved:**

1. Distributors today run on WhatsApp + Excel for order booking, creating errors, missed orders, and delayed collections.
2. Credit management is manual, leading to over-exposure and bad debt.
3. GST compliance is a monthly scramble, not a day-zero process.
4. Inventory visibility across branches is non-existent.
5. Field sales force accountability is low with no beat-plan adherence tracking.

**The platform addresses all five problems in a single, integrated product.**

---

## 3. System Architecture

### 3.1 Technology Stack

| Layer | Technology | Purpose |
|---|---|---|
| **Web Frontend** | Next.js 14, TypeScript, Tailwind CSS | App Router, SSR + CSR hybrid |
| **Backend API** | Ruby 3.2, Rails 7.1 (API-only) | JSON REST API, versioned at `/api/v1/` |
| **Database** | PostgreSQL 14+ | Primary relational store, multi-tenant scoped |
| **Cache / Queue** | Redis 7+ | Sidekiq job queue, session cache |
| **Background Jobs** | Sidekiq 7.x | Async processing: invoicing, notifications, stock checks |
| **Authentication** | Devise + devise-jwt | JWT tokens (24-hr expiry), mobile + web |
| **Authorization** | Pundit | Policy-per-resource, role-gated |
| **Mobile** | React Native (Expo SDK 55) | Field sales & delivery apps |

### 3.2 Multi-Tenancy Model

```
Organization  (one per distributor company)
  └── Branch  (warehouse / office location)
        └── Membership  (User × Organization × Branch × Role)
```

All database records carry `organization_id` as a hard-tenancy boundary. Branch scoping provides operational isolation within the same organization. A user can hold memberships across multiple organizations with different roles.

### 3.3 Request Flow

```
Browser → Next.js Edge (layout.tsx) → API Route / Server Component
                                     → Rails API (/api/v1/)
                                           → PostgreSQL
                                           → Redis/Sidekiq (async)
```

All pages are client-rendered under the App Router using `"use client"` components fetching data via JWT-authenticated REST calls. The `OrgBranchProvider` context propagates `token`, `orgId`, `branchId`, and `branches` to every page component.

---

## 4. User Roles & Access Control

The platform defines **six operational roles** enforced at both the API layer (Pundit policies) and the UI layer (role-gated views):

| Role | Persona | Primary Responsibilities |
|---|---|---|
| **Owner** | Distributor proprietor | Full access; plan management, all reports, all settings |
| **Admin** | Senior manager / IT admin | All operational access; user management; no billing |
| **Manager** | Branch / area manager | Order approvals, credit decisions, team performance |
| **Sales Rep** | Field sales executive | Order booking, retailer visits, beat plans |
| **Accountant** | Finance / billing staff | Collections, invoices, GST, aging reports |
| **Warehouse Staff** | Godown / warehouse in-charge | Inventory, stock transfers, pick lists, purchase receipts |
| **Driver** | Delivery vehicle operator | Trip view, stop completion, delivery confirmation |

Access control is implemented via:
- **API layer:** Pundit policies on every controller action (`authorize @record` before any mutation)
- **Web layer:** Role-differentiated dashboard views, hidden navigation items per role
- **Data layer:** `organization_id` tenant scoping on all queries; branch filtering where applicable

---

## 5. Authentication & Onboarding

### 5.1 Signup Flow (6-Step Wizard)

New distributor registration is a guided multi-step flow:

| Step | API Endpoint | Data Captured |
|---|---|---|
| 1 — Initiate | `POST /api/v1/signup/initiate` | Email address; OTP dispatched |
| 2 — Verify OTP | `POST /api/v1/signup/verify_otp` | 6-digit OTP verification |
| 3 — Set Password | `POST /api/v1/signup/set_password` | Password + confirm |
| 4 — Org Details | `POST /api/v1/signup/org_details` | Company name, GSTIN, PAN, state |
| 5 — First Branch | `POST /api/v1/signup/first_branch` | Branch name, address, pincode |
| 6 — Choose Plan | `POST /api/v1/signup/choose_plan` | Subscription tier selection |

### 5.2 Onboarding Wizard (11-Step Setup)

Post-signup, new organizations are taken through an 11-step onboarding wizard before reaching the live dashboard. This wizard collects business-critical configuration:

1. **Welcome** — Product overview with "Load Demo Mode" option to explore with pre-populated data
2. **Business Type** — FMCG Distributor / Rice Distributor / Wholesale Grocery / Custom (sets default credit policies and GST templates)
3. **Organization Details** — Legal name, GSTIN (real-time format validation), PAN, state
4. **Branch Setup** — First warehouse/office location, address, branch code
5. **Operating Model** — Payment terms (COD, 7-day, 30-day, credit), default credit limit policy
6. **Product Catalog** — Seed initial product categories and sample SKUs
7. **Retailer Import** — Bulk CSV import or add first retailers manually
8. **Team Setup** — Invite first team members with roles
9. **Sales Routes** — Define geographic sales territories/beats
10. **Credit Policy** — Configure credit scoring rules, block vs. hold thresholds
11. **Go Live Review** — Summary confirmation before activating the organization

A "Demo Mode" pre-fills all steps with dummy data, letting prospects explore the platform without manual setup.

### 5.3 Login & Password Reset

- **Login:** `POST /api/v1/auth/login` → issues JWT (24-hr expiry)
- **Forgot Password:** Email-based reset token flow (`POST /api/v1/passwords/forgot` → `POST /api/v1/passwords/reset`)
- **Token Refresh:** `POST /api/v1/auth/refresh` for seamless re-authentication
- **Logout:** `DELETE /api/v1/auth/logout` (server-side token revocation)

---

## 6. Module: Dashboard & KPIs

### 6.1 Purpose

The dashboard is the operational nerve-center of the platform — a role-personalized view that surfaces real-time alerts, KPI cards, sales trend charts, and activity feeds.

### 6.2 Role-Differentiated Views

The dashboard renders an entirely different layout depending on the authenticated user's role:

| Role | Dashboard Component | Key Widgets |
|---|---|---|
| **Owner / Admin** | `AdminView` | Full KPI grid, alert ribbon, sales trend chart, recent orders, top customers |
| **Manager** | `ManagerView` | Team performance, pending approvals, collection summary |
| **Sales Rep** | `SalesRepView` | Today's beat plan, visits due, personal order pipeline |
| **Accountant** | `AccountantView` | Overdue collections, ageing summary, pending invoices |
| **Warehouse Staff** | `WarehouseView` | Low-stock alerts, pending stock transfers, pick list queue |
| **Driver** | `DriverView` | Today's trip assignment, delivery stops, route map |

### 6.3 KPI Cards (Owner/Admin/Manager)

Eight real-time KPI tiles fetched from `GET /api/v1/dashboard`:

| KPI | Metric | Comparison |
|---|---|---|
| Today's Sales | ₹ sales booked today | vs. yesterday |
| Monthly Sales | ₹ MTD | vs. last month |
| Pending Collections | ₹ outstanding | overdue count |
| Orders in Pipeline | Count by status | submitted / approved / dispatched |
| Active Retailers | Count | new this month |
| Low-Stock SKUs | Count | critical threshold |
| Credit Utilization | % of total credit extended | high-risk retailers |
| Delivery Success Rate | % this month | rejection count |

### 6.4 Alert Ribbon

Contextual alert pills rendered above the KPI grid, linking directly to the problem resource:

| Alert Type | Severity | Destination |
|---|---|---|
| Orders on credit hold | High (red) | `/approvals` |
| Pending approval requests | Medium (amber) | `/approvals` |
| Overdue collections | High (red) | `/finance/collections` |
| Low-stock SKUs | Medium (amber) | `/inventory/stock` |
| Blocked orders | High (red) | `/approvals` |

Each pill shows an icon, count, and is a click-through link. Clicks are tracked as `dashboard_alert_clicked` GA4 events.

### 6.5 Sales Trend Chart

A 30-day line chart rendering daily sales revenue, overlaid with the previous period for comparison. Rendered using a lightweight SVG chart component with ₹ formatting in Indian Lakh/Crore notation.

### 6.6 Recent Orders Feed

Last 10 orders with: order number, retailer name, ₹ value, status badge, and a "View" link. Status badges are color-coded: Draft (grey), Submitted (amber), Approved (blue), Dispatched (teal), Delivered (green), Cancelled (red).

---

## 7. Module: Sales Order Management

### 7.1 Purpose

End-to-end management of the B2B sales order lifecycle from draft creation through delivery and invoicing.

### 7.2 Order Lifecycle

```
Draft → Submitted → [Credit Check] → Approved (or On Hold / Blocked)
      → Confirmed → Dispatched → Delivered → Invoiced → Paid
```

### 7.3 Order List (`/orders`)

- Paginated DataTable with server-side filtering by: status, date range, retailer, sales rep, branch
- Columns: Order #, Retailer, Sales Rep, Date, ₹ Value, Items, Status, Action
- Quick-filters: "Pending Approval", "On Hold", "Overdue"
- Export to CSV

### 7.4 New Order (`/orders/new`)

Guided order creation form:

1. **Retailer selection** — search/select from customer master; shows credit limit, outstanding balance, and credit utilization %
2. **Product line items** — SKU search with real-time price lookup from assigned price list; quantity input; scheme/discount auto-application
3. **Order summary** — subtotal, GST breakup (CGST/SGST/IGST based on state), scheme discounts, final total
4. **Credit gate** — before submission, the API evaluates the order against the retailer's credit account:
   - `approved` → proceeds to Approved status
   - `hold` → placed On Hold, routed to manager approval
   - `blocked` → hard-blocked with reason displayed to rep

Analytics events fired: `order_created` (on draft save), `order_submitted` (on submit action).

### 7.5 Order Detail (`/orders/[id]`)

Full order view with:
- **Next Action Banner** — contextually shows the next required action (e.g., "Submit for Approval", "Record Payment", "Generate Invoice") with a single primary CTA
- Line items table with unit price, GST rate, scheme discount, net price
- Order lifecycle timeline (every status change with timestamp + user)
- Credit decision history with reason codes
- Related invoice & payment links

### 7.6 Order API Operations

| Action | Endpoint | Access |
|---|---|---|
| Create draft | `POST /api/v1/sales_orders` | Sales Rep+ |
| Submit for approval | `POST /api/v1/sales_orders/:id/submit` | Sales Rep+ |
| Approve | `POST /api/v1/sales_orders/:id/approve` | Manager+ |
| Hold | `POST /api/v1/sales_orders/:id/hold` | Manager+ |
| Cancel | `POST /api/v1/sales_orders/:id/cancel` | Manager+ |
| Refresh price | `POST /api/v1/sales_orders/:id/refresh_price` | Sales Rep+ |
| View lifecycle | `GET /api/v1/sales_orders/:id/lifecycle` | All |

---

## 8. Module: Retailer CRM (Customers)

### 8.1 Purpose

Full lifecycle management of retail outlet (customer) records — the master data that drives order booking, credit management, and beat planning.

### 8.2 Customer List (`/customers`)

- Server-side searchable and filterable DataTable
- Columns: Outlet Name, Contact, Route, Credit Limit, Outstanding, Status
- Bulk CSV import with duplicate-check endpoint (`GET /api/v1/customers/check_duplicate`)
- Export to CSV (`GET /api/v1/customers/export_csv`)

### 8.3 Customer Master Data

Each retailer record maintains:

| Field Group | Fields |
|---|---|
| **Identity** | Business name, owner name, phone, email, GSTIN |
| **Address** | Full address, city, state, pincode, geolocation |
| **Credit Profile** | Credit limit, payment terms, credit score flags |
| **Classification** | Route assignment, category, tier |
| **Status** | Active / Inactive / Blocked |

### 8.4 Customer Detail

- **Credit Usage widget** — live donut showing utilized vs. available credit, outstanding balance, overdue amount
- **Order history** — all orders with status, filterable
- **Payment history** — all collections recorded
- **Activity timeline** — every visit, order, payment, credit change with full audit trail (`GET /api/v1/customers/:id/timeline`)

### 8.5 Credit Account Operations

- Raise credit limit change request (`POST /api/v1/credit_accounts/:id/limit_change_requests`)
- Block / unblock retailer (`POST /api/v1/customers/:id/block`)
- Deactivate retailer (`POST /api/v1/customers/:id/deactivate`)

---

## 9. Module: Inventory Management

### 9.1 Purpose

Real-time stock position visibility across all branches, with incoming stock management (purchase invoices), outbound stock tracking, and inventory adjustments.

### 9.2 Stock Position (`/inventory/stock`)

- **List view:** DataTable with columns: Product, SKU, Branch, On Hand, Reserved, Available, Status
- **Heatmap view:** Visual grid showing stock health across branches and products simultaneously
- **Filter:** Branch selector, "Low stock only" toggle (active/inactive pill, same pattern as Low stock alert)
- **Low Stock Alert:** Ribbon showing count of SKUs below minimum threshold; click-through to filtered list
- Data source: `GET /api/v1/inventory/balances`

### 9.3 Stock Transfer (`/inventory/transfers`)

Inter-branch stock movement workflow:

1. Raise transfer request — source branch, destination branch, SKUs + quantities
2. Dispatch by warehouse staff at source → `POST /api/v1/stock_transfers/:id/dispatch`
3. Receive at destination → `POST /api/v1/stock_transfers/:id/receive`
4. Inventory balances updated atomically on receipt

Analytics event fired on creation: `stock_transfer_created`.

### 9.4 Inventory Adjustments (`/inventory/adjustments`)

Stock correction entries (damages, count corrections, shrinkage):
- Product, branch, quantity delta (positive = receipt, negative = write-off), reason, notes
- Every adjustment posted to inventory movements ledger
- `POST /api/v1/inventory/adjustments`

Analytics event fired: `inventory_adjustment_created`.

### 9.5 Inventory Movements Ledger

Full chronological log of every stock movement: order picks, returns, transfers, adjustments, purchase receipts — `GET /api/v1/inventory/movements`.

---

## 10. Module: Dispatch & Delivery

### 10.1 Purpose

End-to-end management of outbound delivery operations — from trip creation and vehicle assignment through stop-by-stop execution and delivery confirmation.

### 10.2 Delivery Trip List (`/delivery`)

- Active and completed trips
- Filter by date, vehicle, driver
- Columns: Trip #, Driver, Vehicle, Stops, Status, Dispatched At

### 10.3 New Trip (`/delivery/new`)

Trip creation:
1. Select date and vehicle
2. Auto-populate eligible orders (approved, confirmed, ready for dispatch); manually add/remove stops
3. Assign driver (filtered by role = driver)
4. Dispatch trip → `POST /api/v1/delivery_trips/:id/dispatch` → triggers pick list generation

Analytics event fired: `trip_created` with `items_count` (number of stops).

### 10.4 Trip Execution (Driver View)

The driver's dashboard shows:
- Today's assigned trip with stop sequence
- Each stop: retailer name, address, order value, items
- Complete stop → `POST /api/v1/delivery_trips/:id/trip_stops/:stop_id/complete`
- Raise rejection per stop → `POST /api/v1/delivery_trips/:id/trip_stops/:stop_id/rejections`

### 10.5 Delivery Exceptions & Rejections

- `GET /api/v1/delivery_exceptions` — all delivery failures
- `GET /api/v1/delivery_rejections` — customer rejections with reason
- Linked back to returns workflow for rejected-on-delivery goods

### 10.6 Auto-Trip Creation

Batch trip generation from eligible orders: `POST /api/v1/delivery_trips/auto_create` — groups orders by route/zone and creates optimal trip sequences.

---

## 11. Module: Finance & Collections

### 11.1 Purpose

Complete AR (Accounts Receivable) management — recording collections, tracking outstanding balances, managing advance payments, and generating collection schedules for field agents.

### 11.2 Collections (`/finance/collections`)

- Outstanding balance table by retailer: invoice amount, paid, balance, overdue days
- **Record Collection modal:** Amount, payment mode (cash / cheque / NEFT / UPI), reference number, date → `POST /api/v1/payments`
- Payment confirmation workflow: `POST /api/v1/payments/:id/confirm`
- Payment reversal: `POST /api/v1/payments/:id/reverse`

Analytics event fired on recording: `collection_recorded` with `payment_method`.

### 11.3 Sales Invoices (`/sales-invoices`)

- Auto-generate invoices from delivered orders (`POST /api/v1/sales_invoices/generate_from_order/:sales_order_id`)
- Bulk invoice generation (`POST /api/v1/sales_invoices/bulk_generate`)
- Issue invoice → `POST /api/v1/sales_invoices/:id/issue`
- PDF download → `GET /api/v1/sales_invoices/:id/pdf`
- **e-Invoice generation** (IRN) → `POST /api/v1/sales_invoices/:id/einvoice`
- **e-Way Bill** → `POST /api/v1/sales_invoices/:id/ewaybill`
- Void invoice → `POST /api/v1/sales_invoices/:id/void`

### 11.4 Advance Payments

- Record advance (pre-payment) against a retailer's account
- Apply advance to future invoices → `POST /api/v1/advance_payments/:id/apply`
- Refund advance → `POST /api/v1/advance_payments/:id/refund`

### 11.5 Collection Schedules

Planned collection visits assigned to field agents:
- `POST /api/v1/collection_schedules` — create schedule
- `POST /api/v1/collection_schedules/:id/complete` — mark collected
- `POST /api/v1/collection_schedules/:id/skip` — skip with reason
- `POST /api/v1/collection_schedules/:id/reschedule` — move date

### 11.6 Ageing Report

Generated via `GET /api/v1/reports/ageing_report` — segments outstanding balances into 0–30, 31–60, 61–90, 90+ day buckets per retailer.

---

## 12. Module: Approvals & Credit Engine

### 12.1 Purpose

A unified approvals inbox giving managers a single screen to act on all pending decisions: order holds, credit limit change requests, and return requests.

### 12.2 Approvals Inbox (`/approvals`)

Two-panel layout:

**Panel 1 — Order Approvals**
- Tabular list of orders in `submitted` / `on_hold` / `blocked` status requiring manager action
- Per-order: retailer credit profile, order value vs. credit utilization, block reason
- Actions: **Approve** (`POST /api/v1/sales_orders/:id/approve`) | **Reject** (`POST /api/v1/sales_orders/:id/hold`)

**Panel 2 — Credit Limit Change Requests**
- Raised by sales reps to increase a retailer's credit ceiling
- Shows: current limit, requested limit, requester, rationale
- Actions: **Approve** (`POST /api/v1/credit_limit_change_requests/:id/decision` with `{decision: "approved"}`) | **Reject** (same with `{decision: "rejected"}`)

Analytics events: `order_approved`, `order_rejected`, `credit_limit_approved`.

### 12.3 Credit Engine Rules

Configurable via `GET/PUT /api/v1/credit_policy`:

| Rule | Description |
|---|---|
| **Credit Limit** | Per-retailer ceiling in ₹ |
| **Hold Threshold** | % of limit; order placed on hold above this |
| **Block Threshold** | % of limit; order hard-blocked above this |
| **Overdue Lock** | Block all new orders if overdue > N days |
| **Prepayment SKUs** | Specific products always requiring advance payment |

The credit engine evaluates every order at submission time and at price-refresh, setting `credit_decision` to `approved`, `hold`, or `blocked` with reason codes.

### 12.4 Credit Limit Change Request SLA

A Sidekiq cron job (`CreditLimitSlaBreachJob`, every 30 minutes) stamps `sla_breached_at` on requests that exceed the configured response SLA — surfaced as alerts on the manager dashboard.

---

## 13. Module: Insights & Analytics

### 13.1 Purpose

A self-serve business intelligence layer giving owners and managers actionable data across sales, collections, inventory, credit risk, returns, and scheme performance — without needing a separate BI tool.

### 13.2 Analytics Sub-Modules

| Page | Route | API Endpoint | Primary Charts |
|---|---|---|---|
| **Overview** | `/insights` | `GET /api/v1/analytics/overview` | Revenue trend, order volume, top 10 retailers |
| **Sales** | `/insights/sales` | `GET /api/v1/analytics/sales` | Daily/weekly/monthly revenue, rep performance, product mix |
| **Collections** | `/insights/collections` | `GET /api/v1/analytics/collections` | Collection vs. billing, overdues trend, payment mode split |
| **Inventory Health** | `/insights/inventory` | `GET /api/v1/analytics/inventory_health` | Turnover ratio, dead stock, fast/slow movers |
| **Credit Risk** | `/insights/credit-risk` | `GET /api/v1/analytics/credit_risk` | Retailer-level risk scores, overdue aging, credit utilisation distribution |
| **Returns** | `/insights/returns` | `GET /api/v1/analytics/returns` | Return rate %, rejection reasons, product-level returns |
| **Schemes** | `/insights/schemes` | `GET /api/v1/analytics/schemes` | Scheme redemption rate, discount outgo, ROI per scheme |
| **Beat Performance** | `/insights/beats` | `GET /api/v1/analytics/beat_performance` | Visit adherence %, productive vs. non-productive calls |

### 13.3 Downloadable Reports

`GET /api/v1/reports/*` — all reports available as CSV downloads:

- Sales Summary
- Collection Summary
- Product Performance
- Customer Outstanding
- Sales Rep Performance
- Delivery Performance
- Ageing Report

Collections CSV also available inline: `GET /api/v1/analytics/collections/export`.

---

## 14. Module: Purchases & Supplier Management

### 14.1 Supplier Master (`/suppliers`)

- CRUD for suppliers with GST details, payment terms, product catalog linkage
- `POST /api/v1/suppliers/:id/blacklist` — blacklist non-compliant suppliers
- Supplier Products sub-resource: `GET/POST /api/v1/suppliers/:id/supplier_products`

Analytics event on creation: `supplier_created`.

### 14.2 Purchase Invoices (`/purchases/invoices`)

Inbound stock receipts from suppliers:

- Create purchase invoice against a supplier: products, quantities, purchase price, GST
- `POST /api/v1/purchase_invoices/:id/post` — post invoice (updates inventory)
- `POST /api/v1/purchase_invoices/:id/cancel` — cancel before posting

Analytics event on creation: `purchase_invoice_created`.

### 14.3 Supplier Debit Notes (`/supplier-debit-notes`)

Raise debit notes against suppliers for returns, price discrepancies, or quality issues:
- `POST /api/v1/supplier_debit_notes/:id/issue`
- `POST /api/v1/supplier_debit_notes/:id/void`

---

## 15. Module: Returns & Credit Notes

### 15.1 Return Requests (`/returns`)

Outbound returns from retailers (damaged goods, order errors, expiry):

- Create return request with retailer, order reference, items + return reason
- `POST /api/v1/return_requests/:id/submit`
- `POST /api/v1/return_requests/:id/start_qc` — QC verification by warehouse
- `POST /api/v1/return_requests/:id/complete_qc` — QC pass/fail with item-level decisions

Analytics event on creation: `return_created`.

### 15.2 Credit Notes (`/credit-notes`)

Auto-issued from approved returns; can also be raised manually:

- `POST /api/v1/credit_notes/from_return/:return_request_id/issue` — issue credit note from approved return
- `POST /api/v1/credit_notes/:id/apply` — apply credit note against open invoice
- `POST /api/v1/credit_notes/:id/void` — void unapplied credit note

---

## 16. Module: Trade Promotions & Schemes

### 16.1 Scheme Engine (`/schemes`)

Flexible trade promotion engine covering: volume discounts, product combos, free-goods offers, flat-rate discounts, and retailer-tier schemes.

- Create scheme with conditions: minimum order value, specific SKUs, retailer segment, date range
- `GET /api/v1/schemes/by_product?product_id=X` — all active schemes for a product
- `POST /api/v1/order_pricing/preview` — real-time price preview with scheme application before order confirmation

### 16.2 Scheme Application in Orders

The order creation flow calls `order_pricing/preview` on every line item change, showing:
- Unit MRP
- Applicable scheme name + discount %
- Net unit price
- Per-line GST

All discounts are tracked against scheme budgets and surfaced in the Schemes Insights report.

---

## 17. Module: Compliance & GST

### 17.1 GSTR-1 (`/compliance`)

- **Preview** (`GET /api/v1/compliance/gstr1/preview`) — generates the GSTR-1 structured output (B2B invoices, B2C, credit notes, export invoices) from the invoice ledger for a selected return period
- **Export** (`GET /api/v1/compliance/gstr1/export`) — downloads GSTR-1 in JSON format compatible with GST portal upload

### 17.2 HSN/SAC Master (`/settings` → HSN/SAC)

- Full CRUD for HSN/SAC code master (`/api/v1/hsn_sac_codes`)
- Bulk CSV import with sample template download
- Lookup endpoint for product catalog integration: `GET /api/v1/hsn_sac_codes/lookup`

### 17.3 Per-Invoice GST Treatment

Every sales invoice computes GST as:
- **CGST + SGST** for intra-state transactions
- **IGST** for inter-state transactions

GST rates are pulled from the product's HSN/SAC code assignment. All invoices carry GSTIN of both seller and buyer.

---

## 18. Module: Accounting Integration

### 18.1 Purpose

A two-way integration layer that syncs sales, collections, purchase invoices, and credit notes to external accounting software (Tally, Zoho Books, QuickBooks, custom ERP).

### 18.2 Integration Architecture

The system uses an **Agent Model** for Tally (on-premise):

```
OrderLane Cloud API
      ↕ (poll / push over HTTPS)
Accounting Agent (lightweight daemon running locally at distributor's machine)
      ↕
Tally / Local ERP
```

- `POST /api/v1/accounting/integrations` — register an integration
- `POST /api/v1/accounting/integrations/:id/test_configuration` — validate connectivity
- `GET /api/v1/accounting/agent/poll` — agent polls for pending sync commands
- `POST /api/v1/accounting/agent/heartbeat` — agent health monitoring
- `POST /api/v1/accounting/agent/push_from_tally` — Tally-originated data push (payment reconciliation)

### 18.3 Mapping Layer

`/api/v1/accounting/integrations/:id/mappings` — configures how OrderLane entities (customers, products, ledgers) map to accounting software masters. Supports custom field mappings.

### 18.4 Export Files

For cloud accounting tools: `POST /api/v1/accounting/export_files` generates downloadable import files; `GET /:id/download_url` provides a pre-signed URL.

### 18.5 Sync Monitoring

`GET /api/v1/accounting/sync_records` — full log of every sync attempt with status, error codes, and `POST /:id/retry` for failed records.

A Sidekiq cron (`AccountingAgentHeartbeatJob`, every 5 minutes) marks agents as offline if heartbeat is stale — surfaced as an alert on the owner dashboard.

---

## 19. Setup & Configuration

### 19.1 Organization Settings (`/settings`)

| Section | What It Controls |
|---|---|
| **Organization** | Legal name, GSTIN, PAN, address, logo |
| **Branches** | Add/edit branches; per-branch settings |
| **Products** | Product catalog, categories, units of measure |
| **HSN/SAC** | Tax code master |
| **Pricing** | Price lists, per-customer price list assignment |
| **Vehicles** | Fleet master for delivery trip assignment |
| **Users / Team** | Member management, role assignment, invitations |
| **Preferences** | Default payment terms, credit policy defaults, notification preferences |

### 19.2 Team Management (`/users`)

- DataTable of all members: Name, Role badge, Branch, Status (Active/Inactive)
- **Pending Invitations filter toggle** — "Pending invitations only (N)" pill button, active/outline state, filters table to show only pending rows
- **Invite Member modal:** Email, Role selector (from live roles API), Branch selector (optional)
- Deactivate member → `POST /api/v1/users/:id/deactivate`
- Revoke invitation → `DELETE /api/v1/invitations/:id`

### 19.3 Beat & Route Planning (`/beats`, `/routes`)

- Define sales territories (routes) with geographic scope
- Create beat plans: which retailers a rep visits on which day of the week
- Bulk-assign retailers to beat schedules: `POST /api/v1/beats/:id/schedules/:schedule_id/bulk_upsert`

---

## 20. Notifications & Audit Trail

### 20.1 In-App Notifications

- `GET /api/v1/notifications` — paginated notification feed
- `PATCH /api/v1/notifications/:id/read` — mark single read
- `POST /api/v1/notifications/read_all`
- `DELETE /api/v1/notifications/:id`

Notification bell in the top-bar shows unread count badge.

### 20.2 Push Notifications (Mobile)

Device tokens registered via `POST /api/v1/device_tokens`. Background jobs (Sidekiq `critical` queue) dispatch push notifications for: order status changes, credit decisions, low stock alerts, and collection reminders.

### 20.3 Audit Logs

`GET /api/v1/audit_logs` — full immutable audit trail of every data mutation: who, what, when, from which IP. Available to Owner/Admin roles.

### 20.4 Webhooks

`/api/v1/webhook_endpoints` — organizations can register HTTP webhooks to receive real-time events (order created, payment confirmed, delivery completed, etc.) to integrate with their own systems.

---

## 21. Security Model

### 21.1 Authentication Security

| Control | Implementation |
|---|---|
| JWT expiry | 24-hour tokens; refresh endpoint available |
| Token secret | `JWT_SECRET` env var; rotatable without downtime |
| Password hashing | bcrypt via Devise |
| OTP verification | Time-limited 6-digit codes for signup |

### 21.2 Authorization

- Every API action calls Pundit `authorize` before any data access or mutation
- Tenant isolation enforced at ActiveRecord query scope level — cross-tenant data access is architecturally impossible
- Branch-level scoping applied in addition to org-level for sensitive financial data

### 21.3 Transport Security

- All API and web traffic over HTTPS (TLS 1.2+)
- CORS configured at Rails level (`rack-cors`) — only trusted origins whitelisted
- Sidekiq dashboard protected by HTTP Basic Auth + session cookie (not exposed to JWT API middleware)

### 21.4 Data Protection

- No PII stored in logs
- All credentials (JWT secret, DB password, Redis URL) via environment variables — never in source code
- Webhooks validate with HMAC signatures; Sidekiq web guarded by `SIDEKIQ_USER`/`SIDEKIQ_PASSWORD` env vars

---

## 22. Performance & Infrastructure

### 22.1 Background Jobs (Sidekiq)

Four-queue priority system:

| Queue | Priority Weight | Job Types |
|---|---|---|
| `critical` | 3× | Invoice PDF generation, webhook delivery, push notifications |
| `invoicing` | 3× | Auto-invoice generation from delivery stops |
| `default` | 2× | Most background operations |
| `low` | 1× | CSV exports, report generation, analytics aggregation |

Scheduled cron jobs:

| Job | Schedule | Purpose |
|---|---|---|
| `AccountingAgentHeartbeatJob` | Every 5 min | Mark offline accounting agents |
| `CreditLimitSlaBreachJob` | Every 30 min | Flag overdue credit approval requests |
| `CheckLowStockJob` | 2 AM daily | Notify warehouse staff of low-stock conditions |

### 22.2 Offline Sync (Mobile)

- `GET /api/v1/sync/delta` — returns only records changed since a given timestamp (efficient mobile sync)
- `POST /api/v1/sync/push` — mobile app pushes locally-created records on reconnect
- All field operations (order booking, visit check-in, delivery confirmation) continue offline; sync resolves conflicts on next connection

### 22.3 API Versioning

- All production endpoints under `/api/v1/`
- `/api/v2/` namespace scaffolded for future breaking changes with opt-in via `Accept-Version: v2` header
- v1 maintained with no breaking changes; v2 changes are additive

---

## 23. API Design & Mobile Parity

The Rails backend is **API-only** — it serves both the Next.js web app and the React Native mobile app from the same versioned endpoints. This ensures:

1. **Feature parity** — any feature built on mobile is immediately available on web (same API)
2. **Single source of truth** — business logic lives in Rails models/services, never duplicated in frontend
3. **Consistent authorization** — Pundit policies apply equally regardless of client type

Standard response envelope across all endpoints:

```json
// Success
{ "data": { ... }, "meta": { "total_count": 42, "page": 1 } }

// Error
{ "errors": ["Credit limit exceeded", "GSTIN format invalid"] }
```

---

## 24. Analytics Instrumentation

The web dashboard has full GA4 event tracking implemented on all user interactions:

### 24.1 Automatic Page Views

A `usePageTracking()` hook fires page view events on every route change. All 60+ routes are mapped to named events via `ROUTE_EVENT_MAP` in `lib/analytics/constants.ts`.

### 24.2 Business Event Tracking

Every meaningful CTA records a structured business event:

| Event Name | Trigger | Key Properties |
|---|---|---|
| `order_created` | Draft saved | `order_id`, `items_count` |
| `order_submitted` | Order submitted for approval | `order_id` |
| `order_approved` / `order_rejected` | Manager decision | `order_id` |
| `collection_recorded` | Payment recorded | `payment_method` |
| `retailer_created` | New customer saved | — |
| `product_created` | New product saved | — |
| `supplier_created` | New supplier saved | — |
| `purchase_invoice_created` | Purchase invoice created | — |
| `return_created` | Return request created | — |
| `trip_created` | Delivery trip created | `items_count` |
| `stock_transfer_created` | Inventory transfer created | `items_count` |
| `inventory_adjustment_created` | Stock adjustment posted | — |
| `user_invited` | Team member invited | `invited_role` |
| `credit_limit_approved` | Credit limit approved | — |
| `dashboard_alert_clicked` | Alert ribbon CTA clicked | `alert_type`, `severity`, `count` |
| `sidebar_nav_clicked` | Sidebar navigation used | `nav_item`, `element_label` |
| `global_search_used` | Command palette opened | — |

### 24.3 Implementation

- GA4 script injected via `next/script` `strategy="afterInteractive"` in `app/layout.tsx`
- All `gtag()` calls wrapped in `safeGtag()` — silently no-ops if GA ID is missing or in dev mode
- Dev mode tracking opt-in via `NEXT_PUBLIC_GA_DEV_ENABLED=true`
- `suppressHydrationWarning` on `<html>`, `<head>`, `<body>` to prevent browser-extension-caused hydration errors

---

## Appendix A — Environment Variables

| Variable | Purpose | Required |
|---|---|---|
| `DATABASE_URL` | PostgreSQL connection string | Yes |
| `REDIS_URL` | Redis connection string | Yes |
| `JWT_SECRET` | JWT signing key | Yes |
| `NEXT_PUBLIC_API_URL` | Backend API base URL | Yes |
| `NEXT_PUBLIC_GA_MEASUREMENT_ID` | Google Analytics 4 property ID | Recommended |
| `NEXT_PUBLIC_GA_DEV_ENABLED` | Enable GA in development | Optional |
| `SIDEKIQ_USER` / `SIDEKIQ_PASSWORD` | Sidekiq dashboard auth | Yes |
| `NEXT_PUBLIC_APP_URL` | App base URL for OG metadata | Recommended |

---

## Appendix B — Module / Route Map

| Module | Web Route | Primary API |
|---|---|---|
| Dashboard | `/dashboard` | `GET /api/v1/dashboard` |
| Orders | `/orders` | `/api/v1/sales_orders` |
| Customers | `/customers` | `/api/v1/customers` |
| Inventory — Stock | `/inventory/stock` | `/api/v1/inventory/balances` |
| Inventory — Transfers | `/inventory/transfers` | `/api/v1/stock_transfers` |
| Inventory — Adjustments | `/inventory/adjustments` | `/api/v1/inventory/adjustments` |
| Delivery | `/delivery` | `/api/v1/delivery_trips` |
| Finance — Collections | `/finance/collections` | `/api/v1/payments` |
| Sales Invoices | `/sales-invoices` | `/api/v1/sales_invoices` |
| Approvals | `/approvals` | `/api/v1/approvals`, `/api/v1/credit_limit_change_requests` |
| Returns | `/returns` | `/api/v1/return_requests` |
| Credit Notes | `/credit-notes` | `/api/v1/credit_notes` |
| Purchases | `/purchases/invoices` | `/api/v1/purchase_invoices` |
| Suppliers | `/suppliers` | `/api/v1/suppliers` |
| Schemes | `/schemes` | `/api/v1/schemes` |
| Insights | `/insights/*` | `/api/v1/analytics/*` |
| Compliance | `/compliance` | `/api/v1/compliance/gstr1/*` |
| Beats | `/beats` | `/api/v1/beats` |
| Routes | `/routes` | `/api/v1/routes` |
| Accounting | `/accounting` | `/api/v1/accounting/*` |
| Users | `/users` | `/api/v1/users`, `/api/v1/invitations` |
| Settings | `/settings/*` | `/api/v1/organizations`, `/api/v1/branches`, etc. |

---

*This document reflects the implemented state of the OrderLane Pro platform as of March 2026. All feature descriptions correspond to working, deployed code.*
