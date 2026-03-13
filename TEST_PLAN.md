# OrdWave Test Plan

## Project Overview
**OrdWave** is an offline-first, credit-first Order Management System for B2B distributors across FMCG categories.

### Tech Stack
- **Backend**: Ruby 3.2 · Rails 7.1 API (PostgreSQL + Redis + Sidekiq)
- **Web**: Next.js 14 · TypeScript · Tailwind CSS
- **Mobile**: Expo React Native app (TypeScript)
- **Auth**: JWT (API) · Session/cookie (Web)

### Roles in System
1. **owner** - Full access to everything
2. **admin** - Administrative access, can manage users and settings
3. **manager** - Can manage orders, customers, and operations
4. **sales_rep** - Can create orders and view assigned customers
5. **warehouse_staff** - Can manage pick lists and inventory
6. **accountant** - Can manage payments, invoices, and accounting
7. **driver** - Can manage deliveries and trips

---

## Test Case Categories

### 1. Authentication & Signup Flows

#### TC-AUTH-001: User Signup - Complete Flow
**Priority**: High
**Steps**:
1. Navigate to signup page
2. Enter email address
3. Receive and verify OTP
4. Set password
5. Enter organization details
6. Create first branch
7. Choose plan (starter/growth/enterprise)
8. Verify user is created with owner role

**Expected Result**: User successfully signed up with owner role and organization created

#### TC-AUTH-002: User Login - Valid Credentials
**Priority**: High
**Steps**:
1. Navigate to login page
2. Enter valid email and password
3. Submit login form

**Expected Result**: User logged in successfully, JWT token received

#### TC-AUTH-003: User Login - Invalid Credentials
**Priority**: High
**Steps**:
1. Navigate to login page
2. Enter invalid email or password
3. Submit login form

**Expected Result**: Login rejected with appropriate error message

#### TC-AUTH-004: Password Reset Flow
**Priority**: Medium
**Steps**:
1. Click "Forgot Password"
2. Enter registered email
3. Receive reset token
4. Set new password
5. Login with new password

**Expected Result**: Password reset successful, can login with new password

#### TC-AUTH-005: User Logout
**Priority**: Medium
**Steps**:
1. Login as any user
2. Click logout

**Expected Result**: User logged out, token revoked

---

### 2. Owner Role Test Cases

#### TC-OWNER-001: Dashboard Access
**Priority**: High
**Steps**:
1. Login as owner
2. Navigate to dashboard

**Expected Result**: Dashboard loads with organization overview, analytics, and all widgets

#### TC-OWNER-002: Organization Management
**Priority**: High
**Steps**:
1. Navigate to Settings > Organization
2. Update organization details
3. View plan information
4. Update workflow settings

**Expected Result**: Organization settings updated successfully

#### TC-OWNER-003: Branch Management - Create
**Priority**: High
**Steps**:
1. Navigate to Settings > Branches
2. Click "Add Branch"
3. Enter branch details (name, code, city, state)
4. Save branch

**Expected Result**: Branch created successfully

#### TC-OWNER-004: Branch Management - Update
**Priority**: High
**Steps**:
1. Navigate to existing branch
2. Update branch details
3. Update branch settings

**Expected Result**: Branch updated successfully

#### TC-OWNER-005: User Management - Invite User
**Priority**: High
**Steps**:
1. Navigate to Settings > Team
2. Click "Invite User"
3. Enter email, select role, assign branch
4. Send invitation

**Expected Result**: Invitation sent, pending invitation created

#### TC-OWNER-006: User Management - Deactivate User
**Priority**: High
**Steps**:
1. Navigate to Users page
2. Select a user
3. Click "Deactivate"

**Expected Result**: User deactivated, tokens revoked

#### TC-OWNER-007: Role Management - View Roles
**Priority**: Medium
**Steps**:
1. Navigate to Roles page
2. View all available roles

**Expected Result**: All system roles displayed (owner, admin, manager, sales_rep, warehouse_staff, accountant, driver)

#### TC-OWNER-008: Credit Policy Management
**Priority**: High
**Steps**:
1. Navigate to Settings > Credit Policy
2. Update credit policy settings:
   - Hard block overdue days
   - Soft hold overdue days
   - Collection first bucket
   - Approval SLA hours
3. Save changes

**Expected Result**: Credit policy updated successfully

#### TC-OWNER-009: Customer Management - Full CRUD
**Priority**: High
**Steps**:
1. Navigate to Customers
2. Create new customer with all details
3. Update customer information
4. View customer credit usage
5. View customer timeline
6. Block/Unblock customer
7. Deactivate customer

**Expected Result**: All customer operations successful

#### TC-OWNER-010: Product Management - Full CRUD
**Priority**: High
**Steps**:
1. Navigate to Products
2. Create product category
3. Create unit of measure
4. Create HSN/SAC code
5. Create product with all details
6. Update product
7. Discontinue product
8. Bulk import products

**Expected Result**: All product operations successful

#### TC-OWNER-011: Price List Management
**Priority**: High
**Steps**:
1. Navigate to Products > Price Lists
2. Create price list
3. Add items to price list
4. Assign price list to customer/tier
5. Bulk import price list items

**Expected Result**: Price list operations successful

#### TC-OWNER-012: Sales Order - Full Lifecycle
**Priority**: High
**Steps**:
1. Navigate to Orders
2. Create new order
3. Add order lines
4. Submit order
5. Approve order
6. Pick order
7. Confirm pick
8. Generate invoice
9. Cancel order (test cancellation flow)

**Expected Result**: Order lifecycle completed successfully

#### TC-OWNER-013: Sales Invoice Management
**Priority**: High
**Steps**:
1. Navigate to Sales Invoices
2. View all invoices
3. Generate invoice from order
4. Issue invoice
5. Download PDF
6. Generate e-waybill
7. Void invoice

**Expected Result**: Invoice operations successful

#### TC-OWNER-014: Payments & Collections
**Priority**: High
**Steps**:
1. Navigate to Collections
2. Create payment
3. Confirm payment
4. View advance payments
5. Apply advance payment
6. Create collection schedule
7. Complete collection schedule

**Expected Result**: Payment operations successful

#### TC-OWNER-015: Returns Management
**Priority**: High
**Steps**:
1. Navigate to Returns
2. Create return request
3. Submit return
4. Start QC
5. Complete QC
6. Issue credit note
7. Apply credit note

**Expected Result**: Return workflow completed successfully

#### TC-OWNER-016: Credit Notes Management
**Priority**: High
**Steps**:
1. Navigate to Credit Notes
2. View all credit notes
3. Issue credit note from return
4. Void credit note
5. Apply credit note to invoice

**Expected Result**: Credit note operations successful

#### TC-OWNER-017: Supplier Management
**Priority**: High
**Steps**:
1. Navigate to Suppliers
2. Create supplier
3. Update supplier
4. Blacklist supplier
5. Activate supplier
6. Add supplier products

**Expected Result**: Supplier operations successful

#### TC-OWNER-018: Purchase Invoice Management
**Priority**: High
**Steps**:
1. Navigate to Purchases > Invoices
2. Create purchase invoice
3. Post invoice
4. Cancel invoice

**Expected Result**: Purchase invoice operations successful

#### TC-OWNER-019: Inventory Management
**Priority**: High
**Steps**:
1. Navigate to Inventory
2. View stock levels
3. Create stock transfer
4. Dispatch transfer
5. Receive transfer
6. Create inventory adjustment
7. View stock movements

**Expected Result**: Inventory operations successful

#### TC-OWNER-020: Route Management
**Priority**: High
**Steps**:
1. Navigate to Routes
2. Create route
3. Update route
4. Delete route

**Expected Result**: Route operations successful

#### TC-OWNER-021: Beat Management
**Priority**: High
**Steps**:
1. Navigate to Beats
2. Create beat
3. Add retailers to beat
4. Create beat schedule
5. Bulk upsert retailers

**Expected Result**: Beat operations successful

#### TC-OWNER-022: Vehicle Management
**Priority**: High
**Steps**:
1. Navigate to Settings > Fleet
2. Create vehicle
3. Update vehicle
4. Delete vehicle

**Expected Result**: Vehicle operations successful

#### TC-OWNER-023: Delivery Trip Management
**Priority**: High
**Steps**:
1. Navigate to Delivery
2. Create delivery trip
3. Add stops to trip
4. Dispatch trip
5. Complete stop
6. Record rejection

**Expected Result**: Delivery operations successful

#### TC-OWNER-024: Scheme Management
**Priority**: High
**Steps**:
1. Navigate to Schemes
2. Create scheme with conditions and rewards
3. Update scheme
4. Delete scheme
5. View scheme stats

**Expected Result**: Scheme operations successful

#### TC-OWNER-025: Order Pricing Preview
**Priority**: Medium
**Steps**:
1. Navigate to Pricing
2. Preview order pricing with schemes
3. Verify price calculations

**Expected Result**: Pricing preview accurate

#### TC-OWNER-026: GST Compliance - GSTR-1
**Priority**: High
**Steps**:
1. Navigate to Compliance > GSTR-1
2. Preview GSTR-1 data
3. Generate GSTR-1 export
4. View amendments
5. Detect amendments

**Expected Result**: GSTR-1 operations successful

#### TC-OWNER-027: GST Compliance - GSTR-2B
**Priority**: High
**Steps**:
1. Navigate to Compliance > GSTR-2B
2. Import GSTR-2B
3. View import details
4. View lines

**Expected Result**: GSTR-2B operations successful

#### TC-OWNER-028: GST Compliance - GSTR-3B
**Priority**: High
**Steps**:
1. Navigate to Compliance > GSTR-3B
2. Generate GSTR-3B
3. View computation
4. Check variance

**Expected Result**: GSTR-3B operations successful

#### TC-OWNER-029: Reconciliation
**Priority**: High
**Steps**:
1. Navigate to Compliance > Reconciliation
2. View issues
3. Run reconciliation
4. Resolve issue
5. Acknowledge issue
6. Ignore issue

**Expected Result**: Reconciliation operations successful

#### TC-OWNER-030: GST Periods Management
**Priority**: High
**Steps**:
1. Navigate to Compliance > GST Periods
2. Review period
3. Lock period
4. File return
5. Reopen period

**Expected Result**: GST period operations successful

#### TC-OWNER-031: Financial Years
**Priority**: High
**Steps**:
1. Navigate to Finance > Financial Years
2. Create financial year
3. Lock GST for year
4. Close financial year
5. View checklist

**Expected Result**: Financial year operations successful

#### TC-OWNER-032: Bank Reconciliation - Accounts
**Priority**: High
**Steps**:
1. Navigate to Bank Reconciliation
2. Create bank account
3. Update bank account
4. View dashboard

**Expected Result**: Bank account operations successful

#### TC-OWNER-033: Bank Reconciliation - Statement Import
**Priority**: High
**Steps**:
1. Import bank statement
2. View import details
3. Process import

**Expected Result**: Statement import successful

#### TC-OWNER-034: Bank Reconciliation - Transactions
**Priority**: High
**Steps**:
1. View bank transactions
2. Confirm match
3. Mark as advance
4. Ignore transaction
5. Retry match

**Expected Result**: Transaction operations successful

#### TC-OWNER-035: Accounting Integration
**Priority**: High
**Steps**:
1. Navigate to Accounting > Integrations
2. Create integration (Tally)
3. Test configuration
4. Mark connected/disconnected
5. Manage mappings
6. View sync records
7. Retry failed syncs

**Expected Result**: Accounting integration operations successful

#### TC-OWNER-036: Analytics & Reports
**Priority**: High
**Steps**:
1. Navigate to Insights
2. View overview
3. View sales analytics
4. View collections analytics
5. View credit risk
6. View beat performance
7. View inventory health
8. View returns
9. View schemes
10. Export reports

**Expected Result**: All analytics and reports accessible

#### TC-OWNER-037: Audit Logs
**Priority**: Medium
**Steps**:
1. Navigate to Settings > Audit
2. View audit logs
3. Filter by action/actor

**Expected Result**: Audit logs displayed correctly

#### TC-OWNER-038: Approvals Inbox
**Priority**: High
**Steps**:
1. Navigate to Approvals
2. View pending approvals
3. Approve/Reject credit limit requests

**Expected Result**: Approval operations successful

#### TC-OWNER-039: Credit Limit Change Requests
**Priority**: High
**Steps**:
1. Navigate to Approvals > Credit Limits
2. View pending requests
3. Make decision (approve/reject)

**Expected Result**: Decision recorded, credit limit updated

#### TC-OWNER-040: Prepayment SKU Management
**Priority**: Medium
**Steps**:
1. Navigate to Settings > Prepayment SKUs
2. Create prepayment SKU
3. Deactivate prepayment SKU

**Expected Result**: Prepayment SKU operations successful

#### TC-OWNER-041: Pick Lists Management
**Priority**: High
**Steps**:
1. Navigate to Operations > Pick Lists
2. View pick lists
3. Start picking
4. Update pick item
5. Complete pick

**Expected Result**: Pick list operations successful

#### TC-OWNER-042: Notifications
**Priority**: Medium
**Steps**:
1. View notifications
2. Mark as read
3. Mark all as read
4. Delete notification

**Expected Result**: Notification operations successful

#### TC-OWNER-043: Profile Management
**Priority**: Medium
**Steps**:
1. Navigate to Profile
2. Update profile details
3. Change password

**Expected Result**: Profile operations successful

#### TC-OWNER-044: Webhook Management
**Priority**: Medium
**Steps**:
1. Navigate to Settings > Webhooks
2. Create webhook endpoint
3. Update webhook
4. Test webhook
5. Delete webhook

**Expected Result**: Webhook operations successful

#### TC-OWNER-045: Exports
**Priority**: Medium
**Steps**:
1. Navigate to Settings > Exports
2. Create export
3. View export status
4. Download export

**Expected Result**: Export operations successful

#### TC-OWNER-046: Supplier Debit Notes
**Priority**: High
**Steps**:
1. Navigate to Supplier Debit Notes
2. Create debit note
3. Issue debit note
4. Void debit note

**Expected Result**: Debit note operations successful

#### TC-OWNER-047: Retailer Risk Profile
**Priority**: Medium
**Steps**:
1. Navigate to customer
2. View risk profile
3. Recompute risk profile

**Expected Result**: Risk profile displayed and updated

#### TC-OWNER-048: Collection Schedules
**Priority**: High
**Steps**:
1. Navigate to Collections > Schedule
2. Create collection schedule
3. Complete schedule
4. Skip schedule
5. Reschedule

**Expected Result**: Collection schedule operations successful

#### TC-OWNER-049: Delivery Exceptions
**Priority**: Medium
**Steps**:
1. Navigate to Delivery > Exceptions
2. View exceptions

**Expected Result**: Exceptions displayed

#### TC-OWNER-050: Delivery Rejections
**Priority**: Medium
**Steps**:
1. Navigate to Delivery > Rejections
2. View rejections

**Expected Result**: Rejections displayed

---

### 3. Admin Role Test Cases

#### TC-ADMIN-001: Dashboard Access
**Priority**: High
**Expected**: Dashboard accessible with appropriate widgets

#### TC-ADMIN-002: User Management
**Priority**: High
**Permissions**:
- Can invite users (same as owner)
- Can deactivate users (same as owner)
- Cannot delete organization

#### TC-ADMIN-003: Branch Management
**Priority**: High
**Permissions**:
- Can create/update branches
- Cannot delete organization

#### TC-ADMIN-004: Customer Management
**Priority**: High
**Permissions**: Same as owner (manager_above?)

#### TC-ADMIN-005: Product Management
**Priority**: High
**Permissions**: Same as owner (manager_above?)

#### TC-ADMIN-006: Order Management
**Priority**: High
**Permissions**: Same as owner (manager_above?)

#### TC-ADMIN-007: Invoice Management
**Priority**: High
**Permissions**: Same as owner (manager_above?)

#### TC-ADMIN-008: Payment Management
**Priority**: High
**Permissions**: Same as owner (manager_above?)

#### TC-ADMIN-009: Returns Management
**Priority**: High
**Permissions**: Same as owner (manager_above?)

#### TC-ADMIN-010: Credit Policy
**Priority**: High
**Permissions**: Can view/update credit policy

#### TC-ADMIN-011: Settings Access
**Priority**: High
**Permissions**: Most settings accessible except organization deletion

---

### 4. Manager Role Test Cases

#### TC-MANAGER-001: Dashboard Access
**Priority**: High
**Expected**: Dashboard accessible with branch-scoped data

#### TC-MANAGER-002: User Management - Limited
**Priority**: Medium
**Permissions**: Can view users, cannot invite/deactivate

#### TC-MANAGER-003: Customer Management
**Priority**: High
**Permissions**: Full CRUD on customers (manager_above?)

#### TC-MANAGER-004: Order Management
**Priority**: High
**Permissions**:
- Can create orders
- Can update orders (draft and limited fields for submitted)
- Can submit orders
- Can approve orders
- Can hold orders
- Can cancel orders
- Can pick orders
- Can confirm picks

#### TC-MANAGER-005: Invoice Management
**Priority**: High
**Permissions**:
- Can view invoices
- Can create invoices
- Can issue invoices
- Cannot void invoices (owner/admin only)

#### TC-MANAGER-006: Delivery Management
**Priority**: High
**Permissions**: Can manage delivery trips and stops

#### TC-MANAGER-007: Inventory Management
**Priority**: High
**Permissions**: Can manage inventory for assigned branch

#### TC-MANAGER-008: Beat Management
**Priority**: High
**Permissions**: Can manage beats for assigned branch

#### TC-MANAGER-009: Credit Limit Requests
**Priority**: High
**Permissions**: Can approve/reject credit limit change requests

#### TC-MANAGER-010: Data Scope
**Priority**: High
**Expected**: Only sees data for assigned branch

---

### 5. Sales Rep Role Test Cases

#### TC-SALES-001: Dashboard Access
**Priority**: High
**Expected**: Limited dashboard with relevant metrics

#### TC-SALES-002: Customer Access
**Priority**: High
**Permissions**:
- Can view customers (branch-scoped)
- Cannot create/update customers
- Can view credit usage

#### TC-SALES-003: Order Creation
**Priority**: High
**Steps**:
1. Create order
2. Add order lines
3. Submit order (only own orders)
4. Refresh price

**Permissions**:
- Can create orders
- Can update own draft orders
- Can submit own orders
- Cannot approve orders
- Cannot cancel approved orders

#### TC-SALES-004: Order Visibility
**Priority**: High
**Expected**: Only sees orders created by self

#### TC-SALES-005: Beat Visits
**Priority**: High
**Steps**:
1. View today's visits
2. Check-in at retailer
3. Checkout from retailer
4. Skip visit

#### TC-SALES-006: Product Catalog
**Priority**: Medium
**Permissions**: Can view products and prices

#### TC-SALES-007: Mobile Order Entry
**Priority**: High
**Expected**: Can create orders from mobile app

---

### 6. Warehouse Staff Role Test Cases

#### TC-WAREHOUSE-001: Dashboard Access
**Priority**: High
**Expected**: Warehouse-focused dashboard

#### TC-WAREHOUSE-002: Pick Lists
**Priority**: High
**Steps**:
1. View pick lists
2. Start picking
3. Update picked quantities
4. Complete pick

**Permissions**:
- Can view pick lists
- Can start/complete picks
- Cannot confirm picks (manager only)

#### TC-WAREHOUSE-003: Order Visibility
**Priority**: High
**Expected**: Only sees orders pending pick or picked

#### TC-WAREHOUSE-004: Inventory View
**Priority**: High
**Permissions**: Can view inventory levels

#### TC-WAREHOUSE-005: Stock Movements
**Priority**: Medium
**Permissions**: Can view stock movements

---

### 7. Accountant Role Test Cases

#### TC-ACCOUNTANT-001: Dashboard Access
**Priority**: High
**Expected**: Finance-focused dashboard

#### TC-ACCOUNTANT-002: Payments Management
**Priority**: High
**Steps**:
1. Create payments
2. Confirm payments
3. Reverse payments
4. View advance payments

#### TC-ACCOUNTANT-003: Invoice Management
**Priority**: High
**Permissions**: Can view and manage invoices

#### TC-ACCOUNTANT-004: Credit Notes
**Priority**: High
**Permissions**: Can view and manage credit notes

#### TC-ACCOUNTANT-005: Bank Reconciliation
**Priority**: High
**Permissions**: Full access to bank reconciliation

#### TC-ACCOUNTANT-006: Accounting Integration
**Priority**: High
**Permissions**: Can manage accounting integrations

#### TC-ACCOUNTANT-007: GST Compliance
**Priority**: High
**Permissions**: Full access to GST modules

#### TC-ACCOUNTANT-008: Reports
**Priority**: High
**Permissions**: Can generate and view financial reports

#### TC-ACCOUNTANT-009: Purchase Invoices
**Priority**: High
**Permissions**: Can manage purchase invoices

#### TC-ACCOUNTANT-010: Supplier Debit Notes
**Priority**: High
**Permissions**: Can manage supplier debit notes

---

### 8. Driver Role Test Cases

#### TC-DRIVER-001: Mobile App Access
**Priority**: High
**Expected**: Can login to mobile app

#### TC-DRIVER-002: Today's Trips
**Priority**: High
**Steps**:
1. View assigned trips
2. View trip stops
3. Navigate to stops

#### TC-DRIVER-003: Delivery Completion
**Priority**: High
**Steps**:
1. Complete delivery stop
2. Upload delivery proof
3. Record any rejections

#### TC-DRIVER-004: Offline Mode
**Priority**: High
**Expected**: Can operate in offline mode and sync later

---

### 9. Cross-Cutting Test Cases

#### TC-CROSS-001: Multi-Tenancy Isolation
**Priority**: Critical
**Steps**:
1. Create data in Organization A
2. Login to Organization B
3. Verify Organization A data is not visible

**Expected Result**: Complete data isolation between organizations

#### TC-CROSS-002: Branch Scoping
**Priority**: Critical
**Steps**:
1. Create data in Branch A
2. Login as user from Branch B
3. Verify Branch A data is not visible (for non-owner/admin)

**Expected Result**: Proper branch-level data scoping

#### TC-CROSS-003: API Authentication
**Priority**: Critical
**Steps**:
1. Access API without token
2. Access API with expired token
3. Access API with invalid token

**Expected Result**: All unauthorized requests rejected

#### TC-CROSS-004: API Authorization
**Priority**: Critical
**Steps**:
1. Access resource with insufficient permissions
2. Access resource outside scope

**Expected Result**: All unauthorized access attempts rejected

#### TC-CROSS-005: Data Validation
**Priority**: High
**Steps**:
1. Submit forms with invalid data
2. Submit forms with missing required fields
3. Submit duplicate data where not allowed

**Expected Result**: Appropriate validation errors returned

#### TC-CROSS-006: Concurrent Operations
**Priority**: Medium
**Steps**:
1. Two users edit same record simultaneously
2. Verify conflict handling

**Expected Result**: Proper optimistic locking or conflict resolution

#### TC-CROSS-007: Bulk Operations
**Priority**: Medium
**Steps**:
1. Bulk import customers
2. Bulk import products
3. Bulk generate invoices

**Expected Result**: Bulk operations complete successfully

---

### 10. Integration Test Cases

#### TC-INT-001: Order to Invoice Flow
**Priority**: Critical
**Steps**:
1. Create order
2. Submit order
3. Approve order
4. Pick order
5. Generate invoice
6. Issue invoice

**Expected Result**: Complete flow executes without errors

#### TC-INT-002: Return to Credit Note Flow
**Priority**: Critical
**Steps**:
1. Create return request
2. Submit return
3. Complete QC
4. Issue credit note
5. Apply credit note to invoice

**Expected Result**: Complete flow executes without errors

#### TC-INT-003: Payment Allocation Flow
**Priority**: Critical
**Steps**:
1. Create payment
2. Confirm payment
3. Verify invoice allocation
4. Check credit account balance

**Expected Result**: Payment allocated correctly

#### TC-INT-004: Delivery Trip Flow
**Priority**: Critical
**Steps**:
1. Create delivery trip
2. Add stops
3. Dispatch trip
4. Complete stops
5. Generate invoices from stops

**Expected Result**: Complete flow executes without errors

#### TC-INT-005: Scheme Application Flow
**Priority**: High
**Steps**:
1. Create scheme
2. Create order with qualifying products
3. Verify scheme is applied
4. Check pricing calculations

**Expected Result**: Scheme applied correctly

#### TC-INT-006: Credit Limit Check Flow
**Priority**: Critical
**Steps**:
1. Set customer credit limit
2. Create orders exceeding limit
3. Verify blocking/holding behavior
4. Process payment
5. Verify order can proceed

**Expected Result**: Credit limit enforced correctly

#### TC-INT-007: GST Calculation Flow
**Priority**: Critical
**Steps**:
1. Create order with GST items
2. Verify GST calculations
3. Generate invoice
4. Verify GSTR-1 data

**Expected Result**: GST calculated and reported correctly

#### TC-INT-008: Accounting Sync Flow
**Priority**: High
**Steps**:
1. Create invoice
2. Trigger accounting sync
3. Verify sync record created
4. Simulate agent poll
5. Verify data export

**Expected Result**: Accounting sync works correctly

---

## Test Execution Summary

### Test Count by Category

| Category | Test Count |
|----------|------------|
| Authentication & Signup | 5 |
| Owner Role | 50 |
| Admin Role | 11 |
| Manager Role | 10 |
| Sales Rep Role | 7 |
| Warehouse Staff Role | 5 |
| Accountant Role | 10 |
| Driver Role | 4 |
| Cross-Cutting | 7 |
| Integration | 8 |
| **Total** | **117** |

### Priority Distribution

| Priority | Count |
|----------|-------|
| Critical | 12 |
| High | 85 |
| Medium | 20 |

### Role Permissions Matrix

| Feature | Owner | Admin | Manager | Sales Rep | Warehouse | Accountant | Driver |
|---------|-------|-------|---------|-----------|-----------|------------|--------|
| Organization Mgmt | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| User Invite | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| User Deactivate | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Branch Mgmt | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Customer CRUD | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Product CRUD | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Order Create | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Order Approve | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Order Pick | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ |
| Order Confirm Pick | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Invoice Create | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Invoice Void | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Payment Manage | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ |
| Returns Manage | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Credit Note Issue | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Delivery Manage | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ |
| Beat Manage | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Inventory Manage | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ |
| GST Compliance | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ |
| Accounting | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ |
| Reports | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ |
| Scheme Manage | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Credit Policy | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Approvals | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Audit Logs | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Settings | ✅ | ✅ | Limited | ❌ | ❌ | ❌ | ❌ |

---

## Notes

1. **Database Connection Required**: Backend RSpec tests require PostgreSQL database connection
2. **Test Data**: Tests use FactoryBot for test data generation
3. **Authentication**: API tests require JWT token authentication
4. **Authorization**: Tests verify Pundit policy enforcement
5. **Multi-tenancy**: Tests verify organization and branch scoping

## Recommendations

1. Set up test database for automated test execution
2. Implement Cypress/Playwright for E2E frontend testing
3. Add API contract tests
4. Add performance tests for critical paths
5. Add mobile app E2E tests using Detox or Appium
