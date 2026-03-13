# db/seeds_bank_reconciliation.rb
#
# Bank Reconciliation — Demo Seed Data
# ─────────────────────────────────────
# Loaded in the context of db/seeds.rb where the following are already set:
#   org, branch, admin, customers, seed_invoices
#
# Demonstrates 5 matching scenarios:
#   TXN-1  Exact invoice number in narration → auto_matched  (rule: exact_invoice_number,  score 100)
#   TXN-2  Customer trade name + exact amount → suggested    (rule: exact_amount_customer_name, score 85)
#   TXN-3  Two open invoices combined for same customer       (rule: multi_invoice_same_customer, score 88)
#   TXN-4  Unmatched credit — no matching signal             (status: unmatched)
#   TXN-5  Duplicate row from a second upload (idempotency)  (shows duplicate_rows_count counter)
#
# Usage:
#   load Rails.root.join("db/seeds_bank_reconciliation.rb")
# Or add the following line to db/seeds.rb after seed_invoices is populated:
#   load Rails.root.join("db/seeds_bank_reconciliation.rb")

puts ''
puts '  == Seeding bank reconciliation demo data...'

# ── Bank Account ──────────────────────────────────────────────────────────────
bank_acct = BankAccount.find_or_initialize_by(
  organization: org,
  account_number_masked: '••••9821'
)
bank_acct.assign_attributes(
  branch:               branch,
  bank_name:            'HDFC Bank',
  account_name:         org.name,
  account_number_full:  '503109999999821',
  ifsc:                 'HDFC0002701',
  status:               'active'
)
bank_acct.save!
puts "    BankAccount: #{bank_acct.display_name}"

# ── Import record (represents a CSV statement upload) ────────────────────────
def txn_key(bank_acct, date_str, amount, ref, narration)
  BankTransaction.build_idempotency_key(
    bank_acct.id,
    Date.parse(date_str),
    amount,
    ref,
    narration
  )
end

import_exists = ->(fname) { BankStatementImport.exists?(organization: org, file_name: fname) }

unless import_exists.('hdfc_march_2026_demo.csv')
  import = BankStatementImport.create!(
    organization:         org,
    bank_account:         bank_acct,
    uploaded_by:          admin,
    file_name:            'hdfc_march_2026_demo.csv',
    source_type:          'csv',
    status:               'completed',
    rows_count:           6,          # 5 data rows + 1 duplicate attempt
    processed_rows_count: 5,
    new_rows_count:       4,
    duplicate_rows_count: 1,
    failed_rows_count:    0
  )
  puts "    BankStatementImport: #{import.file_name} (id: #{import.id})"

  # Shared helper
  txn_exists = ->(key) { BankTransaction.exists?(idempotency_key: key) }

  # ── TXN-1: Exact invoice number match → auto_matched ─────────────────────
  # Narration contains "SI-ARYA-202603-0001"; ExactInvoiceNumberRule fires at score=100
  inv1     = seed_invoices['SI-ARYA-202603-0001']
  txn1_key = txn_key(bank_acct, '2026-03-10', inv1.grand_total, 'NEFT202603100001', "NEFT/SI-ARYA-202603-0001/RAJU STORES/UTR928374650")

  unless txn_exists.(txn1_key)
    txn1 = BankTransaction.create!(
      organization:          org,
      bank_account:          bank_acct,
      bank_statement_import: import,
      txn_date:              Date.parse('2026-03-10'),
      amount:                inv1.grand_total,
      direction:             'credit',
      utr_number:            'UTR928374650',
      reference_number:      'NEFT202603100001',
      payer_name:            'RAJU STORES',
      narration:             'NEFT/SI-ARYA-202603-0001/RAJU STORES/UTR928374650',
      normalized_narration:  'NEFT SI ARYA 202603 0001 RAJU STORES UTR928374650',
      raw_row_json:          { date: '10/03/2026', description: 'NEFT/SI-ARYA-202603-0001/RAJU STORES', credit: inv1.grand_total.to_s, balance: '1_00_000.00' },
      match_meta:            { 'invoice_numbers' => ['SI-ARYA-202603-0001'], 'customer_codes' => [], 'utr_candidates' => ['UTR928374650'], 'tokens' => %w[NEFT RAJU STORES] },
      status:                'auto_matched',
      match_score:           100.0,
      match_rule:            'exact_invoice_number',
      matched_customer:      inv1.customer,
      matched_invoice:       inv1,
      idempotency_key:       txn1_key
    )
    BankTransactionMatch.create!(
      bank_transaction: txn1,
      customer:         inv1.customer,
      sales_invoice:    inv1,
      score:            100.0,
      rule_code:        'exact_invoice_number',
      explanation:      { strategy: 'invoice_number_in_narration', matched: 'SI-ARYA-202603-0001' },
      selected:         true
    )
    puts "    [TXN-1] auto_matched  | ₹#{inv1.grand_total} | #{txn1.narration}"
  end

  # ── TXN-2: Customer name + exact amount → suggested ───────────────────────
  # Customer CUST-002 trade name appears in narration; amount = their open invoice
  inv2         = seed_invoices['SI-ARYA-202603-0002']
  cust2        = customers['CUST-002']
  txn2_key     = txn_key(bank_acct, '2026-03-11', inv2.grand_total, 'UPI202603110002', "UPI/CR/#{cust2.trade_name.upcase}/UTR928374651")

  unless txn_exists.(txn2_key)
    txn2 = BankTransaction.create!(
      organization:          org,
      bank_account:          bank_acct,
      bank_statement_import: import,
      txn_date:              Date.parse('2026-03-11'),
      amount:                inv2.grand_total,
      direction:             'credit',
      utr_number:            'UTR928374651',
      reference_number:      'UPI202603110002',
      payer_name:            cust2.trade_name,
      narration:             "UPI/CR/#{cust2.trade_name.upcase}/UTR928374651",
      normalized_narration:  "UPI CR #{cust2.trade_name.upcase} UTR928374651",
      raw_row_json:          { date: '11/03/2026', description: "UPI/CR/#{cust2.trade_name}", credit: inv2.grand_total.to_s },
      match_meta:            { 'invoice_numbers' => [], 'customer_codes' => [cust2.code], 'utr_candidates' => ['UTR928374651'], 'tokens' => ['UPI', 'CR'] },
      status:                'suggested',
      match_score:           85.0,
      match_rule:            'exact_amount_customer_name',
      matched_customer:      cust2,
      matched_invoice:       inv2,
      idempotency_key:       txn2_key
    )
    BankTransactionMatch.create!(
      bank_transaction: txn2,
      customer:         cust2,
      sales_invoice:    inv2,
      score:            85.0,
      rule_code:        'exact_amount_customer_name',
      explanation:      { strategy: 'name_and_amount', name_matched: cust2.trade_name, amount_matched: inv2.grand_total },
      selected:         true
    )
    puts "    [TXN-2] suggested     | ₹#{inv2.grand_total} | #{txn2.payer_name}"
  end

  # ── TXN-3: Multi-invoice combination → suggested ──────────────────────────
  # Amount = INV-0004 + INV-0005 (same customer CUST-001), opaque narration
  inv4         = seed_invoices['SI-ARYA-202603-0004']
  inv5         = seed_invoices['SI-ARYA-202603-0005']
  combined_amt = (inv4.grand_total + inv5.grand_total).round(2)
  txn3_key     = txn_key(bank_acct, '2026-03-12', combined_amt, 'IMPS202603120003', 'IMPS/CR/ARYA PAY/UTR928374652')

  unless txn_exists.(txn3_key)
    txn3 = BankTransaction.create!(
      organization:          org,
      bank_account:          bank_acct,
      bank_statement_import: import,
      txn_date:              Date.parse('2026-03-12'),
      amount:                combined_amt,
      direction:             'credit',
      utr_number:            'UTR928374652',
      reference_number:      'IMPS202603120003',
      payer_name:            customers['CUST-001'].trade_name,
      narration:             'IMPS/CR/ARYA PAY/UTR928374652',
      normalized_narration:  'IMPS CR ARYA PAY UTR928374652',
      raw_row_json:          { date: '12/03/2026', description: 'IMPS/CR/ARYA PAY', credit: combined_amt.to_s },
      match_meta:            { 'invoice_numbers' => [], 'customer_codes' => [], 'utr_candidates' => ['UTR928374652'], 'tokens' => %w[IMPS CR ARYA PAY] },
      status:                'suggested',
      match_score:           88.0,
      match_rule:            'multi_invoice_same_customer',
      matched_customer:      customers['CUST-001'],
      idempotency_key:       txn3_key
    )
    [inv4, inv5].each do |inv|
      BankTransactionMatch.create!(
        bank_transaction: txn3,
        customer:         customers['CUST-001'],
        sales_invoice:    inv,
        score:            88.0,
        rule_code:        'multi_invoice_same_customer',
        explanation:      { strategy: 'multi_invoice_combination', all_invoice_ids: [inv4.id, inv5.id], combined_amount: combined_amt },
        selected:         true
      )
    end
    puts "    [TXN-3] suggested     | ₹#{combined_amt} | #{inv4.invoice_number} + #{inv5.invoice_number} combo"
  end

  # ── TXN-4: Unmatched — no matching signal ─────────────────────────────────
  txn4_key = txn_key(bank_acct, '2026-03-13', 18_500.0, 'NEFT202603130004', 'NEFT/CR/UNKNOWN PARTY/UTR928374653')

  unless txn_exists.(txn4_key)
    BankTransaction.create!(
      organization:          org,
      bank_account:          bank_acct,
      bank_statement_import: import,
      txn_date:              Date.parse('2026-03-13'),
      amount:                18_500.0,
      direction:             'credit',
      utr_number:            'UTR928374653',
      reference_number:      'NEFT202603130004',
      payer_name:            'UNKNOWN PARTY',
      narration:             'NEFT/CR/UNKNOWN PARTY/UTR928374653',
      normalized_narration:  'NEFT CR UNKNOWN PARTY UTR928374653',
      raw_row_json:          { date: '13/03/2026', description: 'NEFT/CR/UNKNOWN PARTY', credit: '18500.00' },
      match_meta:            { 'invoice_numbers' => [], 'customer_codes' => [], 'utr_candidates' => ['UTR928374653'], 'tokens' => %w[NEFT CR UNKNOWN PARTY] },
      status:                'unmatched',
      idempotency_key:       txn4_key
    )
    puts "    [TXN-4] unmatched     | ₹18,500.00 | UNKNOWN PARTY — no matching signal"
  end

  # ── Note: TXN-5 demonstrates duplicate idempotency ───────────────────────
  # The import record shows duplicate_rows_count=1 because a second upload
  # of this statement on 2026-03-14 attempted to re-import TXN-1.
  # The CsvImportService detected the matching idempotency_key and skipped
  # the row, incrementing duplicate_rows_count instead of creating a second record.
  puts "    [TXN-5] DUPLICATE (idempotency) — already recorded in import.duplicate_rows_count=#{import.duplicate_rows_count}"

  puts '  == Bank reconciliation demo data seeded.'
end
