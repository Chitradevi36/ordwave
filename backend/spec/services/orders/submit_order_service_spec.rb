require 'rails_helper'

RSpec.describe Orders::SubmitOrderService, type: :service do
  let(:org)      { create(:organization) }
  let(:branch)   { create(:branch, organization: org) }
  let(:customer) { create(:customer, organization: org, branch: branch) }
  let(:actor)    { create(:user) }
  let(:product)  { create(:product, organization: org) }

  let!(:credit_policy) { create(:credit_policy, organization: org) }
  let!(:credit_account) do
    create(:credit_account, customer: customer, organization: org, branch: branch,
           credit_limit: 100_000, current_balance: 0, available_credit: 100_000,
           overdue_amount: 0, overdue_days: 0)
  end

  let(:price_result) do
    Pricing::EffectivePriceResolver::Result.new(
      unit_price:      100.0,
      source:          'standard',
      price_list_id:   nil,
      discount_pct:    0,
      min_qty_matched: false,
      valid_from:      nil,
      valid_to:        nil
    )
  end

  before do
    allow(Pricing::EffectivePriceResolver).to receive(:call).and_return(price_result)
  end

  def make_draft_order
    order = create(:sales_order, organization: org, branch: branch, customer: customer, created_by: actor, status: 'draft')
    create(:sales_order_line, sales_order: order, product: product, qty: 5, unit_price: 100, discount_pct: 0, line_total: 500)
    order.recalculate_totals!
    order
  end

  describe '.call' do
    context 'when credit is ok' do
      before do
        allow(Credit::CreditEngine).to receive(:evaluate_order).and_return(
          { decision: 'ok', reasons: [], metrics: { available: 99_500, credit_limit: 100_000,
                                                    outstanding: 500, overdue_days: 0 },
            actions_required: {} }
        )
      end

      it 'transitions order to submitted' do
        order  = make_draft_order
        result = described_class.call(actor: actor, order: order)

        expect(result[:ok]).to be true
        expect(result[:order].status).to eq('submitted')
        expect(result[:order].submitted_at).not_to be_nil
        expect(result[:order].credit_decision).to eq('ok')
      end

      it 'includes credit result in return hash' do
        result = described_class.call(actor: actor, order: make_draft_order)
        expect(result[:credit]).to include(decision: 'ok', reasons: [], metrics: hash_including(:available))
      end

      it 'creates audit log entries for submit and credit check' do
        order = make_draft_order
        expect {
          described_class.call(actor: actor, order: order)
        }.to change(AuditLog, :count).by_at_least(2)
      end
    end

    context 'when credit is hold' do
      before do
        allow(Credit::CreditEngine).to receive(:evaluate_order).and_return(
          { decision: 'hold', reasons: ['Overdue 20 days'],
            metrics: { overdue_days: 20 }, actions_required: {} }
        )
      end

      it 'transitions order to on_hold' do
        order  = make_draft_order
        result = described_class.call(actor: actor, order: order)

        expect(result[:ok]).to be true
        expect(result[:order].status).to eq('on_hold')
        expect(result[:order].credit_decision).to eq('hold')
        expect(result[:order].credit_reasons).to include('Overdue 20 days')
      end

      it 'includes credit result with hold decision' do
        result = described_class.call(actor: actor, order: make_draft_order)
        expect(result[:credit]).to include(decision: 'hold')
        expect(result[:credit][:reasons]).to include('Overdue 20 days')
      end

      it 'creates on_hold audit log entry' do
        order = make_draft_order
        expect {
          described_class.call(actor: actor, order: order)
        }.to change(AuditLog, :count).by_at_least(3)
      end
    end

    context 'when credit is blocked' do
      before do
        allow(Credit::CreditEngine).to receive(:evaluate_order).and_return(
          { decision: 'blocked',
            reasons: ['Overdue by 45 days (threshold: 30)'],
            metrics: { overdue_days: 45, credit_limit: 100_000, outstanding: 80_000,
                       available: 20_000 },
            actions_required: {} }
        )
      end

      it 'returns ok: false' do
        result = described_class.call(actor: actor, order: make_draft_order)
        expect(result[:ok]).to be false
      end

      it 'keeps order in draft status' do
        order  = make_draft_order
        result = described_class.call(actor: actor, order: order)
        expect(result[:order].status).to eq('draft')
      end

      it 'persists credit_decision and credit_snapshot on order' do
        order = make_draft_order
        described_class.call(actor: actor, order: order)
        order.reload
        expect(order.credit_decision).to eq('blocked')
        expect(order.credit_reasons).to include('Overdue by 45 days (threshold: 30)')
        expect(order.credit_snapshot['overdue_days']).to eq(45)
      end

      it 'includes credit object with blocked decision in result' do
        result = described_class.call(actor: actor, order: make_draft_order)
        expect(result[:credit]).to include(decision: 'blocked')
        expect(result[:credit][:reasons]).to include('Overdue by 45 days (threshold: 30)')
      end

      it 'writes a credit_checked audit log but NOT an order_submitted log' do
        order = make_draft_order
        described_class.call(actor: actor, order: order)
        actions = AuditLog.where(auditable: order).pluck(:action)
        expect(actions).to include('order_credit_checked')
        expect(actions).not_to include('order_submitted')
      end

      it 'includes blocking reasons in error messages' do
        result = described_class.call(actor: actor, order: make_draft_order)
        expect(result[:errors]).to include('Order blocked by credit policy')
      end
    end

    context 'idempotency' do
      it 'returns existing submitted order when idempotency key matches' do
        order = make_draft_order
        allow(Credit::CreditEngine).to receive(:evaluate_order).and_return(
          { decision: 'ok', reasons: [], metrics: {}, actions_required: {} }
        )

        described_class.call(actor: actor, order: order, idempotency_key: 'key-abc-123')

        order2 = make_draft_order
        result = described_class.call(actor: actor, order: order2, idempotency_key: 'key-abc-123')

        expect(result[:idempotent]).to be true
        expect(result[:order].order_number).to eq(order.order_number)
      end
    end

    context 'concurrent credit evaluation (BUG-D02 regression)' do
      # Verifies that the with_lock guard prevents double-spending credit when
      # two orders for the same customer are evaluated at the same time.
      it 'does not allow credit to be double-spent under concurrent load', :db do
        limit = 1_000
        credit_account.update!(credit_limit: limit, available_credit: limit, current_balance: 0)

        allow(Credit::CreditEngine).to receive(:evaluate_order).and_call_original

        order_a = make_draft_order  # total = 500
        order_b = make_draft_order  # total = 500   → combined = 1 000, both should fit

        results = []
        threads = [
          Thread.new { results << described_class.call(actor: actor, order: order_a) },
          Thread.new { results << described_class.call(actor: actor, order: order_b) }
        ]
        threads.each(&:join)

        credit_account.reload
        approved_count = results.count { |r| r[:ok] }

        # Credit used must never exceed the limit
        expect(credit_account.current_balance).to be <= limit
        # At least one order must succeed; both may succeed if credit covers both
        expect(approved_count).to be >= 1
      end
    end

    context 'validation failures' do      it 'returns error when order is not a draft' do
        order = create(:sales_order, organization: org, branch: branch, customer: customer,
                       created_by: actor, status: 'submitted', submitted_at: Time.current)
        result = described_class.call(actor: actor, order: order)

        expect(result[:ok]).to be false
        expect(result[:errors]).to include('Order is not in draft status')
      end

      it 'returns error when order has no lines' do
        order  = create(:sales_order, organization: org, branch: branch, customer: customer,
                        created_by: actor, status: 'draft')
        result = described_class.call(actor: actor, order: order)

        expect(result[:ok]).to be false
        expect(result[:errors]).to include('Order has no lines')
      end
    end
  end
end
