# frozen_string_literal: true
# db/seeds/bank_reconciliation.rb
# Seeds covering all 5 match scenarios so the matcher can be exercised manually.
# Run via: rails db:seed:bank_reconciliation  OR  included in db/seeds.rb

puts "== Bank Reconciliation Seed =="

org = Organization.first
raise "Need at least one Organization" unless org

branch = org.branches.first || Branch.create!(organization: org, name: "HQ", code: "HQ")
user   = org.users.first || raise("Need at least one User in the organization")

# ── Bank Account ─────────────────────────────────────────────────────────────

bank_account = BankAccount.find_or_create_by!(
  organization: org,
  account_name: "ordWave Distribution Pvt Ltd"
) do |ba|
  ba.bank_name             = "HDFC Bank"
  ba.account_number_masked = "XXXXXXXX9012"
  ba.account_number_full   = "123456789012"
  ba.ifsc                  = "HDFC0001234"
  ba.status                = "active"
  ba.branch                = branch
end
puts "  BankAccount: #{bank_account.id}"

# ── Customers (5) ─────────────────────────────────────────────────────────────

customers_data = [
  { name: "Ravi Traders",     code: "RT001" },
  { name: "Shree Enterprises",code: "SE002" },
  { name: "Mehta & Co",       code: "MC003" },
  { name: "Priya Stores",     code: "PS004" },
  { name: "Gupta Brothers",   code: "GB005" },
]

customers = customers_data.map do |d|
  c = Customer.find_or_create_by!(organization: org, code: d[:code]) do |cust|
    cust.name   = d[:name]
    cust.branch = branch
  end

  # Create aliases (common narration patterns banks strip to)
  CustomerAlias.find_or_create_by!(customer: c, alias_name: d[:name].upcase)
  CustomerAlias.find_or_create_by!(customer: c, alias_name: d[:code].upcase)
  c
end
puts "  Customers + aliases: #{customers.map(&:code).join(', ')}"

# ── Open Invoices (10) ──────────────────────────────────────────────────────

invoice_data = [
  # [customer_index, invoice_number, amount]
  [0, "INV/2025/001", 15_000],
  [0, "INV/2025/002",  8_500],
  [1, "INV/2025/003", 22_750],
  [1, "INV/2025/004", 12_000],
  [2, "INV/2025/005",  5_000],
  [2, "INV/2025/006", 30_000],
  [3, "INV/2025/007", 18_250],
  [3, "INV/2025/008",  9_999],
  [4, "INV/2025/009", 45_000],
  [4, "INV/2025/010",  7_200],
]

invoices = invoice_data.map do |idx, inv_no, amount|
  inv = SalesInvoice.find_or_create_by!(organization: org, invoice_number: inv_no) do |i|
    i.customer     = customers[idx]
    i.branch       = branch
    i.created_by   = user
    i.grand_total  = amount
    i.status       = :issued
    i.invoice_date = 30.days.ago.to_date
    i.due_date     = 15.days.from_now.to_date
  end
  # Create expected payment reference for each invoice
  ExpectedPaymentReference.find_or_create_by!(
    organization:    org,
    customer:        customers[idx],
    sales_invoice:   inv,
    reference_type:  :invoice_number,
    reference_value: inv_no.upcase
  ) { |r| r.status = :pending }
  inv
end
puts "  Invoices: #{invoices.map(&:invoice_number).join(', ')}"

# ── Bank Statement Import placeholder ──────────────────────────────────────

import = BankStatementImport.create!(
  organization:        org,
  bank_account:        bank_account,
  source_type:         :manual,
  status:              :completed,
  file_name:           "seed_statement.csv",
  rows_count:          5,
  new_rows_count:      5,
  duplicate_rows_count: 0,
  failed_rows_count:   0
)

# ── Bank Transactions — one per scenario ────────────────────────────────────

scenarios = [
  # 1. Exact invoice number in narration (score 100)
  {
    txn_date:         5.days.ago.to_date,
    amount:           15_000,
    direction:        :credit,
    narration:        "NEFT/INV/2025/001/RAVI TRADERS/HDFC",
    utr_number:       "HDFC52312345678",
    match_meta:       {
      "invoice_numbers" => ["INV/2025/001"],
      "customer_codes"  => ["RT001"],
      "utr_candidates"  => ["HDFC52312345678"],
      "tokens"          => ["NEFT", "INV", "2025", "001", "RAVI", "TRADERS", "HDFC"]
    }
  },
  # 2. Retailer code + exact amount (score 98)
  {
    txn_date:         4.days.ago.to_date,
    amount:           22_750,
    direction:        :credit,
    narration:        "UPI/SE002/SHREE ENTERPRISES/PAYMENT",
    utr_number:       "UPI20251101022750",
    match_meta:       {
      "invoice_numbers" => [],
      "customer_codes"  => ["SE002"],
      "utr_candidates"  => ["UPI20251101022750"],
      "tokens"          => ["UPI", "SE002", "SHREE", "ENTERPRISES", "PAYMENT"]
    }
  },
  # 3. UTR matches an ExpectedPaymentReference (score 100)
  {
    txn_date:         3.days.ago.to_date,
    amount:           5_000,
    direction:        :credit,
    narration:        "RTGS/IMPS/2025/MEHTA/PAYMENT",
    utr_number:       nil,
    reference_number: "INV/2025/005",
    match_meta:       {
      "invoice_numbers" => ["INV/2025/005"],
      "customer_codes"  => [],
      "utr_candidates"  => [],
      "tokens"          => ["RTGS", "IMPS", "2025", "MEHTA", "PAYMENT"]
    }
  },
  # 4. Alias fuzzy match + exact amount (score 95)
  {
    txn_date:         2.days.ago.to_date,
    amount:           18_250,
    direction:        :credit,
    narration:        "NEFT CR/PRIYA STORES/REF8821973",
    utr_number:       "NEFT8821973",
    match_meta:       {
      "invoice_numbers" => [],
      "customer_codes"  => [],
      "utr_candidates"  => ["NEFT8821973"],
      "tokens"          => ["NEFT", "CR", "PRIYA", "STORES", "REF8821973"]
    }
  },
  # 5. Amount-only match — unique open invoice with that amount (score 90)
  {
    txn_date:         1.day.ago.to_date,
    amount:           45_000,
    direction:        :credit,
    narration:        "TRANSFER/REF:TXT9990001",
    utr_number:       "TXT9990001",
    match_meta:       {
      "invoice_numbers" => [],
      "customer_codes"  => [],
      "utr_candidates"  => ["TXT9990001"],
      "tokens"          => ["TRANSFER", "REF", "TXT9990001"]
    }
  },
]

scenarios.each do |attrs|
  idem = BankTransaction.build_idempotency_key(
    bank_account_id: bank_account.id,
    txn_date:        attrs[:txn_date],
    amount:          attrs[:amount],
    reference:       attrs[:utr_number] || attrs[:reference_number],
    narration:       attrs[:narration]
  )

  txn = BankTransaction.find_or_create_by!(idempotency_key: idem) do |t|
    t.organization          = org
    t.bank_account          = bank_account
    t.bank_statement_import = import
    t.txn_date              = attrs[:txn_date]
    t.amount                = attrs[:amount]
    t.direction             = attrs[:direction]
    t.narration             = attrs[:narration]
    t.utr_number            = attrs[:utr_number]
    t.reference_number      = attrs[:reference_number]
    t.status                = :unmatched
    t.match_meta            = attrs[:match_meta]
  end

  # Run matcher immediately so seeds are in a realistic state
  BankReconciliation::Matcher.call(txn, org)
  puts "  Txn #{txn.id}: #{txn.narration[0, 40]} → #{txn.reload.status}"
end

puts "== Done =="
