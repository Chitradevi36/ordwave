# Seeds for Rice OMS — idempotent, safe to re-run.
# Usage: bin/rails db:seed

puts '== Seeding roles...'

role_definitions = [
  { name: 'owner',           description: 'Organization owner — full access, billing control' },
  { name: 'admin',           description: 'Administrator — full operational access within org' },
  { name: 'manager',         description: 'Branch manager — manage staff, inventory, orders for a branch' },
  { name: 'sales_rep',       description: 'Sales representative — create and manage orders' },
  { name: 'warehouse_staff', description: 'Warehouse staff — manage inventory and dispatch' },
  { name: 'accountant',      description: 'Accountant — view financials, manage payments' }
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

  puts ''
  puts '  ┌─ Dev login credentials ────────────────'
  puts "  │  POST /api/v1/auth/login"
  puts "  │  email:    admin@riceoms.dev"
  puts "  │  password: Password@123"
  puts "  │  X-Organization-Id: #{org.id}"
  puts '  └────────────────────────────────────────'
end
