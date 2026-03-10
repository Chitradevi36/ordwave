# OrderLane Pro — Shared Components & Design System Plan

## 8. Shared Components and Design System Plan

### 8.1 Cross-Platform Design Tokens

Standardize these tokens across web (Tailwind CSS) and mobile (Flutter ThemeData):

| Token | Web (CSS Variable) | Tailwind Class | Flutter Constant |
|---|---|---|---|
| Primary | `--color-primary: #1B4332` | `text-primary` / `bg-primary` | `OlColors.primary = Color(0xFF1B4332)` |
| Primary Light | `--color-primary-light: #2D6A4F` | `text-primary-600` | `OlColors.primaryLight = Color(0xFF2D6A4F)` |
| Accent / Success | `--color-accent: #52B788` | `text-accent` / `bg-accent` | `OlColors.accent = Color(0xFF52B788)` |
| Danger | `--color-danger: #DC2626` | `text-danger` / `bg-danger` | `OlColors.danger = Color(0xFFDC2626)` |
| Warning | `--color-warning: #D97706` | `text-warning` | `OlColors.warning = Color(0xFFD97706)` |
| Info | `--color-info: #2563EB` | `text-blue-600` | `OlColors.info = Color(0xFF2563EB)` |
| Text Primary | `#1a1a1a` | `text-gray-900` | `OlColors.textPrimary = Color(0xFF1A1A1A)` |
| Text Secondary | `#6B7280` | `text-gray-500` | `OlColors.textSecondary = Color(0xFF6B7280)` |
| Text Muted | `#9CA3AF` | `text-gray-400` | `OlColors.textMuted = Color(0xFF9CA3AF)` |
| Border | `#E5E7EB` | `border-gray-200` | `OlColors.border = Color(0xFFE5E7EB)` |
| Background | `#FFFFFF` | `bg-white` | `OlColors.background = Color(0xFFFFFFFF)` |
| Background Subtle | `#F8FAF8` | `bg-[#F8FAF8]` | `OlColors.backgroundSubtle = Color(0xFFF8FAF8)` |
| Background Hover | `#F3F4F6` | `bg-gray-100` | `OlColors.backgroundHover = Color(0xFFF3F4F6)` |

### 8.2 Typography Scale

| Name | Web | Flutter |
|---|---|---|
| H1 | `text-2xl font-bold` (28px/700) | `TextStyle(fontSize: 28, fontWeight: FontWeight.w700)` |
| H2 | `text-xl font-semibold` (24px/600) | `TextStyle(fontSize: 24, fontWeight: FontWeight.w600)` |
| H3 | `text-lg font-semibold` (20px/600) | `TextStyle(fontSize: 20, fontWeight: FontWeight.w600)` |
| H4 | `text-base font-semibold` (16px/600) | `TextStyle(fontSize: 16, fontWeight: FontWeight.w600)` |
| Body | `text-sm` (14px/400) | `TextStyle(fontSize: 14, fontWeight: FontWeight.w400)` |
| Body Small | `text-xs` (12px/400) | `TextStyle(fontSize: 12, fontWeight: FontWeight.w400)` |
| Label | `text-xs font-medium uppercase tracking-wide` | `TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5)` |
| Mono | `font-mono text-sm` | `TextStyle(fontSize: 14, fontFamily: 'monospace')` |

### 8.3 Universal Status Color Mapping

This mapping MUST be identical across web and mobile to ensure visual consistency:

```typescript
// Web: lib/constants/status-variants.ts
export const STATUS_VARIANTS: Record<string, BadgeVariant> = {
  // Neutral / Initial
  draft: 'secondary',
  inactive: 'secondary',
  
  // Pending / Attention
  submitted: 'warning',
  pending: 'warning',
  on_hold: 'warning',
  planned: 'warning',
  partial_delivery: 'warning',
  partially_paid: 'warning',
  partially_received: 'warning',
  qc_in_progress: 'warning',
  syncing: 'warning',
  
  // Success / Complete
  approved: 'success',
  confirmed: 'success',
  delivered: 'success',
  completed: 'success',
  paid: 'success',
  issued: 'success',
  active: 'success',
  received: 'success',
  qc_completed: 'success',
  credit_note_issued: 'success',
  synced: 'success',
  connected: 'success',
  
  // In-Progress / Informational
  dispatched: 'default',
  in_progress: 'default',
  processing: 'default',
  
  // Danger / Terminal
  rejected: 'danger',
  cancelled: 'danger',
  void: 'danger',
  failed: 'danger',
  reversed: 'danger',
  blocked: 'danger',
  blacklisted: 'danger',
  overdue: 'danger',
  error: 'danger',
  disconnected: 'danger',
};
```

```dart
// Flutter: lib/core/theme/status_colors.dart
enum StatusVariant { neutral, warning, success, info, danger }

final Map<String, StatusVariant> statusVariants = {
  'draft': StatusVariant.neutral,
  'inactive': StatusVariant.neutral,
  'submitted': StatusVariant.warning,
  'pending': StatusVariant.warning,
  'on_hold': StatusVariant.warning,
  'planned': StatusVariant.warning,
  'partial_delivery': StatusVariant.warning,
  'partially_paid': StatusVariant.warning,
  'approved': StatusVariant.success,
  'confirmed': StatusVariant.success,
  'delivered': StatusVariant.success,
  'completed': StatusVariant.success,
  'paid': StatusVariant.success,
  'issued': StatusVariant.success,
  'active': StatusVariant.success,
  'dispatched': StatusVariant.info,
  'in_progress': StatusVariant.info,
  'rejected': StatusVariant.danger,
  'cancelled': StatusVariant.danger,
  'void': StatusVariant.danger,
  'failed': StatusVariant.danger,
  'reversed': StatusVariant.danger,
  'blocked': StatusVariant.danger,
  'overdue': StatusVariant.danger,
};
```

### 8.4 Web Shared Components

#### Existing (Enhance)

| Component | Current | Enhancement |
|---|---|---|
| `DataTable` | Generic typed table with sort, skeleton, empty state | Add column resize, sticky header, row selection checkbox, bulk actions bar |
| `Badge` | 6 variants (default, secondary, success, warning, danger, outline) | Add `dot` variant (small colored dot + text), icon support |
| `Modal` | Radix Dialog, 4 sizes | Add confirmation modal variant with danger styling |
| `EmptyState` | Icon + title + description + action | Add illustration variants per module |
| `Card` | Header/content/footer | Add collapsible variant, loading skeleton variant |

#### New Components to Build

| Component | Purpose | Props | Used In |
|---|---|---|---|
| **StatusTimeline** | Visual stepped event timeline with actors + timestamps | `events: { status, actor, timestamp, description }[]` | Order detail, delivery detail, return detail, payment detail, credit limit request |
| **CreditBanner** | Customer credit status summary bar | `outstanding, limit, overdue, overduedays, flags: { hold, blocked, watchlist, collectFirst }` | Customer detail header, order creation, customer list row |
| **ApprovalCard** | Actionable approval item | `title, description, requestor, timestamp, entityType, onApprove, onReject, requireReason` | Approval inbox |
| **ExceptionPanel** | Collapsible exception/error list | `exceptions: { code, message, severity }[], onResolve` | Delivery exceptions, sync errors, import results |
| **SummaryBanner** | Horizontal KPI strip for detail pages | `items: { label, value, variant? }[]` | Order detail (total/paid/outstanding), customer detail, trip detail |
| **FilterBar** | Standardized filter row | `statusTabs, searchPlaceholder, dateRange?, dropdownFilters?` | Every list page — replaces ad-hoc filter implementations |
| **ActionDrawer** | Right-side slide-out panel | `open, onClose, title, width?, children` | Quick create payment, order detail actions, bulk actions |
| **SyncStatusBadge** | Synced/pending/failed indicator | `status: 'synced' \| 'pending' \| 'failed', tooltip?` | Any mobile-originated record shown on web |
| **AgeingChart** | Horizontal stacked bar for overdue buckets | `buckets: { label, amount, color }[]` | Credit risk dashboard, customer detail, accountant dashboard |
| **ProgressTracker** | Horizontal step indicator | `steps: { label, status: 'done' \| 'current' \| 'upcoming' }[]` | Order lifecycle, onboarding, delivery trip |
| **MetricCard** | KPI card with optional sparkline | `label, value, change?, trend?, sparklineData?` | All dashboards |
| **ConfirmDialog** | Confirmation modal with danger variant | `title, message, confirmLabel, variant: 'default' \| 'danger', onConfirm` | Delete actions, void actions, reversal actions |

### 8.5 Mobile Shared Widgets

| Widget | Purpose | Key Props |
|---|---|---|
| `OlAppBar` | Consistent app bar with sync indicator | `title, subtitle, leadingAction, trailingActions, showSyncBadge` |
| `OlCard` | Card container | `variant (elevated/outlined/flat), onTap, padding, child` |
| `OlStatusChip` | Colored status pill matching web | `status (string), size (sm/md)` |
| `OlListItem` | Standard list row | `leading, title, subtitle, trailing, onTap, showDivider` |
| `OlButton` | Full button system | `variant, size, loading, fullWidth, icon, onPressed` |
| `OlTextField` | Labeled text input | `label, hint, error, controller, keyboardType, validator, obscure` |
| `OlAmountInput` | Currency input with ₹ prefix | `value, onChanged, label` — auto-formats Indian number system |
| `OlBottomSheet` | Action sheet | `title, child, actions` — handles safe area + keyboard avoidance |
| `OlSyncBadge` | Sync status indicator | `syncStatus (synced/pending/failed)` |
| `OlCreditBanner` | Credit check result banner | `decision (ok/hold/blocked), outstanding, limit, overdueDays` |
| `OlEmptyState` | Empty state placeholder | `icon, title, description, actionLabel, onAction` |
| `OlProductCard` | Product with qty stepper | `product, qty, onQtyChanged, price` — large +/- 48dp buttons |
| `OlStopCard` | Delivery stop summary | `stop, onTap` — sequence #, retailer, status, amount |
| `OlSignaturePad` | Signature capture | `onSaved` — uses syncfusion_flutter_signaturepad |
| `OlLoadingShimmer` | Shimmer placeholder | `width, height, borderRadius` |
| `OlSearchBar` | Search input with debounce | `onSearch, placeholder, autofocus` |
| `OlKpiRow` | Horizontal KPI cards row | `items: { label, value, icon }[]` |

### 8.6 Spacing & Layout Constants

| Token | Web | Flutter | Usage |
|---|---|---|---|
| xs | `p-1` / 4px | `EdgeInsets.all(4)` | Icon padding, tight spacing |
| sm | `p-2` / 8px | `EdgeInsets.all(8)` | Chip padding, compact lists |
| md | `p-3` / 12px | `EdgeInsets.all(12)` | Card content padding |
| base | `p-4` / 16px | `EdgeInsets.all(16)` | Standard content padding |
| lg | `p-5` / 20px | `EdgeInsets.all(20)` | Section spacing |
| xl | `p-6` / 24px | `EdgeInsets.all(24)` | Page padding |
| xxl | `p-8` / 32px | `EdgeInsets.all(32)` | Major section gaps |

### 8.7 Icon Usage

**Web:** lucide-react icons throughout. Key icons per module:
- Dashboard: `LayoutDashboard`
- Sales/Orders: `ShoppingCart`
- Customers: `Users`
- Catalog: `BookOpen`
- Operations/Delivery: `Truck`
- Inventory: `Layers`
- Finance: `DollarSign` (use `IndianRupee` where contextual)
- Insights: `BarChart2`
- Accounting: `BookMarked`
- Settings: `Settings`
- Notifications: `Bell`
- Sync: `RefreshCw`

**Flutter:** Use equivalent Material/Cupertino icons or `lucide_icons` package for consistency.

### 8.8 Currency Formatting Standard

```typescript
// Web: lib/utils/currency.ts
export function formatINR(amount: number): string {
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
  }).format(amount);
}
// Output: ₹1,23,456.78
```

```dart
// Flutter: lib/core/utils/currency.dart
import 'package:intl/intl.dart';

String formatINR(double amount) {
  final format = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  return format.format(amount);
}
// Output: ₹1,23,456.78
```
