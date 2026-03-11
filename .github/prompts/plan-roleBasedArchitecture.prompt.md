# OrdWave — Role-Based Product Architecture

## 3. Final Role-Based Product Architecture

### Owner
| Aspect | Detail |
|---|---|
| **Main goals** | Monitor business health, review exceptions, approve high-value decisions |
| **Daily jobs** | Review dashboard KPIs, check overdue collections, approve credit limit changes, review returns, check sales rep performance |
| **Login view** | Executive dashboard: revenue today/MTD, outstanding receivables, overdue %, top alerts, order pipeline, sales trend chart |
| **Dashboard cards** | Revenue (today/MTD), Outstanding AR, Overdue Amount, Orders Today, Collection Today, Low Stock Alerts, Credit Blocked Customers |
| **Navigation** | All 9 workspaces. Primary: Dashboard, Sales, Finance, Insights |
| **Allowed modules** | All |
| **Quick actions** | View Approvals, Export Reports, Add Branch, Invite Team Member |
| **Alerts** | High-value order holds, credit limit breaches, payment reversals, stock-outs, failed deliveries |
| **Hidden** | Nothing |
| **Platform** | Web primary, mobile for occasional checks |

### Branch Manager
| Aspect | Detail |
|---|---|
| **Main goals** | Run branch operations efficiently, ensure orders flow, manage team |
| **Daily jobs** | Assign beats, review orders, dispatch trips, resolve exceptions, check inventory |
| **Login view** | Branch operations dashboard: Orders pending approval, trips in progress, low stock items, team activity |
| **Dashboard cards** | Pending Approvals, Active Trips, Today's Orders, Inventory Alerts, Team Online |
| **Navigation** | Dashboard, Sales, Customers, Catalog, Operations, Inventory |
| **Allowed modules** | All except Billing, Accounting Integration |
| **Quick actions** | Approve Order, Create Trip, Auto-Create Trips, Adjust Stock |
| **Alerts** | Orders awaiting approval, failed deliveries, stock shortages, beat coverage gaps |
| **Hidden** | Billing settings, accounting integration config, org-level settings |
| **Platform** | Web primary |

### Sales Rep
| Aspect | Detail |
|---|---|
| **Main goals** | Visit retailers, capture orders, collect payments, build relationships |
| **Daily jobs** | Check beat plan, visit retailers, create orders, collect payments, log visits |
| **Login view** | Today's beat plan with retailer list, pending orders count, collection target |
| **Dashboard cards** | Today's Visits (done/total), Orders Created Today, Collections Today, Beat Completion % |
| **Navigation** | Home, Beat Plan, Retailers, New Order, Collections, My Orders |
| **Allowed modules** | Customers (own), Orders (own), Payments (create/confirm), Visits, Products (read-only) |
| **Quick actions** | New Order, Quick Collect, Check In, Log Visit |
| **Alerts** | Overdue visits, credit-blocked retailers (before ordering), order rejections |
| **Hidden** | Inventory, Delivery, Settings, Insights, Accounting, other reps' data |
| **Platform** | **Mobile primary**, web secondary |

### Driver
| Aspect | Detail |
|---|---|
| **Main goals** | Complete deliveries, capture POD, handle partial/failed deliveries, collect cash |
| **Daily jobs** | View trip, navigate to stops, deliver, get signatures, report exceptions |
| **Login view** | Today's trip with stop list, nav to first undelivered stop |
| **Dashboard cards** | Today's Trip (stops done/total), Pending Deliveries, Cash Collected, Exceptions |
| **Navigation** | Home, My Trip, Stop Detail, Collect Cash |
| **Allowed modules** | DeliveryTrips (own), TripStops (own), Payments (cash collect), Returns (at delivery) |
| **Quick actions** | Start Trip, Complete Stop, Report Exception, Collect Cash |
| **Alerts** | New trip assigned, route changes, customer contact info |
| **Hidden** | Everything except delivery-related modules |
| **Platform** | **Mobile only** |

### Warehouse Staff
| Aspect | Detail |
|---|---|
| **Main goals** | Pick orders, dispatch trips, receive transfers, maintain stock accuracy |
| **Daily jobs** | Process pick lists, load vehicles, confirm dispatches, receive goods, adjust stock |
| **Login view** | Warehouse dashboard: orders to pick, trips to dispatch, transfers incoming, low stock |
| **Dashboard cards** | Orders to Pick, Trips Ready to Dispatch, Incoming Transfers, Low Stock Count, Today's Movements |
| **Navigation** | Dashboard, Pick Lists, Dispatch, Inventory, Transfers, Products |
| **Allowed modules** | Inventory, Stock Transfers, Products (read), Delivery Trips (dispatch only), Orders (read) |
| **Quick actions** | Start Pick List, Confirm Dispatch, Receive Transfer, Adjust Stock |
| **Alerts** | New approved orders (to pick), incoming transfers, low stock thresholds |
| **Hidden** | Finance, Payments, Credit, Pricing, Settings, Insights, Customers |
| **Platform** | Web primary, tablet possible |

### Accountant
| Aspect | Detail |
|---|---|
| **Main goals** | Manage collections, reconcile payments, generate invoices, track outstanding |
| **Daily jobs** | Record payments, allocate to invoices, generate invoices, review overdue, export for Tally |
| **Login view** | Finance dashboard: outstanding AR, overdue ageing, today's collections, pending invoices |
| **Dashboard cards** | Total Outstanding, Overdue Amount, Today's Collections, Pending Invoices, Credit Notes Unapplied |
| **Navigation** | Dashboard, Collections, Invoices, Credit Notes, Payments, Advances, Accounting, Reports |
| **Allowed modules** | Payments, Invoices, Credit Notes, Advance Payments, Customers (credit view), Reports (financial), Accounting |
| **Quick actions** | Record Payment, Generate Invoice, Apply Credit Note, Export to Tally |
| **Alerts** | Overdue > 30 days, payment reversals, large outstanding changes, sync failures |
| **Hidden** | Inventory, Delivery, Products, Catalog, Beats, Schemes |
| **Platform** | Web primary |

---

## Final Web Navigation

```
SIDEBAR (workspace hubs):
├── Dashboard          (all roles)
├── Sales              (owner, admin, manager, sales_rep)
│   ├── Orders
│   ├── Approvals
│   └── Schemes
├── Customers          (owner, admin, manager, sales_rep)
│   ├── All Customers
│   ├── Routes
│   └── Beats
├── Catalog            (owner, admin, manager, warehouse)
│   ├── Products
│   ├── Categories
│   ├── Price Lists
│   └── HSN/SAC Codes
├── Operations         (owner, admin, manager, warehouse, driver)
│   ├── Delivery Trips
│   ├── Exceptions
│   └── Returns
├── Inventory          (owner, admin, manager, warehouse)
│   ├── Stock Levels
│   ├── Transfers
│   ├── Adjustments
│   └── Suppliers & Purchases
├── Finance            (owner, admin, manager, accountant)
│   ├── Collections / Payments
│   ├── Invoices
│   ├── Credit Notes
│   ├── Advance Payments
│   ├── Supplier Debit Notes
│   └── Compliance (GSTR-1)
├── Insights           (owner, admin, manager, accountant)
│   ├── Overview
│   ├── Sales
│   ├── Collections
│   ├── Credit Risk
│   ├── Inventory Health
│   └── Beat Performance
├── Accounting         (owner, admin, accountant)
│   ├── Integrations
│   ├── Sync Records
│   └── Export Files
└── Settings           (owner, admin, manager)
    ├── Organization
    ├── Branches
    ├── Team & Roles
    ├── Credit Policy
    ├── Fleet
    ├── Webhooks
    └── Billing
```

## Final Mobile Flutter Navigation

**Sales Rep Bottom Nav:**
```
Home | Beat Plan | New Order | Collections | More
```

**Driver Bottom Nav:**
```
Home | My Trip | Collect | More
```

---

## Module Ownership Map

| Module | Backend | Web | Mobile |
|---|---|---|---|
| Auth | ✅ | ✅ | ✅ |
| Onboarding | ✅ | ✅ | — |
| Roles & permissions | ✅ | ✅ (nav filtering) | ✅ (role-based home) |
| Retailers / Customers | ✅ | ✅ | ✅ |
| Contacts | ✅ | ✅ | ✅ (read) |
| Addresses | ✅ | ✅ | ✅ (read) |
| Products | ✅ | ✅ | ✅ (read + order) |
| Price Lists | ✅ | ✅ | ✅ (read via order) |
| HSN/SAC | ✅ | ✅ | — |
| Credit | ✅ | ✅ | ✅ (check at order) |
| Orders | ✅ | ✅ | ✅ (create + track) |
| Approvals | ✅ | ✅ | — |
| Delivery | ✅ | ✅ | ✅ (driver primary) |
| Vehicles | ✅ | ✅ | — |
| Suppliers | ✅ | ✅ | — |
| Purchase Invoices | ✅ | ✅ | — |
| Inventory | ✅ | ✅ | — |
| Transfers | ✅ | ✅ | — |
| Payments | ✅ | ✅ | ✅ (collect) |
| Advances | ✅ | ✅ | — |
| Collections | ✅ | ✅ | ✅ (schedule + collect) |
| Invoices | ✅ | ✅ | — |
| Credit Notes | ✅ | ✅ | — |
| Returns | ✅ | ✅ | ✅ (at delivery) |
| Notifications | ✅ | ✅ | ✅ |
| Reports | ✅ | ✅ | — |
| Settings | ✅ | ✅ | ✅ (profile only) |
| Billing | ✅ | ✅ | — |
| Sync / Offline | ✅ (delta API) | — | ✅ (primary) |
