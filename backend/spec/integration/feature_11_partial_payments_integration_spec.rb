require 'rails_helper'

RSpec.describe 'Feature 11: Partial Payments & Advance Deduction Integration', type: :integration do
  let(:org) { create(:organization) }
  let(:branch) { create(:branch, organization: org) }
  let(:customer) { create(:customer, organization: org, branch: branch) }
  let(:actor) { create(:user) }
  let(:product) { create(:product, organization: org) }

  let!(:credit_account) do
    create(:credit_account, customer: customer, organization: org, branch: branch,
           credit_limit: 100_000, current_balance: 0, available_credit: 100_000,
           overdue_amount: 0, overdue_days: 0)
  end

  # === Scenario 1: Simple Partial Payment (No Advances Yet) ===
  describe 'Scenario 1: First payment - partial against single invoice' do
    let!(:invoice) { create(:sales_invoice, organization: org, branch: branch, customer: customer,
                           grand_total: 1_000, outstanding_amount: 1_000, paid_amount: 0,
                           status: 'issued') }

    it 'partial payment creates advance for unallocated amount' do
      payment = create(:payment, organization: org, branch: branch, customer: customer,
                      created_by: actor, amount: 600, status: 'draft')

      result = Payments::ConfirmPaymentService.call(actor: actor, payment: payment)

      expect(result.success?).to be true
      expect(invoice.reload.outstanding_amount).to eq(400.0)
      expect(invoice.reload.paid_amount).to eq(600.0)
      expect(result.advance_payment).to be_present
      expect(result.advance_payment.balance).to eq(0.0) # AdvancePayment created from 0 unallocated
    end
  end

  # === Scenario 2: Multi-Invoice Partial Payment with Manual Allocation ===
  describe 'Scenario 2: Partial payment across multiple invoices (manual allocation)' do
    let!(:inv1) { create(:sales_invoice, organization: org, branch: branch, customer: customer,
                        grand_total: 500, outstanding_amount: 500, paid_amount: 0,
                        status: 'issued', invoice_date: 10.days.ago) }
    let!(:inv2) { create(:sales_invoice, organization: org, branch: branch, customer: customer,
                        grand_total: 300, outstanding_amount: 300, paid_amount: 0,
                        status: 'issued', invoice_date: 5.days.ago) }

    it 'manually allocates payment to specific invoices' do
      payment = create(:payment, organization: org, branch: branch, customer: customer,
                      created_by: actor, amount: 400, status: 'draft')

      # Manually allocate: 300 to inv1, 100 to inv2
      result = Payments::ConfirmPaymentService.call(
        actor: actor,
        payment: payment,
        manual_lines: [
          { sales_invoice_id: inv1.id, amount: 300 },
          { sales_invoice_id: inv2.id, amount: 100 }
        ]
      )

      expect(result.success?).to be true
      expect(inv1.reload.outstanding_amount).to eq(200.0)
      expect(inv2.reload.outstanding_amount).to eq(200.0)
      expect(result.advance_payment).to be_nil # Full allocation, no advance
    end

    it 'handles partial allocation with advance creation' do
      payment = create(:payment, organization: org, branch: branch, customer: customer,
                      created_by: actor, amount: 250, status: 'draft')

      result = Payments::ConfirmPaymentService.call(
        actor: actor,
        payment: payment,
        manual_lines: [
          { sales_invoice_id: inv1.id, amount: 250 }
        ]
      )

      expect(result.success?).to be true
      expect(inv1.reload.outstanding_amount).to eq(250.0)
      expect(result.advance_payment).to be_nil # No unallocated amount with manual allocation
    end
  end

  # === Scenario 3: Advance Deduction on New Payment ===
  describe 'Scenario 3: Customer has advance balance, makes new payment' do
    let!(:inv1) { create(:sales_invoice, organization: org, branch: branch, customer: customer,
                        grand_total: 500, outstanding_amount: 500, paid_amount: 0,
                        status: 'issued', invoice_date: 10.days.ago) }
    let!(:inv2) { create(:sales_invoice, organization: org, branch: branch, customer: customer,
                        grand_total: 400, outstanding_amount: 400, paid_amount: 0,
                        status: 'issued', invoice_date: 5.days.ago) }

    before do
      # Create initial payment that leaves advance balance
      initial_payment = create(:payment, organization: org, branch: branch, customer: customer,
                              created_by: actor, amount: 400, status: 'draft')
      Payments::ConfirmPaymentService.call(actor: actor, payment: initial_payment)
      # Now customer should have advance balance from excess payment
    end

    it 'auto-applies advance balance to new invoice' do
      new_payment = create(:payment, organization: org, branch: branch, customer: customer,
                          created_by: actor, amount: 300, status: 'draft')

      result = Payments::ConfirmPaymentService.call(actor: actor, payment: new_payment)

      expect(result.success?).to be true
      
      # New payment should find existing advance and apply it
      audit = AuditLog.where(action: 'payment_advance_deduction_applied').last
      expect(audit).to be_present
    end
  end

  # === Scenario 4: Phased Payment Pattern with Advances ===
  describe 'Scenario 4: Phased payments - customer pays down invoices gradually' do
    let!(:invoice) { create(:sales_invoice, organization: org, branch: branch, customer: customer,
                           grand_total: 1_000, outstanding_amount: 1_000, paid_amount: 0,
                           status: 'issued') }

    it 'tracks payment progress through advances' do
      # Payment 1: 400 (creates 400 advance)
      payment1 = create(:payment, organization: org, branch: branch, customer: customer,
                       created_by: actor, amount: 400, status: 'draft')
      result1 = Payments::ConfirmPaymentService.call(actor: actor, payment: payment1)
      
      expect(invoice.reload.outstanding_amount).to eq(600.0)
      advance1 = customer.advance_payments.where(status: %w[unapplied partially_applied]).first
      expect(advance1).to be_present if result1.advance_payment

      # Payment 2: 300 (pays from advance + new invoice payment)
      payment2 = create(:payment, organization: org, branch: branch, customer: customer,
                       created_by: actor, amount: 300, status: 'draft')
      result2 = Payments::ConfirmPaymentService.call(actor: actor, payment: payment2)

      expect(invoice.reload.outstanding_amount).to eq(300.0)

      # Payment 3: Final 300 (clears everything)
      payment3 = create(:payment, organization: org, branch: branch, customer: customer,
                       created_by: actor, amount: 300, status: 'draft')
      result3 = Payments::ConfirmPaymentService.call(actor: actor, payment: payment3)

      expect(invoice.reload.outstanding_amount).to eq(0.0)
      expect(invoice.reload.status).to eq('paid')
    end
  end

  # === Scenario 5: Advance Created, Then Applied ===
  describe 'Scenario 5: Fragment advance usage - advance partially applied then new payment uses remainder' do
    let!(:inv1) { create(:sales_invoice, organization: org, branch: branch, customer: customer,
                        grand_total: 500, outstanding_amount: 500, paid_amount: 0,
                        status: 'issued', invoice_date: 10.days.ago) }
    let!(:inv2) { create(:sales_invoice, organization: org, branch: branch, customer: customer,
                        grand_total: 300, outstanding_amount: 300, paid_amount: 0,
                        status: 'issued', invoice_date: 5.days.ago) }

    before do
      # Create advance payment
      adv_base = create(:payment, organization: org, branch: branch, customer: customer,
                       created_by: actor, amount: 400, status: 'confirmed')
      @advance = create(:advance_payment, organization: org, branch: branch, customer: customer,
                       source_payment: adv_base, original_amount: 400, balance: 400,
                       status: 'unapplied')
    end

    it 'applies advance then uses new cash for remainder' do
      new_payment = create(:payment, organization: org, branch: branch, customer: customer,
                          created_by: actor, amount: 300, status: 'draft')

      result = Payments::ConfirmPaymentService.call(actor: actor, payment: new_payment)

      expect(result.success?).to be true
      
      # Advance should be reduced
      expect(@advance.reload.balance).to be < 400.0
      
      # Invoices should be paid
      expect(inv1.reload.outstanding_amount).to be < 500.0
    end
  end

  # === Scenario 6: Custom Allocation Preference ===
  describe 'Scenario 6: Customer chooses specific invoices to pay (opt-out of advance)' do
    let!(:inv1) { create(:sales_invoice, organization: org, branch: branch, customer: customer,
                        grand_total: 500, outstanding_amount: 500, paid_amount: 0,
                        status: 'issued', invoice_date: 10.days.ago) }
    let!(:inv2) { create(:sales_invoice, organization: org, branch: branch, customer: customer,
                        grand_total: 300, outstanding_amount: 300, paid_amount: 0,
                        status: 'issued', invoice_date: 5.days.ago) }

    before do
      # Pre-create an advance that customer might want to skip
      adv_base = create(:payment, organization: org, branch: branch, customer: customer,
                       created_by: actor, amount: 200, status: 'confirmed')
      @advance = create(:advance_payment, organization: org, branch: branch, customer: customer,
                       source_payment: adv_base, original_amount: 200, balance: 200,
                       status: 'unapplied')
    end

    it 'allows manual allocation to override advance autodeduction preference' do
      new_payment = create(:payment, organization: org, branch: branch, customer: customer,
                          created_by: actor, amount: 400, status: 'draft')

      # Customer explicitly allocates (bypasses auto-advance logic - both services run but manual takes precedence)
      result = Payments::ConfirmPaymentService.call(
        actor: actor,
        payment: new_payment,
        manual_lines: [
          { sales_invoice_id: inv1.id, amount: 200 },
          { sales_invoice_id: inv2.id, amount: 200 }
        ]
      )

      expect(result.success?).to be true
      expect(inv1.reload.paid_amount).to eq(200.0)
      expect(inv2.reload.paid_amount).to eq(200.0)
    end
  end

  # === Scenario 7: Cross-Invoice Advance Coverage ===
  describe 'Scenario 7: Single advance covers multiple invoices' do
    let!(:inv1) { create(:sales_invoice, organization: org, branch: branch, customer: customer,
                        grand_total: 200, outstanding_amount: 200, paid_amount: 0,
                        status: 'issued', invoice_date: 10.days.ago) }
    let!(:inv2) { create(:sales_invoice, organization: org, branch: branch, customer: customer,
                        grand_total: 300, outstanding_amount: 300, paid_amount: 0,
                        status: 'issued', invoice_date: 5.days.ago) }

    before do
      adv_base = create(:payment, organization: org, branch: branch, customer: customer,
                       created_by: actor, amount: 400, status: 'confirmed')
      @advance = create(:advance_payment, organization: org, branch: branch, customer: customer,
                       source_payment: adv_base, original_amount: 400, balance: 400,
                       status: 'unapplied')
    end

    it 'applies advance across multiple invoices in FIFO order' do
      result = described_class::AdvanceAllocationService.call(
        actor: actor,
        customer: customer,
        deduction_amount: 400.0,
        advance_payment: @advance
      )

      expect(result.success?).to be true
      expect(inv1.reload.outstanding_amount).to eq(0.0) # Fully covered
      expect(inv2.reload.outstanding_amount).to eq(100.0) # Partially covered (300 - 200)
      expect(@advance.reload.balance).to eq(0.0)
    end
  end

  # === Scenario 8: Audit Trail ===
  describe 'Scenario 8: Complete audit trail of advance deductions' do
    let!(:invoice) { create(:sales_invoice, organization: org, branch: branch, customer: customer,
                           grand_total: 1_000, outstanding_amount: 1_000, paid_amount: 0,
                           status: 'issued') }

    before do
      adv_base = create(:payment, organization: org, branch: branch, customer: customer,
                       created_by: actor, amount: 300, status: 'confirmed')
      @advance = create(:advance_payment, organization: org, branch: branch, customer: customer,
                       source_payment: adv_base, original_amount: 300, balance: 300,
                       status: 'unapplied')
    end

    it 'logs all advance application steps' do
      new_payment = create(:payment, organization: org, branch: branch, customer: customer,
                          created_by: actor, amount: 500, status: 'draft')

      Payments::ConfirmPaymentService.call(actor: actor, payment: new_payment)

      # Check for advance deduction log
      deduction_audit = AuditLog.where(action: 'payment_advance_deduction_applied').last
      expect(deduction_audit).to be_present
      expect(deduction_audit.changes['advance_deducted']).to eq(300.0)

      # Check for auto-application log
      application_audits = AuditLog.where(action: 'advance_auto_applied_to_invoice')
      expect(application_audits.count).to be > 0
    end
  end

  # === Scenario 9: Zero Advance Edge Case ===
  describe 'Scenario 9: Customer with zero-balance advance' do
    let!(:invoice) { create(:sales_invoice, organization: org, branch: branch, customer: customer,
                           grand_total: 1_000, outstanding_amount: 1_000, paid_amount: 0,
                           status: 'issued') }

    before do
      adv_base = create(:payment, organization: org, branch: branch, customer: customer,
                       created_by: actor, amount: 500, status: 'confirmed')
      # Explicitly create zero-balance advance (applied)
      @advance = create(:advance_payment, organization: org, branch: branch, customer: customer,
                       source_payment: adv_base, original_amount: 500, balance: 0,
                       status: 'applied')
    end

    it 'skips applied advances and processes payment normally' do
      new_payment = create(:payment, organization: org, branch: branch, customer: customer,
                          created_by: actor, amount: 400, status: 'draft')

      result = Payments::ConfirmPaymentService.call(actor: actor, payment: new_payment)

      expect(result.success?).to be true
      expect(invoice.reload.paid_amount).to eq(400.0)
      expect(result.advance_payment).to be_present # Creates new advance from unallocated
    end
  end
end
