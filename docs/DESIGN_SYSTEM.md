# OmniDist OMS – Design System

## Overview

OmniDist OMS uses a consistent enterprise SaaS design system based on deep green brand colors. The same design tokens are applied across the web (Tailwind CSS) and mobile (React Native StyleSheet) platforms.

---

## Color Palette

| Token            | Hex       | Usage                              |
|------------------|-----------|------------------------------------|
| Primary          | `#1B4332` | CTA buttons, sidebar, header       |
| Secondary        | `#2D6A4F` | Secondary actions, hover states    |
| Accent / Success | `#52B788` | Success badges, highlights         |
| Background       | `#FFFFFF` | Page background                    |
| Background Subtle| `#F8FAF8` | Panels, table rows, sidebar items  |
| Text Primary     | `#1E293B` | Headings, body text                |
| Text Secondary   | `#64748B` | Labels, subtitles, placeholders    |
| Danger           | `#DC2626` | Error states, delete actions       |
| Warning          | `#D97706` | Warnings, alerts                   |
| Border           | `#E2E8F0` | Dividers, input borders, cards     |

### Web (Tailwind)

Colors are configured in `web/tailwind.config.ts` under `theme.extend.colors`. Use the Tailwind color utilities:

```tsx
// Good
<div className="bg-primary text-white" />
<p className="text-text-secondary" />
<div className="border-border" />

// Avoid hardcoding hex values
```

### Mobile (React Native)

Import from the theme:

```typescript
import { colors } from '../theme';

const styles = StyleSheet.create({
  container: { backgroundColor: colors.background },
  title: { color: colors.textPrimary },
});
```

---

## Typography

**Font**: Inter (400 regular, 500 medium, 600 semibold, 700 bold)

| Style       | Size | Weight | Usage               |
|-------------|------|--------|---------------------|
| H1          | 28px | 700    | Page titles         |
| H2          | 22px | 700    | Section titles      |
| H3          | 18px | 600    | Card titles         |
| Body        | 14px | 400    | Default text        |
| Body Small  | 12px | 400    | Helper text, labels |
| Label       | 13px | 500    | Form labels         |

---

## Spacing Scale

| Token | Value |
|-------|-------|
| xs    | 4px   |
| sm    | 8px   |
| md    | 12px  |
| lg    | 16px  |
| xl    | 24px  |
| xxl   | 32px  |

---

## Component Library

### Web (`web/components/`)

#### Layout

| Component   | File                           | Description                               |
|-------------|--------------------------------|-------------------------------------------|
| AppShell    | `layout/app-shell.tsx`         | Full-page layout: Sidebar + TopBar + main |
| Sidebar     | `layout/sidebar.tsx`           | Left nav with brand logo and nav items    |
| TopBar      | `layout/top-bar.tsx`           | Header with search, notifications, user   |
| PageHeader  | `layout/page-header.tsx`       | Page title + description + action buttons |

#### Atoms (UI primitives)

| Component | File               | Variants                                       |
|-----------|--------------------|------------------------------------------------|
| Button    | `ui/button.tsx`    | default, secondary, outline, ghost, danger, link |
| Input     | `ui/input.tsx`     | with label, error, helperText                  |
| Badge     | `ui/badge.tsx`     | default, secondary, success, warning, danger, outline |
| Alert     | `ui/alert.tsx`     | default, success, warning, danger              |

#### Molecules

| Component   | File                  | Description                                  |
|-------------|-----------------------|----------------------------------------------|
| Card        | `ui/card.tsx`         | Card with Header, Title, Description, Content, Footer |
| DataTable   | `ui/data-table.tsx`   | Generic typed table with loading + empty states |
| Modal       | `ui/modal.tsx`        | Radix Dialog-based modal, 4 sizes            |
| Tabs        | `ui/tabs.tsx`         | Radix Tabs with underline active indicator   |
| EmptyState  | `ui/empty-state.tsx`  | Icon + title + description + action CTA      |

All components are exported from `web/components/ui/index.ts` and `web/components/layout/index.ts`.

### Mobile (`mobile/src/components/`)

| Component     | Description                                       |
|---------------|---------------------------------------------------|
| AppBar        | Top header with title, subtitle, left/right slots |
| PrimaryButton | 5 variants × 3 sizes, loading state              |
| Card          | default / elevated / outlined                     |
| ListItem      | Row with left/right elements + optional divider   |
| StatusPill    | Coloured rounded badge (success/warning/danger/info/neutral) |
| FormField     | Labelled TextInput with validation and helper text |
| Banner        | Coloured alert with optional title and left border |

All components are exported from `mobile/src/components/index.ts`.

---

## Usage Examples

### Web – Dashboard Page

```tsx
import { AppShell } from "@/components/layout/app-shell";
import { PageHeader } from "@/components/layout/page-header";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { DataTable, Column } from "@/components/ui/data-table";
import { Badge } from "@/components/ui/badge";

export default function Page() {
  return (
    <AppShell title="Orders">
      <PageHeader
        title="Orders"
        description="Manage distributor orders"
        actions={[{ label: "New Order", onClick: () => {} }]}
      />
      <Card>
        <CardHeader><CardTitle>Recent Orders</CardTitle></CardHeader>
        <CardContent>
          <DataTable columns={columns} data={orders} />
        </CardContent>
      </Card>
    </AppShell>
  );
}
```

### Mobile – List Screen

```tsx
import { AppBar, Card, ListItem, StatusPill, PrimaryButton } from '../components';
import { colors } from '../theme';

export function OrdersScreen() {
  return (
    <View style={{ flex: 1, backgroundColor: colors.backgroundSubtle }}>
      <AppBar title="Orders" />
      <Card>
        <ListItem
          title="Fresh Mart"
          subtitle="3 items · ₹4,500"
          rightElement={<StatusPill label="Confirmed" variant="success" />}
        />
      </Card>
      <PrimaryButton title="New Order" />
    </View>
  );
}
```

---

## Keeping UI Consistent

1. **Always use theme tokens** (no hardcoded colors or sizes).
2. **Use generic FMCG terminology**: Outlet, Product, Category, Route, Distributor.
3. **New web pages** must use `AppShell` and `PageHeader`.
4. **New mobile screens** must use `AppBar` and follow spacing from `theme/index.ts`.
5. **Status indicators** (order state, payment state) use `Badge` (web) or `StatusPill` (mobile).
