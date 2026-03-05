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

  puts ''
  puts '  ┌─ Dev login credentials ────────────────'
  puts "  │  POST /api/v1/auth/login"
  puts "  │  email:    admin@riceoms.dev"
  puts "  │  password: Password@123"
  puts "  │  X-Organization-Id: #{org.id}"
  puts '  └────────────────────────────────────────'
end
