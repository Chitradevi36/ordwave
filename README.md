# OmniDist OMS

> **Offline-first, Credit-first OMS for FMCG Distributors**

OmniDist OMS is a multi-tenant Order Management System for B2B distributors across all FMCG categories — packaged foods, beverages, pharma, household goods, and more.

---

## Monorepo Structure

```
orderlane_pro/
├── backend/    → Rails 7.1 API (PostgreSQL + Redis + Sidekiq)
├── web/        → Next.js 14 web app (TypeScript + Tailwind)
├── mobile/     → Expo React Native app (TypeScript)
├── docs/       → Architecture, design system, backend conventions
└── .github/    → CI workflows
```

---

## Quick Start

### Backend (Rails API)

```bash
cd backend
bundle install
cp .env.example .env   # set DATABASE_URL, REDIS_URL, JWT_SECRET
rails db:create db:migrate
rails server -p 3001
```

### Web (Next.js)

```bash
cd web
npm install
cp .env.local.example .env.local   # set NEXT_PUBLIC_API_URL
npm run dev -- -p 4000
# npm run dev   # http://localhost:3001
```

### Mobile (Expo)

```bash
cd mobile
npm install
npx expo start
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [docs/ARCHITECTURE_OVERVIEW.md](docs/ARCHITECTURE_OVERVIEW.md) | Stack, folder layout, multi-tenancy, how to add modules |
| [docs/DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md) | Colors, typography, component library reference |
| [docs/BACKEND_CONVENTIONS.md](docs/BACKEND_CONVENTIONS.md) | API conventions, auth, authorization, background jobs |

---

## Design System Colors

| Token | Color | Usage |
|-------|-------|-------|
| Primary | `#1B4332` | Sidebar, buttons, headers |
| Secondary | `#2D6A4F` | Hover states, secondary actions |
| Accent | `#52B788` | Success, highlights |
| Danger | `#DC2626` | Errors, destructive actions |
| Warning | `#D97706` | Alerts, warnings |

---

## Tech Stack

- **Backend**: Ruby 3.2 · Rails 7.1 · PostgreSQL · Redis · Sidekiq · Devise · Pundit
- **Web**: Next.js 14 · TypeScript · Tailwind CSS · Radix UI
- **Mobile**: Expo SDK 55 · React Native · TypeScript · React Navigation

---

## CI

GitHub Actions workflows run on changes to each sub-project:

- `.github/workflows/backend-ci.yml` — RuboCop + Rails tests
- `.github/workflows/web-ci.yml` — TypeScript check + ESLint + Next.js build
- `.github/workflows/mobile-ci.yml` — TypeScript check