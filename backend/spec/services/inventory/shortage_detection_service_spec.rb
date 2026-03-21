require 'rails_helper'

RSpec.describe Inventory::ShortageDetectionService, type: :service do
  let(:org) { create(:organization) }
  let(:branch) { create(:branch, organization: org) }
  let(:customer) { create(:customer, organization: org, branch: branch) }
  let(:actor) { create(:user) }
  let(:product1) { create(:product, organization: org, name: 'Widget A', sku: 'SKU-001') }
  let(:product2) { create(:product, organization: org, name: 'Gadget B', sku: 'SKU-002') }

  describe '.call' do
    context 'no shortage: sufficient inventory' do
      let(:order) { create(:sales_order, organization: org, branch: branch, customer: customer, created_by: actor) }

      before do
        create(:inventory_level, organization: org, branch: branch, product: product1,
               qty_on_hand: 100, qty_reserved: 0)
        create(:inventory_level, organization: org, branch: branch, product: product2,
               qty_on_hand: 50, qty_reserved: 0)

        create(:sales_order_line, sales_order: order, product: product1, qty: 10, unit_price: 100)
        create(:sales_order_line, sales_order: order, product: product2, qty: 20, unit_price: 50)
      end

      it 'returns has_shortage? = false' do
        result = described_class.call(order: order, branch: branch, actor: actor)
        expect(result.has_shortage?).to be false
      end

      it 'returns empty shortage items' do
        result = described_class.call(order: order, branch: branch, actor: actor)
        expect(result.shortage_items).to be_empty
      end

      it 'returns zero total shortage value' do
        result = described_class.call(order: order, branch: branch, actor: actor)
        expect(result.total_shortage_value).to eq(0)
      end

      it 'returns empty resolution options' do
        result = described_class.call(order: order, branch: branch, actor: actor)
        expect(result.resolution_options).to be_empty
      end
    end

    context 'complete shortage: zero inventory' do
      let(:order) { create(:sales_order, organization: org, branch: branch, customer: customer, created_by: actor) }

      before do
        create(:inventory_level, organization: org, branch: branch, product: product1,
               qty_on_hand: 0, qty_reserved: 0)

        create(:sales_order_line, sales_order: order, product: product1, qty: 10, unit_price: 100)
      end

      it 'detects shortage' do
        result = described_class.call(order: order, branch: branch, actor: actor)
        expect(result.has_shortage?).to be true
      end

      it 'returns shortage item with correct details' do
        result = described_class.call(order: order, branch: branch, actor: actor)
        expect(result.shortage_items.count).to eq(1)

        item = result.shortage_items.first
        expect(item.product_id).to eq(product1.id)
        expect(item.requested_qty).to eq(10.to_d)
        expect(item.available_qty).to eq(0.to_d)
        expect(item.shortage_qty).to eq(10.to_d)
        expect(item.shortage_value).to eq(1_000.to_d)
      end

      it 'returns correct total shortage value' do
        result = described_class.call(order: order, branch: branch, actor: actor)
        expect(result.total_shortage_value).to eq(1_000.to_d)
      end

      it 'includes refund in resolution options' do
        result = described_class.call(order: order, branch: branch, actor: actor)
        expect(result.resolution_options).to include(:refund)
      end

      it 'does not include partial in resolution options' do
        result = described_class.call(order: order, branch: branch, actor: actor)
        expect(result.resolution_options).not_to include(:partial)
      end

      it 'includes reschedule in resolution options' do
        result = described_class.call(order: order, branch: branch, actor: actor)
        expect(result.resolution_options).to include(:reschedule)
      end
    end

    context 'partial shortage: some inventory available' do
      let(:order) { create(:sales_order, organization: org, branch: branch, customer: customer, created_by: actor) }

      before do
        create(:inventory_level, organization: org, branch: branch, product: product1,
               qty_on_hand: 6, qty_reserved: 0)

        create(:sales_order_line, sales_order: order, product: product1, qty: 10, unit_price: 100)
      end

      it 'detects shortage' do
        result = described_class.call(order: order, branch: branch, actor: actor)
        expect(result.has_shortage?).to be true
      end

      it 'reports available and shortage quantities correctly' do
        result = described_class.call(order: order, branch: branch, actor: actor)
        item = result.shortage_items.first

        expect(item.requested_qty).to eq(10.to_d)
        expect(item.available_qty).to eq(6.to_d)
        expect(item.shortage_qty).to eq(4.to_d)
        expect(item.shortage_value).to eq(400.to_d)
      end

      it 'includes partial in resolution options' do
        result = described_class.call(order: order, branch: branch, actor: actor)
        expect(result.resolution_options).to include(:partial)
      end

      it 'includes refund in resolution options' do
        result = described_class.call(order: order, branch: branch, actor: actor)
        expect(result.resolution_options).to include(:refund)
      end

      it 'includes reschedule in resolution options' do
        result = described_class.call(order: order, branch: branch, actor: actor)
        expect(result.resolution_options).to include(:reschedule)
      end
    end

    context 'multiple items with mixed shortages' do
      let(:order) { create(:sales_order, organization: org, branch: branch, customer: customer, created_by: actor) }

      before do
        # Product 1: Complete shortage
        create(:inventory_level, organization: org, branch: branch, product: product1,
               qty_on_hand: 0, qty_reserved: 0)

        # Product 2: Partial shortage
        create(:inventory_level, organization: org, branch: branch, product: product2,
               qty_on_hand: 5, qty_reserved: 0)

        create(:sales_order_line, sales_order: order, product: product1, qty: 10, unit_price: 100)
        create(:sales_order_line, sales_order: order, product: product2, qty: 20, unit_price: 50)
      end

      it 'detects both shortages' do
        result = described_class.call(order: order, branch: branch, actor: actor)
        expect(result.shortage_items.count).to eq(2)
      end

      it 'calculates total shortage value correctly' do
        result = described_class.call(order: order, branch: branch, actor: actor)
        # Product 1: 10 * 100 = 1000
        # Product 2: (20 - 5) * 50 = 750
        # Total: 1750
        expect(result.total_shortage_value).to eq(1_750.to_d)
      end

      it 'includes partial in resolution options (since product2 has some stock)' do
        result = described_class.call(order: order, branch: branch, actor: actor)
        expect(result.resolution_options).to include(:partial)
      end
    end

    context 'reserved inventory deducted from available' do
      let(:order) { create(:sales_order, organization: org, branch: branch, customer: customer, created_by: actor) }

      before do
        # 100 on hand, 30 reserved = 70 available
        create(:inventory_level, organization: org, branch: branch, product: product1,
               qty_on_hand: 100, qty_reserved: 30)

        create(:sales_order_line, sales_order: order, product: product1, qty: 80, unit_price: 100)
      end

      it 'considers reserved inventory in shortage calculation' do
        result = described_class.call(order: order, branch: branch, actor: actor)

        expect(result.has_shortage?).to be true
        item = result.shortage_items.first
        expect(item.available_qty).to eq(70.to_d) # 100 on hand - 30 reserved
        expect(item.shortage_qty).to eq(10.to_d)  # 80 requested - 70 available
      end
    end

    context 'order without explicit branch uses order branch' do
      let(:order) { create(:sales_order, organization: org, branch: branch, customer: customer, created_by: actor) }

      before do
        create(:inventory_level, organization: org, branch: branch, product: product1,
               qty_on_hand: 5, qty_reserved: 0)

        create(:sales_order_line, sales_order: order, product: product1, qty: 10, unit_price: 100)
      end

      it 'uses order branch when not explicitly provided' do
        result = described_class.call(order: order, actor: actor) # no branch param

        expect(result.has_shortage?).to be true
      end
    end

    context 'creates inventory level if it does not exist' do
      let(:order) { create(:sales_order, organization: org, branch: branch, customer: customer, created_by: actor) }

      before do
        # Don't create inventory level; service should handle it
        create(:sales_order_line, sales_order: order, product: product1, qty: 10, unit_price: 100)
      end

      it 'creates missing inventory level' do
        expect {
          described_class.call(order: order, branch: branch, actor: actor)
        }.to change(InventoryLevel, :count).by(1)
      end

      it 'detects shortage when inventory level did not exist' do
        result = described_class.call(order: order, branch: branch, actor: actor)

        expect(result.has_shortage?).to be true
        expect(result.shortage_items.first.available_qty).to eq(0.to_d)
      end
    end

    context 'product metadata preserved in shortage items' do
      let(:order) { create(:sales_order, organization: org, branch: branch, customer: customer, created_by: actor) }

      before do
        create(:inventory_level, organization: org, branch: branch, product: product1,
               qty_on_hand: 0, qty_reserved: 0)

        create(:sales_order_line, sales_order: order, product: product1, qty: 10, unit_price: 250.75)
      end

      it 'includes product name and SKU' do
        result = described_class.call(order: order, branch: branch, actor: actor)
        item = result.shortage_items.first

        expect(item.product_name).to eq('Widget A')
        expect(item.product_sku).to eq('SKU-001')
      end

      it 'includes unit price for value calculation' do
        result = described_class.call(order: order, branch: branch, actor: actor)
        item = result.shortage_items.first

        expect(item.unit_price).to eq(250.75)
        expect(item.shortage_value).to eq((10 * 250.75).round(2))
      end
    end
  end
end
