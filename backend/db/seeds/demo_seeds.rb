# frozen_string_literal: true
#
# Demo seed data for OrdWave — Kannan Rice Distributors
# Idempotent: safe to re-run. Uses find_or_initialize_by throughout.
#
# Usage:
#   rails runner db/seeds/demo_seeds.rb
#   OR add to seeds.rb:  load File.join(__dir__, 'seeds/demo_seeds.rb') if Rails.env.development?

puts ""
puts "=" * 60
puts "  OrdWave — Demo Seed: Kannan Rice Distributors"
puts "=" * 60
puts ""

# ── Helpers ────────────────────────────────────────────────────────────────────

def demo_password = "demo1234"

def upsert(model, find_by, attrs)
  rec = model.find_or_initialize_by(find_by)
  rec.assign_attributes(attrs)
  rec.save!
  rec
end

# ── 1. Organization & Branches ─────────────────────────────────────────────────
puts "== [1/12] Organization & Branches..."

org = upsert(Organization, { slug: "kannan-rice" }, {
  name:          "Kannan Rice Distributors",
  plan:          "growth",
  active:        true,
  city:          "Chennai",
  state:         "Tamil Nadu",
  contact_email: "ops@kannanrice.demo"
})
puts "  Org: #{org.name} (id: #{org.id})"

branch_chennai = upsert(Branch, { code: "KRD-CHN", organization: org }, {
  name:   "Chennai Main",
  city:   "Chennai",
  state:  "Tamil Nadu",
  active: true
})

branch_cbe = upsert(Branch, { code: "KRD-CBE", organization: org }, {
  name:   "Coimbatore Branch",
  city:   "Coimbatore",
  state:  "Tamil Nadu",
  active: true
})

puts "  Branches: #{branch_chennai.name}, #{branch_cbe.name}"
branch = branch_chennai  # default branch

# ── 2. Team Members ────────────────────────────────────────────────────────────
puts ""
puts "== [2/12] Team Members..."

role = ->(name) { Role.find_by!(name: name) }

team_defs = [
  { email: "kannan@demo.orderlanepro.dev",  first: "Kannan",  last: "Rajan",    role: "owner",           branch: branch_chennai },
  { email: "priya@demo.orderlanepro.dev",   first: "Priya",   last: "Murugan",  role: "admin",           branch: branch_chennai },
  { email: "senthil@demo.orderlanepro.dev", first: "Senthil", last: "Kumar",    role: "manager",         branch: branch_chennai },
  { email: "rajan@demo.orderlanepro.dev",   first: "Rajan",   last: "Perumal",  role: "sales_rep",       branch: branch_chennai },
  { email: "kumar@demo.orderlanepro.dev",   first: "Kumar",   last: "Selvam",   role: "warehouse_staff", branch: branch_chennai },
  { email: "lakshmi@demo.orderlanepro.dev", first: "Lakshmi", last: "Venkat",   role: "accountant",      branch: branch_chennai },
  { email: "muthu@demo.orderlanepro.dev",   first: "Muthu",   last: "Arumugam", role: "driver",          branch: branch_chennai },
]

team = {}
team_defs.each do |d|
  u = User.find_or_initialize_by(email: d[:email])
  u.assign_attributes(first_name: d[:first], last_name: d[:last], active: true, plan: "growth")
  u.password = demo_password if u.new_record? || u.encrypted_password.blank?
  u.save!

  unless Membership.exists?(user: u, organization: org, branch: d[:branch])
    Membership.create!(user: u, organization: org, branch: d[:branch], role: role.(d[:role]), active: true)
  end

  team[d[:role]] = u
  puts "  #{d[:role].ljust(18)} #{u.email}"
end

kannan  = team["owner"]
rajan   = team["sales_rep"]
senthil = team["manager"]
muthu   = team["driver"]
kumar   = team["warehouse_staff"]
lakshmi = team["accountant"]

# ── 3. Product Categories ──────────────────────────────────────────────────────
puts ""
puts "== [3/12] Product Categories..."

cat_defs = [
  { code: "DEMO-RICE",   name: "Rice & Cereals"    },
  { code: "DEMO-PULSES", name: "Pulses & Dals"     },
  { code: "DEMO-OILS",   name: "Edible Oils"       },
  { code: "DEMO-SPICES", name: "Spices & Masalas"  },
  { code: "DEMO-MISC",   name: "Miscellaneous"     },
]

cats = {}
cat_defs.each do |d|
  c = upsert(ProductCategory, { code: d[:code], organization: org }, { name: d[:name], active: true })
  cats[d[:code]] = c
  puts "  #{c.name}"
end

# ── 4. Products (50) ──────────────────────────────────────────────────────────
puts ""
puts "== [4/12] Products..."

uom_kg  = UnitsOfMeasure.find_by!(symbol: "KG")
uom_ltr = UnitsOfMeasure.find_by!(symbol: "LTR")
uom_pcs = UnitsOfMeasure.find_by(symbol: "PCS") || uom_kg

hsn_rice   = HsnSacCode.find_by!(code: "10061090")
hsn_pulse  = HsnSacCode.find_by!(code: "07134000")
hsn_oil    = HsnSacCode.find_by!(code: "15121990")
hsn_spice  = HsnSacCode.find_by!(code: "09042210")
hsn_misc   = HsnSacCode.find_by!(code: "25010010")

product_defs = [
  # ── Rice (15 SKUs) ──
  { sku: "KRD-PONNI-RAW-5",   name: "Ponni Raw Rice (5 kg)",        cat: "DEMO-RICE",   uom: uom_kg,  hsn: hsn_rice,  pp: 180,  sp: 235  },
  { sku: "KRD-PONNI-RAW-10",  name: "Ponni Raw Rice (10 kg)",       cat: "DEMO-RICE",   uom: uom_kg,  hsn: hsn_rice,  pp: 345,  sp: 450  },
  { sku: "KRD-PONNI-RAW-25",  name: "Ponni Raw Rice (25 kg)",       cat: "DEMO-RICE",   uom: uom_kg,  hsn: hsn_rice,  pp: 830,  sp: 1080 },
  { sku: "KRD-SONA-5",        name: "Sona Masuri Rice (5 kg)",      cat: "DEMO-RICE",   uom: uom_kg,  hsn: hsn_rice,  pp: 220,  sp: 285  },
  { sku: "KRD-SONA-10",       name: "Sona Masuri Rice (10 kg)",     cat: "DEMO-RICE",   uom: uom_kg,  hsn: hsn_rice,  pp: 420,  sp: 545  },
  { sku: "KRD-SONA-25",       name: "Sona Masuri Rice (25 kg)",     cat: "DEMO-RICE",   uom: uom_kg,  hsn: hsn_rice,  pp: 1000, sp: 1300 },
  { sku: "KRD-BSMT-5",        name: "Basmati Rice (5 kg)",          cat: "DEMO-RICE",   uom: uom_kg,  hsn: hsn_rice,  pp: 320,  sp: 420  },
  { sku: "KRD-BSMT-25",       name: "Basmati Rice (25 kg)",         cat: "DEMO-RICE",   uom: uom_kg,  hsn: hsn_rice,  pp: 1500, sp: 1950 },
  { sku: "KRD-KOLAM-5",       name: "Kolam Rice (5 kg)",            cat: "DEMO-RICE",   uom: uom_kg,  hsn: hsn_rice,  pp: 195,  sp: 255  },
  { sku: "KRD-KOLAM-25",      name: "Kolam Rice (25 kg)",           cat: "DEMO-RICE",   uom: uom_kg,  hsn: hsn_rice,  pp: 920,  sp: 1200 },
  { sku: "KRD-ROSEMATA-25",   name: "Rosematta Rice (25 kg)",       cat: "DEMO-RICE",   uom: uom_kg,  hsn: hsn_rice,  pp: 950,  sp: 1240 },
  { sku: "KRD-IDLI-25",       name: "Idli Rice (25 kg)",            cat: "DEMO-RICE",   uom: uom_kg,  hsn: hsn_rice,  pp: 780,  sp: 1015 },
  { sku: "KRD-BOILED-5",      name: "Boiled Rice (5 kg)",           cat: "DEMO-RICE",   uom: uom_kg,  hsn: hsn_rice,  pp: 165,  sp: 215  },
  { sku: "KRD-BOILED-25",     name: "Boiled Rice (25 kg)",          cat: "DEMO-RICE",   uom: uom_kg,  hsn: hsn_rice,  pp: 800,  sp: 1040 },
  { sku: "KRD-SURTI-25",      name: "Surti Kolam Rice (25 kg)",     cat: "DEMO-RICE",   uom: uom_kg,  hsn: hsn_rice,  pp: 870,  sp: 1130 },
  # ── Dals / Pulses (10 SKUs) ──
  { sku: "KRD-TOOR-1",        name: "Toor Dal (1 kg)",              cat: "DEMO-PULSES", uom: uom_kg,  hsn: hsn_pulse, pp: 140,  sp: 175  },
  { sku: "KRD-TOOR-5",        name: "Toor Dal (5 kg)",              cat: "DEMO-PULSES", uom: uom_kg,  hsn: hsn_pulse, pp: 680,  sp: 860  },
  { sku: "KRD-URAD-1",        name: "Urad Dal (1 kg)",              cat: "DEMO-PULSES", uom: uom_kg,  hsn: hsn_pulse, pp: 155,  sp: 195  },
  { sku: "KRD-URAD-5",        name: "Urad Dal (5 kg)",              cat: "DEMO-PULSES", uom: uom_kg,  hsn: hsn_pulse, pp: 745,  sp: 950  },
  { sku: "KRD-MOONG-1",       name: "Moong Dal (1 kg)",             cat: "DEMO-PULSES", uom: uom_kg,  hsn: hsn_pulse, pp: 135,  sp: 170  },
  { sku: "KRD-CHANA-1",       name: "Chana Dal (1 kg)",             cat: "DEMO-PULSES", uom: uom_kg,  hsn: hsn_pulse, pp: 98,   sp: 128  },
  { sku: "KRD-MASOOR-1",      name: "Masoor Dal (1 kg)",            cat: "DEMO-PULSES", uom: uom_kg,  hsn: hsn_pulse, pp: 105,  sp: 135  },
  { sku: "KRD-RAJMA-1",       name: "Rajma (1 kg)",                 cat: "DEMO-PULSES", uom: uom_kg,  hsn: hsn_pulse, pp: 145,  sp: 185  },
  { sku: "KRD-KABULI-1",      name: "Kabuli Chana (1 kg)",          cat: "DEMO-PULSES", uom: uom_kg,  hsn: hsn_pulse, pp: 130,  sp: 165  },
  { sku: "KRD-HORSEGRAM-1",   name: "Horse Gram (1 kg)",            cat: "DEMO-PULSES", uom: uom_kg,  hsn: hsn_pulse, pp: 80,   sp: 105  },
  # ── Oils (10 SKUs) ──
  { sku: "KRD-SUNFLWR-1L",    name: "Sunflower Oil (1 L)",          cat: "DEMO-OILS",   uom: uom_ltr, hsn: hsn_oil,   pp: 145,  sp: 185  },
  { sku: "KRD-SUNFLWR-5L",    name: "Sunflower Oil (5 L)",          cat: "DEMO-OILS",   uom: uom_ltr, hsn: hsn_oil,   pp: 690,  sp: 875  },
  { sku: "KRD-COCONUT-1L",    name: "Coconut Oil (1 L)",            cat: "DEMO-OILS",   uom: uom_ltr, hsn: hsn_oil,   pp: 185,  sp: 240  },
  { sku: "KRD-COCONUT-5L",    name: "Coconut Oil (5 L)",            cat: "DEMO-OILS",   uom: uom_ltr, hsn: hsn_oil,   pp: 900,  sp: 1170 },
  { sku: "KRD-GRNDNT-1L",     name: "Groundnut Oil (1 L)",          cat: "DEMO-OILS",   uom: uom_ltr, hsn: hsn_oil,   pp: 195,  sp: 255  },
  { sku: "KRD-GRNDNT-5L",     name: "Groundnut Oil (5 L)",          cat: "DEMO-OILS",   uom: uom_ltr, hsn: hsn_oil,   pp: 950,  sp: 1235 },
  { sku: "KRD-MUSTARD-1L",    name: "Mustard Oil (1 L)",            cat: "DEMO-OILS",   uom: uom_ltr, hsn: hsn_oil,   pp: 165,  sp: 215  },
  { sku: "KRD-PALM-5L",       name: "Palm Oil (5 L)",               cat: "DEMO-OILS",   uom: uom_ltr, hsn: hsn_oil,   pp: 620,  sp: 805  },
  { sku: "KRD-SESAME-1L",     name: "Sesame Oil (1 L)",             cat: "DEMO-OILS",   uom: uom_ltr, hsn: hsn_oil,   pp: 220,  sp: 285  },
  { sku: "KRD-RICEBRAN-5L",   name: "Rice Bran Oil (5 L)",          cat: "DEMO-OILS",   uom: uom_ltr, hsn: hsn_oil,   pp: 680,  sp: 880  },
  # ── Spices (10 SKUs) ──
  { sku: "KRD-CHILLI-100G",   name: "Chilli Powder (100 g)",        cat: "DEMO-SPICES", uom: uom_kg,  hsn: hsn_spice, pp: 28,   sp: 38   },
  { sku: "KRD-TURMERIC-100G", name: "Turmeric Powder (100 g)",      cat: "DEMO-SPICES", uom: uom_kg,  hsn: hsn_spice, pp: 22,   sp: 32   },
  { sku: "KRD-CORIANDER-100G",name: "Coriander Powder (100 g)",     cat: "DEMO-SPICES", uom: uom_kg,  hsn: hsn_spice, pp: 18,   sp: 28   },
  { sku: "KRD-PEPPER-100G",   name: "Black Pepper (100 g)",         cat: "DEMO-SPICES", uom: uom_kg,  hsn: hsn_spice, pp: 45,   sp: 60   },
  { sku: "KRD-CUMIN-100G",    name: "Cumin Seeds (100 g)",          cat: "DEMO-SPICES", uom: uom_kg,  hsn: hsn_spice, pp: 35,   sp: 48   },
  { sku: "KRD-SAMBAR-200G",   name: "Sambar Powder (200 g)",        cat: "DEMO-SPICES", uom: uom_kg,  hsn: hsn_spice, pp: 42,   sp: 58   },
  { sku: "KRD-RASAM-200G",    name: "Rasam Powder (200 g)",         cat: "DEMO-SPICES", uom: uom_kg,  hsn: hsn_spice, pp: 38,   sp: 52   },
  { sku: "KRD-GARAM-100G",    name: "Garam Masala (100 g)",         cat: "DEMO-SPICES", uom: uom_kg,  hsn: hsn_spice, pp: 50,   sp: 68   },
  { sku: "KRD-SALT-1",        name: "Iodised Salt (1 kg)",          cat: "DEMO-SPICES", uom: uom_kg,  hsn: hsn_misc,  pp: 16,   sp: 22   },
  { sku: "KRD-TAMARIND-200G", name: "Tamarind (200 g)",             cat: "DEMO-SPICES", uom: uom_kg,  hsn: hsn_spice, pp: 24,   sp: 34   },
  # ── Miscellaneous (5 SKUs) ──
  { sku: "KRD-SUGAR-1",       name: "Refined Sugar (1 kg)",         cat: "DEMO-MISC",   uom: uom_kg,  hsn: hsn_misc,  pp: 45,   sp: 58   },
  { sku: "KRD-JAGGERY-1",     name: "Jaggery (1 kg)",               cat: "DEMO-MISC",   uom: uom_kg,  hsn: hsn_misc,  pp: 55,   sp: 72   },
  { sku: "KRD-POHA-500G",     name: "Poha (500 g)",                 cat: "DEMO-MISC",   uom: uom_kg,  hsn: hsn_misc,  pp: 30,   sp: 42   },
  { sku: "KRD-RAVA-500G",     name: "Semolina / Rava (500 g)",      cat: "DEMO-MISC",   uom: uom_kg,  hsn: hsn_misc,  pp: 28,   sp: 38   },
  { sku: "KRD-VERMICELLI-200G",name: "Roasted Vermicelli (200 g)",  cat: "DEMO-MISC",   uom: uom_pcs, hsn: hsn_misc,  pp: 22,   sp: 32   },
]

products = {}
product_defs.each do |d|
  p = upsert(Product, { sku: d[:sku], organization: org }, {
    name:             d[:name],
    product_category: cats[d[:cat]],
    units_of_measure: d[:uom],
    hsn_sac_code:     d[:hsn],
    purchase_price:   d[:pp],
    min_order_qty:    1,
    status:           "active"
  })
  products[d[:sku]] = p
end
puts "  #{products.size} products seeded."

# ── 5. Price Lists (3) ────────────────────────────────────────────────────────
puts ""
puts "== [5/12] Price Lists..."

std_list = upsert(PriceList, { organization: org, name: "Standard Price List", list_type: "standard" }, {
  branch: nil, status: "active", deleted_at: nil
})

wholesale_list = upsert(PriceList, { organization: org, name: "Wholesale Discount (10%)", list_type: "wholesale" }, {
  branch: nil, status: "active", deleted_at: nil
})

festival_list = upsert(PriceList, { organization: org, name: "Festival Special (15%)", list_type: "promo" }, {
  branch: nil, status: "active",
  valid_from: Date.current,
  valid_to:   Date.current + 45.days,
  deleted_at: nil
})

product_defs.each do |d|
  prod = products[d[:sku]]
  # Standard
  upsert(PriceListItem, { price_list: std_list, product: prod, min_qty: nil }, {
    unit_price: d[:sp], discount_pct: 0
  })
  # Wholesale (10% off)
  upsert(PriceListItem, { price_list: wholesale_list, product: prod, min_qty: nil }, {
    unit_price: d[:sp], discount_pct: 10
  })
  # Festival (15% off)
  upsert(PriceListItem, { price_list: festival_list, product: prod, min_qty: nil }, {
    unit_price: d[:sp], discount_pct: 15
  })
end
puts "  3 price lists seeded with #{products.size} items each."

# ── 6. Customers (30) ─────────────────────────────────────────────────────────
puts ""
puts "== [6/12] Customers (30)..."

customer_defs = [
  # Kiranas — Tier A (3)
  { code: "KRD-C001", name: "Sri Lakshmi Stores",          channel: "general_trade", tier: "gold",     type: "retailer",     credit_limit: 150_000, credit_days: 30, status: "active",   overdue: 0         },
  { code: "KRD-C002", name: "Murugan Provision Store",     channel: "general_trade", tier: "gold",     type: "retailer",     credit_limit: 120_000, credit_days: 30, status: "active",   overdue: 0         },
  { code: "KRD-C003", name: "Annapoorna General Stores",   channel: "general_trade", tier: "platinum", type: "retailer",     credit_limit: 200_000, credit_days: 45, status: "active",   overdue: 0         },
  # Kiranas — Tier B (5)
  { code: "KRD-C004", name: "Ravi Provision Mart",         channel: "general_trade", tier: "silver",   type: "retailer",     credit_limit: 75_000,  credit_days: 21, status: "active",   overdue: 12_000    },
  { code: "KRD-C005", name: "Karthik Rice Centre",         channel: "general_trade", tier: "silver",   type: "retailer",     credit_limit: 80_000,  credit_days: 21, status: "active",   overdue: 0         },
  { code: "KRD-C006", name: "Vel Murugan Stores",          channel: "general_trade", tier: "silver",   type: "retailer",     credit_limit: 60_000,  credit_days: 21, status: "active",   overdue: 18_500    },
  { code: "KRD-C007", name: "Senthil Provision Store",     channel: "general_trade", tier: "silver",   type: "retailer",     credit_limit: 65_000,  credit_days: 21, status: "active",   overdue: 0         },
  { code: "KRD-C008", name: "Balaji General Merchant",     channel: "general_trade", tier: "silver",   type: "retailer",     credit_limit: 70_000,  credit_days: 21, status: "active",   overdue: 8_200     },
  # Kiranas — Tier C (2)
  { code: "KRD-C009", name: "Ganesha Kirana Shop",         channel: "general_trade", tier: "bronze",   type: "retailer",     credit_limit: 25_000,  credit_days: 14, status: "active",   overdue: 4_500     },
  { code: "KRD-C010", name: "Thiruvenkatam Provision",     channel: "general_trade", tier: "bronze",   type: "retailer",     credit_limit: 30_000,  credit_days: 14, status: "active",   overdue: 0         },
  # Supermarkets — Tier A (5)
  { code: "KRD-C011", name: "A1 Supermarket",              channel: "modern_trade",  tier: "platinum", type: "retailer",     credit_limit: 500_000, credit_days: 45, status: "active",   overdue: 0         },
  { code: "KRD-C012", name: "Family Mart Chennai",         channel: "modern_trade",  tier: "platinum", type: "retailer",     credit_limit: 400_000, credit_days: 45, status: "active",   overdue: 0         },
  { code: "KRD-C013", name: "Metro Superstore",            channel: "modern_trade",  tier: "gold",     type: "retailer",     credit_limit: 300_000, credit_days: 45, status: "active",   overdue: 0         },
  { code: "KRD-C014", name: "Star Bazaar Adyar",           channel: "modern_trade",  tier: "gold",     type: "retailer",     credit_limit: 350_000, credit_days: 45, status: "active",   overdue: 0         },
  { code: "KRD-C015", name: "Nilgiri's T.Nagar",           channel: "modern_trade",  tier: "gold",     type: "retailer",     credit_limit: 280_000, credit_days: 45, status: "active",   overdue: 0         },
  # Supermarkets — Tier B (3)
  { code: "KRD-C016", name: "Mega Mart Anna Nagar",        channel: "modern_trade",  tier: "silver",   type: "retailer",     credit_limit: 180_000, credit_days: 30, status: "active",   overdue: 0         },
  { code: "KRD-C017", name: "Big Day Supermarket",         channel: "modern_trade",  tier: "silver",   type: "retailer",     credit_limit: 160_000, credit_days: 30, status: "active",   overdue: 22_000    },
  { code: "KRD-C018", name: "Saravana Stores Grocery",     channel: "modern_trade",  tier: "silver",   type: "retailer",     credit_limit: 150_000, credit_days: 30, status: "active",   overdue: 0         },
  # Wholesale (5)
  { code: "KRD-C019", name: "Murugan Traders Wholesale",   channel: "wholesale",     tier: "gold",     type: "wholesaler",   credit_limit: 5_00_000, credit_days: 60, status: "active",  overdue: 45_000    },
  { code: "KRD-C020", name: "Sri Ganesh Rice Wholesale",   channel: "wholesale",     tier: "gold",     type: "wholesaler",   credit_limit: 4_00_000, credit_days: 60, status: "active",  overdue: 0         },
  { code: "KRD-C021", name: "Chennai Distributors",        channel: "wholesale",     tier: "silver",   type: "distributor",  credit_limit: 3_00_000, credit_days: 45, status: "active",  overdue: 0         },
  { code: "KRD-C022", name: "Tamil Nadu Traders",          channel: "wholesale",     tier: "silver",   type: "wholesaler",   credit_limit: 2_50_000, credit_days: 45, status: "blocked",  overdue: 67_500    },
  { code: "KRD-C023", name: "Kovai Wholesale Centre",      channel: "wholesale",     tier: "silver",   type: "wholesaler",   credit_limit: 2_00_000, credit_days: 45, status: "active",  overdue: 0         },
  # Hotels / Restaurants (4)
  { code: "KRD-C024", name: "Hotel Saravana Bhavan",       channel: "horeca",        tier: "gold",     type: "horeca",       credit_limit: 80_000,  credit_days: 21, status: "active",   overdue: 0         },
  { code: "KRD-C025", name: "Murugan Idli Shop",           channel: "horeca",        tier: "silver",   type: "horeca",       credit_limit: 40_000,  credit_days: 14, status: "active",   overdue: 0         },
  { code: "KRD-C026", name: "Vasantha Vilas Hotel",        channel: "horeca",        tier: "silver",   type: "horeca",       credit_limit: 50_000,  credit_days: 14, status: "blocked",  overdue: 31_000    },
  { code: "KRD-C027", name: "Royal Biriyani Centre",       channel: "horeca",        tier: "bronze",   type: "horeca",       credit_limit: 30_000,  credit_days: 14, status: "active",   overdue: 3_200     },
  # Institutional (3)
  { code: "KRD-C028", name: "Chennai Corp. Mid-Day Meals", channel: "wholesale",     tier: "platinum", type: "institution",  credit_limit: 5_00_000, credit_days: 60, status: "active",  overdue: 0         },
  { code: "KRD-C029", name: "St. Xavier's College Mess",   channel: "wholesale",     tier: "gold",     type: "institution",  credit_limit: 1_50_000, credit_days: 45, status: "active",  overdue: 0         },
  { code: "KRD-C030", name: "Government Hospital Canteen", channel: "wholesale",     tier: "gold",     type: "institution",  credit_limit: 2_00_000, credit_days: 45, status: "active",  overdue: 0         },
]

customers = {}
customer_defs.each do |d|
  cust = upsert(Customer, { code: d[:code], organization: org }, {
    name:           d[:name],
    branch:         branch,
    channel:        d[:channel],
    tier:           d[:tier],
    customer_type:  d[:type],
    status:         d[:status],
    credit_days:    d[:credit_days],
    sales_rep:      rajan,
    visit_frequency: "weekly",
    credit_block_rule: d[:status] == "blocked" ? "hard_block" : "none"
  })

  ca = CreditAccount.find_or_initialize_by(customer: cust, organization: org)
  ca.assign_attributes(
    credit_limit:      d[:credit_limit],
    current_balance:   d[:overdue] > 0 ? d[:overdue] + rand(5_000..25_000) : rand(0..15_000),
    overdue_amount:    d[:overdue],
    available_credit:  [d[:credit_limit] - (d[:overdue] > 0 ? d[:overdue] + rand(5_000..25_000) : rand(0..15_000)), 0].max,
    credit_status:     d[:status] == "blocked" ? "blocked" : (d[:overdue] > 20_000 ? "overdue" : "ok"),
    currency:          "INR"
  )
  ca.save!

  customers[d[:code]] = cust
  print "."
end
puts ""
puts "  #{customers.size} customers seeded with credit accounts."

# ── 7. Sales Orders (50) ─────────────────────────────────────────────────────
puts ""
puts "== [7/12] Sales Orders (50)..."

order_scenarios = [
  # status,       customer_key,  days_ago, amount
  ["delivered",   "KRD-C001",   28, 22_500],
  ["delivered",   "KRD-C002",   26, 14_800],
  ["delivered",   "KRD-C011",   25, 85_400],
  ["delivered",   "KRD-C019",   24, 1_25_000],
  ["delivered",   "KRD-C003",   22, 31_600],
  ["delivered",   "KRD-C012",   20, 72_300],
  ["delivered",   "KRD-C020",   19, 96_500],
  ["delivered",   "KRD-C028",   18, 2_40_000],
  ["delivered",   "KRD-C024",   17, 18_700],
  ["delivered",   "KRD-C015",   16, 61_200],
  ["dispatched",  "KRD-C013",   10,  88_000],
  ["dispatched",  "KRD-C004",    9,  26_400],
  ["dispatched",  "KRD-C029",    8, 1_15_000],
  ["dispatched",  "KRD-C005",    7,  19_800],
  ["dispatched",  "KRD-C023",    6,  78_500],
  ["dispatched",  "KRD-C025",    5,  12_600],
  ["dispatched",  "KRD-C014",    4,  54_300],
  ["dispatched",  "KRD-C030",    3, 1_30_000],
  ["approved",    "KRD-C016",    5,  61_000],
  ["approved",    "KRD-C001",    4,  35_500],
  ["approved",    "KRD-C011",    4, 1_20_000],
  ["approved",    "KRD-C006",    3,  22_800],
  ["approved",    "KRD-C003",    3,  48_000],
  ["approved",    "KRD-C018",    2,  55_600],
  ["approved",    "KRD-C007",    2,  31_200],
  ["approved",    "KRD-C017",    2,  44_800],
  ["approved",    "KRD-C008",    1,  28_400],
  ["approved",    "KRD-C012",    1,  91_500],
  ["approved",    "KRD-C002",    1,  24_600],
  ["approved",    "KRD-C010",    1,  16_200],
  ["on_hold",     "KRD-C019",    3, 1_50_000],
  ["on_hold",     "KRD-C026",    2,  45_000],
  ["on_hold",     "KRD-C022",    2, 2_00_000],
  ["on_hold",     "KRD-C006",    1,  38_000],
  ["on_hold",     "KRD-C008",    1,  21_600],
  ["submitted",   "KRD-C013",    2, 1_05_000],
  ["submitted",   "KRD-C001",    2,  28_000],
  ["submitted",   "KRD-C015",    1,  74_500],
  ["submitted",   "KRD-C009",    1,  11_800],
  ["submitted",   "KRD-C004",    1,  32_400],
  ["submitted",   "KRD-C024",    0,  22_000],
  ["submitted",   "KRD-C005",    0,  17_500],
  ["submitted",   "KRD-C016",    0,  68_000],
  ["submitted",   "KRD-C029",    0, 1_10_000],
  ["submitted",   "KRD-C030",    0, 1_85_000],
  ["draft",       "KRD-C011",    0, 96_000],
  ["draft",       "KRD-C020",    0, 1_40_000],
  ["draft",       "KRD-C003",    0, 55_000],
  ["draft",       "KRD-C002",    0, 22_500],
  ["draft",       "KRD-C007",    0, 19_800],
]

orders = []
order_scenarios.each_with_index do |(status, cust_key, days_ago, amount), i|
  num = "KRD-ORD-2026%04d" % (i + 1)
  next if SalesOrder.exists?(organization: org, order_number: num)

  cust = customers[cust_key]
  ord = SalesOrder.create!(
    organization: org,
    branch:       branch,
    customer:     cust,
    created_by:   rajan,
    order_number: num,
    status:       status,
    order_date:   Date.current - days_ago.days,
    subtotal:     (amount / 1.05).round(2),
    tax_total:    (amount - amount / 1.05).round(2),
    grand_total:  amount,
    credit_decision: status == "on_hold" ? "hold" : (cust.status == "blocked" ? "blocked" : "ok"),
    cancellation_reason: nil
  )

  # Add at least one order line
  prod = products.values.sample
  SalesOrderLine.find_or_create_by(sales_order: ord, product: prod) do |line|
    line.quantity    = (amount / [prod.purchase_price * 1.3, 1].max).ceil.clamp(1, 50)
    line.unit_price  = prod.purchase_price * 1.3
    line.discount    = 0
    line.tax_rate    = 5
    line.line_total  = line.quantity * line.unit_price
  end

  orders << ord
  print "."
end
puts ""
puts "  #{orders.size} orders created."

# ── 8. Payments (30) ──────────────────────────────────────────────────────────
puts ""
puts "== [8/12] Payments (30)..."

payment_scenarios = [
  ["cash",         "KRD-C001",  25, 22_500,  "confirmed"],
  ["upi",          "KRD-C002",  22, 14_800,  "confirmed"],
  ["cash",         "KRD-C011",  20, 85_400,  "confirmed"],
  ["bank_transfer","KRD-C019",  18, 1_25_000,"confirmed"],
  ["cash",         "KRD-C003",  17, 31_600,  "confirmed"],
  ["upi",          "KRD-C012",  16, 72_300,  "confirmed"],
  ["bank_transfer","KRD-C020",  15, 96_500,  "confirmed"],
  ["cheque",       "KRD-C028",  14, 2_00_000,"confirmed"],
  ["cash",         "KRD-C024",  13, 18_700,  "confirmed"],
  ["upi",          "KRD-C015",  12, 61_200,  "confirmed"],
  ["cash",         "KRD-C004",  10, 26_400,  "confirmed"],
  ["upi",          "KRD-C005",   9, 19_800,  "confirmed"],
  ["cash",         "KRD-C023",   8, 78_500,  "confirmed"],
  ["bank_transfer","KRD-C029",   7, 1_00_000,"confirmed"],
  ["upi",          "KRD-C001",   6, 35_000,  "confirmed"],
  ["cash",         "KRD-C006",   5, 15_000,  "confirmed"],
  ["cheque",       "KRD-C016",   4, 60_000,  "confirmed"],
  ["upi",          "KRD-C030",   4, 1_50_000,"confirmed"],
  ["cash",         "KRD-C007",   3, 25_000,  "confirmed"],
  ["upi",          "KRD-C008",   3, 20_000,  "confirmed"],
  ["bank_transfer","KRD-C028",   3, 2_40_000,"confirmed"],
  ["cash",         "KRD-C014",   2, 50_000,  "confirmed"],
  ["upi",          "KRD-C025",   2, 12_600,  "confirmed"],
  ["cash",         "KRD-C013",   2, 88_000,  "confirmed"],
  ["cheque",       "KRD-C017",   1, 44_800,  "pending"],
  ["upi",          "KRD-C018",   1, 55_600,  "pending"],
  ["cash",         "KRD-C010",   1, 16_200,  "pending"],
  ["bank_transfer","KRD-C021",   0, 90_000,  "draft"],
  ["cash",         "KRD-C027",   0,  8_500,  "draft"],
  ["upi",          "KRD-C009",   0,  4_500,  "draft"],
]

payment_scenarios.each_with_index do |(mode, cust_key, days_ago, amount, status), i|
  num = "KRD-PAY-2026%04d" % (i + 1)
  next if Payment.exists?(organization: org, payment_number: num)

  cust = customers[cust_key]
  Payment.create!(
    organization:   org,
    branch:         branch,
    customer:       cust,
    created_by:     lakshmi,
    payment_number: num,
    amount:         amount,
    payment_mode:   mode,
    received_date:  Date.current - days_ago.days,
    status:         status,
    reference_number: mode.in?(%w[upi bank_transfer cheque]) ? "REF#{SecureRandom.hex(6).upcase}" : nil,
    notes:          "#{mode.humanize} collection — demo data"
  )
  print "."
end
puts ""
puts "  30 payments seeded."

# ── 9. Delivery Vehicles & Trips ──────────────────────────────────────────────
puts ""
puts "== [9/12] Delivery Trips..."

# Vehicle for Muthu
vehicle = upsert(Vehicle, { registration_number: "TN09AB1234", organization: org }, {
  make: "Tata", model: "Ace", vehicle_type: "mini_truck", active: true
})

trip_defs = [
  { ref: "KRD-TRIP-001", days_ago: 10, status: "completed",   stops_count: 5 },
  { ref: "KRD-TRIP-002", days_ago: 7,  status: "completed",   stops_count: 4 },
  { ref: "KRD-TRIP-003", days_ago: 3,  status: "completed",   stops_count: 6 },
  { ref: "KRD-TRIP-004", days_ago: 1,  status: "in_progress", stops_count: 4 },
  { ref: "KRD-TRIP-005", days_ago: 1,  status: "in_progress", stops_count: 3 },
  { ref: "KRD-TRIP-006", days_ago: 0,  status: "planned",     stops_count: 5 },
  { ref: "KRD-TRIP-007", days_ago: 0,  status: "planned",     stops_count: 4 },
  { ref: "KRD-TRIP-008", days_ago: 0,  status: "planned",     stops_count: 3 },
  { ref: "KRD-TRIP-009", days_ago: -1, status: "draft",       stops_count: 5 },
  { ref: "KRD-TRIP-010", days_ago: -2, status: "draft",       stops_count: 4 },
]

trip_defs.each do |d|
  next if DeliveryTrip.exists?(organization: org, trip_reference: d[:ref])

  trip = DeliveryTrip.create!(
    organization:    org,
    branch:          branch,
    driver:          muthu,
    vehicle:         vehicle,
    trip_reference:  d[:ref],
    status:          d[:status],
    scheduled_date:  Date.current - d[:days_ago].days,
    created_by:      kumar
  )

  d[:stops_count].times do |j|
    cust_key = customer_defs.map { |c| c[:code] }.sample
    TripStop.find_or_create_by(delivery_trip: trip, sequence: j + 1) do |s|
      s.customer = customers[cust_key]
      s.status   = d[:status] == "completed" ? "delivered" : "pending"
      s.organization = org
    end
  end
  print "."
end
puts ""
puts "  #{trip_defs.size} trips seeded."

# ── 10. Beat Schedules ────────────────────────────────────────────────────────
puts ""
puts "== [10/12] Beat Schedules..."

beat_defs = [
  { name: "Chennai North Beat",  day: "monday",    customers: %w[KRD-C001 KRD-C002 KRD-C003 KRD-C009] },
  { name: "Chennai South Beat",  day: "tuesday",   customers: %w[KRD-C004 KRD-C005 KRD-C006 KRD-C010] },
  { name: "T.Nagar Beat",        day: "wednesday", customers: %w[KRD-C011 KRD-C012 KRD-C016 KRD-C024 KRD-C025] },
  { name: "Wholesale Beat",      day: "thursday",  customers: %w[KRD-C019 KRD-C020 KRD-C021 KRD-C023] },
  { name: "Institutional Beat",  day: "friday",    customers: %w[KRD-C028 KRD-C029 KRD-C030] },
]

beat_defs.each do |d|
  beat = upsert(Beat, { name: d[:name], organization: org }, {
    branch:     branch,
    day_of_week: d[:day],
    active:     true,
    sales_rep:  rajan
  })

  d[:customers].each_with_index do |cust_key, seq|
    BeatRetailer.find_or_create_by(beat: beat, customer: customers[cust_key]) do |br|
      br.sequence    = seq + 1
      br.active      = true
    end
  end
  print "."
end
puts ""
puts "  5 beat schedules seeded."

# ── 11. Notifications (20) ────────────────────────────────────────────────────
puts ""
puts "== [11/12] Notifications (20)..."

notification_defs = [
  { title: "Order Approved",          body: "Order KRD-ORD-2026-0019 has been approved — ₹61,000",    recipient: rajan,   notif_type: "order_approved"     },
  { title: "Payment Confirmed",       body: "Payment KRD-PAY-2026-0001 confirmed — ₹22,500 cash",     recipient: lakshmi, notif_type: "payment_confirmed"  },
  { title: "3 Orders Awaiting Approval", body: "Review pending orders in your inbox",                 recipient: senthil, notif_type: "approval_required"  },
  { title: "Credit Limit Request",    body: "Sri Ganesh: increase from ₹4L to ₹5L",                  recipient: senthil, notif_type: "credit_request"     },
  { title: "Trip Completed",          body: "Trip KRD-TRIP-003: 6 stops, ₹3.4L collected",           recipient: kumar,   notif_type: "trip_completed"     },
  { title: "Low Stock Warning",       body: "Ponni Raw Rice 25kg: only 12 bags left",                 recipient: kumar,   notif_type: "low_stock"          },
  { title: "Order On Hold",           body: "KRD-ORD-2026-0031: Murugan Traders hold — overdue",     recipient: rajan,   notif_type: "order_on_hold"      },
  { title: "Customer Blocked",        body: "Tamil Nadu Traders has been blocked by admin",           recipient: rajan,   notif_type: "customer_blocked"   },
  { title: "Invoice Generated",       body: "SI-KRD-001 generated for A1 Supermarket — ₹85,400",    recipient: lakshmi, notif_type: "invoice_generated"  },
  { title: "Payment Reversed",        body: "Cheque bounce: PAY-KRD-XXX reversed for ₹44,800",      recipient: lakshmi, notif_type: "payment_reversed"   },
  { title: "Return Request Submitted",body: "Sri Lakshmi Stores: 5 bags Ponni requested return",     recipient: kumar,   notif_type: "return_submitted"   },
  { title: "Trip Started",            body: "Muthu has started Trip KRD-TRIP-004",                   recipient: senthil, notif_type: "trip_started"       },
  { title: "Order Delivered",         body: "Chennai Corp. Mid-Day Meals: delivered ₹2.4L",          recipient: rajan,   notif_type: "order_delivered"    },
  { title: "Overdue Alert — ₹45,000", body: "Murugan Traders: overdue exceeds limit",                recipient: kannan,  notif_type: "overdue_alert"      },
  { title: "Daily Sales Summary",     body: "Today: 8 orders ₹4.2L | Collections ₹3.1L",            recipient: kannan,  notif_type: "daily_summary"      },
  { title: "New Order Submitted",     body: "KRD-ORD-2026-0036: Family Mart — ₹1.05L awaits approval",recipient: senthil, notif_type: "order_submitted"  },
  { title: "Stock Replenishment Due", body: "Toor Dal 1kg stock drops below reorder point",           recipient: kumar,   notif_type: "low_stock"          },
  { title: "Beat Assignment",         body: "Rajan: Chennai North Beat updated for next week",        recipient: rajan,   notif_type: "beat_assigned"      },
  { title: "Credit Note Issued",      body: "CN-KRD-001: ₹3,500 credit note for Hotel Saravana",    recipient: lakshmi, notif_type: "credit_note_issued" },
  { title: "Monthly Report Ready",    body: "February 2026 sales report is ready to download",       recipient: kannan,  notif_type: "report_ready"       },
]

notification_defs.each_with_index do |d, i|
  next if Notification.exists?(organization: org, user: d[:recipient], title: d[:title], body: d[:body])

  Notification.create!(
    organization:  org,
    user:          d[:recipient],
    title:         d[:title],
    body:          d[:body],
    notification_type: d[:notif_type],
    read_at:       nil,      # all unread for demo
    created_at:    Time.current - (20 - i).hours
  )
  print "."
end
puts ""
puts "  20 notifications seeded (all unread)."

# ── 12. Summary ────────────────────────────────────────────────────────────────
puts ""
puts "=" * 60
puts "  Demo seed complete!"
puts ""
puts "  Organization : #{org.name}"
puts "  Team         : #{team_defs.size} users (owner → driver)"
puts "  Customers    : #{customers.size} (with credit accounts)"
puts "  Products     : #{products.size} SKUs across 5 categories"
puts "  Price Lists  : 3 (standard, wholesale, festival)"
puts "  Orders       : #{orders.size} created"
puts "  Payments     : 30 seeded"
puts "  Trips        : #{trip_defs.size} (3 completed, 2 in progress, 5 planned/draft)"
puts "  Beats        : 5 schedules"
puts "  Notifications: 20 unread"
puts ""
puts "  Demo Login Credentials (password: demo1234)"
team_defs.each { |d| puts "    #{d[:role].ljust(18)} #{d[:email]}" }
puts "=" * 60
