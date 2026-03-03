# OmniDist OMS – Backend Conventions

## Overview

The backend is a **Rails 7.1 API-only** application. It serves JSON exclusively and is consumed by both the web (Next.js) and mobile (Expo) frontends.

---

## Stack

| Technology | Version | Purpose                   |
|------------|---------|---------------------------|
| Ruby       | 3.2.x   | Language runtime          |
| Rails      | 7.1.6   | Web framework             |
| PostgreSQL | 14+     | Primary database          |
| Redis      | 7+      | Cache, Sidekiq queue      |
| Sidekiq    | 7.x     | Background job processing |
| Devise     | 4.9.x   | User authentication       |
| devise-jwt | 0.11.x  | JWT token strategy        |
| Pundit     | 2.3.x   | Authorization policies    |
| Rack CORS  | latest  | Cross-origin requests     |

---

## Folder Structure

```
backend/
├── app/
│   ├── controllers/
│   │   └── api/
│   │       └── v1/
│   │           ├── base_controller.rb       # JWT auth + Pundit
│   │           ├── sessions_controller.rb   # Login/logout
│   │           ├── organizations_controller.rb
│   │           └── ...
│   ├── models/
│   │   ├── organization.rb
│   │   ├── branch.rb
│   │   ├── user.rb
│   │   ├── membership.rb
│   │   └── role.rb
│   ├── policies/                            # Pundit policies
│   └── jobs/                               # Sidekiq jobs
├── config/
│   ├── routes.rb                           # Versioned routes
│   ├── initializers/
│   │   └── sidekiq.rb
│   └── database.yml
└── db/
    └── migrate/
```

---

## Authentication

### JWT (API consumers: web + mobile)

All API requests under `/api/v1/` must include:

```
Authorization: Bearer <token>
```

Tokens are issued by `POST /api/v1/auth/login`:

```json
// Request
{ "email": "user@example.com", "password": "secret" }

// Response
{ "token": "<jwt>", "user": { "id": 1, "email": "...", ... } }
```

- Tokens expire in **24 hours**.
- Token secret is configured via the `JWT_SECRET` environment variable.
- The `BaseController` decodes the JWT and sets `current_user`.

### Environment Variables

```
JWT_SECRET=<strong_random_secret>
DATABASE_URL=postgresql://localhost/omnidist_development
REDIS_URL=redis://localhost:6379/0
```

---

## Authorization

Pundit policies live in `app/policies/`. Each controller calls `authorize @record` before mutating data.

```ruby
# app/policies/organization_policy.rb
class OrganizationPolicy < ApplicationPolicy
  def index?  = user.present?
  def show?   = user.present?
  def create? = user.present?
  def update? = membership_admin?

  private

  def membership_admin?
    user.memberships.where(organization: record, role: Role.admin).exists?
  end
end
```

---

## Multi-Tenancy

All resources are scoped by `organization_id`. Controllers scope queries accordingly:

```ruby
def index
  organizations = current_organization.products
  render json: { data: organizations }
end

def current_organization
  @current_organization ||= current_user.organizations.find(params[:organization_id])
end
```

---

## API Conventions

### Versioning

All routes are namespaced under `/api/v1/`. When introducing a breaking change, add `/api/v2/` alongside the existing version.

### Request / Response Format

**Success:**
```json
{ "data": { "id": 1, "name": "Acme Corp" } }
{ "data": [ { "id": 1 }, { "id": 2 } ] }
```

**Error:**
```json
{ "error": "Unauthorized" }
{ "errors": { "name": ["can't be blank"] } }
```

### Pagination

Use Kaminari. Controllers should accept `page` and `per_page` params:

```ruby
products = Product.page(params[:page]).per(params[:per_page] || 25)
render json: {
  data: products,
  meta: { current_page: products.current_page, total_pages: products.total_pages }
}
```

---

## Background Jobs

All async work goes through Sidekiq. Create jobs in `app/jobs/`:

```ruby
class NotifyOutletJob < ApplicationJob
  queue_as :default

  def perform(outlet_id, message)
    outlet = Outlet.find(outlet_id)
    # send notification
  end
end

# Enqueue
NotifyOutletJob.perform_later(outlet.id, "Your order is dispatched")
```

The Sidekiq web UI is mounted at `/sidekiq` (restrict access in production).

---

## Adding a New Module

### Example: Adding "Products"

1. **Generate model + migration:**
   ```
   rails generate model Product name:string sku:string:uniq organization:references category:string active:boolean
   rails db:migrate
   ```

2. **Create controller:**
   ```ruby
   # app/controllers/api/v1/products_controller.rb
   module Api
     module V1
       class ProductsController < BaseController
         def index
           products = Product.where(organization: current_organization)
           render json: { data: products }
         end

         # ... show, create, update, destroy
       end
     end
   end
   ```

3. **Create Pundit policy:**
   ```ruby
   # app/policies/product_policy.rb
   class ProductPolicy < ApplicationPolicy
     def index?  = user.present?
     def show?   = org_member?
     def create? = org_admin?
     def update? = org_admin?
   end
   ```

4. **Add routes:**
   ```ruby
   namespace :api do
     namespace :v1 do
       resources :products
     end
   end
   ```

5. **Write tests** (RSpec recommended):
   ```ruby
   # spec/requests/api/v1/products_spec.rb
   describe "GET /api/v1/products" do
     it "returns the product list" do
       get "/api/v1/products", headers: auth_headers
       expect(response).to have_http_status(:ok)
     end
   end
   ```

---

## Code Style

- Rubocop with `rubocop-rails`. Config at `backend/.rubocop.yml`.
- Run: `cd backend && bundle exec rubocop`
- All controllers inherit from `Api::V1::BaseController`.
- No business logic in controllers — use service objects or POROs.
- Use `snake_case` for everything; `SCREAMING_SNAKE_CASE` for constants.
