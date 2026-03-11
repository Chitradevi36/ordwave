# OrdWave — Top 30 Priority Tasks + Risks + Appendices

## Section 10: Top 30 Implementation Tasks (Priority Order)

Tasks are sequenced considering dependencies, risk reduction, and demo value.

| # | Task | Phase | Layer | Effort | Impact |
|---|------|-------|-------|--------|--------|
| 1 | Create `middleware.ts` for auth guard on web | 0 | Web | 2h | High — prevents unauthenticated access |
| 2 | Add error.tsx + loading.tsx + not-found.tsx boundaries | 0 | Web | 3h | High — professional error handling |
| 3 | Initialize Flutter project (lib/, pubspec.yaml, platform dirs) | 0 | Mobile | 4h | Critical — unblocks all mobile work |
| 4 | Flutter: Set up Dio + Auth interceptor + GoRouter | 0 | Mobile | 4h | Critical — network + navigation foundation |
| 5 | Flutter: Set up Drift DB with entity tables | 2 | Mobile | 6h | Critical — offline data layer |
| 6 | Create Notification model + migration + controller | 1 | Backend | 4h | High — enables real-time alerts |
| 7 | Wire NotificationsPanel to real API (replace mock data) | 1 | Web | 3h | High — removes embarrassing mock data |
| 8 | Flutter: Build login screen + token storage | 1 | Mobile | 4h | Critical — entry point |
| 9 | Flutter: Build role-based home (Sales Rep + Driver) | 1 | Mobile | 6h | High — role-specific experience |
| 10 | Flutter: Build bottom navigation per role | 1 | Mobile | 4h | High — app navigation structure |
| 11 | Build Approval Inbox page on web | 1 | Web | 8h | High — manager approval workflow |
| 12 | Enhance Customer Detail with credit banner + timeline + tabs | 2 | Web | 8h | High — CRM depth |
| 13 | Flutter: Build Retailer list + profile screens | 2 | Mobile | 8h | High — field CRM |
| 14 | Create Delta Sync API + Batch Push API | 3 | Backend | 8h | Critical — enables offline-first |
| 15 | Flutter: Build New Order flow (4 screens) | 3 | Mobile | 16h | Critical — core value proposition |
| 16 | Flutter: Build Offline Order Queue + Background Sync | 3 | Mobile | 12h | Critical — offline-first USP |
| 17 | Create PickList model + auto-creation on order approval | 3 | Backend | 6h | High — warehouse workflow |
| 18 | Build Pick List view on web (warehouse) | 3 | Web | 8h | High — warehouse operations |
| 19 | Add Order Status Kanban view toggle | 3 | Web | 6h | Medium — visual overview |
| 20 | Flutter: Build Trip screens (list + detail + stops) | 4 | Mobile | 12h | High — delivery workflow |
| 21 | Flutter: Build POD capture (photo/signature/OTP) | 4 | Mobile | 8h | High — delivery proof |
| 22 | Flutter: Build Partial Delivery + Returns at Delivery | 4 | Mobile | 8h | High — real-world scenarios |
| 23 | Build Collection Schedule (model + web UI + mobile screen) | 5 | Full | 12h | High — collections workflow |
| 24 | Flutter: Build Quick Collect screen | 5 | Mobile | 6h | High — cash collection |
| 25 | Enhance Insights with real charts | 6 | Web | 8h | Medium — analytics value |
| 26 | Wire all notification triggers (20+ events) | 6 | Backend | 6h | Medium — completeness |
| 27 | Flutter: Build Check-in/Check-out flow with GPS | 6 | Mobile | 6h | Medium — SFA tracking |
| 28 | Flutter: Sync engine polish (conflict resolution, priority queue) | 7 | Mobile | 10h | High — reliability |
| 29 | Flutter: Empty states + offline indicators + data freshness | 7 | Mobile | 6h | Medium — UX polish |
| 30 | Comprehensive demo seed data | 8 | Backend | 8h | Critical — demo readiness |

**Total estimated effort: ~224 hours (~5.6 person-weeks)**

---

## Section 11: Risks, Dependencies & Refactoring Cautions

### Critical Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Flutter cold-start from zero code | High | Phase 0 focuses entirely on project setup; use Flutter templates/generators; pair with experienced Flutter dev |
| Offline sync conflicts losing financial data | Critical | Idempotency keys on all financial mutations; server-side validation as ultimate authority; never allow money operations without server confirmation on next sync |
| Two mobile apps (RN + Flutter) causing confusion | Medium | Mark RN as deprecated immediately; do not invest further in RN; archive `mobile/` directory after Flutter reaches feature parity |
| Performance of delta sync with large datasets | Medium | Paginate sync responses (1000 records max per batch); use `has_more` flag; test with 10K customers, 50K products |
| Schema migrations on production data | High | Always use reversible migrations; test rollback; blue-green deployment for critical migrations |
| Credit engine accuracy with offline stale data | High | Offline credit checks are advisory only — server re-validates on sync push; clear UX messaging that offline decisions are "estimated" |

### Dependency Chain
```
Phase 0 → unblocks all other phases
Phase 1 → unblocks Phase 3 (notifications used in order flow)
Phase 2 → unblocks Phase 3 (retailers + products needed for orders)
Phase 3 → unblocks Phase 4 (orders needed for delivery)
Phase 3 → unblocks Phase 5 (orders needed for invoicing)
Phase 4 → partially unblocks Phase 5 (delivery needed for auto-invoicing)
Phase 5 → unblocks Phase 8 (financial flows needed for demo)
Phase 6 → independent (can run in parallel with 5 or 7)
Phase 7 → can start after Phase 3 (sync engine refinement)
Phase 8 → after all others
```

### Refactoring Cautions

1. **Don't refactor service objects** that are already working (155+ services). Focus on adding missing ones, not restructuring existing.

2. **Don't change the existing API response format.** Web app expects current format. Add new fields, don't rename existing ones.

3. **Don't merge return_records into return_requests** in a single migration. Use the phased approach (Phase 0: link, Phase 5: remove).

4. **Don't introduce a new ORM or framework** in Flutter. Stick with Drift (previously Moor) since it's already a resolved dependency.

5. **Don't replace React Query with a custom solution** on web. Standardize on React Query v5 consistently.

6. **Don't over-abstract mobile UI.** Start with concrete screens, extract shared widgets only when patterns repeat 3+ times.

7. **Don't build a custom push notification system.** Use Firebase Cloud Messaging (FCM) directly.

8. **Don't cache auth tokens in Drift.** Use `flutter_secure_storage` (already a dependency) for sensitive data.

9. **Don't use WebSocket for notifications v1.** Server-push via Action Cable exists but mobile polling + push notifications is simpler and more reliable for v1.

10. **Don't create separate branches per phase.** Use feature branches within each phase, merge to main frequently.

---

## Section 12: Appendices

### Appendix A: Top 10 UX Changes (Web)

1. **Real notification panel** — Replace mock NotificationsPanel with live API data + unread badges
2. **Approval Inbox** — Single page for all pending approvals (orders + credit requests)
3. **Customer credit banner** — Outstanding/overdue/credit utilization visible at glance
4. **Order Kanban view** — Visual board showing order status distribution
5. **Visual status timeline** — Timeline component on all entities (orders, trips, returns, transfers)
6. **Loading skeletons** — Replace all "Loading..." text with proper skeleton screens
7. **Empty states with CTAs** — Informative empty states instead of blank pages
8. **Collection schedule page** — Calendar + list view for planned collections
9. **Inventory heatmap** — Cross-branch stock visibility at a glance
10. **Keyboard shortcuts** — Ctrl+K search, Ctrl+N new order

### Appendix B: Top 10 Backend Changes

1. **Notification model + 20 triggers** — Foundation for real-time alerting
2. **PickList model + auto-generation** — Bridge between order approval and warehouse
3. **CollectionSchedule model** — Structured collections management
4. **Delta Sync API** — Efficient incremental data sync for mobile
5. **Batch Push API** — Offline operation queue processing with idempotency
6. **Comprehensive demo seed data** — 30 customers, 50 products, 50 orders, full lifecycle
7. **Add idempotency_key to payments** — Prevent duplicate financial transactions
8. **Auto-create returns from delivery rejections** — Streamline delivery-to-returns flow
9. **Return_records deprecation** — Clean up duplicate return system
10. **Customer timeline API** — Chronological activity log for CRM depth

### Appendix C: Top 10 Mobile (Flutter) Changes

1. **Initialize Flutter project from scratch** — Create lib/, pubspec.yaml, platform dirs
2. **New Order flow (4 screens)** — Retailer → Products → Cart → Credit Check → Submit
3. **Offline order queue + background sync** — Core differentiator, works without internet
4. **Delivery trip flow** — Trip list → stops → POD capture → partial delivery → returns
5. **Quick Collect screen** — Fast payment collection with offline support
6. **Drift local database** — Retailers, products, prices cached locally for instant access
7. **Sync engine with conflict resolution** — Priority queue, retry logic, user-resolvable conflicts
8. **Beat plan + check-in/check-out** — GPS-tracked field visits
9. **Push notifications via FCM** — Deep-linked alerts
10. **Offline indicators + data freshness** — Sync badges, connection banners, freshness timestamps

---

### Technology Stack Summary

| Layer | Technology | Version |
|-------|-----------|---------|
| **Backend API** | Ruby on Rails | 7.1 |
| **Database** | PostgreSQL | 14+ |
| **Background Jobs** | Sidekiq | Latest |
| **Auth** | Devise + devise-jwt | JWT 24h |
| **Authorization** | Pundit | Latest |
| **Web Frontend** | Next.js | 14 |
| **Web State** | React Query | v5 |
| **Web UI** | Radix UI + Tailwind CSS | Latest |
| **Web Charts** | Recharts | Latest |
| **Mobile** | Flutter | 3.x |
| **Mobile State** | Riverpod | Latest |
| **Mobile Navigation** | GoRouter | Latest |
| **Mobile HTTP** | Dio | Latest |
| **Mobile Local DB** | Drift (SQLite) | Latest |
| **Mobile Offline Sync** | WorkManager + custom | - |
| **Push Notifications** | Firebase Cloud Messaging | - |
| **Deployment** | Docker | - |
| **Cache/Queue** | Redis (Sidekiq) | - |

### Estimated Timeline

| Phase | Name | Duration | Parallelizable With |
|-------|------|----------|---------------------|
| 0 | Repo Cleanup & Architecture Foundation | 1 week | — |
| 1 | Core Role/Navigation Foundation | 1 week | — |
| 2 | Retailer + Product + Pricing Foundation | 1.5 weeks | — |
| 3 | Credit + Order Flow Completion | 2 weeks | — |
| 4 | Delivery + Warehouse + Inventory | 2 weeks | — |
| 5 | Payments + Invoices + Returns + Credit Notes | 2 weeks | Phase 6, 7 |
| 6 | Notifications + Settings + Reports Polish | 1.5 weeks | Phase 5, 7 |
| 7 | Mobile Offline Experience Polish | 1.5 weeks | Phase 5, 6 |
| 8 | Demo-Readiness + Production-Hardening | 1 week | — |

**Sequential total: ~13.5 weeks**
**With parallelization (phases 5/6/7): ~11 weeks**
**With 2 developers: ~7-8 weeks**
