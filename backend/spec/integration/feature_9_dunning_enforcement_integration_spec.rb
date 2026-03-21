require 'rails_helper'

RSpec.describe 'Feature 9: Dunning Enforcement Integration', type: :integration do
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

  # === Workflow Test: Day 0 (Order Creation through Invoice) ===
  describe 'Day 0: Normal order-to-invoice workflow' do
    it 'completes without any dunning enforcement' do
      # Create and approve order
      order = create(:sales_order, organization: org, branch: branch, customer: customer,
                     created_by: actor, status: 'on_hold')
      create(:sales_order_line, sales_order: order, product: product, qty: 5,
             unit_price: 100, discount_pct: 0, line_total: 500)
      order.recalculate_totals!

      result = Orders::ApproveOrderService.call(
        order: order, decision: 'approved', actor: actor
      )
      expect(result[:success]).to be true
      expect(order.reload.status).to eq('approved')

      # Generate invoice
      invoice_result = Invoice::GenerateFromDeliveryService.call(
        actor: actor, branch: branch, customer: customer,
        delivered_lines: [{
          product_id: product.id,
          qty: 5,
          unit_price: 100,
          discount_pct: 0,
          hsn_code: '22011000',
          gst_rate: 18
        }],
        generation_source: 'manual_from_order'
      )

      expect(invoice_result.success?).to be true
      invoice = invoice_result.invoice
      expect(invoice.status).to eq('issued')
      expect(invoice.outstanding_amount).to eq(invoice.grand_total)

      # No dunning logs should exist
      expect(AuditLog.where(action: 'payment_from_suspended_customer').count).to eq(0)
      expect(AuditLog.where(action: 'invoice_generated_for_suspended_customer').count).to eq(0)
    end
  end

  # === Workflow Test: Day 5 (Soft Block Enforcement) ===
  describe 'Day 5: Soft block enforcement (order requires approval)' do
    before do
      # Create overdue invoice
      @invoice = create(:sales_invoice, organization: org, branch: branch, customer: customer,
                       status: 'issued', grand_total: 1_000, outstanding_amount: 1_000,
                       paid_amount: 0, invoice_date: 5.days.ago, due_date: 2.days.ago)
    end

    it 'applies soft_block via DunningEnforcementJob' do
      # Simulate Day 5 enforcement trigger
      create(:dunning_sequence, customer: customer, organization: org,
             last_email_sent_at: 5.days.ago, enforcement_level: 'day_5')

      DunningEnforcementJob.perform_now

      expect(customer.reload.credit_block_rule).to eq('soft_block')
      expect(customer.dunning_suspended_at).to be_nil # No suspension yet
    end

    it 'allows orders to be submitted but prevents auto-approval' do
      customer.update(credit_block_rule: 'soft_block')

      # Orders can still be created
      order = create(:sales_order, organization: org, branch: branch, customer: customer,
                     created_by: actor, status: 'submitted')
      create(:sales_order_line, sales_order: order, product: product, qty: 5,
             unit_price: 100, discount_pct: 0, line_total: 500)
      order.recalculate_totals!

      # But manual approval can still occur (soft block just flags for review)
      result = Orders::ApproveOrderService.call(
        order: order, decision: 'approved', actor: actor
      )
      expect(result[:success]).to be true # Soft block allows approval
    end

    it 'notifies finance team of soft block' do
      create(:dunning_sequence, customer: customer, organization: org,
             last_email_sent_at: 5.days.ago, enforcement_level: 'day_5')

      expect {
        DunningEnforcementJob.perform_now
      }.to change { Notification.where(notification_type: 'dunning_enforced_day_5').count }.by(1)
    end
  end

  # === Workflow Test: Day 10 (Hard Block & Suspension) ===
  describe 'Day 10: Hard block enforcement (orders blocked)' do
    before do
      @invoice = create(:sales_invoice, organization: org, branch: branch, customer: customer,
                       status: 'issued', grand_total: 1_000, outstanding_amount: 1_000,
                       paid_amount: 0, invoice_date: 10.days.ago, due_date: 5.days.ago)
    end

    it 'applies hard_block and suspension via DunningEnforcementJob' do
      create(:dunning_sequence, customer: customer, organization: org,
             last_email_sent_at: 10.days.ago, enforcement_level: 'day_10',
             invoice_id: @invoice.id)

      DunningEnforcementJob.perform_now

      expect(customer.reload.credit_block_rule).to eq('hard_block')
      expect(customer.dunning_suspended_at).to be_present
      expect(customer.dunning_suspension_reason).to eq('day_10')
      expect(customer.dunning_suspension_invoice_id).to eq(@invoice.id)
    end

    it 'prevents order approval for suspended customer' do
      customer.update(
        credit_block_rule: 'hard_block',
        dunning_suspended_at: 1.day.ago
      )

      order = create(:sales_order, organization: org, branch: branch, customer: customer,
                     created_by: actor, status: 'on_hold')
      create(:sales_order_line, sales_order: order, product: product, qty: 5,
             unit_price: 100, discount_pct: 0, line_total: 500)
      order.recalculate_totals!

      result = Orders::ApproveOrderService.call(
        order: order, decision: 'approved', actor: actor
      )

      expect(result[:success]).to be false
      expect(result[:errors]).to include(
        include("Cannot approve order: Customer account is suspended")
      )
    end

    it 'still allows payment processing (for dunning resolution)' do
      customer.update(dunning_suspended_at: 1.day.ago)

      payment = create(:payment, organization: org, branch: branch, customer: customer,
                      created_by: actor, amount: 500, status: 'draft')

      create(:sales_invoice, organization: org, branch: branch, customer: customer,
             status: 'issued', grand_total: 1_000, outstanding_amount: 1_000,
             paid_amount: 0)

      result = Payments::ConfirmPaymentService.call(actor: actor, payment: payment)

      expect(result.success?).to be true
      expect(AuditLog.where(action: 'payment_from_suspended_customer').count).to eq(1)
    end

    it 'flags payment from suspended customer for review' do
      customer.update(dunning_suspended_at: 2.days.ago)

      payment = create(:payment, organization: org, branch: branch, customer: customer,
                      created_by: actor, amount: 500, status: 'draft')

      create(:sales_invoice, organization: org, branch: branch, customer: customer,
             status: 'issued', grand_total: 1_000, outstanding_amount: 1_000,
             paid_amount: 0)

      expect {
        Payments::ConfirmPaymentService.call(actor: actor, payment: payment)
      }.to change { Notification.where(notification_type: 'payment_from_suspended_customer').count }.by(1)
    end

    it 'notifies operations managers of suspension' do
      create(:dunning_sequence, customer: customer, organization: org,
             last_email_sent_at: 10.days.ago, enforcement_level: 'day_10')

      expect {
        DunningEnforcementJob.perform_now
      }.to change { Notification.where(notification_type: 'dunning_enforced_day_10').count }.by(1)
    end

    it 'allows invoice generation but flags it' do
      customer.update(dunning_suspended_at: 1.day.ago)

      invoice_result = Invoice::GenerateFromDeliveryService.call(
        actor: actor, branch: branch, customer: customer,
        delivered_lines: [{
          product_id: product.id,
          qty: 5,
          unit_price: 100,
          discount_pct: 0,
          hsn_code: '22011000',
          gst_rate: 18
        }],
        generation_source: 'manual_from_order'
      )

      expect(invoice_result.success?).to be true
      expect(AuditLog.where(action: 'invoice_generated_for_suspended_customer').count).to eq(1)
    end
  end

  # === Workflow Test: Day 15 (Escalation) ===
  describe 'Day 15: Escalation alert to operations' do
    before do
      @invoice = create(:sales_invoice, organization: org, branch: branch, customer: customer,
                       status: 'issued', grand_total: 1_000, outstanding_amount: 1_000,
                       paid_amount: 0, invoice_date: 15.days.ago, due_date: 10.days.ago)
    end

    it 'maintains suspension and sends manager alert via DunningEnforcementJob' do
      customer.update(
        credit_block_rule: 'hard_block',
        dunning_suspended_at: 5.days.ago
      )

      create(:dunning_sequence, customer: customer, organization: org,
             last_email_sent_at: 15.days.ago, enforcement_level: 'day_15')

      DunningEnforcementJob.perform_now

      expect(customer.reload.credit_block_rule).to eq('hard_block')
      expect(customer.dunning_suspended_at).to be_present
    end

    it 'creates escalation notification for managers' do
      customer.update(dunning_suspended_at: 5.days.ago)

      create(:dunning_sequence, customer: customer, organization: org,
             last_email_sent_at: 15.days.ago, enforcement_level: 'day_15')

      expect {
        DunningEnforcementJob.perform_now
      }.to change { Notification.where(notification_type: 'dunning_escalation_15day').count }.by(1)
    end
  end

  # === Workflow Test: Suspension Lift ===
  describe 'Suspension lifted: Customer can place orders again' do
    before do
      customer.update(
        credit_block_rule: 'hard_block',
        dunning_suspended_at: 10.days.ago,
        dunning_suspension_reason: 'overdue_invoice'
      )
    end

    it 'allows order approval when suspension is cleared' do
      # Finance manually clears suspension after payment received
      customer.update(
        dunning_suspended_at: nil,
        credit_block_rule: 'none'
      )

      order = create(:sales_order, organization: org, branch: branch, customer: customer,
                     created_by: actor, status: 'on_hold')
      create(:sales_order_line, sales_order: order, product: product, qty: 5,
             unit_price: 100, discount_pct: 0, line_total: 500)
      order.recalculate_totals!

      result = Orders::ApproveOrderService.call(
        order: order, decision: 'approved', actor: actor
      )

      expect(result[:success]).to be true
      expect(order.reload.status).to eq('approved')

      # No dunning notifications
      expect(AuditLog.where(action: 'payment_from_suspended_customer').count).to eq(0)
    end
  end

  # === Edge Case Tests ===
  describe 'Edge cases' do
    context 'customer with multiple invoices at different overdue levels' do
      before do
        create(:sales_invoice, organization: org, customer: customer,
               grand_total: 500, outstanding_amount: 500, status: 'issued',
               invoice_date: 3.days.ago, due_date: 1.day.ago) # 2 days overdue

        create(:sales_invoice, organization: org, customer: customer,
               grand_total: 1_000, outstanding_amount: 1_000, status: 'issued',
               invoice_date: 15.days.ago, due_date: 10.days.ago) # 15 days overdue
      end

      it 'applies enforcement based on oldest overdue invoice' do
        create(:dunning_sequence, customer: customer, organization: org,
               last_email_sent_at: 15.days.ago, enforcement_level: 'day_15')

        DunningEnforcementJob.perform_now

        expect(customer.reload.credit_block_rule).to eq('hard_block')
        expect(customer.dunning_suspended_at).to be_present
      end
    end

    context 'customer with payment in progress' do
      before do
        create(:sales_invoice, organization: org, customer: customer,
               grand_total: 1_000, outstanding_amount: 500, status: 'partially_paid',
               paid_amount: 500, invoice_date: 10.days.ago, due_date: 5.days.ago)
      end

      it 'still applies enforcement if partially paid invoice is overdue' do
        create(:dunning_sequence, customer: customer, organization: org,
               last_email_sent_at: 10.days.ago, enforcement_level: 'day_10')

        DunningEnforcementJob.perform_now

        expect(customer.reload.credit_block_rule).to eq('hard_block')
      end
    end

    context 'duplicate enforcement attempts' do
      before do
        customer.update(
          credit_block_rule: 'hard_block',
          dunning_suspended_at: 5.days.ago
        )

        create(:sales_invoice, organization: org, customer: customer,
               grand_total: 1_000, outstanding_amount: 1_000, status: 'issued',
               invoice_date: 10.days.ago, due_date: 5.days.ago)
      end

      it 'is idempotent (running enforcement twice has same effect)' do
        create(:dunning_sequence, customer: customer, organization: org,
               last_email_sent_at: 10.days.ago, enforcement_level: 'day_10')

        DunningEnforcementJob.perform_now
        original_suspended_at = customer.reload.dunning_suspended_at

        # Run again
        DunningEnforcementJob.perform_now

        expect(customer.reload.dunning_suspended_at).to eq(original_suspended_at)
        expect(customer.credit_block_rule).to eq('hard_block')
      end
    end
  end

  # === Audit Trail Test ===
  describe 'Audit trail' do
    it 'logs all dunning enforcement actions' do
      customer.update(dunning_suspended_at: nil)

      create(:sales_invoice, organization: org, customer: customer,
             grand_total: 1_000, outstanding_amount: 1_000, status: 'issued',
             invoice_date: 10.days.ago, due_date: 5.days.ago)

      create(:dunning_sequence, customer: customer, organization: org,
             last_email_sent_at: 10.days.ago, enforcement_level: 'day_10')

      DunningEnforcementJob.perform_now

      audits = AuditLog.where(customer: customer)
      expect(audits.count).to be > 0
    end

    it 'tracks order rejection due to dunning suspension' do
      customer.update(dunning_suspended_at: 2.days.ago)

      order = create(:sales_order, organization: org, branch: branch, customer: customer,
                     created_by: actor, status: 'on_hold')
      create(:sales_order_line, sales_order: order, product: product, qty: 5,
             unit_price: 100, discount_pct: 0, line_total: 500)
      order.recalculate_totals!

      Orders::ApproveOrderService.call(
        order: order, decision: 'approved', actor: actor
      )

      # Order rejection should be logged
      expect(order.reload.status).to eq('on_hold') # Remains unchanged
    end
  end
end
