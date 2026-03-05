require 'rails_helper'

RSpec.describe Returns::CompleteQc, type: :service do
  let(:org)     { create(:organization) }
  let(:branch)  { create(:branch, organization: org) }
  let(:customer){ create(:customer, organization: org) }
  let(:actor)   { create(:user) }
  let(:product) { create(:product, organization: org) }

  # Build a return_request already in qc_in_progress with price snapshots set
  let(:return_request) do
    rr = create(:return_request, organization: org, branch: branch, customer: customer,
                 created_by: actor, status: 'qc_in_progress')
    rr
  end

  let(:return_line) do
    create(:return_line,
           return_request:     return_request,
           product:            product,
           qty_reported:       5,
           unit_price_snapshot: 100.0,
           gst_rate_snapshot:  18.0)
  end

  def call(qc_lines: nil)
    qc_lines ||= [
      {
        return_line_id:  return_line.id,
        qty_resalable:   3,
        qty_damaged:     1,
        qty_expired:     0,
        condition_final: 'mixed'
      }
    ]
    described_class.call(actor: actor, return_request: return_request, qc_lines: qc_lines)
  end

  # Seed some stock so return_received movement has something to post into
  before do
    Inventory::PostMovement.call(
      org: org, branch: branch, product: product,
      movement_type: 'purchase_posted', quantity: 50, actor: actor
    )
  end

  describe '.call' do
    context 'with valid QC data' do
      it 'returns success' do
        expect(call.success?).to be true
      end

      it 'transitions the return request to qc_completed' do
        call
        expect(return_request.reload.status).to eq('qc_completed')
      end

      it 'creates a ReturnQcItem for the line' do
        expect { call }.to change(ReturnQcItem, :count).by(1)
      end

      it 'records the correct qty_resalable on the QC item' do
        call
        expect(return_line.reload.qc_item.qty_resalable).to eq(3)
      end

      it 'updates qty_accepted on the return line' do
        call
        expect(return_line.reload.qty_accepted).to eq(3)
      end

      it 'updates qty_rejected on the return line (damaged + expired)' do
        call
        expect(return_line.reload.qty_rejected).to eq(1)
      end

      it 'posts a return_received StockMovement for resalable qty' do
        expect {
          call
        }.to change { StockMovement.where(movement_type: 'return_received').count }.by(1)
      end

      it 'posts resalable qty (not damaged/expired) to inventory' do
        call
        mv = StockMovement.where(movement_type: 'return_received').last
        expect(mv.qty).to eq(3)
      end

      it 'increases qty_on_hand by resalable quantity only' do
        expect {
          call
        }.to change {
          InventoryLevel.find_by(organization: org, branch: branch, product: product)&.qty_on_hand.to_d
        }.by(3)
      end

      it 'does NOT post an inventory movement for damaged/expired items' do
        call
        movements = StockMovement.where(product: product, movement_type: 'return_received')
        expect(movements.sum(:qty)).to eq(3)   # only the resalable 3
      end

      it 'creates an audit log entry' do
        expect { call }.to change(AuditLog, :count).by(1)
      end

      it 'sets audit log action to return_qc_completed' do
        call
        expect(AuditLog.last.action).to eq('return_qc_completed')
      end
    end

    context 'when QC total exceeds qty_reported' do
      it 'returns failure' do
        result = call(qc_lines: [
          { return_line_id: return_line.id, qty_resalable: 4, qty_damaged: 2, qty_expired: 1 }
        ])
        expect(result.success?).to be false
        expect(result.errors.join).to match(/exceeds qty_reported/i)
      end

      it 'does not post any inventory movement' do
        expect {
          call(qc_lines: [
            { return_line_id: return_line.id, qty_resalable: 4, qty_damaged: 2, qty_expired: 1 }
          ])
        }.not_to change(StockMovement, :count)
      end

      it 'does not transition the return request' do
        call(qc_lines: [
          { return_line_id: return_line.id, qty_resalable: 4, qty_damaged: 2, qty_expired: 1 }
        ])
        expect(return_request.reload.status).to eq('qc_in_progress')
      end
    end

    context 'when all quantity is damaged (zero resalable)' do
      it 'does not post an inventory movement' do
        expect {
          call(qc_lines: [
            { return_line_id: return_line.id, qty_resalable: 0, qty_damaged: 5, qty_expired: 0 }
          ])
        }.not_to change { StockMovement.where(movement_type: 'return_received').count }
      end

      it 'still transitions to qc_completed' do
        result = call(qc_lines: [
          { return_line_id: return_line.id, qty_resalable: 0, qty_damaged: 5, qty_expired: 0 }
        ])
        expect(result.success?).to be true
        expect(result.return_request.reload.status).to eq('qc_completed')
      end
    end

    context 'when return_request is not in qc_in_progress' do
      let(:return_request) do
        create(:return_request, organization: org, branch: branch, customer: customer,
               created_by: actor, status: 'submitted')
      end

      it 'returns failure without touching inventory' do
        result = call
        expect(result.success?).to be false
        expect(result.errors.join).to match(/qc_in_progress/i)
      end
    end

    context 'when qc_lines is empty' do
      it 'returns failure' do
        result = call(qc_lines: [])
        expect(result.success?).to be false
        expect(result.errors).not_to be_empty
      end
    end

    context 'atomicity — when one line fails, none are committed' do
      let(:product2) { create(:product, organization: org) }
      let!(:line2) do
        create(:return_line, return_request: return_request, product: product2,
               qty_reported: 2, unit_price_snapshot: 50.0, gst_rate_snapshot: 5.0)
      end

      it 'rolls back all changes when a second line has invalid totals' do
        expect {
          call(qc_lines: [
            { return_line_id: return_line.id, qty_resalable: 3, qty_damaged: 1, qty_expired: 0 },
            { return_line_id: line2.id,       qty_resalable: 1, qty_damaged: 1, qty_expired: 1 }  # total 3 > 2
          ])
        }.not_to change(ReturnQcItem, :count)
      end
    end
  end
end
