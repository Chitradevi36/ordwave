require 'rails_helper'

RSpec.describe SalesOrder, type: :model do
  let(:org)      { create(:organization) }
  let(:branch)   { create(:branch, organization: org) }
  let(:customer) { create(:customer, organization: org, branch: branch) }
  let(:user)     { create(:user) }

  def build_order(attrs = {})
    build(:sales_order, { organization: org, branch: branch, customer: customer, created_by: user }.merge(attrs))
  end

  def create_order(attrs = {})
    create(:sales_order, { organization: org, branch: branch, customer: customer, created_by: user }.merge(attrs))
  end

  # ── Validations ──────────────────────────────────────────────────────────
  describe 'validations' do
    it 'is valid with required attributes' do
      expect(build_order).to be_valid
    end

    it 'requires a valid status' do
      expect(build_order(status: 'unknown')).not_to be_valid
    end

    it 'requires cancellation_reason when cancelled' do
      order = build_order(status: 'cancelled', cancellation_reason: nil)
      expect(order).not_to be_valid
      expect(order.errors[:cancellation_reason]).to be_present
    end

    it 'is valid when cancelled with a reason' do
      order = build_order(status: 'cancelled', cancellation_reason: 'Customer request')
      expect(order).to be_valid
    end
  end

  # ── Status helpers ────────────────────────────────────────────────────────
  describe 'status predicates' do
    SalesOrder::STATUSES.each do |status|
      it "returns true for #{status}?" do
        order = create_order(status: status, cancellation_reason: status == 'cancelled' ? 'test' : nil)
        expect(order.public_send(:"#{status}?")).to be true
      end
    end
  end

  # ── State machine ─────────────────────────────────────────────────────────
  describe '#transition_to!' do
    it 'allows draft → submitted' do
      order = create_order(status: 'draft')
      order.transition_to!('submitted')
      expect(order.reload.status).to eq('submitted')
      expect(order.submitted_at).not_to be_nil
    end

    it 'allows submitted → on_hold' do
      order = create_order(status: 'submitted', submitted_at: Time.current)
      order.transition_to!('on_hold')
      expect(order.reload.status).to eq('on_hold')
    end

    it 'allows on_hold → approved' do
      order = create_order(status: 'on_hold', submitted_at: Time.current)
      order.transition_to!('approved')
      expect(order.reload.status).to eq('approved')
      expect(order.approved_at).not_to be_nil
    end

    it 'allows cancellation with reason' do
      order = create_order(status: 'submitted', submitted_at: Time.current)
      order.transition_to!('cancelled', reason: 'Customer request')
      expect(order.reload.status).to eq('cancelled')
      expect(order.cancellation_reason).to eq('Customer request')
    end

    it 'raises on invalid transition (approved → submitted)' do
      order = create_order(status: 'approved', submitted_at: Time.current, approved_at: Time.current)
      expect {
        order.transition_to!('submitted')
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'raises on rejected → any' do
      order = create_order(status: 'rejected', submitted_at: Time.current)
      expect {
        order.transition_to!('cancelled', reason: 'test')
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'raises on cancelled → any' do
      order = create_order(status: 'cancelled', cancellation_reason: 'test', cancelled_at: Time.current)
      expect {
        order.transition_to!('draft')
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  # ── cancellable? ─────────────────────────────────────────────────────────
  describe '#cancellable?' do
    %w[draft submitted on_hold approved].each do |status|
      it "returns true for #{status}" do
        order = create_order(status: status, submitted_at: status != 'draft' ? Time.current : nil,
                             approved_at: status == 'approved' ? Time.current : nil)
        expect(order.cancellable?).to be true
      end
    end

    %w[rejected cancelled].each do |status|
      it "returns false for #{status}" do
        order = create_order(status: status,
                             submitted_at: Time.current,
                             cancellation_reason: status == 'cancelled' ? 'test' : nil,
                             cancelled_at: status == 'cancelled' ? Time.current : nil)
        expect(order.cancellable?).to be false
      end
    end
  end

  # ── order_number assignment ───────────────────────────────────────────────
  describe 'order_number auto-assignment' do
    it 'assigns a unique order number on create' do
      order = create_order(order_number: nil)
      expect(order.order_number).to match(/\ASO-\d{4}-\d{6}\z/)
    end

    it 'does not overwrite an existing order number' do
      order = create_order(order_number: 'SO-CUSTOM')
      expect(order.order_number).to eq('SO-CUSTOM')
    end
  end

  # ── recalculate_totals! ───────────────────────────────────────────────────
  describe '#recalculate_totals!' do
    it 'sums line totals' do
      order = create_order
      create(:sales_order_line, sales_order: order, qty: 5, unit_price: 100, discount_pct: 0, line_total: 500, product: create(:product, organization: org))
      create(:sales_order_line, sales_order: order, qty: 2, unit_price: 200, discount_pct: 0, line_total: 400, product: create(:product, organization: org))
      order.lines.reload
      order.recalculate_totals!
      expect(order.reload.total_amount).to eq(900)
    end
  end

  # ── limited_editable? ─────────────────────────────────────────────────────
  describe '#limited_editable?' do
    it 'returns true for submitted' do
      order = create_order(status: 'submitted', submitted_at: Time.current)
      expect(order.limited_editable?).to be true
    end

    it 'returns true for on_hold' do
      order = create_order(status: 'on_hold', submitted_at: Time.current)
      expect(order.limited_editable?).to be true
    end

    %w[draft approved rejected cancelled].each do |other|
      it "returns false for #{other}" do
        attrs = { status: other }
        attrs[:submitted_at]        = Time.current            if %w[approved rejected].include?(other)
        attrs[:approved_at]         = Time.current            if other == 'approved'
        attrs[:cancellation_reason] = 'test'                  if other == 'cancelled'
        attrs[:cancelled_at]        = Time.current            if other == 'cancelled'
        order = create_order(**attrs)
        expect(order.limited_editable?).to be false
      end
    end
  end

  # ── .search_q ─────────────────────────────────────────────────────────────
  describe '.search_q' do
    it 'matches on order_number' do
      order = create_order(order_number: 'SO-FIND-000001')
      other = create_order(order_number: 'SO-SKIP-000002')
      results = SalesOrder.search_q('FIND')
      expect(results).to include(order)
      expect(results).not_to include(other)
    end

    it 'matches on customer name (case insensitive)' do
      matching_customer = create(:customer, organization: org, branch: branch, name: 'Sunrise Mart', code: 'SRMRT')
      order = create_order(customer: matching_customer)
      other_customer = create(:customer, organization: org, branch: branch, name: 'Monsoon Stores', code: 'MNSN')
      other = create_order(customer: other_customer)

      expect(SalesOrder.search_q('sunrise')).to include(order)
      expect(SalesOrder.search_q('sunrise')).not_to include(other)
    end

    it 'matches on customer code' do
      match_customer = create(:customer, organization: org, branch: branch, code: 'UNIQ-XYZ', name: 'Generic Name')
      order = create_order(customer: match_customer)
      expect(SalesOrder.search_q('UNIQ')).to include(order)
    end

    it 'returns all matching records when query is a wildcard fragment' do
      create_order(order_number: 'SO-WILD-000099')
      # With blank, ILIKE '%%' matches all — the controller guards this with present? check
      expect(SalesOrder.search_q('WILD').count).to be >= 1
    end
  end

  # ── .by_date_range ────────────────────────────────────────────────────────
  describe '.by_date_range' do
    it 'returns orders within the date range' do
      inside  = create_order
      outside = create_order
      inside.update_column(:created_at,  3.days.ago)
      outside.update_column(:created_at, 10.days.ago)

      results = SalesOrder.by_date_range(5.days.ago.to_date, Date.today)
      expect(results).to include(inside)
      expect(results).not_to include(outside)
    end

    it 'applies only from_date when to_date is nil' do
      recent = create_order
      old    = create_order
      recent.update_column(:created_at, 2.days.ago)
      old.update_column(:created_at,   20.days.ago)

      results = SalesOrder.by_date_range(5.days.ago.to_date, nil)
      expect(results).to include(recent)
      expect(results).not_to include(old)
    end

    it 'applies only to_date when from_date is nil' do
      old    = create_order
      recent = create_order
      old.update_column(:created_at,    20.days.ago)
      recent.update_column(:created_at,  1.day.ago)

      results = SalesOrder.by_date_range(nil, 5.days.ago.to_date)
      expect(results).to include(old)
      expect(results).not_to include(recent)
    end

    it 'returns all orders when both bounds are nil' do
      o1 = create_order
      o2 = create_order
      results = SalesOrder.by_date_range(nil, nil)
      expect(results).to include(o1, o2)
    end
  end
end
