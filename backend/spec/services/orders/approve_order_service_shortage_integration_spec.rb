require 'rails_helper'

RSpec.describe Orders::ApproveOrderService, type: :service do
  let(:org) { create(:organization) }
  let(:branch) { create(:branch, organization: org) }
  let(:customer) { create(:customer, organization: org, branch: branch) }
  let(:actor) { create(:user, organization: org) }
  let(:product) { create(:product, organization: org, name: 'Widget') }

  let(:order) do
    o = create(:sales_order, organization: org, branch: branch, customer: customer, created_by: actor, status: 'on_hold')
    create(:sales_order_line, sales_order: o, product: product, qty: 50, unit_price: 100)
    o.recalculate_totals!
    o
  end

  describe 'Feature 12 Integration: Shortage Detection During Approval' do
    context 'when no shortage exists' do
      before do
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 100, qty_reserved: 0)
      end

      it 'approves order immediately' do
        result = described_class.call(
          actor:    actor,
          order:    order,
          decision: 'approved'
        )

        expect(result[:ok]).to be true
        expect(result[:shortage_blocked]).to be false
        expect(order.reload.status).to eq('approved')
      end

      it 'does not return shortage_detection info' do
        result = described_class.call(
          actor:    actor,
          order:    order,
          decision: 'approved'
        )

        expect(result[:shortage_blocked]).to be_falsey
      end
    end

    context 'when partial shortage exists' do
      before do
        # 50 requested, 30 available, 20 short
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 30, qty_reserved: 0)
      end

      it 'blocks approval and returns shortage details' do
        result = described_class.call(
          actor:    actor,
          order:    order,
          decision: 'approved'
        )

        expect(result[:ok]).to be false
        expect(result[:shortage_blocked]).to be true
        expect(order.reload.status).to eq('on_hold') # No status change
      end

      it 'returns shortage_detection with required fields' do
        result = described_class.call(
          actor:    actor,
          order:    order,
          decision: 'approved'
        )

        shortage = result[:shortage_detection]
        expect(shortage[:has_shortage]).to be true
        expect(shortage[:shortage_items]).to be_present
        expect(shortage[:total_shortage_qty]).to eq(20)
        expect(shortage[:total_shortage_value]).to eq(2000)
        expect(shortage[:resolution_options]).to include(:refund, :partial, :reschedule, :override)
      end

      it 'includes serialized shortage items' do
        result = described_class.call(
          actor:    actor,
          order:    order,
          decision: 'approved'
        )

        item = result[:shortage_detection][:shortage_items].first
        expect(item[:product_id]).to eq(product.id)
        expect(item[:product_name]).to eq('Widget')
        expect(item[:requested_qty]).to eq(50)
        expect(item[:available_qty]).to eq(30)
        expect(item[:shortage_qty]).to eq(20)
        expect(item[:unit_price]).to eq(100)
        expect(item[:shortage_value]).to eq(2000)
      end

      it 'includes actionable message in shortage_detection' do
        result = described_class.call(
          actor:    actor,
          order:    order,
          decision: 'approved'
        )

        expect(result[:shortage_detection][:message]).to include('resolve shortage')
      end
    end

    context 'when complete shortage exists' do
      before do
        # 50 requested, 0 available, 50 short
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 0, qty_reserved: 0)
      end

      it 'blocks approval with complete shortage info' do
        result = described_class.call(
          actor:    actor,
          order:    order,
          decision: 'approved'
        )

        expect(result[:shortage_blocked]).to be true
        expect(result[:shortage_detection][:total_shortage_qty]).to eq(50)
        expect(result[:shortage_detection][:total_shortage_value]).to eq(5000)
      end
    end

    context 'when multiple items have mixed shortages' do
      let(:product_b) { create(:product, organization: org, name: 'Item B') }
      let(:order) do
        o = create(:sales_order, organization: org, branch: branch, customer: customer, created_by: actor, status: 'on_hold')
        create(:sales_order_line, sales_order: o, product: product, qty: 100, unit_price: 10)
        create(:sales_order_line, sales_order: o, product: product_b, qty: 50, unit_price: 20)
        o.recalculate_totals!
        o
      end

      before do
        # Product A: no shortage
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 100, qty_reserved: 0)
        # Product B: partial shortage
        create(:inventory_level, organization: org, branch: branch, product: product_b,
               qty_on_hand: 25, qty_reserved: 0)
      end

      it 'reports shortage for affected items only' do
        result = described_class.call(
          actor:    actor,
          order:    order,
          decision: 'approved'
        )

        expect(result[:shortage_blocked]).to be true
        items = result[:shortage_detection][:shortage_items]
        expect(items.count).to eq(1) # Only product_b
        expect(items.first[:product_id]).to eq(product_b.id)
        expect(items.first[:shortage_qty]).to eq(25)
      end
    end

    context 'rejection bypasses shortage check' do
      before do
        # Complete shortage but rejecting anyway
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 0, qty_reserved: 0)
      end

      it 'rejects order without checking shortages' do
        result = described_class.call(
          actor:    actor,
          order:    order,
          decision: 'rejected',
          reason:   'Insufficient credit'
        )

        expect(result[:ok]).to be true # Rejection succeeds
        expect(result[:shortage_blocked]).to be_falsey
        expect(order.reload.status).to eq('rejected')
      end
    end

    context 'end-to-end: shortage detection → resolution → approval' do
      before do
        # 50 requested, 30 available, 20 short
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 30, qty_reserved: 0)
      end

      it 'blocks on first approval due to shortage' do
        result1 = described_class.call(
          actor:    actor,
          order:    order,
          decision: 'approved'
        )

        expect(result1[:shortage_blocked]).to be true
        expect(order.reload.status).to eq('on_hold')
      end

      it 'approves after partial resolution' do
        # First attempt - blocked by shortage
        result1 = described_class.call(
          actor:    actor,
          order:    order,
          decision: 'approved'
        )
        expect(result1[:shortage_blocked]).to be true

        # Resolve via partial delivery
        Inventory::ShortageResolutionService.call(
          order:            order,
          resolution_type:  'partial',
          actor:            actor
        )

        # Second attempt - should approve now (shortage already resolved)
        result2 = described_class.call(
          actor:    actor,
          order:    order,
          decision: 'approved'
        )

        expect(result2[:ok]).to be true
        expect(result2[:shortage_blocked]).to be_falsey
        expect(order.reload.status).to eq('approved')
      end

      it 'approves after reschedule resolution' do
        # First attempt - blocked by shortage
        described_class.call(
          actor:    actor,
          order:    order,
          decision: 'approved'
        )

        # Resolve via reschedule
        Inventory::ShortageResolutionService.call(
          order:            order,
          resolution_type:  'reschedule',
          actor:            actor
        )

        # Second attempt - approve
        result = described_class.call(
          actor:    actor,
          order:    order,
          decision: 'approved'
        )

        expect(result[:ok]).to be true
        expect(order.reload.status).to eq('approved')
      end

      it 'approves after override resolution' do
        # First attempt - blocked by shortage
        described_class.call(
          actor:    actor,
          order:    order,
          decision: 'approved'
        )

        # Resolve via override (manager approval)
        Inventory::ShortageResolutionService.call(
          order:            order,
          resolution_type:  'override',
          actor:            actor
        )

        # Attempt to approve - should succeed
        result = described_class.call(
          actor:    actor,
          order:    order,
          decision: 'approved'
        )

        expect(result[:ok]).to be true
        expect(order.reload.status).to eq('approved')
      end
    end

    context 'shortage detection does not create audit logs' do
      before do
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 30, qty_reserved: 0)
      end

      it 'does not log blocked approval attempt' do
        expect {
          described_class.call(
            actor:    actor,
            order:    order,
            decision: 'approved'
          )
        }.not_to change { AuditLog.count }
      end

      it 'creates audit log only on actual approval' do
        # Create inventory to allow approval
        order.lines.first.update(qty: 30) # Match available qty

        expect {
          described_class.call(
            actor:    actor,
            order:    order,
            decision: 'approved'
          )
        }.to change { AuditLog.count }.by(1)
      end
    end

    context 'when dunning suspension exists' do
      before do
        customer.update(dunning_suspended_at: Time.current)
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 100, qty_reserved: 0)
      end

      it 'blocks due to dunning suspension before checking shortages' do
        result = described_class.call(
          actor:    actor,
          order:    order,
          decision: 'approved'
        )

        expect(result[:ok]).to be false
        expect(result[:errors]).to include(/suspended/)
        expect(result[:shortage_blocked]).to be_falsey # Dunning check comes first
      end
    end

    context 'error handling' do
      before do
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 100, qty_reserved: 0)
      end

      it 'handles invalid decision gracefully' do
        result = described_class.call(
          actor:    actor,
          order:    order,
          decision: 'invalid'
        )

        expect(result[:ok]).to be false
        expect(result[:errors]).to include(/Invalid decision/)
      end

      it 'still detects shortages even if pick list creation fails' do
        allow_any_instance_of(described_class).to receive(:create_pick_list_for_order).and_return(nil)

        # Update inventory to trigger shortage
        order.lines.first.update(qty: 200)
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 100, qty_reserved: 0)

        result = described_class.call(
          actor:    actor,
          order:    order,
          decision: 'approved'
        )

        expect(result[:shortage_blocked]).to be true
      end
    end

    context 'reserved inventory deduction' do
      let(:existing_order) do
        o = create(:sales_order, organization: org, branch: branch, customer: customer, created_by: actor)
        create(:sales_order_line, sales_order: o, product: product, qty: 40, unit_price: 100)
        o.recalculate_totals!
        o
      end

      before do
        # 150 on hand, 40 reserved for existing order = 110 available
        inv = create(:inventory_level, organization: org, branch: branch, product: product,
                     qty_on_hand: 150, qty_reserved: 40)
        # Current order wants 50, only 110 available (after reservations) - no shortage
      end

      it 'accounts for reserved inventory in shortage detection' do
        result = described_class.call(
          actor:    actor,
          order:    order,
          decision: 'approved'
        )

        # 50 requested vs 110 available = no shortage
        expect(result[:ok]).to be true
        expect(result[:shortage_blocked]).to be_falsey
      end

      it 'detects shortage when reserved inventory blocks fulfillment' do
        # Increase reservation to 120 (only 30 available for new order)
        InventoryLevel.find_by(organization: org, branch: branch, product: product)
                      .update(qty_reserved: 120)

        result = described_class.call(
          actor:    actor,
          order:    order,
          decision: 'approved'
        )

        # 50 requested vs 30 available = 20 short
        expect(result[:shortage_blocked]).to be true
        expect(result[:shortage_detection][:total_shortage_qty]).to eq(20)
      end
    end
  end
end
