require 'rails_helper'

RSpec.describe Inventory::PostMovement, type: :service do
  let(:org)     { create(:organization) }
  let(:branch)  { create(:branch, organization: org) }
  let(:product) { create(:product, organization: org) }
  let(:actor)   { create(:user) }

  def call(**overrides)
    described_class.call(
      org:           org,
      branch:        branch,
      product:       product,
      movement_type: 'purchase_posted',
      quantity:      10,
      actor:         actor,
      **overrides
    )
  end

  describe '.call' do
    context 'with valid inputs (in-movement)' do
      it 'returns success' do
        result = call
        expect(result.success?).to be true
      end

      it 'creates a StockMovement record' do
        expect { call }.to change(StockMovement, :count).by(1)
      end

      it 'sets direction to in' do
        call
        expect(StockMovement.last.direction).to eq('in')
      end

      it 'increases qty_on_hand on InventoryLevel' do
        expect { call }.to change {
          InventoryLevel.find_by(organization: org, branch: branch, product: product)&.qty_on_hand.to_d
        }.by(10)
      end

      it 'sets occurred_at to Time.current when not provided' do
        freeze_time = Time.current
        travel_to(freeze_time) do
          call
        end
        expect(StockMovement.last.occurred_at).to be_within(1.second).of(freeze_time)
      end
    end

    context 'when movement_type is invalid' do
      it 'returns failure with descriptive error' do
        result = call(movement_type: 'explode_stock')
        expect(result.success?).to be false
        expect(result.errors.join).to match(/Invalid movement_type/i)
      end

      it 'does not create a StockMovement' do
        expect { call(movement_type: 'explode_stock') }.not_to change(StockMovement, :count)
      end
    end

    context 'when quantity is zero or negative' do
      it 'returns failure for zero' do
        result = call(quantity: 0)
        expect(result.success?).to be false
        expect(result.errors.join).to match(/quantity/i)
      end

      it 'returns failure for negative' do
        result = call(quantity: -5)
        expect(result.success?).to be false
      end
    end

    context 'stock-out movement (sale_dispatched)' do
      before do
        # Seed some stock first via purchase_posted
        described_class.call(
          org: org, branch: branch, product: product,
          movement_type: 'purchase_posted', quantity: 20, actor: actor
        )
      end

      it 'decreases qty_on_hand' do
        expect {
          described_class.call(
            org: org, branch: branch, product: product,
            movement_type: 'sale_dispatched', quantity: 5, actor: actor
          )
        }.to change {
          InventoryLevel.find_by(organization: org, branch: branch, product: product).qty_on_hand.to_d
        }.by(-5)
      end

      it 'prevents going negative (insufficient stock)' do
        result = described_class.call(
          org: org, branch: branch, product: product,
          movement_type: 'sale_dispatched', quantity: 100, actor: actor
        )
        expect(result.success?).to be false
        expect(result.errors.join).to match(/insufficient stock/i)
      end
    end

    context 'reserve movement (sale_reserved)' do
      before do
        described_class.call(
          org: org, branch: branch, product: product,
          movement_type: 'purchase_posted', quantity: 50, actor: actor
        )
      end

      it 'increases qty_reserved' do
        expect {
          described_class.call(
            org: org, branch: branch, product: product,
            movement_type: 'sale_reserved', quantity: 10, actor: actor
          )
        }.to change {
          InventoryLevel.find_by(organization: org, branch: branch, product: product).qty_reserved.to_d
        }.by(10)
      end
    end

    context 'immutability' do
      it 'raises when attempting to update an existing movement' do
        call
        mv = StockMovement.last
        expect { mv.update!(qty: 999) }.to raise_error(ActiveRecord::ReadOnlyRecord)
      end

      it 'raises when attempting to destroy an existing movement' do
        call
        mv = StockMovement.last
        expect { mv.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
      end
    end
  end
end
