# Seeds for Rice OMS — idempotent, safe to re-run.
# Usage: bin/rails db:seed

puts '== Seeding Units of Measure...'

UnitsOfMeasure::SEEDS.each do |attrs|
  uom = UnitsOfMeasure.find_or_initialize_by(symbol: attrs[:symbol].upcase)
  uom.assign_attributes(name: attrs[:name], active: true)
  uom.save!
  puts "  UOM: #{uom.symbol} (#{uom.name})"
end

puts '== Units of Measure seeded.'
puts ''

puts '== Seeding HSN/SAC codes (FMCG)...'

hsn_definitions = [
  # Rice & Cereals
  { code: '10061090', description: 'Rice — other (including basmati)',         gst_rate: 5  },
  { code: '10062000', description: 'Husked (brown) rice',                       gst_rate: 0  },
  { code: '10063000', description: 'Semi-milled or wholly milled rice',         gst_rate: 5  },
  { code: '10064000', description: 'Broken rice',                               gst_rate: 0  },
  { code: '10019900', description: 'Wheat — other',                             gst_rate: 0  },
  { code: '10011100', description: 'Durum wheat — seed',                        gst_rate: 0  },
  # Flours
  { code: '11010000', description: 'Wheat or meslin flour',                     gst_rate: 0  },
  { code: '11022000', description: 'Maize (corn) flour',                        gst_rate: 0  },
  { code: '11031300', description: 'Pellets / groats of maize',                 gst_rate: 5  },
  # Pulses
  { code: '07132000', description: 'Chickpeas (garbanzos), shelled',            gst_rate: 0  },
  { code: '07133100', description: 'Beans — vigna mungo (urad dal)',             gst_rate: 0  },
  { code: '07134000', description: 'Lentils',                                   gst_rate: 0  },
  { code: '07135000', description: 'Broad beans and horse beans',               gst_rate: 0  },
  # Edible Oils
  { code: '15121110', description: 'Crude sunflower-seed or safflower oil',     gst_rate: 5  },
  { code: '15121990', description: 'Refined sunflower oil — other',             gst_rate: 5  },
  { code: '15131100', description: 'Crude coconut oil',                         gst_rate: 5  },
  { code: '15131990', description: 'Refined coconut oil — other',               gst_rate: 5  },
  { code: '15141100', description: 'Crude mustard oil',                         gst_rate: 5  },
  { code: '15089000', description: 'Groundnut oil — other',                     gst_rate: 5  },
  # Sugar & Jaggery
  { code: '17011200', description: 'Cane sugar — raw',                          gst_rate: 5  },
  { code: '17011400', description: 'Cane sugar — other refined',                gst_rate: 5  },
  { code: '17029090', description: 'Other sugars — jaggery',                    gst_rate: 0  },
  # Salt & Spices
  { code: '25010010', description: 'Common salt',                               gst_rate: 0  },
  { code: '09041100', description: 'Pepper — neither crushed nor ground',       gst_rate: 5  },
  { code: '09042210', description: 'Chilli powder',                             gst_rate: 5  },
  { code: '09030000', description: 'Turmeric (curcuma)',                        gst_rate: 5  },
  # Dairy
  { code: '04012000', description: 'Milk — fat content > 1% <= 6%',            gst_rate: 0  },
  { code: '04069000', description: 'Cheese — other',                            gst_rate: 12 },
  # Beverages
  { code: '22021090', description: 'Waters — flavoured, aerated',               gst_rate: 18 },
  { code: '09021000', description: 'Green tea (not fermented)',                  gst_rate: 5  },
  # Biscuits & Snacks
  { code: '19053100', description: 'Sweet biscuits',                            gst_rate: 18 },
  { code: '19054000', description: 'Rusks, toasted bread and similar',          gst_rate: 18 },
  # Soaps & Detergents
  { code: '34011100', description: 'Soap for toilet use',                       gst_rate: 18 },
  { code: '34029010', description: 'Detergents — household',                    gst_rate: 18 },
]

hsn_definitions.each do |attrs|
  hsn = HsnSacCode.find_or_initialize_by(code: attrs[:code].strip.upcase, effective_to: nil)
  hsn.assign_attributes(
    description:    attrs[:description],
    code_type:      'HSN',
    gst_rate:       attrs[:gst_rate],
    active:         true,
    effective_from: Date.new(2017, 7, 1)   # GST rollout date
  )
  hsn.save!
  puts "  HSN: #{hsn.code} — #{hsn.description} (#{hsn.gst_rate}%)"
end

puts '== HSN/SAC codes seeded.'
puts ''

puts '== Seeding roles...'

role_definitions = [
  { name: 'owner',           description: 'Organization owner — full access, billing control' },
  { name: 'admin',           description: 'Administrator — full operational access within org' },
  { name: 'manager',         description: 'Branch manager — manage staff, inventory, orders for a branch' },
  { name: 'sales_rep',       description: 'Sales representative — create and manage orders' },
  { name: 'warehouse_staff', description: 'Warehouse staff — manage inventory and dispatch' },
  { name: 'accountant',      description: 'Accountant — view financials, manage payments' },
  { name: 'driver',          description: 'Delivery driver — complete trip stops via mobile app' }
]

role_definitions.each do |attrs|
  role = Role.find_or_initialize_by(name: attrs[:name])
  role.description = attrs[:description]
  role.save!
  puts "  Role: #{role.name}"
end

puts '== Roles seeded.'

if Rails.env.development?
  puts ''
  puts '== Seeding development data...'

  admin = User.find_or_initialize_by(email: 'admin@riceoms.dev')
  admin.assign_attributes(
    first_name: 'Admin',
    last_name:  'User',
    plan:       'growth',
    active:     true
  )
  admin.password = 'Password@123' if admin.new_record? || admin.encrypted_password.blank?
  admin.save!
  puts "  User: #{admin.email} (plan: #{admin.plan})"

  org = Organization.find_or_initialize_by(slug: 'arya-rice')
  org.assign_attributes(
    name:          'Arya Rice Distributors',
    plan:          admin.plan,
    active:        true,
    city:          'Hyderabad',
    state:         'Telangana',
    contact_email: 'ops@aryarice.in'
  )
  org.save!
  puts "  Org: #{org.name} (slug: #{org.slug}, id: #{org.id})"

  branch = Branch.find_or_initialize_by(code: 'ARYA-HO')
  branch.assign_attributes(
    name:         'Head Office',
    organization: org,
    city:         'Hyderabad',
    state:        'Telangana',
    active:       true
  )
  branch.save!
  puts "  Branch: #{branch.name} (#{branch.code})"

  owner_role = Role.find_by!(name: 'owner')
  unless Membership.exists?(user: admin, organization: org, branch: branch)
    Membership.create!(
      user:         admin,
      organization: org,
      branch:       branch,
      role:         owner_role,
      active:       true
    )
    puts "  Membership: #{admin.email} → #{org.name} / #{branch.name} (owner)"
  end

  # ── Product Categories ────────────────────────────────────────────────────
  puts ''
  puts '  == Seeding product categories...'

  category_defs = [
    { name: 'Rice & Cereals',  code: 'RICE-CRL' },
    { name: 'Pulses & Lentils', code: 'PULSES'  },
    { name: 'Edible Oils',     code: 'OILS'     },
    { name: 'Sugar & Jaggery', code: 'SUGAR'    },
    { name: 'Spices & Salt',   code: 'SPICES'   },
  ]

  categories = {}
  category_defs.each do |attrs|
    cat = ProductCategory.find_or_initialize_by(code: attrs[:code], organization: org)
    cat.assign_attributes(name: attrs[:name], active: true)
    cat.save!
    categories[attrs[:code]] = cat
    puts "    Category: #{cat.name}"
  end

  # ── Sample Products ────────────────────────────────────────────────────────
  puts ''
  puts '  == Seeding sample products...'

  uom_kg  = UnitsOfMeasure.find_by!(symbol: 'KG')
  uom_ltr = UnitsOfMeasure.find_by!(symbol: 'LTR')

  hsn_rice      = HsnSacCode.find_by!(code: '10061090')  # Basmati rice — 5%
  hsn_pulse     = HsnSacCode.find_by!(code: '07134000')  # Lentils — 0%
  hsn_oil       = HsnSacCode.find_by!(code: '15121990')  # Refined sunflower oil — 5%
  hsn_sugar     = HsnSacCode.find_by!(code: '17011400')  # Cane sugar — 5%
  hsn_salt      = HsnSacCode.find_by!(code: '25010010')  # Common salt — 0%

  product_defs = [
    { sku: 'RICE-BSMT-5KG',  name: 'Basmati Rice (5 kg)',       category: 'RICE-CRL',  uom: uom_kg,  hsn: hsn_rice,  purchase_price: 320, min_order_qty: 1 },
    { sku: 'RICE-BSMT-25KG', name: 'Basmati Rice (25 kg)',      category: 'RICE-CRL',  uom: uom_kg,  hsn: hsn_rice,  purchase_price: 1500, min_order_qty: 1 },
    { sku: 'RICE-SONA-5KG',  name: 'Sona Masoori Rice (5 kg)',  category: 'RICE-CRL',  uom: uom_kg,  hsn: hsn_rice,  purchase_price: 220, min_order_qty: 1 },
    { sku: 'PULSE-TOOR-1KG', name: 'Toor Dal (1 kg)',           category: 'PULSES',    uom: uom_kg,  hsn: hsn_pulse, purchase_price: 140, min_order_qty: 1 },
    { sku: 'PULSE-URAD-1KG', name: 'Urad Dal (1 kg)',           category: 'PULSES',    uom: uom_kg,  hsn: hsn_pulse, purchase_price: 155, min_order_qty: 1 },
    { sku: 'OIL-SFR-1L',     name: 'Refined Sunflower Oil (1 L)', category: 'OILS',    uom: uom_ltr, hsn: hsn_oil,   purchase_price: 145, min_order_qty: 1 },
    { sku: 'OIL-SFR-5L',     name: 'Refined Sunflower Oil (5 L)', category: 'OILS',    uom: uom_ltr, hsn: hsn_oil,   purchase_price: 690, min_order_qty: 1 },
    { sku: 'SUGAR-REF-1KG',  name: 'Refined Sugar (1 kg)',      category: 'SUGAR',     uom: uom_kg,  hsn: hsn_sugar, purchase_price: 45,  min_order_qty: 1 },
    { sku: 'SALT-CMN-1KG',   name: 'Common Salt (1 kg)',        category: 'SPICES',    uom: uom_kg,  hsn: hsn_salt,  purchase_price: 18,  min_order_qty: 1 },
  ]

  products = {}
  product_defs.each do |attrs|
    p = Product.find_or_initialize_by(sku: attrs[:sku], organization: org)
    p.assign_attributes(
      name:             attrs[:name],
      product_category: categories[attrs[:category]],
      units_of_measure: attrs[:uom],
      hsn_sac_code:     attrs[:hsn],
      purchase_price:   attrs[:purchase_price],
      min_order_qty:    attrs[:min_order_qty],
      status:           'active'
    )
    p.save!
    products[attrs[:sku]] = p
    puts "    Product: #{p.sku} — #{p.name} (GST #{p.gst_rate}%)"
  end

  # ── Price Lists ────────────────────────────────────────────────────────────
  puts ''
  puts '  == Seeding price lists...'

  # 1. Standard org-wide list (applicable to all branches)
  std_list = PriceList.find_or_initialize_by(
    organization: org,
    branch:       nil,
    list_type:    'standard',
    name:         'Standard Price List'
  )
  std_list.assign_attributes(status: 'active', deleted_at: nil)
  std_list.save!
  puts "    PriceList: #{std_list.name} (#{std_list.list_type})"

  # Standard prices — ~25% margin over purchase price
  std_prices = {
    'RICE-BSMT-5KG'  => 420,
    'RICE-BSMT-25KG' => 1950,
    'RICE-SONA-5KG'  => 290,
    'PULSE-TOOR-1KG' => 175,
    'PULSE-URAD-1KG' => 195,
    'OIL-SFR-1L'     => 185,
    'OIL-SFR-5L'     => 875,
    'SUGAR-REF-1KG'  => 56,
    'SALT-CMN-1KG'   => 24,
  }

  std_prices.each do |sku, price|
    item = PriceListItem.find_or_initialize_by(
      price_list: std_list,
      product:    products[sku],
      min_qty:    nil
    )
    item.assign_attributes(unit_price: price, discount_pct: 0)
    item.save!
  end
  puts "    → #{std_prices.size} items added to Standard Price List"

  # Volume break for bulk rice purchase (qty >= 10 bags at 5% off)
  bulk_rice_skus = %w[RICE-BSMT-5KG RICE-SONA-5KG]
  bulk_rice_skus.each do |sku|
    item = PriceListItem.find_or_initialize_by(
      price_list: std_list,
      product:    products[sku],
      min_qty:    10
    )
    item.assign_attributes(unit_price: std_prices[sku], discount_pct: 5)
    item.save!
  end
  puts "    → Volume break (qty ≥ 10) added for #{bulk_rice_skus.join(', ')}"

  # 2. Seasonal Promo list (10% off oils & pulses, valid 30 days)
  promo_list = PriceList.find_or_initialize_by(
    organization: org,
    branch:       branch,
    list_type:    'promo',
    name:         'Summer Promo — Oils & Pulses'
  )
  promo_list.assign_attributes(
    status:     'active',
    valid_from: Date.current,
    valid_to:   Date.current + 30.days,
    deleted_at: nil
  )
  promo_list.save!
  puts "    PriceList: #{promo_list.name} (#{promo_list.valid_from} → #{promo_list.valid_to})"

  promo_skus = %w[OIL-SFR-1L OIL-SFR-5L PULSE-TOOR-1KG PULSE-URAD-1KG]
  promo_skus.each do |sku|
    item = PriceListItem.find_or_initialize_by(
      price_list: promo_list,
      product:    products[sku],
      min_qty:    nil
    )
    item.assign_attributes(unit_price: std_prices[sku], discount_pct: 10)
    item.save!
  end
  puts "    → #{promo_skus.size} items added to Promo Price List (10% off)"

  puts ''
  puts '  == Price lists seeded.'

  # ── Delivery: Vehicles & Drivers ─────────────────────────────────────────
  puts ''
  puts '  == Seeding delivery vehicles and drivers...'

  driver_role = Role.find_by!(name: 'driver')

  driver_defs = [
    { email: 'driver1@riceoms.dev', first_name: 'Ravi',   last_name: 'Kumar' },
    { email: 'driver2@riceoms.dev', first_name: 'Suresh', last_name: 'Yadav' },
    { email: 'driver3@riceoms.dev', first_name: 'Mohan',  last_name: 'Das'   },
  ]

  drivers = driver_defs.map do |attrs|
    u = User.find_or_initialize_by(email: attrs[:email])
    u.assign_attributes(first_name: attrs[:first_name], last_name: attrs[:last_name], active: true)
    u.password = 'Password@123' if u.new_record? || u.encrypted_password.blank?
    u.save!
    unless Membership.exists?(user: u, organization: org, branch: branch)
      Membership.create!(user: u, organization: org, branch: branch, role: driver_role, active: true)
    end
    puts "    Driver: #{u.email} (#{u.first_name} #{u.last_name})"
    u
  end

  vehicle_defs = [
    { registration_number: 'TS09EA4321', vehicle_type: 'truck', capacity_kg: 3000, capacity_units: 1200,
      status: 'active', insurance_expiry: 1.year.from_now.to_date, fitness_expiry: 1.year.from_now.to_date },
    { registration_number: 'TS09EA8765', vehicle_type: 'tempo', capacity_kg: 1500, capacity_units: 600,
      status: 'active', insurance_expiry: 8.months.from_now.to_date, fitness_expiry: 10.months.from_now.to_date },
    { registration_number: 'TS09EA2201', vehicle_type: 'bike',  capacity_kg: nil,  capacity_units: nil,
      status: 'active', insurance_expiry: 6.months.from_now.to_date, fitness_expiry: nil },
  ]

  vehicle_defs.each_with_index do |attrs, i|
    v = Vehicle.find_or_initialize_by(registration_number: attrs[:registration_number], organization: org)
    v.assign_attributes(
      vehicle_type:      attrs[:vehicle_type],
      capacity_kg:       attrs[:capacity_kg],
      capacity_units:    attrs[:capacity_units],
      status:            attrs[:status],
      insurance_expiry:  attrs[:insurance_expiry],
      fitness_expiry:    attrs[:fitness_expiry],
      default_driver_id: drivers[i]&.id
    )
    v.save!
    puts "    Vehicle: #{v.registration_number} (#{v.vehicle_type}) → driver: #{drivers[i]&.email}"
  end

  puts '  == Vehicles and drivers seeded.'

  # ── Suppliers ─────────────────────────────────────────────────────────────
  puts ''
  puts '  == Seeding suppliers...'

  supplier_defs = [
    {
      name:               'Sharma Distributors',
      code:               'SUPP-001',
      status:             'active',
      phone:              '9876540001',
      email:              'contact@sharmadist.in',
      contact_person:     'Ramesh Sharma',
      gstin:              '27AABCS1429B1ZB',
      pan:                'AABCS1429B',
      address:            '12 Warehouse Lane, APMC',
      city:               'Mumbai',
      state:              'Maharashtra',
      pincode:            '400002',
      bank_name:          'State Bank of India',
      bank_account:       '30987654321',
      bank_ifsc:          'SBIN0001234',
      payment_terms_days: 30,
      credit_limit:       500_000,
      notes:              'Primary rice and cereal supplier. Preferred vendor.',
    },
    {
      name:               'Patel Agro Exports',
      code:               'SUPP-002',
      status:             'active',
      phone:              '9876540002',
      email:              'patel.agro@example.com',
      contact_person:     'Suresh Patel',
      gstin:              '24AACCP1234A1ZK',
      pan:                'AACCP1234A',
      address:            'Plot 45, GIDC',
      city:               'Ahmedabad',
      state:              'Gujarat',
      pincode:            '382425',
      bank_name:          'HDFC Bank',
      bank_account:       '50100123456789',
      bank_ifsc:          'HDFC0001122',
      payment_terms_days: 15,
      credit_limit:       250_000,
      notes:              'Pulses and edible oils.',
    },
    {
      name:               'Mysore Oil Mills',
      code:               'SUPP-003',
      status:             'active',
      phone:              '9876540003',
      email:              nil,
      contact_person:     'Anand Krishnan',
      gstin:              nil,
      pan:                nil,
      address:            '88 Industrial Area',
      city:               'Mysore',
      state:              'Karnataka',
      pincode:            '570016',
      bank_name:          nil,
      bank_account:       nil,
      bank_ifsc:          nil,
      payment_terms_days: 0,
      credit_limit:       nil,
      notes:              'Cash-on-delivery terms only.',
    },
    {
      name:               'Delhi Spice Traders',
      code:               'SUPP-004',
      status:             'inactive',
      phone:              '9876540004',
      email:              'delhispice@example.com',
      contact_person:     nil,
      gstin:              '07AADFD1234B1ZC',
      pan:                'AADFD1234B',
      address:            '3 Khari Baoli',
      city:               'New Delhi',
      state:              'Delhi',
      pincode:            '110006',
      bank_name:          'Punjab National Bank',
      bank_account:       '1234567890',
      bank_ifsc:          'PUNB0001100',
      payment_terms_days: 45,
      credit_limit:       100_000,
      notes:              'On hold — pending GST reconciliation.',
    },
  ]

  supplier_defs.each do |attrs|
    s = Supplier.find_or_initialize_by(code: attrs[:code], organization: org)
    s.assign_attributes(attrs)
    s.save!
    puts "    Supplier: #{s.code} — #{s.name} (#{s.status})"
  end

  puts '  == Suppliers seeded.'

  # ── Purchase Invoices ─────────────────────────────────────────────────────
  puts ''
  puts '  == Seeding purchase invoices (all scenarios)...'

  # Reload supplier references
  supp_sharma = Supplier.find_by!(code: 'SUPP-001', organization: org)
  supp_patel  = Supplier.find_by!(code: 'SUPP-002', organization: org)
  supp_mysore = Supplier.find_by!(code: 'SUPP-003', organization: org)

  # Product references (already created above)
  p_rice_5kg   = products['RICE-BSMT-5KG']
  p_rice_25kg  = products['RICE-BSMT-25KG']
  p_sona_5kg   = products['RICE-SONA-5KG']
  p_toor       = products['PULSE-TOOR-1KG']
  p_urad       = products['PULSE-URAD-1KG']
  p_oil_1l     = products['OIL-SFR-1L']
  p_oil_5l     = products['OIL-SFR-5L']
  p_sugar      = products['SUGAR-REF-1KG']
  p_salt       = products['SALT-CMN-1KG']

  def seed_invoice(invoice_number:, supplier:, organization:, branch:, actor:,
                   invoice_date:, due_date: nil, notes: nil, lines:)
    return if PurchaseInvoice.exists?(invoice_number: invoice_number, supplier: supplier)

    result = PurchaseInvoices::CreateService.new(
      params: {
        supplier_id:    supplier.id,
        branch_id:      branch.id,
        invoice_number: invoice_number,
        invoice_date:   invoice_date,
        due_date:       due_date,
        currency:       'INR',
        notes:          notes,
        lines:          lines,
      },
      organization: organization,
      branch:       branch,
      actor:        actor
    ).call

    raise "Seed invoice #{invoice_number} failed: #{result.errors.join(', ')}" unless result.success?
    result.invoice
  end

  # ── SCENARIO 1: DRAFT — recent, multi-line, Sharma Distributors ───────────
  inv_draft_1 = seed_invoice(
    invoice_number: 'SEED-INV-001',
    supplier:       supp_sharma,
    organization:   org,
    branch:         branch,
    actor:          admin,
    invoice_date:   Date.current - 2.days,
    due_date:       Date.current + 28.days,
    notes:          'Monthly rice stock replenishment. Awaiting GRN confirmation.',
    lines: [
      { product_id: p_rice_5kg.id,  qty: 50,  unit_price: p_rice_5kg.purchase_price,  discount_pct: 0, tax_rate: 5, hsn_sac_code_id: p_rice_5kg.hsn_sac_code_id },
      { product_id: p_rice_25kg.id, qty: 20,  unit_price: p_rice_25kg.purchase_price, discount_pct: 0, tax_rate: 5, hsn_sac_code_id: p_rice_25kg.hsn_sac_code_id },
      { product_id: p_sona_5kg.id,  qty: 30,  unit_price: p_sona_5kg.purchase_price,  discount_pct: 0, tax_rate: 5, hsn_sac_code_id: p_sona_5kg.hsn_sac_code_id },
    ]
  )
  puts "    [DRAFT]     #{inv_draft_1&.invoice_number || 'SEED-INV-001 (already exists)'}"

  # ── SCENARIO 2: DRAFT — Patel Agro, oils + pulses, early settlement discount ──
  inv_draft_2 = seed_invoice(
    invoice_number: 'SEED-INV-002',
    supplier:       supp_patel,
    organization:   org,
    branch:         branch,
    actor:          admin,
    invoice_date:   Date.current - 1.day,
    due_date:       Date.current + 14.days,
    notes:          'Patel Q1 supply — oils and pulses. Pending QC check.',
    lines: [
      { product_id: p_oil_1l.id,  qty: 100, unit_price: p_oil_1l.purchase_price,  discount_pct: 2,   tax_rate: 5, hsn_sac_code_id: p_oil_1l.hsn_sac_code_id  },
      { product_id: p_oil_5l.id,  qty: 40,  unit_price: p_oil_5l.purchase_price,  discount_pct: 2,   tax_rate: 5, hsn_sac_code_id: p_oil_5l.hsn_sac_code_id  },
      { product_id: p_toor.id,    qty: 200, unit_price: p_toor.purchase_price,    discount_pct: 0,   tax_rate: 0, hsn_sac_code_id: p_toor.hsn_sac_code_id    },
      { product_id: p_urad.id,    qty: 150, unit_price: p_urad.purchase_price,    discount_pct: 0,   tax_rate: 0, hsn_sac_code_id: p_urad.hsn_sac_code_id    },
    ]
  )
  puts "    [DRAFT]     #{inv_draft_2&.invoice_number || 'SEED-INV-002 (already exists)'}"

  # ── SCENARIO 3: DRAFT — Mysore Oil Mills, no GST (CoD supplier) ───────────
  inv_draft_3 = seed_invoice(
    invoice_number: 'SEED-INV-006',
    supplier:       supp_mysore,
    organization:   org,
    branch:         branch,
    actor:          admin,
    invoice_date:   Date.current,
    due_date:       nil,
    notes:          'Cash purchase — Mysore Oil Mills. No credit terms.',
    lines: [
      { product_id: p_oil_1l.id,  qty: 60,  unit_price: 140, discount_pct: 0, tax_rate: 5, hsn_sac_code_id: p_oil_1l.hsn_sac_code_id },
      { product_id: p_sugar.id,   qty: 100, unit_price: 44,  discount_pct: 0, tax_rate: 5, hsn_sac_code_id: p_sugar.hsn_sac_code_id  },
    ]
  )
  puts "    [DRAFT]     #{inv_draft_3&.invoice_number || 'SEED-INV-006 (already exists)'}"

  # ── SCENARIO 4: POSTED — Sharma, last week, stock updated ────────────────
  inv_posted_1 = seed_invoice(
    invoice_number: 'SEED-INV-003',
    supplier:       supp_sharma,
    organization:   org,
    branch:         branch,
    actor:          admin,
    invoice_date:   Date.current - 7.days,
    due_date:       Date.current + 23.days,
    notes:          'Week-1 rice restock. Verified and received.',
    lines: [
      { product_id: p_rice_5kg.id,  qty: 100, unit_price: p_rice_5kg.purchase_price,  discount_pct: 0, tax_rate: 5, hsn_sac_code_id: p_rice_5kg.hsn_sac_code_id },
      { product_id: p_sona_5kg.id,  qty: 80,  unit_price: p_sona_5kg.purchase_price,  discount_pct: 0, tax_rate: 5, hsn_sac_code_id: p_sona_5kg.hsn_sac_code_id },
      { product_id: p_salt.id,      qty: 500, unit_price: p_salt.purchase_price,       discount_pct: 0, tax_rate: 0, hsn_sac_code_id: p_salt.hsn_sac_code_id    },
    ]
  )
  if inv_posted_1 && inv_posted_1.draft?
    result = PurchaseInvoices::PostService.new(invoice: inv_posted_1, actor: admin).call
    raise "Post SEED-INV-003 failed: #{result.errors.join(', ')}" unless result.success?
  end
  puts "    [POSTED]    #{(inv_posted_1 || PurchaseInvoice.find_by(invoice_number: 'SEED-INV-003', supplier: supp_sharma))&.invoice_number || 'SEED-INV-003 (already exists)'}"

  # ── SCENARIO 5: POSTED — Patel, 2 weeks ago, large bulk order ────────────
  inv_posted_2 = seed_invoice(
    invoice_number: 'SEED-INV-004',
    supplier:       supp_patel,
    organization:   org,
    branch:         branch,
    actor:          admin,
    invoice_date:   Date.current - 14.days,
    due_date:       Date.current + 1.day,
    notes:          'February bulk stock. All items received in good condition.',
    lines: [
      { product_id: p_toor.id,   qty: 500, unit_price: p_toor.purchase_price,   discount_pct: 3, tax_rate: 0, hsn_sac_code_id: p_toor.hsn_sac_code_id  },
      { product_id: p_urad.id,   qty: 300, unit_price: p_urad.purchase_price,   discount_pct: 3, tax_rate: 0, hsn_sac_code_id: p_urad.hsn_sac_code_id  },
      { product_id: p_sugar.id,  qty: 200, unit_price: p_sugar.purchase_price,  discount_pct: 0, tax_rate: 5, hsn_sac_code_id: p_sugar.hsn_sac_code_id },
    ]
  )
  if inv_posted_2 && inv_posted_2.draft?
    result = PurchaseInvoices::PostService.new(invoice: inv_posted_2, actor: admin).call
    raise "Post SEED-INV-004 failed: #{result.errors.join(', ')}" unless result.success?
  end
  puts "    [POSTED]    #{(inv_posted_2 || PurchaseInvoice.find_by(invoice_number: 'SEED-INV-004', supplier: supp_patel))&.invoice_number || 'SEED-INV-004 (already exists)'}"

  # ── SCENARIO 6: CANCELLED FROM DRAFT — supplier changed, never posted ────
  inv_cancel_draft = seed_invoice(
    invoice_number: 'SEED-INV-005',
    supplier:       supp_patel,
    organization:   org,
    branch:         branch,
    actor:          admin,
    invoice_date:   Date.current - 5.days,
    due_date:       Date.current + 10.days,
    notes:          'Duplicate entry — cancelled before posting.',
    lines: [
      { product_id: p_toor.id,  qty: 50,  unit_price: 145, discount_pct: 0, tax_rate: 0, hsn_sac_code_id: p_toor.hsn_sac_code_id },
      { product_id: p_urad.id,  qty: 30,  unit_price: 160, discount_pct: 0, tax_rate: 0, hsn_sac_code_id: p_urad.hsn_sac_code_id },
    ]
  )
  if inv_cancel_draft && inv_cancel_draft.draft?
    result = PurchaseInvoices::CancelService.new(
      invoice: inv_cancel_draft,
      actor:   admin,
      reason:  'Duplicate entry raised by mistake — no stock impact expected.'
    ).call
    raise "Cancel SEED-INV-005 failed: #{result.errors.join(', ')}" unless result.success?
  end
  puts "    [CANCELLED] #{(inv_cancel_draft || PurchaseInvoice.find_by(invoice_number: 'SEED-INV-005', supplier: supp_patel))&.invoice_number || 'SEED-INV-005 (already exists)'} (from draft — no stock movement)"

  # ── SCENARIO 7: CANCELLED FROM POSTED — received then returned ───────────
  inv_cancel_posted = seed_invoice(
    invoice_number: 'SEED-INV-007',
    supplier:       supp_sharma,
    organization:   org,
    branch:         branch,
    actor:          admin,
    invoice_date:   Date.current - 10.days,
    due_date:       Date.current + 20.days,
    notes:          'Batch failed quality check. Full return initiated.',
    lines: [
      { product_id: p_rice_25kg.id, qty: 10, unit_price: p_rice_25kg.purchase_price, discount_pct: 0, tax_rate: 5, hsn_sac_code_id: p_rice_25kg.hsn_sac_code_id },
    ]
  )
  if inv_cancel_posted
    if inv_cancel_posted.draft?
      post_result = PurchaseInvoices::PostService.new(invoice: inv_cancel_posted, actor: admin).call
      raise "Post SEED-INV-007 failed: #{post_result.errors.join(', ')}" unless post_result.success?
    end
    if inv_cancel_posted.reload.posted?
      cancel_result = PurchaseInvoices::CancelService.new(
        invoice: inv_cancel_posted,
        actor:   admin,
        reason:  'Quality rejection — Rice 25 kg batch B241 failed moisture test. Stock reversed.'
      ).call
      raise "Cancel SEED-INV-007 failed: #{cancel_result.errors.join(', ')}" unless cancel_result.success?
    end
  end
  inv_cancel_posted_display = inv_cancel_posted || PurchaseInvoice.find_by(invoice_number: 'SEED-INV-007', supplier: supp_sharma)
  puts "    [CANCELLED] #{inv_cancel_posted_display&.invoice_number || 'SEED-INV-007 (already exists)'} (from posted — stock reversed)"

  puts ''
  puts '  == Purchase invoices summary:'
  puts "       Draft:     #{PurchaseInvoice.where(organization: org, status: 'draft').count}"
  puts "       Posted:    #{PurchaseInvoice.where(organization: org, status: 'posted').count}"
  puts "       Cancelled: #{PurchaseInvoice.where(organization: org, status: 'cancelled').count}"

  puts '  == Purchase invoices seeded.'

  # ── Inventory Ledger Seeding ──────────────────────────────────────────────
  puts ''
  puts '  == Seeding inventory ledger (adjustments, thresholds, movements)...'

  # Lambda: idempotent guard — skip if a movement with this scenario key already exists
  inv_scenario_exists = ->(scenario) {
    StockMovement.where("metadata->>'scenario' = ?", scenario.to_s).exists?
  }

  # Helper: post a movement and stamp the scenario key into its metadata
  post_inv_scenario = ->(scenario, **kwargs) {
    return if inv_scenario_exists.(scenario)
    base_meta = kwargs.delete(:metadata) || {}
    result = Inventory::PostMovement.call(**kwargs, metadata: base_meta.merge('scenario' => scenario))
    raise "Inventory movement seed failed (#{scenario}): #{result.errors.join(', ')}" unless result.success?
    result.movement
  }

  post_adj_scenario = ->(scenario, **kwargs) {
    return if inv_scenario_exists.(scenario)
    result = Inventory::Adjustment.call(**kwargs)
    raise "Adjustment seed failed (#{scenario}): #{result.errors.join(', ')}" unless result.success?
    result.movement.update_column(:metadata, result.movement.metadata.merge('scenario' => scenario))
    result.movement
  }

  # ─── A. Opening stock top-ups ─────────────────────────────────────────────
  # Products NOT covered by posted invoices (only in draft invoices) need
  # an adjustment_in to represent opening balances.
  opening_stock = [
    { sku: 'RICE-BSMT-25KG', qty: 40,   scenario: 'opening_rice_25kg'  },
    { sku: 'OIL-SFR-1L',     qty: 120,  scenario: 'opening_oil_1l'     },
    { sku: 'OIL-SFR-5L',     qty: 50,   scenario: 'opening_oil_5l'     },
  ]

  opening_stock.each do |row|
    next if inv_scenario_exists.(row[:scenario])

    prod = products[row[:sku]]
    post_adj_scenario.(row[:scenario],
      org:         org,
      branch:      branch,
      product:     prod,
      direction:   :in,
      quantity:    row[:qty],
      actor:       admin,
      reason_code: 'opening_stock',
      notes:       "Opening balance loaded by seed (#{row[:scenario]})"
    )
    puts "    [ADJ-IN]  #{prod.sku.ljust(22)} +#{row[:qty]} (opening stock)"
  end

  # ─── B. Stock write-off — damaged goods ──────────────────────────────────
  if post_adj_scenario.('writeoff_salt_damaged',
    org:         org,
    branch:      branch,
    product:     p_salt,
    direction:   :out,
    quantity:    20,
    actor:       admin,
    reason_code: 'damage_write_off',
    notes:       '20 bags of salt water-damaged in storage — written off (seed scenario)'
  )
    puts "    [ADJ-OUT] #{p_salt.sku.ljust(22)} -20 (damage write-off)"
  end

  # ─── C. Return received from customer ────────────────────────────────────
  if post_inv_scenario.('return_rice_bsmt_5kg_cust01',
    org:           org,
    branch:        branch,
    product:       p_rice_5kg,
    movement_type: 'return_received',
    quantity:      5,
    actor:         admin,
    metadata:      { reason_code: 'customer_return', notes: 'Customer return — 5 bags Basmati 5 kg, good condition, restocked' }
  )
    puts "    [RETURN]  #{p_rice_5kg.sku.ljust(22)} +5 (customer return)"
  end

  # ─── D. Second branch — Secunderabad Depot — opening stock ───────────────
  depot_branch = Branch.find_or_initialize_by(code: 'ARYA-SD')
  depot_branch.assign_attributes(
    name:         'Secunderabad Depot',
    organization: org,
    city:         'Secunderabad',
    state:        'Telangana',
    active:       true
  )
  depot_branch.save!
  puts "    Branch:   #{depot_branch.name} (#{depot_branch.code}) — created/found"

  unless Membership.exists?(user: admin, organization: org, branch: depot_branch)
    Membership.create!(user: admin, organization: org, branch: depot_branch, role: owner_role, active: true)
  end

  depot_opening_stock = [
    { sku: 'RICE-BSMT-5KG',  qty: 60,  scenario: 'depot_opening_rice_bsmt_5kg' },
    { sku: 'RICE-SONA-5KG',  qty: 40,  scenario: 'depot_opening_rice_sona_5kg' },
    { sku: 'PULSE-TOOR-1KG', qty: 200, scenario: 'depot_opening_toor'           },
    { sku: 'OIL-SFR-1L',     qty: 80,  scenario: 'depot_opening_oil_1l'         },
    { sku: 'SUGAR-REF-1KG',  qty: 150, scenario: 'depot_opening_sugar'          },
  ]

  depot_opening_stock.each do |row|
    next if inv_scenario_exists.(row[:scenario])

    prod = products[row[:sku]]
    post_adj_scenario.(row[:scenario],
      org:         org,
      branch:      depot_branch,
      product:     prod,
      direction:   :in,
      quantity:    row[:qty],
      actor:       admin,
      reason_code: 'opening_stock',
      notes:       "Secunderabad Depot opening balance (#{row[:scenario]})"
    )
    puts "    [ADJ-IN]  #{prod.sku.ljust(22)} +#{row[:qty]} (depot opening stock)"
  end

  # ─── E. Transfer from Head Office → Secunderabad Depot ───────────────────
  unless inv_scenario_exists.('transfer_out_salt_to_depot')
    post_inv_scenario.('transfer_out_salt_to_depot',
      org:           org,
      branch:        branch,
      product:       p_salt,
      movement_type: 'transfer_out',
      quantity:      100,
      actor:         admin,
      metadata:      { destination_branch: depot_branch.id, notes: 'Salt transfer HO → Secunderabad Depot' }
    )
    post_inv_scenario.('transfer_in_salt_from_ho',
      org:           org,
      branch:        depot_branch,
      product:       p_salt,
      movement_type: 'transfer_in',
      quantity:      100,
      actor:         admin,
      metadata:      { source_branch: branch.id, notes: 'Salt received from Head Office' }
    )
    puts "    [XFER]    #{p_salt.sku.ljust(22)} HO → Depot (100 units)"
  end

  # ─── G. Stock Transfers ───────────────────────────────────────────────────
  puts ''
  puts '  == Seeding stock transfers...'

  # Idempotency: keyed by a [seed:key] tag embedded in the notes field.
  trf_exists = ->(key) {
    StockTransfer.where(organization: org).where("notes LIKE ?", "%[seed:#{key}]%").exists?
  }

  # Helper: create a draft transfer, return existing record if already seeded.
  seed_transfer = ->(key, source:, destination:, notes:, lines:) {
    if trf_exists.(key)
      return StockTransfer.where(organization: org).where("notes LIKE ?", "%[seed:#{key}]%").first
    end
    result = Transfers::CreateDraftTransfer.new(
      params: {
        source_branch_id:      source.id,
        destination_branch_id: destination.id,
        transfer_date:         Date.current,
        notes:                 "#{notes} [seed:#{key}]",
        lines:                 lines,
      },
      organization: org,
      actor:        admin
    ).call
    raise "Seed transfer '#{key}' failed: #{result.errors.join(', ')}" unless result.success?
    result.transfer
  }

  # ── SCENARIO 1: DRAFT — HO → Depot, awaiting approval ───────────────────
  trf_draft = seed_transfer.('trf_draft',
    source:      branch,
    destination: depot_branch,
    notes:       'Scheduled weekly replenishment — pending dispatch approval.',
    lines: [
      { product_id: p_rice_5kg.id, qty_requested: 20 },
      { product_id: p_toor.id,     qty_requested: 30 },
    ]
  )
  puts "    [DRAFT]              #{trf_draft.transfer_number}  HO → Depot  (rice 5 kg ×20, toor ×30)"

  # ── SCENARIO 2: DISPATCHED — HO → Depot, in transit ─────────────────────
  trf_dispatched = seed_transfer.('trf_dispatched',
    source:      branch,
    destination: depot_branch,
    notes:       'Mid-week restocking for depot. Goods loaded onto truck.',
    lines: [
      { product_id: p_sona_5kg.id, qty_requested: 25 },
      { product_id: p_sugar.id,    qty_requested: 50 },
    ]
  )
  if trf_dispatched.draft?
    trf_dispatched.reload
    d2 = Transfers::DispatchTransfer.new(
      transfer:        trf_dispatched,
      actor:           admin,
      dispatched_lines: trf_dispatched.lines.map { |l| { line_id: l.id, qty_dispatched: l.qty_requested } }
    ).call
    raise "Dispatch trf_dispatched failed: #{d2.errors.join(', ')}" unless d2.success?
    trf_dispatched = d2.transfer
  end
  puts "    [DISPATCHED]         #{trf_dispatched.transfer_number}  HO → Depot  (sona 5 kg ×25, sugar ×50)"

  # ── SCENARIO 3: PARTIALLY RECEIVED — Depot → HO, 1 carton damaged ────────
  trf_partial = seed_transfer.('trf_partial',
    source:      depot_branch,
    destination: branch,
    notes:       'Oils rebalance to HO — partial receipt; damaged cartons noted.',
    lines: [
      { product_id: p_oil_1l.id, qty_requested: 40 },
    ]
  )
  if trf_partial.draft?
    trf_partial.reload
    d3 = Transfers::DispatchTransfer.new(
      transfer:        trf_partial,
      actor:           admin,
      dispatched_lines: trf_partial.lines.map { |l| { line_id: l.id, qty_dispatched: l.qty_requested } }
    ).call
    raise "Dispatch trf_partial failed: #{d3.errors.join(', ')}" unless d3.success?
    trf_partial = d3.transfer
  end
  if trf_partial.dispatched?
    trf_partial.reload
    r3 = Transfers::ReceiveTransfer.new(
      transfer:       trf_partial,
      actor:          admin,
      received_lines: trf_partial.lines
                        .select { |l| l.qty_in_transit > 0 }
                        .map    { |l| { line_id: l.id, qty_received: 25, qty_damaged: 5, reason_code: 'damage' } }
    ).call
    raise "Receive trf_partial failed: #{r3.errors.join(', ')}" unless r3.success?
    trf_partial = r3.transfer
  end
  puts "    [PARTIALLY RECEIVED] #{trf_partial.transfer_number}  Depot → HO  (oil 1 L ×40 dispatched; ×25 received, ×5 damaged)"

  # ── SCENARIO 4: FULLY RECEIVED — Depot → HO ──────────────────────────────
  trf_received = seed_transfer.('trf_received',
    source:      depot_branch,
    destination: branch,
    notes:       'Rice rebalancing — excess depot stock returned to HO for redistribution.',
    lines: [
      { product_id: p_rice_5kg.id, qty_requested: 15 },
    ]
  )
  if trf_received.draft?
    trf_received.reload
    d4 = Transfers::DispatchTransfer.new(
      transfer:        trf_received,
      actor:           admin,
      dispatched_lines: trf_received.lines.map { |l| { line_id: l.id, qty_dispatched: l.qty_requested } }
    ).call
    raise "Dispatch trf_received failed: #{d4.errors.join(', ')}" unless d4.success?
    trf_received = d4.transfer
  end
  if trf_received.dispatched? || trf_received.partially_received?
    trf_received.reload
    r4 = Transfers::ReceiveTransfer.new(
      transfer:       trf_received,
      actor:          admin,
      received_lines: trf_received.lines
                        .select { |l| l.qty_in_transit > 0 }
                        .map    { |l| { line_id: l.id, qty_received: l.qty_in_transit, qty_damaged: 0, reason_code: nil } }
    ).call
    raise "Receive trf_received failed: #{r4.errors.join(', ')}" unless r4.success?
    trf_received = r4.transfer
  end
  puts "    [RECEIVED]           #{trf_received.transfer_number}  Depot → HO  (rice 5 kg ×15 fully received)"

  # ── SCENARIO 5: CANCELLED — raised in error, never dispatched ────────────
  trf_cancelled = seed_transfer.('trf_cancelled',
    source:      branch,
    destination: depot_branch,
    notes:       'Transfer created by mistake — stock not available at time of request.',
    lines: [
      { product_id: p_rice_25kg.id, qty_requested: 5 },
    ]
  )
  if trf_cancelled.draft?
    trf_cancelled.reload
    c5 = Transfers::CancelTransfer.new(
      transfer: trf_cancelled,
      actor:    admin,
      reason:   'Transfer raised in error — no dispatch required. Cancelled by manager before dispatch.'
    ).call
    raise "Cancel trf_cancelled failed: #{c5.errors.join(', ')}" unless c5.success?
    trf_cancelled = c5.transfer
  end
  puts "    [CANCELLED]          #{trf_cancelled.transfer_number}  HO → Depot  (rice 25 kg ×5, cancelled before dispatch)"

  puts ''
  puts '  == Stock transfers summary:'
  StockTransfer.where(organization: org).group(:status).count.sort_by(&:first).each do |status, count|
    puts "       #{status.to_s.ljust(22)} #{count}"
  end
  puts "       Total audit events: #{AuditLog.where(organization: org, auditable_type: 'StockTransfer').count}"
  puts '  == Stock transfers seeded.'

  # ─── H. Set min_qty_threshold on all InventoryLevels ─────────────────────
  # Thresholds are set so that most products are comfortably above threshold,
  # but a few will trigger the low_stock badge for demo purposes.
  threshold_map = {
    # [main branch threshold, depot threshold]  (nil = no threshold)
    'RICE-BSMT-5KG'  => [30,  20],
    'RICE-BSMT-25KG' => [50,  nil],  # HO will be low-stock (only 40 on hand)
    'RICE-SONA-5KG'  => [30,  20],
    'PULSE-TOOR-1KG' => [100, 80],
    'PULSE-URAD-1KG' => [100, nil],
    'OIL-SFR-1L'     => [60,  30],
    'OIL-SFR-5L'     => [20,  nil],
    'SUGAR-REF-1KG'  => [80,  60],
    'SALT-CMN-1KG'   => [150, 50],   # HO may be low after write-off + transfer
  }

  threshold_map.each do |sku, (ho_threshold, depot_threshold)|
    prod = products[sku]

    if ho_threshold
      lvl = InventoryLevel.find_by(organization: org, branch: branch, product: prod)
      if lvl
        lvl.update_column(:min_qty_threshold, ho_threshold)
      end
    end

    if depot_threshold
      lvl2 = InventoryLevel.find_by(organization: org, branch: depot_branch, product: prod)
      if lvl2
        lvl2.update_column(:min_qty_threshold, depot_threshold)
      end
    end
  end
  puts "    Thresholds set on #{threshold_map.size} products across both branches."

  # ─── I. Print final inventory summary ────────────────────────────────────
  puts ''
  puts '  == Final Inventory Levels:'
  puts ''
  puts "     #{'Product SKU'.ljust(22)} #{'Branch'.ljust(22)} #{'On Hand'.rjust(9)} #{'Reserved'.rjust(9)} #{'Available'.rjust(10)} #{'Threshold'.rjust(10)}  Status"
  puts "     #{'─' * 22} #{'─' * 22} #{'─' * 9} #{'─' * 9} #{'─' * 10} #{'─' * 10}  ──────"

  InventoryLevel.where(organization: org)
                .eager_load(:product, :branch)
                .order('branches.name ASC, products.name ASC')
                .each do |lvl|
    threshold_str = lvl.min_qty_threshold ? lvl.min_qty_threshold.to_f.to_s.rjust(10) : '         —'
    status        = lvl.low_stock? ? '⚠ LOW STOCK' : 'OK'
    puts "     #{lvl.product.sku.ljust(22)} #{lvl.branch.name.ljust(22)} #{lvl.qty_on_hand.to_f.to_s.rjust(9)} #{lvl.qty_reserved.to_f.to_s.rjust(9)} #{(lvl.qty_on_hand - lvl.qty_reserved).to_f.to_s.rjust(10)} #{threshold_str}  #{status}"
  end

  low_count = InventoryLevel.where(organization: org).select(&:low_stock?).count
  puts ''
  puts "     Total levels:     #{InventoryLevel.where(organization: org).count}"
  puts "     Low stock alerts: #{low_count}"
  puts "     Total movements:  #{StockMovement.where(organization: org).count}"
  puts "     Stock transfers:  #{StockTransfer.where(organization: org).count}"

  puts ''
  puts '  == Inventory ledger seeded.'


  # â”€â”€ J. Customers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  puts ''
  puts '  == Seeding customers...'

  customer_defs = [
    { name: 'Sri Balaji Stores',      code: 'CUST-001', phone: '9848012345',
      gstin: '36AABCS1234Z1Z5', channel: 'general_trade',    tier: 'gold',
      credit_limit: 50_000,  credit_days: 30 },
    { name: 'Ravi General Merchants', code: 'CUST-002', phone: '9848023456',
      gstin: nil,             channel: 'general_trade',    tier: 'silver',
      credit_limit: 20_000,  credit_days: 15 },
    { name: 'Lakshmi Kirana Depot',   code: 'CUST-003', phone: '9848034567',
      gstin: '36AADCL4567B1ZD', channel: 'wholesale', tier: 'platinum',
      credit_limit: 150_000, credit_days: 45 },
    { name: 'Sai Traders',            code: 'CUST-004', phone: '9848045678',
      gstin: nil,             channel: 'general_trade',    tier: 'bronze',
      credit_limit: 10_000,  credit_days: 7 },
  ]

  customers = {}
  customer_defs.each do |attrs|
    c = Customer.find_or_initialize_by(code: attrs[:code], organization: org)
    c.assign_attributes(
      name:          attrs[:name],
      phone:         attrs[:phone],
      gstin:         attrs[:gstin],
      channel:       attrs[:channel],
      tier:          attrs[:tier],
      credit_limit:  attrs[:credit_limit],
      credit_days:   attrs[:credit_days],
      branch:        branch,
      status:        'active',
      customer_type: 'retailer'
    )
    c.save!
    customers[attrs[:code]] = c
    puts "    Customer: #{c.code} â€“ #{c.name}"
  end

  puts '  == Customers seeded.'

  # â”€â”€ K. Returns & Credit Notes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  puts ''
  puts '  == Seeding returns & credit notes...'

  rr_exists = ->(num) { ReturnRequest.exists?(organization: org, return_number: num) }

  # Approximate selling prices (purchase + ~30% margin)
  sell_prices = {
    'RICE-BSMT-5KG'  => { price: 415.00, gst: 5.0,  hsn: '10061090' },
    'RICE-SONA-5KG'  => { price: 285.00, gst: 5.0,  hsn: '10061090' },
    'PULSE-TOOR-1KG' => { price: 182.00, gst: 0.0,  hsn: '07134000' },
    'PULSE-URAD-1KG' => { price: 202.00, gst: 0.0,  hsn: '07133100' },
    'OIL-SFR-1L'     => { price: 188.00, gst: 5.0,  hsn: '15121990' },
    'SUGAR-REF-1KG'  => { price:  58.00, gst: 5.0,  hsn: '17011400' },
    'SALT-CMN-1KG'   => { price:  22.00, gst: 0.0,  hsn: '25010010' },
  }

  # â”€â”€ SCENARIO 1: DRAFT â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  unless rr_exists.('RET-0001-000001')
    r = Returns::CreateDraft.call(
      actor: admin, organization: org, branch: branch,
      params: {
        customer_id: customers['CUST-001'].id,
        source_type: 'manual',
        return_date: Date.current - 3.days,
        notes:       'Customer reported 2 bags Basmati damaged in transit.',
        lines: [{
          product_id:          products['RICE-BSMT-5KG'].id,
          qty_reported:        2,
          condition_reported:  'damaged',
          reason_code:         'other',
          unit_price_snapshot: sell_prices['RICE-BSMT-5KG'][:price],
          gst_rate_snapshot:   sell_prices['RICE-BSMT-5KG'][:gst],
          hsn_code_snapshot:   sell_prices['RICE-BSMT-5KG'][:hsn],
        }]
      }
    )
    raise "Return DRAFT failed: #{r.errors.join(', ')}" unless r.success?
    puts "    [DRAFT]              #{r.return_request.return_number} â€“ #{customers['CUST-001'].name}"
  end

  # â”€â”€ SCENARIO 2: SUBMITTED â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  unless rr_exists.('RET-0001-000002')
    r = Returns::CreateDraft.call(
      actor: admin, organization: org, branch: branch,
      params: {
        customer_id: customers['CUST-002'].id,
        source_type: 'manual',
        return_date: Date.current - 5.days,
        notes:       'Short-expiry oil batch; customer requested full return.',
        lines: [{
          product_id:          products['OIL-SFR-1L'].id,
          qty_reported:        6,
          condition_reported:  'expired',
          reason_code:         'expired',
          unit_price_snapshot: sell_prices['OIL-SFR-1L'][:price],
          gst_rate_snapshot:   sell_prices['OIL-SFR-1L'][:gst],
          hsn_code_snapshot:   sell_prices['OIL-SFR-1L'][:hsn],
        }]
      }
    )
    raise "Return SUBMITTED create failed: #{r.errors.join(', ')}" unless r.success?
    rr2 = r.return_request
    s = Returns::Submit.call(actor: admin, return_request: rr2)
    raise "Return SUBMITTED submit failed: #{s.errors.join(', ')}" unless s.success?
    puts "    [SUBMITTED]          #{rr2.reload.return_number} â€“ #{customers['CUST-002'].name}"
  end

  # â”€â”€ SCENARIO 3: QC IN PROGRESS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  unless rr_exists.('RET-0001-000003')
    r = Returns::CreateDraft.call(
      actor: admin, organization: org, branch: branch,
      params: {
        customer_id: customers['CUST-003'].id,
        source_type: 'manual',
        return_date: Date.current - 7.days,
        notes:       'Urad dal QC pending â€“ possible moisture damage.',
        lines: [{
          product_id:          products['PULSE-URAD-1KG'].id,
          qty_reported:        10,
          condition_reported:  'unknown',
          reason_code:         'quality_issue',
          unit_price_snapshot: sell_prices['PULSE-URAD-1KG'][:price],
          gst_rate_snapshot:   sell_prices['PULSE-URAD-1KG'][:gst],
          hsn_code_snapshot:   sell_prices['PULSE-URAD-1KG'][:hsn],
        }]
      }
    )
    raise "Return QC_IN_PROGRESS create failed: #{r.errors.join(', ')}" unless r.success?
    rr3 = r.return_request
    s = Returns::Submit.call(actor: admin, return_request: rr3)
    raise "Return QC_IN_PROGRESS submit failed: #{s.errors.join(', ')}" unless s.success?
    q = Returns::StartQc.call(actor: admin, return_request: rr3.reload)
    raise "Return QC_IN_PROGRESS start_qc failed: #{q.errors.join(', ')}" unless q.success?
    puts "    [QC_IN_PROGRESS]     #{rr3.reload.return_number} â€“ #{customers['CUST-003'].name}"
  end

  # â”€â”€ SCENARIO 4: QC COMPLETED (awaiting credit note) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  unless rr_exists.('RET-0001-000004')
    r = Returns::CreateDraft.call(
      actor: admin, organization: org, branch: branch,
      params: {
        customer_id: customers['CUST-001'].id,
        source_type: 'manual',
        return_date: Date.current - 10.days,
        notes:       'Overstocked â€“ Toor dal & Sugar returned.',
        lines: [
          {
            product_id:          products['PULSE-TOOR-1KG'].id,
            qty_reported:        5,
            condition_reported:  'resalable',
            reason_code:         'customer_refused',
            unit_price_snapshot: sell_prices['PULSE-TOOR-1KG'][:price],
            gst_rate_snapshot:   sell_prices['PULSE-TOOR-1KG'][:gst],
            hsn_code_snapshot:   sell_prices['PULSE-TOOR-1KG'][:hsn],
          },
          {
            product_id:          products['SUGAR-REF-1KG'].id,
            qty_reported:        8,
            condition_reported:  'resalable',
            reason_code:         'customer_refused',
            unit_price_snapshot: sell_prices['SUGAR-REF-1KG'][:price],
            gst_rate_snapshot:   sell_prices['SUGAR-REF-1KG'][:gst],
            hsn_code_snapshot:   sell_prices['SUGAR-REF-1KG'][:hsn],
          },
        ]
      }
    )
    raise "Return QC_COMPLETED create failed: #{r.errors.join(', ')}" unless r.success?
    rr4 = r.return_request
    Returns::Submit.call(actor: admin, return_request: rr4).tap { |s| raise s.errors.join(', ') unless s.success? }
    Returns::StartQc.call(actor: admin, return_request: rr4.reload).tap { |s| raise s.errors.join(', ') unless s.success? }
    Returns::CompleteQc.call(
      actor: admin, return_request: rr4.reload,
      qc_lines: [
        { return_line_id: rr4.lines.find_by!(product: products['PULSE-TOOR-1KG']).id,
          qty_resalable: 5, qty_damaged: 0, qty_expired: 0, condition_final: 'resalable' },
        { return_line_id: rr4.lines.find_by!(product: products['SUGAR-REF-1KG']).id,
          qty_resalable: 7, qty_damaged: 1, qty_expired: 0, condition_final: 'mixed' },
      ]
    ).tap { |s| raise s.errors.join(', ') unless s.success? }
    puts "    [QC_COMPLETED]       #{rr4.reload.return_number} â€“ #{customers['CUST-001'].name} (awaiting CN)"
  end

  # â”€â”€ SCENARIO 5: CREDIT NOTE ISSUED â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  unless rr_exists.('RET-0001-000005')
    r = Returns::CreateDraft.call(
      actor: admin, organization: org, branch: branch,
      params: {
        customer_id: customers['CUST-003'].id,
        source_type: 'manual',
        return_date: Date.current - 14.days,
        notes:       'Damaged Sona Masoori batch; credit note requested.',
        lines: [{
          product_id:          products['RICE-SONA-5KG'].id,
          qty_reported:        4,
          condition_reported:  'damaged',
          reason_code:         'other',
          unit_price_snapshot: sell_prices['RICE-SONA-5KG'][:price],
          gst_rate_snapshot:   sell_prices['RICE-SONA-5KG'][:gst],
          hsn_code_snapshot:   sell_prices['RICE-SONA-5KG'][:hsn],
        }]
      }
    )
    raise "Return CN_ISSUED create failed: #{r.errors.join(', ')}" unless r.success?
    rr5 = r.return_request
    Returns::Submit.call(actor: admin, return_request: rr5).tap { |s| raise s.errors.join(', ') unless s.success? }
    Returns::StartQc.call(actor: admin, return_request: rr5.reload).tap { |s| raise s.errors.join(', ') unless s.success? }
    Returns::CompleteQc.call(
      actor: admin, return_request: rr5.reload,
      qc_lines: [{ return_line_id: rr5.lines.first.id,
                   qty_resalable: 2, qty_damaged: 2, qty_expired: 0, condition_final: 'mixed' }]
    ).tap { |s| raise s.errors.join(', ') unless s.success? }
    cn = CreditNotes::IssueFromReturn.call(
      actor: admin, return_request: rr5.reload,
      notes: 'Credit issued for 2 resalable Sona Masoori 5 kg bags.'
    )
    raise "Credit note issue failed: #{cn.errors.join(', ')}" unless cn.success?
    puts "    [CREDIT_NOTE_ISSUED] #{rr5.reload.return_number} -> #{cn.credit_note.credit_note_number} â€“ #{customers['CUST-003'].name}"
  end

  # â”€â”€ SCENARIO 6: CANCELLED â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  unless rr_exists.('RET-0001-000006')
    r = Returns::CreateDraft.call(
      actor: admin, organization: org, branch: branch,
      params: {
        customer_id: customers['CUST-004'].id,
        source_type: 'manual',
        return_date: Date.current - 2.days,
        notes:       'Return entry created by mistake.',
        lines: [{
          product_id:          products['SALT-CMN-1KG'].id,
          qty_reported:        3,
          condition_reported:  'resalable',
          reason_code:         'other',
          unit_price_snapshot: sell_prices['SALT-CMN-1KG'][:price],
          gst_rate_snapshot:   sell_prices['SALT-CMN-1KG'][:gst],
          hsn_code_snapshot:   sell_prices['SALT-CMN-1KG'][:hsn],
        }]
      }
    )
    raise "Return CANCELLED create failed: #{r.errors.join(', ')}" unless r.success?
    rr6 = r.return_request
    c = Returns::Cancel.call(actor: admin, return_request: rr6, reason: 'Created by mistake â€“ wrong customer selected.')
    raise "Return CANCELLED cancel failed: #{c.errors.join(', ')}" unless c.success?
    puts "    [CANCELLED]          #{rr6.reload.return_number} â€“ #{customers['CUST-004'].name}"
  end

  puts '  == Returns & credit notes seeded.'
  puts "     Return requests: #{ReturnRequest.where(organization: org).count}"
  puts "     Credit notes:    #{CreditNote.where(organization: org).count}"



  # ── L. Sales Invoices ──────────────────────────────────────────────────────
  puts ''
  puts '  == Seeding sales invoices...'

  inv_exists = ->(num) { SalesInvoice.exists?(organization: org, invoice_number: num) }

  sell_inv_data = [
    { number: 'SI-ARYA-202603-0001', customer_key: 'CUST-001', amount: 1_800.00, tax:   85.71, grand: 1_885.71, days_ago: 25 },
    { number: 'SI-ARYA-202603-0002', customer_key: 'CUST-002', amount: 3_200.00, tax:  152.38, grand: 3_352.38, days_ago: 18 },
    { number: 'SI-ARYA-202603-0003', customer_key: 'CUST-003', amount: 7_500.00, tax:  357.14, grand: 7_857.14, days_ago: 12 },
    { number: 'SI-ARYA-202603-0004', customer_key: 'CUST-004', amount: 1_100.00, tax:   52.38, grand: 1_152.38, days_ago:  5 },
    { number: 'SI-ARYA-202603-0005', customer_key: 'CUST-001', amount: 4_200.00, tax:  200.00, grand: 4_400.00, days_ago:  3 },
  ]

  seed_invoices = {}
  sell_inv_data.each do |d|
    cust = customers[d[:customer_key]]
    unless inv_exists.(d[:number])
      SalesInvoice.create!(
        organization:       org,
        branch:             branch,
        customer:           cust,
        created_by:         admin,
        invoice_number:     d[:number],
        invoice_date:       Date.current - d[:days_ago].days,
        due_date:           Date.current - d[:days_ago].days + cust.credit_days.days,
        status:             'issued',
        subtotal:           d[:amount],
        tax_total:          d[:tax],
        grand_total:        d[:grand],
        outstanding_amount: d[:grand],
        paid_amount:        0,
        currency:           'INR',
        generation_source:  'manual_direct',
        issued_at:          Time.current - d[:days_ago].days
      )
    end
    seed_invoices[d[:number]] = SalesInvoice.find_by!(organization: org, invoice_number: d[:number])
    puts "    Invoice: #{d[:number]} | #{cust.name} | ₹#{d[:grand]}"
  end

  puts '  == Sales invoices seeded.'

  # ── M. Payments & Collections ─────────────────────────────────────────────
  puts ''
  puts '  == Seeding payments & collections...'

  pay_exists = ->(num) { Payment.exists?(organization: org, payment_number: num) }

  # SCENARIO 1: Cash — fully allocates SI-ARYA-202603-0001 for CUST-001
  unless pay_exists.('PAY-ARYA-202603-0001')
    pay1 = Payment.create!(
      organization:   org, branch: branch, customer: customers['CUST-001'],
      created_by:     admin, payment_number: 'PAY-ARYA-202603-0001',
      amount:         1_885.71, payment_mode: 'cash',
      received_date:  Date.current - 20.days, status: 'draft',
      notes:          'Cash collected by sales rep at store.'
    )
    r1 = Payments::ConfirmPaymentService.call(actor: admin, payment: pay1)
    raise "pay1 confirm failed: #{r1.errors.join(', ')}" unless r1.success?
    puts "    [CASH/CONFIRMED]     #{pay1.reload.payment_number} | #{customers['CUST-001'].name} | #{pay1.amount} | fully allocated"
  end

  # SCENARIO 2: Bank Transfer — exceeds outstanding, creates advance for CUST-002
  unless pay_exists.('PAY-ARYA-202603-0002')
    pay2 = Payment.create!(
      organization:     org, branch: branch, customer: customers['CUST-002'],
      created_by:       admin, payment_number: 'PAY-ARYA-202603-0002',
      amount:           5_000.00, payment_mode: 'bank_transfer',
      reference_number: 'NEFT20260315001', received_date: Date.current - 15.days,
      status:           'draft', notes: 'Excess bank transfer; advance created for next invoice.'
    )
    r2 = Payments::ConfirmPaymentService.call(actor: admin, payment: pay2)
    raise "pay2 confirm failed: #{r2.errors.join(', ')}" unless r2.success?
    puts "    [BANK/CONFIRMED]     #{pay2.reload.payment_number} | #{customers['CUST-002'].name} | advance: #{r2.advance_payment&.balance}"
  end

  # SCENARIO 3: UPI — single large invoice fully allocated for CUST-003
  unless pay_exists.('PAY-ARYA-202603-0003')
    pay3 = Payment.create!(
      organization:     org, branch: branch, customer: customers['CUST-003'],
      created_by:       admin, payment_number: 'PAY-ARYA-202603-0003',
      amount:           7_857.14, payment_mode: 'upi',
      reference_number: 'UPI20260320ABC123', received_date: Date.current - 8.days,
      status:           'draft', notes: 'UPI payment via PhonePe.'
    )
    r3 = Payments::ConfirmPaymentService.call(actor: admin, payment: pay3)
    raise "pay3 confirm failed: #{r3.errors.join(', ')}" unless r3.success?
    puts "    [UPI/CONFIRMED]      #{pay3.reload.payment_number} | #{customers['CUST-003'].name} | fully allocated"
  end

  # SCENARIO 4: Partial payment — CUST-001's second invoice (SI-ARYA-202603-0005)
  unless pay_exists.('PAY-ARYA-202603-0004')
    pay4 = Payment.create!(
      organization:  org, branch: branch, customer: customers['CUST-001'],
      created_by:    admin, payment_number: 'PAY-ARYA-202603-0004',
      amount:        2_000.00, payment_mode: 'upi',
      reference_number: 'UPI20260322DEF456', received_date: Date.current - 3.days,
      status:        'draft', notes: 'Partial advance against open invoice.'
    )
    r4 = Payments::ConfirmPaymentService.call(actor: admin, payment: pay4)
    raise "pay4 confirm failed: #{r4.errors.join(', ')}" unless r4.success?
    puts "    [UPI/PARTIAL]        #{pay4.reload.payment_number} | #{customers['CUST-001'].name} | partial allocation"
  end

  # SCENARIO 5: Cheque — confirmed then reversed (cheque bounce) — CUST-004
  unless pay_exists.('PAY-ARYA-202603-0005')
    pay5 = Payment.create!(
      organization:     org, branch: branch, customer: customers['CUST-004'],
      created_by:       admin, payment_number: 'PAY-ARYA-202603-0005',
      amount:           1_152.38, payment_mode: 'cheque',
      reference_number: 'CHQ998877', received_date: Date.current - 6.days,
      status:           'draft', notes: 'Cheque from Sai Traders.'
    )
    rc = Payments::ConfirmPaymentService.call(actor: admin, payment: pay5)
    raise "pay5 confirm failed: #{rc.errors.join(', ')}" unless rc.success?
    rr = Payments::ReversePaymentService.call(
      actor: admin, payment: pay5.reload,
      reason: 'Cheque CHQ998877 returned — insufficient funds.'
    )
    raise "pay5 reversal failed: #{rr.errors.join(', ')}" unless rr.success?
    puts "    [CHEQUE/REVERSED]    #{pay5.reload.payment_number} | #{customers['CUST-004'].name} | bounced"
  end

  # SCENARIO 6: RTGS — draft, awaiting bank confirmation
  unless pay_exists.('PAY-ARYA-202603-0006')
    pay6 = Payment.create!(
      organization:     org, branch: branch, customer: customers['CUST-001'],
      created_by:       admin, payment_number: 'PAY-ARYA-202603-0006',
      amount:           2_400.00, payment_mode: 'rtgs',
      reference_number: 'RTGS20260325XYZ', received_date: Date.current - 1.day,
      status:           'draft', notes: 'RTGS received; awaiting bank confirmation.'
    )
    puts "    [RTGS/DRAFT]         #{pay6.payment_number} | #{customers['CUST-001'].name} | pending confirmation"
  end

  puts '  == Payments & collections seeded.'
  puts "     Payments:         #{Payment.where(organization: org).count}"
  puts "     Allocations:      #{PaymentAllocation.where(payment_id: Payment.where(organization: org).select(:id)).count}"
  puts "     Advance payments: #{AdvancePayment.where(organization: org).count}"



  # ── Beat Planning Seeds ─────────────────────────────────────────────────────
  puts ''
  puts '  -- Beat Planning (SFA) seeding...'

  route1 = Route.where(organization: org).first
  sales_rep = User.joins(:memberships).where(memberships: { organization: org, role: 'member' }).first || admin

  unless Beat.where(organization: org).exists?
    beat1 = Beat.create!(
      organization: org,
      branch:       branch,
      route:        route1,
      created_by:   admin,
      name:         "North Zone Monday Beat",
      code:         "NZ-MON",
      active:       true,
      notes:        "Covers northern market — high-density residential zone."
    )

    beat2 = Beat.create!(
      organization: org,
      branch:       branch,
      route:        route1,
      created_by:   admin,
      name:         "South Zone Wednesday Beat",
      code:         "SZ-WED",
      active:       true,
      notes:        "Commercial district — grocery + pharmacy mix."
    )

    # Schedules: Monday (weekday=0) and Wednesday (weekday=2)
    sched1 = BeatSchedule.create!(
      organization: org,
      branch:       branch,
      beat:         beat1,
      sales_rep:    sales_rep,
      weekday:      0,
      active:       true
    )

    sched2 = BeatSchedule.create!(
      organization: org,
      branch:       branch,
      beat:         beat2,
      sales_rep:    sales_rep,
      weekday:      2,
      active:       true
    )

    # Add first 3 customers as beat retailers
    org_customers = Customer.active.where(organization: org).limit(3).to_a
    org_customers.each_with_index do |cust, idx|
      BeatRetailer.create!(
        beat_schedule:   sched1,
        customer:        cust,
        sequence_number: idx + 1,
        visit_override:  'default'
      )
    end

    # Add sample visit logs
    if org_customers.any?
      VisitLog.create!(
        organization:     org,
        branch:           branch,
        sales_rep:        sales_rep,
        customer:         org_customers.first,
        route:            route1,
        beat_schedule:    sched1,
        visit_date:       Date.current - 1,
        checkin_at:       Time.current - 1.day - 2.hours,
        checkout_at:      Time.current - 1.day - 1.hour,
        visit_status:     'completed',
        gps_lat:          28.6139,
        gps_lng:          77.2090
      )

      VisitLog.create!(
        organization:     org,
        branch:           branch,
        sales_rep:        sales_rep,
        customer:         org_customers.second || org_customers.first,
        route:            route1,
        beat_schedule:    sched1,
        visit_date:       Date.current - 1,
        visit_status:     'skipped',
        skip_reason_code: 'shop_closed'
      )
    end

    puts "    Beats:          #{Beat.where(organization: org).count}"
    puts "    Beat Schedules: #{BeatSchedule.where(organization: org).count}"
    puts "    Beat Retailers: #{BeatRetailer.where(beat_schedule: BeatSchedule.where(organization: org)).count}"
    puts "    Visit Logs:     #{VisitLog.where(organization: org).count}"
    puts '  == Beat planning seeded.'
  else
    puts '  -- Beats already seeded, skipping.'
  end

  puts ''
  puts '  ┌─ Dev login credentials ────────────────'
  puts "  │  POST /api/v1/auth/login"
  puts "  │  email:    admin@riceoms.dev"
  puts "  │  password: Password@123"
  puts "  │  X-Organization-Id: #{org.id}"
  puts '  └────────────────────────────────────────'
end
