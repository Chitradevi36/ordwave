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

ActiveRecord::Schema[7.1].define(version: 2026_03_05_000007) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "actor_id", null: false
    t.string "auditable_type", null: false
    t.bigint "auditable_id", null: false
    t.string "action", null: false
    t.jsonb "changes_data", default: {}, null: false
    t.string "reason"
    t.datetime "created_at", null: false
    t.index ["actor_id"], name: "index_audit_logs_on_actor_id"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable"
    t.index ["organization_id"], name: "index_audit_logs_on_organization_id"
  end

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
    t.boolean "collection_first", default: false, null: false
    t.boolean "hold_required", default: false, null: false
    t.boolean "watchlist", default: false, null: false
    t.string "overdue_bucket_cached"
    t.index ["branch_id"], name: "index_credit_accounts_on_branch_id"
    t.index ["customer_id"], name: "index_credit_accounts_on_customer_id"
    t.index ["organization_id"], name: "index_credit_accounts_on_organization_id"
  end

  create_table "credit_limit_change_requests", force: :cascade do |t|
    t.bigint "credit_account_id", null: false
    t.bigint "requested_by_id", null: false
    t.bigint "decided_by_id"
    t.decimal "new_limit", precision: 12, scale: 2, null: false
    t.decimal "counter_offer_limit", precision: 12, scale: 2
    t.string "status", default: "pending", null: false
    t.text "reason", null: false
    t.text "supporting_notes"
    t.text "decision_note"
    t.datetime "decided_at"
    t.datetime "sla_breached_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["credit_account_id", "status"], name: "idx_clcr_account_status"
    t.index ["credit_account_id"], name: "index_credit_limit_change_requests_on_credit_account_id"
    t.index ["decided_by_id"], name: "index_credit_limit_change_requests_on_decided_by_id"
    t.index ["requested_by_id"], name: "index_credit_limit_change_requests_on_requested_by_id"
    t.index ["status"], name: "index_credit_limit_change_requests_on_status"
  end

  create_table "credit_policies", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.integer "hard_block_overdue_days", default: 30, null: false
    t.decimal "hard_block_margin_pct", precision: 6, scale: 2, default: "20.0", null: false
    t.integer "soft_hold_overdue_days_min", default: 15, null: false
    t.integer "soft_hold_overdue_days_max", default: 29, null: false
    t.decimal "soft_hold_outstanding_pct", precision: 6, scale: 2, default: "100.0", null: false
    t.string "collection_first_bucket", default: "serious", null: false
    t.integer "approval_sla_hours_manager", default: 4, null: false
    t.integer "approval_sla_hours_owner", default: 8, null: false
    t.string "auto_invoice_trigger", default: "on_delivery", null: false
    t.boolean "allow_partial_allocation", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_credit_policies_on_organization_id", unique: true
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

  create_table "delivery_proofs", force: :cascade do |t|
    t.bigint "trip_stop_id", null: false
    t.string "proof_type", default: "photo", null: false
    t.string "otp_code_digest"
    t.datetime "otp_verified_at"
    t.string "override_reason"
    t.bigint "overridden_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["proof_type"], name: "index_delivery_proofs_on_proof_type"
    t.index ["trip_stop_id"], name: "index_delivery_proofs_on_trip_stop_id"
  end

  create_table "delivery_trips", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "branch_id", null: false
    t.bigint "vehicle_id"
    t.bigint "driver_id"
    t.string "trip_number", null: false
    t.date "trip_date", null: false
    t.string "status", default: "draft", null: false
    t.text "notes"
    t.string "cancellation_reason"
    t.datetime "dispatched_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_delivery_trips_on_branch_id"
    t.index ["driver_id"], name: "index_delivery_trips_on_driver_id"
    t.index ["organization_id", "trip_number"], name: "index_delivery_trips_on_organization_id_and_trip_number", unique: true
    t.index ["organization_id"], name: "index_delivery_trips_on_organization_id"
    t.index ["status"], name: "index_delivery_trips_on_status"
    t.index ["trip_date"], name: "index_delivery_trips_on_trip_date"
    t.index ["vehicle_id"], name: "index_delivery_trips_on_vehicle_id"
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

  create_table "prepayment_skus", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "branch_id"
    t.bigint "product_id", null: false
    t.bigint "created_by_id", null: false
    t.text "reason", null: false
    t.date "effective_from", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_prepayment_skus_on_branch_id"
    t.index ["created_by_id"], name: "index_prepayment_skus_on_created_by_id"
    t.index ["organization_id", "product_id", "branch_id"], name: "idx_prepayment_skus_active_unique", unique: true, where: "(active = true)"
    t.index ["organization_id"], name: "index_prepayment_skus_on_organization_id"
    t.index ["product_id"], name: "index_prepayment_skus_on_product_id"
  end

  create_table "price_list_items", force: :cascade do |t|
    t.bigint "price_list_id", null: false
    t.bigint "product_id", null: false
    t.decimal "unit_price", precision: 12, scale: 2, null: false
    t.decimal "min_qty", precision: 10, scale: 3
    t.decimal "discount_pct", precision: 5, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["price_list_id", "product_id", "min_qty"], name: "idx_price_list_items_unique", unique: true
    t.index ["price_list_id"], name: "index_price_list_items_on_price_list_id"
    t.index ["product_id"], name: "index_price_list_items_on_product_id"
  end

  create_table "price_lists", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "branch_id"
    t.string "name", null: false
    t.string "list_type", default: "standard", null: false
    t.date "valid_from"
    t.date "valid_to"
    t.string "status", default: "active", null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id", "list_type", "status"], name: "idx_price_lists_branch_type_status"
    t.index ["branch_id"], name: "index_price_lists_on_branch_id"
    t.index ["deleted_at"], name: "index_price_lists_on_deleted_at"
    t.index ["list_type"], name: "index_price_lists_on_list_type"
    t.index ["organization_id"], name: "index_price_lists_on_organization_id"
    t.index ["status"], name: "index_price_lists_on_status"
  end

  create_table "product_categories", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "name", null: false
    t.string "code"
    t.text "description"
    t.boolean "active", default: true, null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_product_categories_on_deleted_at"
    t.index ["organization_id", "name"], name: "idx_product_categories_org_name_unique", unique: true, where: "(deleted_at IS NULL)"
    t.index ["organization_id"], name: "index_product_categories_on_organization_id"
  end

  create_table "products", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "product_category_id", null: false
    t.bigint "units_of_measure_id", null: false
    t.string "sku", null: false
    t.string "name", null: false
    t.string "barcode"
    t.text "description"
    t.bigint "hsn_sac_code_id", null: false
    t.decimal "gst_rate", precision: 5, scale: 2, default: "0.0", null: false
    t.decimal "min_order_qty", precision: 10, scale: 3, default: "1.0", null: false
    t.decimal "purchase_price", precision: 12, scale: 2
    t.decimal "weight_kg", precision: 8, scale: 3
    t.string "image_url"
    t.string "status", default: "active", null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["barcode"], name: "index_products_on_barcode", where: "(barcode IS NOT NULL)"
    t.index ["deleted_at"], name: "index_products_on_deleted_at"
    t.index ["hsn_sac_code_id"], name: "index_products_on_hsn_sac_code_id"
    t.index ["organization_id", "sku"], name: "idx_products_org_sku_unique", unique: true, where: "(deleted_at IS NULL)"
    t.index ["organization_id"], name: "index_products_on_organization_id"
    t.index ["product_category_id"], name: "index_products_on_product_category_id"
    t.index ["status"], name: "index_products_on_status"
    t.index ["units_of_measure_id"], name: "index_products_on_units_of_measure_id"
  end

  create_table "retailer_price_list_assignments", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "price_list_id", null: false
    t.date "starts_on"
    t.date "ends_on"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_retailer_price_list_assignments_on_active"
    t.index ["customer_id", "price_list_id"], name: "idx_retailer_pl_assignment_unique", unique: true
    t.index ["customer_id"], name: "index_retailer_price_list_assignments_on_customer_id"
    t.index ["price_list_id"], name: "index_retailer_price_list_assignments_on_price_list_id"
  end

  create_table "return_records", force: :cascade do |t|
    t.bigint "trip_stop_id", null: false
    t.bigint "product_id", null: false
    t.integer "qty_returned", default: 0, null: false
    t.string "condition", default: "good", null: false
    t.string "reason_code", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["condition"], name: "index_return_records_on_condition"
    t.index ["product_id"], name: "index_return_records_on_product_id"
    t.index ["reason_code"], name: "index_return_records_on_reason_code"
    t.index ["trip_stop_id"], name: "index_return_records_on_trip_stop_id"
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

  create_table "sales_order_lines", force: :cascade do |t|
    t.bigint "sales_order_id", null: false
    t.bigint "product_id", null: false
    t.decimal "qty", precision: 14, scale: 3, null: false
    t.decimal "unit_price", precision: 14, scale: 2, null: false
    t.decimal "discount_pct", precision: 5, scale: 2, default: "0.0"
    t.decimal "gst_rate", precision: 5, scale: 2, default: "0.0"
    t.decimal "line_total", precision: 14, scale: 2, default: "0.0", null: false
    t.string "price_source"
    t.bigint "price_list_id"
    t.string "hsn_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "delivered_qty", default: 0, null: false
    t.integer "returned_qty", default: 0, null: false
    t.index ["price_list_id"], name: "index_sales_order_lines_on_price_list_id"
    t.index ["product_id"], name: "index_sales_order_lines_on_product_id"
    t.index ["sales_order_id"], name: "index_sales_order_lines_on_sales_order_id"
  end

  create_table "sales_orders", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "branch_id", null: false
    t.bigint "customer_id", null: false
    t.bigint "created_by_id", null: false
    t.string "order_number", null: false
    t.string "status", default: "draft", null: false
    t.date "delivery_date"
    t.text "notes"
    t.string "idempotency_key"
    t.string "credit_decision"
    t.jsonb "credit_snapshot", default: {}
    t.jsonb "credit_reasons", default: []
    t.decimal "total_amount", precision: 14, scale: 2, default: "0.0"
    t.decimal "discount_amount", precision: 14, scale: 2, default: "0.0"
    t.datetime "submitted_at"
    t.datetime "approved_at"
    t.datetime "cancelled_at"
    t.text "cancellation_reason"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "dispatched_at"
    t.datetime "delivered_at"
    t.text "delivery_failure_reason"
    t.index ["branch_id"], name: "index_sales_orders_on_branch_id"
    t.index ["created_by_id"], name: "index_sales_orders_on_created_by_id"
    t.index ["customer_id"], name: "index_sales_orders_on_customer_id"
    t.index ["deleted_at"], name: "index_sales_orders_on_deleted_at"
    t.index ["idempotency_key"], name: "index_sales_orders_on_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["order_number"], name: "index_sales_orders_on_order_number"
    t.index ["organization_id", "order_number"], name: "index_sales_orders_on_organization_id_and_order_number", unique: true
    t.index ["organization_id"], name: "index_sales_orders_on_organization_id"
    t.index ["status"], name: "index_sales_orders_on_status"
  end

  create_table "tier_price_list_assignments", force: :cascade do |t|
    t.bigint "branch_id", null: false
    t.bigint "price_list_id", null: false
    t.string "retailer_tier", null: false
    t.date "starts_on"
    t.date "ends_on"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id", "retailer_tier", "price_list_id"], name: "idx_tier_pl_assignment_unique", unique: true
    t.index ["branch_id", "retailer_tier"], name: "idx_tier_pl_assignment_branch_tier"
    t.index ["branch_id"], name: "index_tier_price_list_assignments_on_branch_id"
    t.index ["price_list_id"], name: "index_tier_price_list_assignments_on_price_list_id"
  end

  create_table "trip_stops", force: :cascade do |t|
    t.bigint "delivery_trip_id", null: false
    t.bigint "sales_order_id", null: false
    t.integer "sequence", default: 0, null: false
    t.string "status", default: "pending", null: false
    t.datetime "delivered_at"
    t.decimal "latitude", precision: 9, scale: 6
    t.decimal "longitude", precision: 9, scale: 6
    t.string "device_id"
    t.string "exception_code"
    t.text "delivery_notes"
    t.string "idempotency_key"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["delivery_trip_id", "sequence"], name: "index_trip_stops_on_delivery_trip_id_and_sequence"
    t.index ["delivery_trip_id"], name: "index_trip_stops_on_delivery_trip_id"
    t.index ["idempotency_key"], name: "index_trip_stops_on_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["sales_order_id"], name: "index_trip_stops_on_sales_order_id"
    t.index ["status"], name: "index_trip_stops_on_status"
  end

  create_table "units_of_measures", force: :cascade do |t|
    t.string "name", null: false
    t.string "symbol", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_units_of_measures_on_name", unique: true
    t.index ["symbol"], name: "index_units_of_measures_on_symbol", unique: true
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

  create_table "vehicles", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "registration_number", null: false
    t.string "vehicle_type", default: "truck", null: false
    t.decimal "capacity_kg", precision: 10, scale: 2
    t.integer "capacity_units"
    t.bigint "default_driver_id"
    t.date "insurance_expiry"
    t.date "fitness_expiry"
    t.date "permit_expiry"
    t.string "status", default: "active", null: false
    t.text "notes"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_vehicles_on_deleted_at"
    t.index ["organization_id", "registration_number"], name: "index_vehicles_on_organization_id_and_registration_number", unique: true, where: "(deleted_at IS NULL)"
    t.index ["organization_id"], name: "index_vehicles_on_organization_id"
    t.index ["status"], name: "index_vehicles_on_status"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "audit_logs", "organizations"
  add_foreign_key "audit_logs", "users", column: "actor_id"
  add_foreign_key "branches", "organizations"
  add_foreign_key "credit_accounts", "branches"
  add_foreign_key "credit_accounts", "customers"
  add_foreign_key "credit_accounts", "organizations"
  add_foreign_key "credit_limit_change_requests", "credit_accounts"
  add_foreign_key "credit_limit_change_requests", "users", column: "decided_by_id"
  add_foreign_key "credit_limit_change_requests", "users", column: "requested_by_id"
  add_foreign_key "credit_policies", "organizations"
  add_foreign_key "customer_addresses", "customers"
  add_foreign_key "customer_contacts", "customers"
  add_foreign_key "customers", "branches"
  add_foreign_key "customers", "organizations"
  add_foreign_key "customers", "routes"
  add_foreign_key "customers", "users", column: "sales_rep_id"
  add_foreign_key "delivery_proofs", "trip_stops"
  add_foreign_key "delivery_proofs", "users", column: "overridden_by_id"
  add_foreign_key "delivery_trips", "branches"
  add_foreign_key "delivery_trips", "organizations"
  add_foreign_key "delivery_trips", "users", column: "driver_id"
  add_foreign_key "delivery_trips", "vehicles"
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
  add_foreign_key "prepayment_skus", "branches"
  add_foreign_key "prepayment_skus", "organizations"
  add_foreign_key "prepayment_skus", "products"
  add_foreign_key "prepayment_skus", "users", column: "created_by_id"
  add_foreign_key "price_list_items", "price_lists"
  add_foreign_key "price_list_items", "products"
  add_foreign_key "price_lists", "branches"
  add_foreign_key "price_lists", "organizations"
  add_foreign_key "product_categories", "organizations"
  add_foreign_key "products", "hsn_sac_codes"
  add_foreign_key "products", "organizations"
  add_foreign_key "products", "product_categories"
  add_foreign_key "products", "units_of_measures"
  add_foreign_key "retailer_price_list_assignments", "customers"
  add_foreign_key "retailer_price_list_assignments", "price_lists"
  add_foreign_key "return_records", "products"
  add_foreign_key "return_records", "trip_stops"
  add_foreign_key "routes", "branches"
  add_foreign_key "routes", "organizations"
  add_foreign_key "sales_order_lines", "products"
  add_foreign_key "sales_order_lines", "sales_orders"
  add_foreign_key "sales_orders", "branches"
  add_foreign_key "sales_orders", "customers"
  add_foreign_key "sales_orders", "organizations"
  add_foreign_key "sales_orders", "users", column: "created_by_id"
  add_foreign_key "tier_price_list_assignments", "branches"
  add_foreign_key "tier_price_list_assignments", "price_lists"
  add_foreign_key "trip_stops", "delivery_trips"
  add_foreign_key "trip_stops", "sales_orders"
  add_foreign_key "vehicles", "organizations"
  add_foreign_key "vehicles", "users", column: "default_driver_id"
end
