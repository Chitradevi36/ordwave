# OrderLane Pro – Architecture Overview

## Product

**OrderLane Pro** is an offline-first, credit-first Order Management System designed for B2B distributors across FMCG categories (packaged foods, beverages, pharma, household goods, and more).

---

## Tech Stack

| Layer       | Technology                                       |
|-------------|--------------------------------------------------|
| Backend API | Ruby 3.2 · Rails 7.1 (API-only) · PostgreSQL · Redis |
| Web App     | Next.js 14 · TypeScript · Tailwind CSS           |
| Mobile App  | React Native · Expo SDK 55 · TypeScript          |
| Auth        | JWT (API) · Session/cookie (Web)                 |
| Background  | Sidekiq + Redis                                  |
| Auth lib    | Devise + devise-jwt                              |
| Authz       | Pundit                                           |

---

## Monorepo Layout

```
orderlane_pro/
├── backend/          # Rails 7.1 API
│   ├── app/
│   │   ├── controllers/api/v1/
│   │   ├── models/
│   │   └── policies/
│   ├── config/
│   │   └── routes.rb
│   └── db/migrate/
├── web/              # Next.js 14 web app
│   ├── app/          # App Router pages
│   ├── components/
│   │   ├── layout/   # AppShell, Sidebar, TopBar, PageHeader
│   │   └── ui/       # Design system atoms & molecules
│   └── lib/          # Utilities
├── mobile/           # Expo React Native app
│   ├── src/
│   │   ├── components/  # Shared mobile components
│   │   └── theme/       # Design tokens
│   └── App.tsx
├── docs/             # Architecture & conventions
└── .github/
    └── workflows/    # CI pipelines
```

---

## Multi-Tenancy Model

The platform is multi-tenant at the **Organization** level, with sub-tenancy via **Branch**.

```
Organization
  └── Branch(es)
        └── Membership (User + Role)
```

- All resources are scoped by `organization_id` (and optionally `branch_id`).
- The `Membership` model links Users to Organizations and Branches with a Role.
- Roles control Pundit policy access.

---

## API Design

- Base path: `/api/v1/`
- All endpoints return JSON.
- Authentication via `Authorization: Bearer <JWT>` header.
- JWT is issued by `POST /api/v1/auth/login` and expires in 24 hours.
- Standard response envelope:
  ```json
  { "data": { ... } }
  { "errors": { ... } }
  ```

---

## How to Add a New Module

### Backend (Rails)

1. Generate model + migration:
   ```
   cd backend
   rails generate model Widget name:string organization:references
   rails db:migrate
   ```
2. Create controller at `app/controllers/api/v1/widgets_controller.rb` extending `BaseController`.
3. Create Pundit policy at `app/policies/widget_policy.rb`.
4. Add routes under `namespace :api > namespace :v1`.

### Web (Next.js)

1. Add page at `web/app/<module>/page.tsx` — use `AppShell` for layout.
2. Use shared UI components from `web/components/ui/` (Button, DataTable, Card, etc.).
3. Add a nav link to `web/components/layout/sidebar.tsx`.

### Mobile (Expo)

1. Add a new screen in `mobile/src/screens/<Module>Screen.tsx`.
2. Register the screen in the relevant navigator in `App.tsx`.
3. Use shared components from `mobile/src/components/` and tokens from `mobile/src/theme/`.

---

## Key Conventions

- No module or UI label should be category-specific (no "rice", "grain", etc.).
- Use generic FMCG terms: **Outlet**, **Product**, **Category**, **Route**, **Distributor**, **Collection**.
- All new API endpoints must be versioned under `/api/v1/`.
- Background jobs use `Sidekiq` with Redis.
- All models must include `organization_id` for tenant scoping.
