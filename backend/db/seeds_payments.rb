
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

