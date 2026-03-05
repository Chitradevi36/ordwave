require 'rails_helper'

RSpec.describe Orders::LimitedUpdateService, type: :service do
  let(:org)      { create(:organization) }
  let(:branch)   { create(:branch, organization: org) }
  let(:customer) { create(:customer, organization: org, branch: branch) }
  let(:actor)    { create(:user) }

  def create_order(status:, **attrs)
    extra = case status
            when 'submitted'             then { submitted_at: Time.current }
            when 'on_hold'               then { submitted_at: Time.current }
            when 'approved'              then { submitted_at: Time.current, approved_at: Time.current }
            when 'cancelled'             then { submitted_at: Time.current, cancellation_reason: 'test', cancelled_at: Time.current }
            else {}
            end
    create(:sales_order,
           organization: org, branch: branch, customer: customer, created_by: actor,
           status: status, **extra, **attrs)
  end

  # ── Guard: only submitted / on_hold are limited-editable ─────────────────
  describe 'when order is not in a limited-editable state' do
    %w[draft approved rejected cancelled].each do |bad_status|
      it "returns ok: false for #{bad_status} orders" do
        order = create_order(status: bad_status)

        result = described_class.call(
          actor:  actor,
          order:  order,
          params: { delivery_date: 3.days.from_now.to_date, notes: 'new note' }
        )

        expect(result[:ok]).to be false
        expect(result[:errors]).to include('Order is not in a limited-editable state')
      end
    end
  end

  # ── Happy path: submitted ─────────────────────────────────────────────────
  describe 'when order is submitted' do
    let!(:order) { create_order(status: 'submitted', delivery_date: 7.days.from_now.to_date, notes: 'original') }

    it 'updates delivery_date and notes' do
      new_date = 10.days.from_now.to_date

      result = described_class.call(
        actor:  actor,
        order:  order,
        params: { delivery_date: new_date, notes: 'updated note' }
      )

      expect(result[:ok]).to be true
      expect(result[:order].delivery_date).to eq(new_date)
      expect(result[:order].notes).to eq('updated note')
    end

    it 'writes an order_updated audit log entry' do
      expect {
        described_class.call(
          actor:  actor,
          order:  order,
          params: { notes: 'audit check' }
        )
      }.to change { AuditLog.where(auditable: order, action: 'order_updated').count }.by(1)
    end

    it 'records the before/after changes in the audit log' do
      old_notes = order.notes
      described_class.call(actor: actor, order: order, params: { notes: 'changed note' })

      entry = AuditLog.where(auditable: order, action: 'order_updated').last
      changes = entry.changes_data.with_indifferent_access
      expect(changes[:notes]).to eq([old_notes, 'changed note'])
    end

    it 'does not update lines even if passed' do
      original_lines = order.lines.count
      # Service intentionally ignores unexpected keys
      result = described_class.call(
        actor:  actor,
        order:  order,
        params: { notes: 'ok', lines: [{ product_id: 9999, qty: 1 }] }
      )
      expect(result[:ok]).to be true
      expect(order.reload.lines.count).to eq(original_lines)
    end

    it 'allows updating only delivery_date (notes unchanged)' do
      original_notes = order.notes
      new_date = 14.days.from_now.to_date

      result = described_class.call(
        actor:  actor,
        order:  order,
        params: { delivery_date: new_date }
      )

      expect(result[:ok]).to be true
      expect(result[:order].delivery_date).to eq(new_date)
      expect(result[:order].notes).to eq(original_notes)
    end

    it 'allows updating only notes (delivery_date unchanged)' do
      original_date = order.delivery_date

      result = described_class.call(
        actor:  actor,
        order:  order,
        params: { notes: 'notes only change' }
      )

      expect(result[:ok]).to be true
      expect(result[:order].notes).to eq('notes only change')
      expect(result[:order].delivery_date).to eq(original_date)
    end
  end

  # ── Happy path: on_hold ───────────────────────────────────────────────────
  describe 'when order is on_hold' do
    let!(:order) { create_order(status: 'on_hold') }

    it 'updates delivery_date and notes on an on_hold order' do
      new_date = 5.days.from_now.to_date

      result = described_class.call(
        actor:  actor,
        order:  order,
        params: { delivery_date: new_date, notes: 'hold update' }
      )

      expect(result[:ok]).to be true
      expect(result[:order].delivery_date).to eq(new_date)
      expect(result[:order].notes).to eq('hold update')
    end

    it 'writes an audit log for on_hold order update' do
      expect {
        described_class.call(actor: actor, order: order, params: { notes: 'on hold note' })
      }.to change { AuditLog.where(auditable: order, action: 'order_updated').count }.by(1)
    end
  end

  # ── Order status unchanged ────────────────────────────────────────────────
  describe 'status preservation' do
    it 'does not change order status on a submitted order' do
      order = create_order(status: 'submitted')
      described_class.call(actor: actor, order: order, params: { notes: 'no status change' })
      expect(order.reload.status).to eq('submitted')
    end

    it 'does not change order status on an on_hold order' do
      order = create_order(status: 'on_hold')
      described_class.call(actor: actor, order: order, params: { notes: 'no status change' })
      expect(order.reload.status).to eq('on_hold')
    end
  end
end
