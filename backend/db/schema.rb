# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_03_04_230101) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "branches", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.string "code", null: false
    t.string "city"
    t.string "state"
    t.boolean "active", default: true, null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "address"
    t.string "pincode"
    t.jsonb "settings", default: {}, null: false
    t.string "state_code", limit: 2
    t.index ["code"], name: "index_branches_on_code", unique: true
    t.index ["deleted_at"], name: "index_branches_on_deleted_at"
    t.index ["organization_id"], name: "index_branches_on_organization_id"
    t.index ["settings"], name: "index_branches_on_settings", using: :gin
    t.index ["state_code"], name: "index_branches_on_state_code"
  end

  create_table "credit_accounts", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "organization_id", null: false
    t.bigint "branch_id", null: false
    t.decimal "credit_limit", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "current_balance", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "available_credit", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "overdue_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.integer "overdue_days", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_credit_accounts_on_branch_id"
    t.index ["customer_id"], name: "index_credit_accounts_on_customer_id"
    t.index ["organization_id"], name: "index_credit_accounts_on_organization_id"
  end

  create_table "customer_addresses", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "label", default: "billing"
    t.string "line1"
    t.string "line2"
    t.string "city"
    t.string "state"
    t.string "postal_code"
    t.string "country", default: "India"
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_customer_addresses_on_customer_id"
    t.index ["label"], name: "index_customer_addresses_on_label"
  end

  create_table "customer_contacts", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "name", null: false
    t.string "phone"
    t.string "email"
    t.string "designation"
    t.boolean "is_primary", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id", "is_primary"], name: "idx_customer_contacts_primary"
    t.index ["customer_id"], name: "index_customer_contacts_on_customer_id"
  end

  create_table "customers", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.string "channel"
    t.string "tier"
    t.decimal "credit_limit", precision: 12, scale: 2, default: "0.0"
    t.string "gstin"
    t.string "pan"
    t.string "phone"
    t.string "email"
    t.string "status", default: "active", null: false
    t.bigint "branch_id", null: false
    t.bigint "organization_id", null: false
    t.bigint "route_id"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "customer_type", default: "retailer"
    t.string "visit_frequency"
    t.integer "credit_days", default: 30
    t.string "credit_block_rule", default: "none"
    t.decimal "opening_balance", precision: 12, scale: 2, default: "0.0"
    t.text "tag_list", default: [], array: true
    t.bigint "sales_rep_id"
    t.index ["branch_id"], name: "index_customers_on_branch_id"
    t.index ["channel"], name: "index_customers_on_channel"
    t.index ["customer_type"], name: "index_customers_on_customer_type"
    t.index ["deleted_at"], name: "index_customers_on_deleted_at"
    t.index ["organization_id", "code"], name: "idx_customers_org_code", unique: true
    t.index ["organization_id", "gstin"], name: "idx_customers_org_gstin_unique", unique: true, where: "((gstin IS NOT NULL) AND (deleted_at IS NULL))"
    t.index ["organization_id", "phone"], name: "idx_customers_org_phone_unique", unique: true, where: "((phone IS NOT NULL) AND (deleted_at IS NULL))"
    t.index ["organization_id"], name: "index_customers_on_organization_id"
    t.index ["route_id"], name: "index_customers_on_route_id"
    t.index ["sales_rep_id"], name: "index_customers_on_sales_rep_id"
    t.index ["status"], name: "index_customers_on_status"
    t.index ["tag_list"], name: "index_customers_on_tag_list", using: :gin
    t.index ["tier"], name: "index_customers_on_tier"
  end

  create_table "hsn_sac_codes", force: :cascade do |t|
    t.string "code", null: false
    t.string "code_type", default: "HSN", null: false
    t.string "description"
    t.string "chapter"
    t.decimal "gst_rate", precision: 5, scale: 2, default: "0.0", null: false
    t.decimal "cgst_rate", precision: 5, scale: 2, default: "0.0", null: false
    t.decimal "sgst_rate", precision: 5, scale: 2, default: "0.0", null: false
    t.decimal "igst_rate", precision: 5, scale: 2, default: "0.0", null: false
    t.boolean "active", default: true, null: false
    t.date "effective_from", null: false
    t.date "effective_to"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code", "effective_from"], name: "idx_hsn_sac_codes_on_code_effective_from"
    t.index ["code"], name: "idx_hsn_sac_codes_current_active", where: "((active = true) AND (effective_to IS NULL))"
    t.index ["code_type"], name: "index_hsn_sac_codes_on_code_type"
    t.index ["gst_rate"], name: "index_hsn_sac_codes_on_gst_rate"
  end

  create_table "invitations", force: :cascade do |t|
    t.string "email", null: false
    t.string "token_digest", null: false
    t.bigint "organization_id", null: false
    t.bigint "role_id", null: false
    t.bigint "branch_id"
    t.bigint "invited_by_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "expires_at", null: false
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invited_by_id"], name: "index_invitations_on_invited_by_id"
    t.index ["organization_id", "email"], name: "idx_invitations_org_email"
    t.index ["organization_id"], name: "index_invitations_on_organization_id"
    t.index ["token_digest"], name: "index_invitations_on_token_digest", unique: true
  end

  create_table "jwt_denylist", force: :cascade do |t|
    t.string "jti", null: false
    t.datetime "exp", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["jti"], name: "index_jwt_denylist_on_jti", unique: true
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "organization_id", null: false
    t.bigint "branch_id", null: false
    t.bigint "role_id", null: false
    t.boolean "active", default: true, null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status", default: "active", null: false
    t.index ["branch_id"], name: "index_memberships_on_branch_id"
    t.index ["deleted_at"], name: "index_memberships_on_deleted_at"
    t.index ["organization_id"], name: "index_memberships_on_organization_id"
    t.index ["role_id"], name: "index_memberships_on_role_id"
    t.index ["status"], name: "index_memberships_on_status"
    t.index ["user_id", "organization_id", "branch_id"], name: "idx_memberships_unique", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "onboarding_progresses", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "user_id", null: false
    t.jsonb "steps", default: {}, null: false
    t.boolean "completed", default: false, null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "user_id"], name: "idx_onboarding_org_user", unique: true
    t.index ["organization_id"], name: "index_onboarding_progresses_on_organization_id"
    t.index ["user_id"], name: "index_onboarding_progresses_on_user_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "plan", default: "starter", null: false
    t.boolean "active", default: true, null: false
    t.string "gst_number"
    t.string "address"
    t.string "city"
    t.string "state"
    t.string "pincode"
    t.string "contact_email"
    t.string "contact_phone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "pan"
    t.string "logo_url"
    t.string "timezone", default: "Asia/Kolkata"
    t.string "currency", default: "INR"
    t.jsonb "settings", default: {}, null: false
    t.index ["settings"], name: "index_organizations_on_settings", using: :gin
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
  end

  create_table "pending_registrations", force: :cascade do |t|
    t.string "email", null: false
    t.string "otp_code"
    t.datetime "otp_sent_at"
    t.integer "otp_attempts", default: 0, null: false
    t.string "current_step", default: "initiate", null: false
    t.jsonb "data", default: {}, null: false
    t.datetime "expires_at"
    t.boolean "completed", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_pending_registrations_on_email", unique: true
    t.index ["expires_at"], name: "index_pending_registrations_on_expires_at"
    t.index ["otp_code"], name: "index_pending_registrations_on_otp_code"
  end

  create_table "roles", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_roles_on_name", unique: true
  end

  create_table "routes", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.bigint "branch_id", null: false
    t.bigint "organization_id", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id", "code"], name: "index_routes_on_branch_id_and_code", unique: true
    t.index ["branch_id"], name: "index_routes_on_branch_id"
    t.index ["organization_id"], name: "index_routes_on_organization_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "encrypted_password", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "phone"
    t.boolean "active", default: true, null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "plan", default: "starter", null: false
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "branches", "organizations"
  add_foreign_key "credit_accounts", "branches"
  add_foreign_key "credit_accounts", "customers"
  add_foreign_key "credit_accounts", "organizations"
  add_foreign_key "customer_addresses", "customers"
  add_foreign_key "customer_contacts", "customers"
  add_foreign_key "customers", "branches"
  add_foreign_key "customers", "organizations"
  add_foreign_key "customers", "routes"
  add_foreign_key "customers", "users", column: "sales_rep_id"
  add_foreign_key "invitations", "branches"
  add_foreign_key "invitations", "organizations"
  add_foreign_key "invitations", "roles"
  add_foreign_key "invitations", "users", column: "invited_by_id"
  add_foreign_key "memberships", "branches"
  add_foreign_key "memberships", "organizations"
  add_foreign_key "memberships", "roles"
  add_foreign_key "memberships", "users"
  add_foreign_key "onboarding_progresses", "organizations"
  add_foreign_key "onboarding_progresses", "users"
  add_foreign_key "routes", "branches"
  add_foreign_key "routes", "organizations"
end
