require 'rails_helper'

RSpec.describe Invoice::GenerateFromDeliveryService, type: :service do
  # ── Shared setup ─────────────────────────────────────────────────────────────
  let(:org)    { create(:organization) }
  let(:branch) do
    create(:branch, organization: org, code: 'MUM', state_code: '27')
  end
  let(:customer_intra) do
    # Same state → intra-state GST (CGST+SGST)
    create(:customer, organization: org, branch: branch, gstin: '27AAAPL1234F1ZV')
  end
  let(:customer_inter) do
    # Different state → inter-state GST (IGST)
    create(:customer, organization: org, branch: branch, gstin: '29AAAPL1234F1ZV')
  end
  let(:actor)   { create(:user) }
  let(:product) { create(:product, organization: org) }

  let(:order_intra) do
    create(:sales_order, organization: org, branch: branch, customer: customer_intra,
           created_by: actor, status: 'delivered')
  end
  let(:sol_intra) do
    create(:sales_order_line, sales_order: order_intra, product: product,
           qty: 10, unit_price: 100, discount_pct: 0, gst_rate: 18,
           delivered_qty: 10, invoiced_qty: 0, hsn_code: '22011000')
  end

  def call(customer: customer_intra, order: order_intra, sol: sol_intra, qty: nil, **opts)
    Invoice::GenerateFromDeliveryService.call(
      actor:             actor,
      branch:            branch,
      customer:          customer,
      sales_order:       order,
      invoice_date:      Date.today,
      generation_source: 'manual_from_order',
      delivered_lines:   [{
        product_id:          product.id,
        qty:                 qty || sol.delivered_qty,
        sales_order_line_id: sol.id,
        unit_price:          sol.unit_price,
        discount_pct:        sol.discount_pct,
        hsn_code:            sol.hsn_code,
        gst_rate:            sol.gst_rate
      }],
      **opts
    )
  end

  # ── Basic success ─────────────────────────────────────────────────────────────

  describe '.call — basic generation' do
    it 'returns success' do
      expect(call.success?).to be true
    end

    it 'creates a SalesInvoice record' do
      expect { call }.to change(SalesInvoice, :count).by(1)
    end

    it 'creates SalesInvoiceLine records' do
      expect { call }.to change(SalesInvoiceLine, :count).by(1)
    end

    it 'sets status to issued immediately' do
      result = call
      expect(result.invoice.status).to eq('issued')
    end

    it 'assigns an invoice number in SI-BRANCH-YYYYMM-NNNN format' do
      result = call
      expect(result.invoice.invoice_number).to match(/\ASI-MUM-\d{6}-\d{4}\z/)
    end

    it 'freezes the unit_price snapshot on the line' do
      result = call
      line = result.invoice.lines.first
      expect(line.unit_price).to eq(100)
      expect(line.gst_rate).to   eq(18)
    end

    it 'increments invoiced_qty on the sales_order_line' do
      sol_intra # ensure it exists
      expect { call }.to change { sol_intra.reload.invoiced_qty }.from(0).to(10)
    end
  end

  # ── Intra-state: CGST + SGST split ───────────────────────────────────────────

  describe '.call — intra-state GST (CGST/SGST)' do
    it 'stores CGST and SGST amounts on the line' do
      result = call(customer: customer_intra, order: order_intra, sol: sol_intra)
      line   = result.invoice.lines.first
      expect(line.cgst_rate).to   eq(9)
      expect(line.sgst_rate).to   eq(9)
      expect(line.igst_rate).to   eq(0)
      expect(line.cgst_amount).to eq(90)
      expect(line.sgst_amount).to eq(90)
      expect(line.igst_amount).to eq(0)
    end

    it 'computes grand total correctly' do
      result      = call(customer: customer_intra, order: order_intra, sol: sol_intra)
      # 10 * 100 = 1000 taxable; 18% tax = 180; grand = 1180
      expect(result.invoice.grand_total).to eq(1180)
    end
  end

  # ── Inter-state: IGST ─────────────────────────────────────────────────────────

  describe '.call — inter-state GST (IGST)' do
    let(:order_inter) do
      create(:sales_order, organization: org, branch: branch, customer: customer_inter,
             created_by: actor, status: 'delivered')
    end
    let(:sol_inter) do
      create(:sales_order_line, sales_order: order_inter, product: product,
             qty: 10, unit_price: 100, discount_pct: 0, gst_rate: 18,
             delivered_qty: 10, invoiced_qty: 0, hsn_code: '22011000')
    end

    it 'stores IGST amount and zeroes CGST/SGST' do
      result = call(customer: customer_inter, order: order_inter, sol: sol_inter)
      line   = result.invoice.lines.first
      expect(line.cgst_amount).to eq(0)
      expect(line.sgst_amount).to eq(0)
      expect(line.igst_amount).to eq(180)
    end
  end

  # ── Tax snapshot immutability ─────────────────────────────────────────────────

  describe '.call — snapshot immutability' do
    it 'does not change the invoice GST when the sales order line gst_rate changes later' do
      result = call
      invoice_line = result.invoice.lines.first
      original_tax = invoice_line.tax_amount

      sol_intra.update!(gst_rate: 28)  # Change master AFTER invoice creation

      expect(invoice_line.reload.tax_amount).to eq(original_tax)
    end
  end

  # ── Partial delivery / partial invoicing ──────────────────────────────────────

  describe '.call — partial delivery → partial invoice' do
    let(:sol_partial) do
      create(:sales_order_line, sales_order: order_intra, product: product,
             qty: 20, unit_price: 100, discount_pct: 0, gst_rate: 5,
             delivered_qty: 12, invoiced_qty: 0, hsn_code: '22011000')
    end

    it 'creates invoice for partial delivered qty' do
      result = call(sol: sol_partial, qty: 8)
      expect(result.success?).to be true
      expect(result.invoice.lines.first.qty).to eq(8)
    end

    it 'stamps invoiced_qty with the partial amount' do
      call(sol: sol_partial, qty: 8)
      expect(sol_partial.reload.invoiced_qty).to eq(8)
    end

    it 'allows a second invoice for the remaining qty' do
      call(sol: sol_partial, qty: 8)        # first partial invoice
      result2 = Invoice::GenerateFromDeliveryService.call(
        actor:             actor,
        branch:            branch,
        customer:          customer_intra,
        sales_order:       order_intra,
        invoice_date:      Date.today,
        generation_source: 'manual_from_order',
        delivered_lines: [{
          product_id:          product.id,
          qty:                 4,
          sales_order_line_id: sol_partial.id,
          unit_price:          sol_partial.unit_price,
          discount_pct:        sol_partial.discount_pct,
          hsn_code:            sol_partial.hsn_code,
          gst_rate:            sol_partial.gst_rate
        }]
      )
      expect(result2.success?).to be true
      expect(sol_partial.reload.invoiced_qty).to eq(12)
    end
  end

  # ── Idempotency for auto generation ──────────────────────────────────────────

  describe '.call — auto delivery idempotency' do
    let(:trip)  { create(:delivery_trip, organization: org, branch: branch, status: 'completed') }
    let(:stop)  { create(:trip_stop, delivery_trip: trip, sales_order: order_intra, status: 'delivered') }

    def auto_call(trip_stop: stop)
      Invoice::GenerateFromDeliveryService.call(
        actor:             actor,
        branch:            branch,
        customer:          customer_intra,
        sales_order:       order_intra,
        trip_stop:         trip_stop,
        invoice_date:      Date.today,
        generation_source: 'auto_on_delivery',
        delivered_lines: [{
          product_id:          product.id,
          qty:                 sol_intra.delivered_qty,
          sales_order_line_id: sol_intra.id,
          unit_price:          sol_intra.unit_price,
          discount_pct:        sol_intra.discount_pct,
          hsn_code:            sol_intra.hsn_code,
          gst_rate:            sol_intra.gst_rate
        }]
      )
    end

    before { sol_intra } # materialize

    it 'prevents duplicate auto invoice for same stop + customer' do
      auto_call  # first call succeeds
      result2 = auto_call

      expect(result2.success?).to be false
      expect(result2.errors).to include(a_string_matching(/already auto-generated/))
    end
  end

  # ── Validation errors ─────────────────────────────────────────────────────────

  describe '.call — validation errors' do
    it 'fails when delivered_lines is empty' do
      result = Invoice::GenerateFromDeliveryService.call(
        actor: actor, branch: branch, customer: customer_intra,
        delivered_lines: []
      )
      expect(result.success?).to be false
      expect(result.errors).to include(a_string_matching(/empty/i))
    end

    it 'fails when qty <= 0' do
      result = Invoice::GenerateFromDeliveryService.call(
        actor: actor, branch: branch, customer: customer_intra,
        delivered_lines: [{ product_id: product.id, qty: 0 }]
      )
      expect(result.success?).to be false
    end
  end

  # Feature 9: Dunning suspension handling for invoice generation
  describe '.call — dunning suspension scenarios' do
    context 'when customer is dunning suspended' do
      before do
        customer_intra.update(
          credit_block_rule: 'hard_block',
          dunning_suspended_at: 5.days.ago,
          dunning_suspension_reason: 'overdue_invoice',
          dunning_suspension_invoice_id: 'INV-OLD-123'
        )
      end

      it 'still generates invoice (allows billing to continue)' do
        result = call
        expect(result.success?).to be true
        expect(result.invoice).to be_present
      end

      it 'creates audit log noting suspended customer invoice' do
        expect {
          call
        }.to change(AuditLog, :count)

        audit = AuditLog.where(action: 'invoice_generated_for_suspended_customer').last
        expect(audit).to be_present
        expect(audit.changes['customer_id']).to eq(customer_intra.id)
        expect(audit.changes['suspended_since']).to be_present
      end

      it 'notifies finance team for manual review' do
        expect {
          call
        }.to change(Notification, :count)

        notification = Notification.where(notification_type: 'invoice_generated_for_suspended_customer').last
        expect(notification).to be_present
        expect(notification.title).to include('suspended account')
        expect(notification.body).to include(customer_intra.name)
        expect(notification.severity).to eq('medium')
      end

      it 'includes suspension details in audit log' do
        call

        audit = AuditLog.where(action: 'invoice_generated_for_suspended_customer').last
        expect(audit.changes).to include(
          'suspension_reason' => 'overdue_invoice',
          'suspension_invoice_id' => 'INV-OLD-123',
          'manual_review_recommended' => true
        )
      end

      it 'creates invoice with correct amount despite suspension' do
        result = call
        expect(result.invoice.grand_total).to be > 0
        expect(result.invoice.outstanding_amount).to eq(result.invoice.grand_total)
      end
    end

    context 'when customer is not suspended' do
      before do
        customer_intra.update(dunning_suspended_at: nil, credit_block_rule: 'none')
      end

      it 'generates invoice without dunning notifications' do
        expect {
          call
        }.not_to change { Notification.where(notification_type: 'invoice_generated_for_suspended_customer').count }
      end

      it 'does not create dunning suspension audit log' do
        expect {
          call
        }.not_to change { AuditLog.where(action: 'invoice_generated_for_suspended_customer').count }
      end
    end

    context 'with auto_on_delivery source and suspended customer' do
      let(:trip_stop) { create(:trip_stop) }

      it 'generates invoice even if delivery is automatic for suspended customer' do
        customer_intra.update(dunning_suspended_at: 2.days.ago)

        result = Invoice::GenerateFromDeliveryService.call(
          actor: actor,
          branch: branch,
          customer: customer_intra,
          sales_order: order_intra,
          trip_stop: trip_stop,
          generation_source: 'auto_on_delivery',
          delivered_lines: [{
            product_id: product.id,
            qty: sol_intra.delivered_qty
          }]
        )

        expect(result.success?).to be true
        expect(AuditLog.where(action: 'invoice_generated_for_suspended_customer').count).to eq(1)
      end
    end
  end
end
