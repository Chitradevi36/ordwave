require 'rails_helper'

RSpec.describe 'Feature 12: Inventory Shortage Detection & Resolution', type: :integration do
  let(:org) { create(:organization) }
  let(:branch) { create(:branch, organization: org) }
  let(:customer) { create(:customer, organization: org, branch: branch) }
  let(:actor) { create(:user, organization: org) }

  describe 'Complete Shortage Workflow: Detection → Resolution → Notification' do
    context 'Scenario 1: Complete Shortage → Full Refund Path' do
      let(:product) { create(:product, organization: org, name: 'Premium Service') }
      let(:order) do
        o = create(:sales_order, organization: org, branch: branch, customer: customer, created_by: actor)
        create(:sales_order_line, sales_order: o, product: product, qty: 100, unit_price: 50)
        o.recalculate_totals!
        o
      end

      before do
        # Zero inventory - complete shortage
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 0, qty_reserved: 0)
      end

      it 'detects shortage correctly' do
        result = Inventory::ShortageDetectionService.call(
          order: order,
          branch: branch,
          actor: actor
        )

        expect(result.success?).to be true
        expect(result.has_shortage?).to be true
        expect(result.shortage_items.count).to eq(1)
        expect(result.shortage_items.first.shortage_qty).to eq(100)
        expect(result.shortage_items.first.shortage_value).to eq(5000) # 100 * 50
        expect(result.total_shortage_value).to eq(5000)
        expect(result.resolution_options).to include(:refund, :reschedule, :override)
      end

      it 'processes full refund resolution' do
        # Detect
        detection = Inventory::ShortageDetectionService.call(
          order: order,
          branch: branch,
          actor: actor
        )
        expect(detection.has_shortage?).to be true

        # Resolve
        resolution = Inventory::ShortageResolutionService.call(
          order: order,
          resolution_type: 'refund',
          actor: actor,
          notes: 'Out of stock, full refund issued'
        )

        expect(resolution.success?).to be true
        expect(resolution.order.status).to eq('cancelled')
        expect(resolution.order.cancellation_reason).to eq('inventory_shortage')
        expect(resolution.refunded_amount).to eq(5000)
      end

      it 'creates audit trail for entire workflow' do
        detection = Inventory::ShortageDetectionService.call(
          order: order,
          branch: branch,
          actor: actor
        )

        resolution = Inventory::ShortageResolutionService.call(
          order: order,
          resolution_type: 'refund',
          actor: actor
        )

        audit_logs = AuditLog.where(resource_id: order.id, resource_type: 'SalesOrder')
        expect(audit_logs.count).to be >= 1
        expect(audit_logs.pluck(:action)).to include('shortage_resolved')
      end
    end

    context 'Scenario 2: Partial Shortage → Partial Delivery Path' do
      let(:product_a) { create(:product, organization: org, name: 'Product A') }
      let(:product_b) { create(:product, organization: org, name: 'Product B') }
      let(:order) do
        o = create(:sales_order, organization: org, branch: branch, customer: customer, created_by: actor)
        create(:sales_order_line, sales_order: o, product: product_a, qty: 50, unit_price: 20)
        create(:sales_order_line, sales_order: o, product: product_b, qty: 30, unit_price: 40)
        o.recalculate_totals!
        o
      end

      before do
        # Product A: 50 requested, 30 available (20 short)
        create(:inventory_level, organization: org, branch: branch, product: product_a,
               qty_on_hand: 30, qty_reserved: 0)
        # Product B: 30 requested, 25 available (5 short)
        create(:inventory_level, organization: org, branch: branch, product: product_b,
               qty_on_hand: 25, qty_reserved: 0)
      end

      it 'detects partial shortage across multiple items' do
        result = Inventory::ShortageDetectionService.call(
          order: order,
          branch: branch,
          actor: actor
        )

        expect(result.success?).to be true
        expect(result.has_shortage?).to be true
        expect(result.shortage_items.count).to eq(2)
        
        # Check Product A shortage: 50 - 30 = 20 short, 20 * 20 = 400
        product_a_shortage = result.shortage_items.find { |s| s.product_id == product_a.id }
        expect(product_a_shortage.shortage_qty).to eq(20)
        expect(product_a_shortage.shortage_value).to eq(400)
        
        # Check Product B shortage: 30 - 25 = 5 short, 5 * 40 = 200
        product_b_shortage = result.shortage_items.find { |s| s.product_id == product_b.id }
        expect(product_b_shortage.shortage_qty).to eq(5)
        expect(product_b_shortage.shortage_value).to eq(200)
        
        # Total shortage: 400 + 200 = 600
        expect(result.total_shortage_value).to eq(600)
      end

      it 'processes partial delivery with correct refund calculation' do
        detection = Inventory::ShortageDetectionService.call(
          order: order,
          branch: branch,
          actor: actor
        )
        expect(detection.has_shortage?).to be true

        resolution = Inventory::ShortageResolutionService.call(
          order: order,
          resolution_type: 'partial',
          actor: actor,
          notes: 'Partial stock available, customer approved partial delivery'
        )

        expect(resolution.success?).to be true
        expect(resolution.order.status).to eq('partially_fulfilled')
        expect(resolution.refunded_amount).to eq(600) # 20*20 + 5*40
      end

      it 'updates order lines with only available quantities' do
        resolution = Inventory::ShortageResolutionService.call(
          order: order,
          resolution_type: 'partial',
          actor: actor
        )

        order.reload
        lines_by_product = order.lines.index_by(&:product_id)

        # Product A should have qty 30 (available amount)
        expect(lines_by_product[product_a.id].qty).to eq(30.to_d)
        # Product B should have qty 25 (available amount)
        expect(lines_by_product[product_b.id].qty).to eq(25.to_d)
      end
    end

    context 'Scenario 3: Partial Shortage → Reschedule Path' do
      let(:product) { create(:product, organization: org, name: 'Widget Premium') }
      let(:order) do
        o = create(:sales_order, organization: org, branch: branch, customer: customer, created_by: actor)
        create(:sales_order_line, sales_order: o, product: product, qty: 100, unit_price: 75)
        o.recalculate_totals!
        o
      end

      before do
        # 60 available, 40 short
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 60, qty_reserved: 0)
      end

      it 'detects shortage and allows reschedule option' do
        result = Inventory::ShortageDetectionService.call(
          order: order,
          branch: branch,
          actor: actor
        )

        expect(result.has_shortage?).to be true
        expect(result.resolution_options).to include(:reschedule)
      end

      it 'reschedules order with planned delivery date' do
        Inventory::ShortageDetectionService.call(order: order, branch: branch, actor: actor)

        resolution = Inventory::ShortageResolutionService.call(
          order: order,
          resolution_type: 'reschedule',
          actor: actor,
          notes: 'Stock arriving from supplier, expected by next week'
        )

        expect(resolution.success?).to be true
        expect(order.reload.status).to eq('rescheduled')
        expect(order.rescheduled_at).to be_present
        expect(order.planned_delivery_date).to be_present
        expect(order.rescheduled_reason).to eq('inventory_shortage')
      end

      it 'maintains original quantities for rescheduled order' do
        original_qty = order.lines.first.qty

        Inventory::ShortageResolutionService.call(
          order: order,
          resolution_type: 'reschedule',
          actor: actor
        )

        expect(order.reload.lines.first.qty).to eq(original_qty)
      end

      it 'calculates ~7 day reschedule period' do
        Inventory::ShortageResolutionService.call(
          order: order,
          resolution_type: 'reschedule',
          actor: actor
        )

        planned_date = order.reload.planned_delivery_date
        days_out = (planned_date - Date.today).to_i
        expect(days_out).to be_between(6, 8)
      end
    end

    context 'Scenario 4: Complete Shortage → Manager Override Path' do
      let(:product) { create(:product, organization: org, name: 'Exclusive Item') }
      let(:manager) { create(:user, organization: org, role: :manager) }
      let(:order) do
        o = create(:sales_order, organization: org, branch: branch, customer: customer, created_by: actor)
        create(:sales_order_line, sales_order: o, product: product, qty: 200, unit_price: 150)
        o.recalculate_totals!
        o
      end

      before do
        # Zero inventory - complete shortage
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 0, qty_reserved: 0)
      end

      it 'allows manager to override shortage and approve order' do
        detection = Inventory::ShortageDetectionService.call(
          order: order,
          branch: branch,
          actor: actor
        )
        expect(detection.has_shortage?).to be true

        resolution = Inventory::ShortageResolutionService.call(
          order: order,
          resolution_type: 'override',
          actor: manager,
          notes: 'VIP client, expedite from backup supplier'
        )

        expect(resolution.success?).to be true
        expect(order.reload.status).to eq('approved')
      end

      it 'records manager approval in audit trail' do
        Inventory::ShortageResolutionService.call(
          order: order,
          resolution_type: 'override',
          actor: manager,
          notes: 'Special arrangement with supplier'
        )

        audit = AuditLog.where(action: 'shortage_resolved').last
        expect(audit.changes['metadata']['actor']).to include(manager.email)
        expect(audit.changes['resolution_type']).to eq('manager_override')
      end
    end

    context 'Scenario 5: Multiple Items with Mixed Shortages' do
      let(:product_a) { create(:product, organization: org, name: 'Item A') }
      let(:product_b) { create(:product, organization: org, name: 'Item B') }
      let(:product_c) { create(:product, organization: org, name: 'Item C') }
      let(:order) do
        o = create(:sales_order, organization: org, branch: branch, customer: customer, created_by: actor)
        # Item A: 100 qty, no shortage (80 available)
        create(:sales_order_line, sales_order: o, product: product_a, qty: 100, unit_price: 10)
        # Item B: 50 qty, shortage (25 available, 25 short)
        create(:sales_order_line, sales_order: o, product: product_b, qty: 50, unit_price: 20)
        # Item C: 30 qty, complete shortage (0 available, 30 short)
        create(:sales_order_line, sales_order: o, product: product_c, qty: 30, unit_price: 50)
        o.recalculate_totals!
        o
      end

      before do
        create(:inventory_level, organization: org, branch: branch, product: product_a,
               qty_on_hand: 100, qty_reserved: 0)
        create(:inventory_level, organization: org, branch: branch, product: product_b,
               qty_on_hand: 25, qty_reserved: 0)
        create(:inventory_level, organization: org, branch: branch, product: product_c,
               qty_on_hand: 0, qty_reserved: 0)
      end

      it 'detects mixed shortage scenario correctly' do
        result = Inventory::ShortageDetectionService.call(
          order: order,
          branch: branch,
          actor: actor
        )

        expect(result.has_shortage?).to be true
        expect(result.shortage_items.count).to eq(2) # Only B and C have shortage
        
        shortage_qty_total = result.shortage_items.sum(&:shortage_qty)
        expect(shortage_qty_total).to eq(55) # 25 (B) + 30 (C)
      end

      it 'processes partial delivery for mixed scenario' do
        resolution = Inventory::ShortageResolutionService.call(
          order: order,
          resolution_type: 'partial',
          actor: actor
        )

        expect(resolution.success?).to be true
        order.reload

        lines = order.lines.index_by(&:product_id)
        # A: Full qty 100 (no shortage)
        expect(lines[product_a.id].qty).to eq(100.to_d)
        # B: Qty 25 (partial shortage)
        expect(lines[product_b.id].qty).to eq(25.to_d)
        # C: Qty 0 (complete shortage, but partial delivery keeps it)
        expect(lines[product_c.id].qty).to eq(0.to_d)

        # Refund: (100-100)*10 + (50-25)*20 + (30-0)*50 = 0 + 500 + 1500 = 2000
        expect(resolution.refunded_amount).to eq(2000)
      end
    end

    context 'Scenario 6: Reserved Inventory Impact' do
      let(:product) { create(:product, organization: org, name: 'Reserved Item') }
      let(:order) do
        o = create(:sales_order, organization: org, branch: branch, customer: customer, created_by: actor)
        create(:sales_order_line, sales_order: o, product: product, qty: 50, unit_price: 100)
        o.recalculate_totals!
        o
      end

      before do
        # 100 on hand, 60 reserved = 40 available
        # Requesting 50, so 10 short
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 100, qty_reserved: 60)
      end

      it 'correctly calculates available qty after reservations' do
        result = Inventory::ShortageDetectionService.call(
          order: order,
          branch: branch,
          actor: actor
        )

        expect(result.has_shortage?).to be true
        expect(result.shortage_items.first.available_qty).to eq(40) # 100 - 60
        expect(result.shortage_items.first.shortage_qty).to eq(10) # 50 - 40
      end

      it 'processes partial delivery with reserved inventory factored in' do
        resolution = Inventory::ShortageResolutionService.call(
          order: order,
          resolution_type: 'partial',
          actor: actor
        )

        expect(resolution.success?).to be true
        expect(order.reload.lines.first.qty).to eq(40) # Available after reservation
        expect(resolution.refunded_amount).to eq(1000) # 10 * 100
      end
    end

    context 'Scenario 7: Inventory Shortage with Low Stock Scenario' do
      let(:product) { create(:product, organization: org, name: 'Popular Item') }
      let(:order) do
        o = create(:sales_order, organization: org, branch: branch, customer: customer, created_by: actor)
        create(:sales_order_line, sales_order: o, product: product, qty: 100, unit_price: 50)
        o.recalculate_totals!
        o
      end

      before do
        # Only 15 in stock, 100 requested
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 15, qty_reserved: 0, min_qty_threshold: 50)
      end

      it 'detects shortage even when hitting min threshold' do
        result = Inventory::ShortageDetectionService.call(
          order: order,
          branch: branch,
          actor: actor
        )

        expect(result.has_shortage?).to be true
        expect(result.shortage_items.first.shortage_qty).to eq(85)
      end

      it 'processes partial delivery with min threshold maintained' do
        resolution = Inventory::ShortageResolutionService.call(
          order: order,
          resolution_type: 'partial',
          actor: actor
        )

        expect(resolution.success?).to be true
        # Partial delivery uses available qty (15), respects that min_qty is informational
        expect(order.reload.lines.first.qty).to eq(15.to_d)
      end
    end

    context 'Scenario 8: Order Total Recalculation After Partial' do
      let(:product) { create(:product, organization: org, name: 'Premium Widget') }
      let(:order) do
        o = create(:sales_order, organization: org, branch: branch, customer: customer, created_by: actor)
        create(:sales_order_line, sales_order: o, product: product, qty: 100, unit_price: 50)
        o.recalculate_totals!
        o
      end

      before do
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 40, qty_reserved: 0)
      end

      it 'recalculates order totals after partial resolution' do
        original_total = order.total.to_d

        Inventory::ShortageResolutionService.call(
          order: order,
          resolution_type: 'partial',
          actor: actor
        )

        order.reload
        # Original: 100 * 50 = 5000
        # After partial: 40 * 50 = 2000
        expect(order.total.to_d).to eq(2000)
        expect(order.total.to_d).to be < original_total
      end
    end
  end

  describe 'Error Scenarios & Edge Cases' do
    let(:product) { create(:product, organization: org, name: 'Test Product') }
    let(:order) do
      o = create(:sales_order, organization: org, branch: branch, customer: customer, created_by: actor)
      create(:sales_order_line, sales_order: o, product: product, qty: 50, unit_price: 100)
      o.recalculate_totals!
      o
    end

    context 'when inventory level does not exist' do
      it 'creates inventory level on detection' do
        expect {
          Inventory::ShortageDetectionService.call(
            order: order,
            branch: branch,
            actor: actor
          )
        }.to change { InventoryLevel.count }.by(1)
      end

      it 'treats missing inventory as zero available' do
        result = Inventory::ShortageDetectionService.call(
          order: order,
          branch: branch,
          actor: actor
        )

        expect(result.has_shortage?).to be true
        expect(result.shortage_items.first.available_qty).to eq(0)
        expect(result.shortage_items.first.shortage_qty).to eq(50)
      end
    end

    context 'when order has no lines' do
      let(:empty_order) do
        create(:sales_order, organization: org, branch: branch, customer: customer, created_by: actor)
      end

      it 'detects no shortage' do
        result = Inventory::ShortageDetectionService.call(
          order: empty_order,
          branch: branch,
          actor: actor
        )

        expect(result.success?).to be true
        expect(result.has_shortage?).to be false
        expect(result.shortage_items).to be_empty
      end
    end

    context 'when resolving non-existent order' do
      it 'fails gracefully' do
        result = Inventory::ShortageResolutionService.call(
          order: nil,
          resolution_type: 'refund',
          actor: actor
        )

        expect(result.success?).to be false
        expect(result.errors).to include('Order not found')
      end
    end
  end
end
