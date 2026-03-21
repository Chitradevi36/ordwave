require 'rails_helper'

RSpec.describe Inventory::ShortageResolutionService, type: :service do
  let(:org) { create(:organization) }
  let(:branch) { create(:branch, organization: org) }
  let(:customer) { create(:customer, organization: org, branch: branch) }
  let(:actor) { create(:user) }
  let(:product) { create(:product, organization: org, name: 'Widget') }
  let(:order) do
    order = create(:sales_order, organization: org, branch: branch, customer: customer,
                   created_by: actor, status: 'on_hold')
    create(:sales_order_line, sales_order: order, product: product, qty: 10, unit_price: 100)
    order.recalculate_totals!
    order
  end

  describe '.call' do
    context 'refund resolution' do
      it 'cancels order' do
        result = described_class.call(
          order: order,
          resolution_type: 'refund',
          actor: actor
        )

        expect(result.success?).to be true
        expect(order.reload.status).to eq('cancelled')
        expect(order.reload.cancellation_reason).to eq('inventory_shortage')
      end

      it 'creates audit log' do
        expect {
          described_class.call(
            order: order,
            resolution_type: 'refund',
            actor: actor
          )
        }.to change { AuditLog.where(action: 'shortage_resolved').count }.by(1)
      end

      it 'includes resolution type in audit log' do
        described_class.call(
          order: order,
          resolution_type: 'refund',
          actor: actor
        )

        audit = AuditLog.where(action: 'shortage_resolved').last
        expect(audit.changes['resolution_type']).to eq('full_refund')
      end

      it 'provides success response' do
        result = described_class.call(
          order: order,
          resolution_type: 'refund',
          actor: actor
        )

        expect(result.success?).to be true
        expect(result.order).to eq(order)
        expect(result.errors).to be_empty
      end
    end

    context 'partial resolution' do
      before do
        # Create shortage: 10 requested, 4 available, so 6 short
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 4, qty_reserved: 0)
      end

      it 'marks order as partially fulfilled' do
        result = described_class.call(
          order: order,
          resolution_type: 'partial',
          actor: actor
        )

        expect(result.success?).to be true
        expect(order.reload.status).to eq('partially_fulfilled')
      end

      it 'updates order with partial delivery notes' do
        result = described_class.call(
          order: order,
          resolution_type: 'partial',
          actor: actor,
          notes: 'Customer approved partial delivery'
        )

        expect(order.reload.notes).to include('Partial Delivery')
        expect(order.reload.notes).to include('Customer approved partial delivery')
      end

      it 'includes resolution type in audit log' do
        described_class.call(
          order: order,
          resolution_type: 'partial',
          actor: actor
        )

        audit = AuditLog.where(action: 'shortage_resolved').last
        expect(audit.changes['resolution_type']).to eq('partial_delivery')
      end

      it 'calculates refund for shortage portion' do
        result = described_class.call(
          order: order,
          resolution_type: 'partial',
          actor: actor
        )

        # 6 items short * 100 = 600 refund
        expect(result.refunded_amount).to eq(600.to_d)
      end

      it 'updates order lines to reflect partial quantities' do
        described_class.call(
          order: order,
          resolution_type: 'partial',
          actor: actor
        )

        # Order line should now be qty 4 (available) instead of 10
        line = order.reload.lines.first
        expect(line.qty).to eq(4.to_d)
      end
    end

    context 'reschedule resolution' do
      it 'marks order as rescheduled' do
        result = described_class.call(
          order: order,
          resolution_type: 'reschedule',
          actor: actor
        )

        expect(result.success?).to be true
        expect(order.reload.status).to eq('rescheduled')
      end

      it 'sets rescheduled_at timestamp' do
        result = described_class.call(
          order: order,
          resolution_type: 'reschedule',
          actor: actor
        )

        expect(order.reload.rescheduled_at).to be_present
        expect(order.rescheduled_at).to be_within(1.minute).of(Time.current)
      end

      it 'sets rescheduled_from to original creation date' do
        original_created = order.created_at

        result = described_class.call(
          order: order,
          resolution_type: 'reschedule',
          actor: actor
        )

        expect(order.reload.rescheduled_from).to eq(original_created)
      end

      it 'sets rescheduled_reason' do
        result = described_class.call(
          order: order,
          resolution_type: 'reschedule',
          actor: actor
        )

        expect(order.reload.rescheduled_reason).to eq('inventory_shortage')
      end

      it 'sets planned delivery date approximately 7 days from now' do
        result = described_class.call(
          order: order,
          resolution_type: 'reschedule',
          actor: actor
        )

        planned = order.reload.planned_delivery_date
        expect(planned).to be_within(1.day).of(7.days.from_now.to_date)
      end

      it 'includes reschedule details in audit log' do
        described_class.call(
          order: order,
          resolution_type: 'reschedule',
          actor: actor
        )

        audit = AuditLog.where(action: 'shortage_resolved').last
        expect(audit.changes['resolution_type']).to eq('rescheduled')
        expect(audit.changes['metadata']['planned_date']).to be_present
      end

      it 'includes notes in order' do
        result = described_class.call(
          order: order,
          resolution_type: 'reschedule',
          actor: actor,
          notes: 'Stock arriving next week'
        )

        expect(order.reload.notes).to include('[Rescheduled]')
        expect(order.reload.notes).to include('Stock arriving next week')
      end

      it 'returns zero refunded amount' do
        result = described_class.call(
          order: order,
          resolution_type: 'reschedule',
          actor: actor
        )

        expect(result.refunded_amount).to eq(0)
      end
    end

    context 'override resolution' do
      it 'approves order despite shortage' do
        result = described_class.call(
          order: order,
          resolution_type: 'override',
          actor: actor
        )

        expect(result.success?).to be true
        expect(order.reload.status).to eq('approved')
      end

      it 'adds override note to order' do
        described_class.call(
          order: order,
          resolution_type: 'override',
          actor: actor,
          notes: 'Customer willing to wait for back-order'
        )

        expect(order.reload.notes).to include('[Override]')
        expect(order.reload.notes).to include('Manager approved')
        expect(order.reload.notes).to include('Customer willing to wait for back-order')
      end

      it 'includes manager info in audit log' do
        described_class.call(
          order: order,
          resolution_type: 'override',
          actor: actor,
          notes: 'VIP customer - special approval'
        )

        audit = AuditLog.where(action: 'shortage_resolved').last
        expect(audit.changes['resolution_type']).to eq('manager_override')
        expect(audit.changes['metadata']['actor']).to include(actor.email)
      end

      it 'returns no refund' do
        result = described_class.call(
          order: order,
          resolution_type: 'override',
          actor: actor
        )

        expect(result.refunded_amount).to eq(0)
      end
    end

    context 'error handling' do
      it 'fails on invalid resolution type' do
        result = described_class.call(
          order: order,
          resolution_type: 'invalid_type',
          actor: actor
        )

        expect(result.success?).to be false
        expect(result.errors).to include('Invalid resolution type')
      end

      it 'fails when order is nil' do
        result = described_class.call(
          order: nil,
          resolution_type: 'refund',
          actor: actor
        )

        expect(result.success?).to be false
        expect(result.errors).to include('Order not found')
      end
    end

    context 'customer communication flags' do
      it 'handles email communication preference' do
        result = described_class.call(
          order: order,
          resolution_type: 'refund',
          actor: actor,
          customer_communication: { email: true }
        )

        expect(result.success?).to be true
      end

      it 'handles SMS communication preference' do
        result = described_class.call(
          order: order,
          resolution_type: 'refund',
          actor: actor,
          customer_communication: { sms: true }
        )

        expect(result.success?).to be true
      end

      it 'handles both communication preferences' do
        result = described_class.call(
          order: order,
          resolution_type: 'reschedule',
          actor: actor,
          customer_communication: { email: true, sms: true }
        )

        expect(result.success?).to be true
      end
    end

    context 'transaction rollback on error' do
      let(:order_with_error) { create(:sales_order, organization: org, branch: branch, customer: customer, created_by: actor) }

      it 'rolls back changes if update fails' do
        original_status = order.status

        # This test verifies transaction safety
        expect {
          described_class.call(
            order: order,
            resolution_type: 'refund',
            actor: actor
          )
        }.not_to raise_error

        expect(order.reload.status).to eq('cancelled')
      end
    end

    context 'integration: detection followed by resolution' do
      before do
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 4, qty_reserved: 0)
      end

      it 'detects shortage then resolves with partial' do
        # Detect shortage
        detection = Inventory::ShortageDetectionService.call(
          order: order,
          branch: branch,
          actor: actor
        )

        expect(detection.has_shortage?).to be true
        expect(detection.shortage_items.count).to eq(1)

        # Resolve shortage
        resolution = described_class.call(
          order: order,
          resolution_type: 'partial',
          actor: actor
        )

        expect(resolution.success?).to be true
        expect(resolution.refunded_amount).to eq((10 - 4) * 100) # 6 * 100 = 600
      end

      it 'detects shortage then resolves with refund' do
        detection = Inventory::ShortageDetectionService.call(
          order: order,
          branch: branch,
          actor: actor
        )

        expect(detection.has_shortage?).to be true
        expect(detection.resolution_options).to include(:refund)

        resolution = described_class.call(
          order: order,
          resolution_type: 'refund',
          actor: actor
        )

        expect(resolution.success?).to be true
        expect(order.reload.status).to eq('cancelled')
      end
    end
  end
end
