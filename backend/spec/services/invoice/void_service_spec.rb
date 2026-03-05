require 'rails_helper'

RSpec.describe Invoice::VoidService, type: :service do
  let(:org)      { create(:organization) }
  let(:branch)   { create(:branch, organization: org) }
  let(:customer) { create(:customer, organization: org, branch: branch) }
  let(:actor)    { create(:user) }
  let(:product)  { create(:product, organization: org) }

  let(:order) do
    create(:sales_order, organization: org, branch: branch, customer: customer,
           created_by: actor, status: 'delivered')
  end

  # Invoice with one line that has already incremented invoiced_qty on the SOL
  let(:invoice) do
    inv = create(:sales_invoice, organization: org, branch: branch,
                 customer: customer, created_by: actor,
                 sales_order: order, status: 'issued', issued_at: Time.current)
    inv
  end

  let(:sol) do
    create(:sales_order_line, sales_order: order, product: product,
           qty: 10, unit_price: 100, delivered_qty: 10, invoiced_qty: 10,
           gst_rate: 18, hsn_code: '22011000')
  end

  let!(:invoice_line) do
    create(:sales_invoice_line, sales_invoice: invoice, product: product,
           qty: 10, unit_price: 100, source_sales_order_line: sol,
           taxable_value: 1000, tax_amount: 180, line_total: 1180,
           gst_rate: 18, cgst_rate: 9, sgst_rate: 9, igst_rate: 0,
           cgst_amount: 90, sgst_amount: 90, igst_amount: 0)
  end

  def call(reason: 'Duplicate invoice', inv: invoice)
    Invoice::VoidService.call(
      actor:   actor,
      invoice: inv,
      reason:  reason
    )
  end

  # ── Happy path ────────────────────────────────────────────────────────────────

  describe '.call — success' do
    it 'returns success' do
      expect(call.success?).to be true
    end

    it 'transitions the invoice status to void' do
      call
      expect(invoice.reload.status).to eq('void')
    end

    it 'stamps voided_at timestamp' do
      call
      expect(invoice.reload.voided_at).to be_within(2.seconds).of(Time.current)
    end

    it 'stores the void_reason' do
      call(reason: 'Test reason')
      expect(invoice.reload.void_reason).to eq('Test reason')
    end
  end

  # ── invoiced_qty reversal ─────────────────────────────────────────────────────

  describe '.call — invoiced_qty reversal' do
    it 'decrements invoiced_qty on linked order lines by the invoiced qty' do
      expect { call }.to change { sol.reload.invoiced_qty }.from(10).to(0)
    end

    it 'never reduces invoiced_qty below zero' do
      sol.update!(invoiced_qty: 0)
      expect { call }.not_to change { sol.reload.invoiced_qty }
    end
  end

  # ── Audit trail ───────────────────────────────────────────────────────────────

  describe '.call — audit trail' do
    it 'creates an audit log entry' do
      expect { call }.to change(AuditLog, :count).by(1)
    end

    it 'records the invoice_voided action' do
      call
      log = AuditLog.last
      expect(log.action).to eq('invoice_voided')
    end

    it 'stores the reason in the audit log' do
      call(reason: 'Reason stored in audit')
      log = AuditLog.last
      expect(log.reason).to eq('Reason stored in audit')
    end

    it 'associates the audit log with the invoice' do
      call
      log = AuditLog.last
      expect(log.auditable).to eq(invoice)
    end
  end

  # ── Guard: blank reason ───────────────────────────────────────────────────────

  describe '.call — blank reason' do
    it 'returns failure when reason is nil' do
      result = call(reason: nil)
      expect(result.success?).to be false
      expect(result.errors).to include(a_string_matching(/reason/i))
    end

    it 'returns failure when reason is empty string' do
      result = call(reason: '   ')
      expect(result.success?).to be false
      expect(result.errors).to include(a_string_matching(/reason/i))
    end

    it 'does not change invoice status on blank-reason failure' do
      call(reason: '')
      expect(invoice.reload.status).to eq('issued')
    end
  end

  # ── Guard: wrong status ───────────────────────────────────────────────────────

  describe '.call — status guard' do
    it 'cannot void a draft invoice' do
      draft_inv = create(:sales_invoice, organization: org, branch: branch,
                         customer: customer, created_by: actor,
                         sales_order: order, status: 'draft')
      result = Invoice::VoidService.call(actor: actor, invoice: draft_inv,
                                         reason: 'Test')
      expect(result.success?).to be false
      expect(result.errors).to include(a_string_matching(/issued/i))
    end

    it 'cannot void an already-voided invoice' do
      invoice.update!(status: 'void', voided_at: Time.current,
                      void_reason: 'Already voided')
      result = Invoice::VoidService.call(actor: actor, invoice: invoice,
                                         reason: 'Re-void attempt')
      expect(result.success?).to be false
      expect(result.errors).to include(a_string_matching(/issued/i))
    end
  end
end
