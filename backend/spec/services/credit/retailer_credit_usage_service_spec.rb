require 'rails_helper'

RSpec.describe Credit::RetailerCreditUsageService, type: :service do
  # ─── Shared setup ──────────────────────────────────────────────────────────
  let(:org)    { create(:organization) }
  let(:branch) { create(:branch, organization: org) }
  let(:retailer) do
    create(:customer, organization: org, branch: branch)
  end
  let!(:credit_account) do
    create(:credit_account,
           customer:        retailer,
           organization:    org,
           branch:          branch,
           credit_limit:    50_000.00,
           current_balance: 10_000.00)
  end

  def call(opts = {})
    described_class.call(
      retailer: opts[:retailer] || retailer,
      branch:   opts[:branch]   || branch,
      on_date:  opts[:on_date]  || Date.current
    )
  end

  def make_order(status:, total:)
    create(:sales_order,
           organization: org,
           branch:       branch,
           customer:     retailer,
           status:       status,
           total_amount: total)
  end

  # ─── Basic happy path ──────────────────────────────────────────────────────
  describe '.call — happy path' do
    it 'returns a result hash with all required keys' do
      result = call
      expect(result).to include(
        :credit_limit, :invoice_outstanding, :order_exposure,
        :hold_exposure, :credit_used_total, :available_credit,
        :contributing_orders, :breakdown, :debug
      )
    end

    it 'reads credit_limit from credit_account' do
      expect(call[:credit_limit]).to eq(50_000.00)
    end

    it 'reads invoice_outstanding from current_balance' do
      expect(call[:invoice_outstanding]).to eq(10_000.00)
    end

    it 'returns zero order_exposure when no orders exist' do
      expect(call[:order_exposure]).to eq(0.0)
    end

    it 'returns zero hold_exposure when no on_hold orders exist' do
      expect(call[:hold_exposure]).to eq(0.0)
    end

    it 'computes credit_used_total as invoice_outstanding + order_exposure' do
      make_order(status: 'submitted', total: 5_000.00)
      result = call
      expect(result[:credit_used_total]).to eq(15_000.00)
    end

    it 'computes available_credit as credit_limit minus credit_used_total' do
      make_order(status: 'submitted', total: 5_000.00)
      result = call
      expect(result[:available_credit]).to eq(35_000.00)
    end
  end

  # ─── Exposure status inclusion ─────────────────────────────────────────────
  describe '.call — EXPOSURE_STATUSES (submitted, approved)' do
    it 'includes submitted orders in order_exposure' do
      make_order(status: 'submitted', total: 3_000.00)
      expect(call[:order_exposure]).to eq(3_000.00)
    end

    it 'includes approved orders in order_exposure' do
      make_order(status: 'approved', total: 7_000.00)
      expect(call[:order_exposure]).to eq(7_000.00)
    end

    it 'sums multiple submitted+approved orders together' do
      make_order(status: 'submitted', total: 2_000.00)
      make_order(status: 'approved',  total: 4_000.00)
      expect(call[:order_exposure]).to eq(6_000.00)
    end
  end

  # ─── Excluded statuses ─────────────────────────────────────────────────────
  describe '.call — EXCLUDED_STATUSES (draft, rejected, cancelled)' do
    it 'excludes draft orders from order_exposure' do
      make_order(status: 'draft', total: 9_000.00)
      expect(call[:order_exposure]).to eq(0.0)
    end

    it 'excludes rejected orders from order_exposure' do
      make_order(status: 'rejected', total: 9_000.00)
      expect(call[:order_exposure]).to eq(0.0)
    end

    it 'excludes cancelled orders from order_exposure' do
      make_order(status: 'cancelled', total: 9_000.00)
      expect(call[:order_exposure]).to eq(0.0)
    end
  end

  # ─── Hold exposure ─────────────────────────────────────────────────────────
  describe '.call — HOLD_STATUSES (on_hold)' do
    it 'counts on_hold orders in hold_exposure, not order_exposure' do
      make_order(status: 'on_hold', total: 4_500.00)
      result = call
      expect(result[:hold_exposure]).to  eq(4_500.00)
      expect(result[:order_exposure]).to eq(0.0)
    end

    it 'does not include hold_exposure in credit_used_total' do
      make_order(status: 'on_hold', total: 4_500.00)
      result = call
      # credit_used_total = invoice_outstanding(10_000) + order_exposure(0)
      expect(result[:credit_used_total]).to eq(10_000.00)
    end
  end

  # ─── available_credit floor ────────────────────────────────────────────────
  describe '.call — available_credit clamped to 0' do
    it 'returns 0 when credit_used_total exceeds credit_limit' do
      # invoice_outstanding already 10_000; add 45_000 order → total 55_000 > 50_000
      make_order(status: 'submitted', total: 45_000.00)
      result = call
      expect(result[:available_credit]).to eq(0.0)
    end

    it 'does not return a negative available_credit' do
      make_order(status: 'submitted', total: 100_000.00)
      expect(call[:available_credit]).to be >= 0
    end
  end

  # ─── No credit account ─────────────────────────────────────────────────────
  describe '.call — retailer with no credit_account' do
    let(:bare_retailer) { create(:customer, organization: org, branch: branch) }

    it 'returns zeros for all monetary fields' do
      result = described_class.call(retailer: bare_retailer, branch: branch)
      expect(result[:credit_limit]).to       eq(0.0)
      expect(result[:invoice_outstanding]).to eq(0.0)
      expect(result[:order_exposure]).to      eq(0.0)
      expect(result[:credit_used_total]).to   eq(0.0)
      expect(result[:available_credit]).to    eq(0.0)
    end
  end

  # ─── Branch scoping ────────────────────────────────────────────────────────
  describe '.call — branch scoping' do
    it 'ignores orders belonging to a different branch' do
      other_branch = create(:branch, organization: org)
      create(:sales_order, organization: org, branch: other_branch,
             customer: retailer, status: 'submitted', total_amount: 8_000.00)
      expect(call[:order_exposure]).to eq(0.0)
    end
  end

  # ─── breakdown hash ────────────────────────────────────────────────────────
  describe '.call — breakdown hash' do
    it 'includes per-status counts and totals' do
      make_order(status: 'submitted', total: 2_000.00)
      make_order(status: 'approved',  total: 3_000.00)
      make_order(status: 'on_hold',   total: 1_500.00)

      bd = call[:breakdown]
      expect(bd[:submitted][:count]).to eq(1)
      expect(bd[:submitted][:total]).to eq(2_000.00)
      expect(bd[:approved][:count]).to  eq(1)
      expect(bd[:approved][:total]).to  eq(3_000.00)
      expect(bd[:on_hold][:count]).to   eq(1)
      expect(bd[:on_hold][:total]).to   eq(1_500.00)
    end
  end

  # ─── contributing_orders ──────────────────────────────────────────────────
  describe '.call — contributing_orders' do
    it 'lists submitted and approved orders' do
      o1 = make_order(status: 'submitted', total: 2_000.00)
      o2 = make_order(status: 'approved',  total: 3_000.00)
      orders = call[:contributing_orders]
      ids = orders.map { |o| o[:id] }
      expect(ids).to include(o1.id, o2.id)
    end

    it 'excludes draft orders from contributing_orders' do
      draft = make_order(status: 'draft', total: 9_999.00)
      orders = call[:contributing_orders]
      expect(orders.map { |o| o[:id] }).not_to include(draft.id)
    end

    it 'includes expected keys in each contributing order' do
      make_order(status: 'submitted', total: 1_000.00)
      order = call[:contributing_orders].first
      expect(order).to include(:id, :order_number, :status, :total_amount, :created_at)
    end

    it 'limits contributing_orders to 10' do
      12.times { make_order(status: 'submitted', total: 500.00) }
      expect(call[:contributing_orders].length).to eq(10)
    end
  end

  # ─── .batch ────────────────────────────────────────────────────────────────
  describe '.batch' do
    let(:retailer2) { create(:customer, organization: org, branch: branch) }

    it 'returns order_exposure keyed by retailer id' do
      make_order(status: 'submitted', total: 5_000.00)
      create(:sales_order, organization: org, branch: branch, customer: retailer2,
             status: 'approved', total_amount: 2_000.00)

      batch = described_class.batch(branch: branch,
                                    retailer_ids: [retailer.id, retailer2.id])

      expect(batch[retailer.id][:order_exposure]).to  eq(5_000.00)
      expect(batch[retailer2.id][:order_exposure]).to eq(2_000.00)
    end

    it 'returns hold_exposure keyed by retailer id' do
      make_order(status: 'on_hold', total: 1_800.00)

      batch = described_class.batch(branch: branch, retailer_ids: [retailer.id])
      expect(batch[retailer.id][:hold_exposure]).to eq(1_800.00)
    end

    it 'returns zero order_exposure for retailers with no matching orders' do
      batch = described_class.batch(branch: branch, retailer_ids: [retailer.id])
      expect(batch[retailer.id][:order_exposure]).to eq(0.0)
    end

    it 'returns an empty hash for empty retailer_ids' do
      batch = described_class.batch(branch: branch, retailer_ids: [])
      expect(batch).to eq({})
    end

    it 'excludes draft orders from batch order_exposure' do
      make_order(status: 'draft', total: 9_000.00)
      batch = described_class.batch(branch: branch, retailer_ids: [retailer.id])
      expect(batch[retailer.id][:order_exposure]).to eq(0.0)
    end

    it 'excludes cancelled orders from batch order_exposure' do
      make_order(status: 'cancelled', total: 9_000.00)
      batch = described_class.batch(branch: branch, retailer_ids: [retailer.id])
      expect(batch[retailer.id][:order_exposure]).to eq(0.0)
    end
  end
end
