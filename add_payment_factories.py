import sys

factories_path = '/mnt/c/Users/chitr/Projects/orderlane_pro/backend/spec/factories.rb'

new_factories = '''
  factory :payment do
    association :organization
    association :branch
    association :customer
    association :created_by, factory: :user
    sequence(:payment_number) { |n| "PAY-TEST-#{Time.current.strftime('%Y%m')}-#{n.to_s.rjust(4, '0')}" }
    amount            { 1_000.0 }
    payment_mode      { 'cash' }
    received_date     { Date.today }
    status            { 'draft' }
    allocated_amount  { 0.0 }
    unallocated_amount { 0.0 }
  end

  factory :payment_allocation do
    association :payment
    association :sales_invoice
    allocated_amount { 500.0 }
    status           { 'active' }
  end

  factory :advance_payment do
    association :organization
    association :branch
    association :customer
    association :source_payment, factory: :payment
    original_amount { 500.0 }
    balance         { 500.0 }
    status          { 'unapplied' }
  end
'''

with open(factories_path, 'r', encoding='utf-8') as f:
    content = f.read()

if 'factory :payment do' in content:
    print('Payment factories already present, skipping.')
    sys.exit(0)

# Insert before the final closing 'end'
last_end = content.rfind('\nend\n')
if last_end == -1:
    last_end = content.rfind('\nend')

new_content = content[:last_end] + new_factories + content[last_end:]

with open(factories_path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print('Done. Payment factories added to factories.rb')
