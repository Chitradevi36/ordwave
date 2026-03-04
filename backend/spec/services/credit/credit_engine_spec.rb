require 'rails_helper'

RSpec.describe Credit::CreditEngine, type: :service do
  let(:org)     { create(:organization) }
  let(:branch)  { create(:branch, organization: org) }
  let(:customer) { create(:customer, organization: org, branch: branch) }
  let!(:policy)  { create(:credit_policy, organization: org) }

  def account_with(overrides = {})
    create(:credit_account, {
      organization: org,
      branch:       branch,
      customer:     customer,
      credit_limit:    50_000,
      current_balance: 0,
      overdue_amount:  0,
      overdue_days:    0
    }.merge(overrides))
  end

  def evaluate(account, opts = {})
    Credit::CreditEngine.evaluate_order(
      credit_account: account,
      product_ids:    opts[:product_ids] || [],
      order_total:    opts[:order_total] || 1000,
      on_date:        opts[:on_date]     || Date.current
    )
  end

  context 'when account is in good standing' do
    it 'returns ok decision' do
      result = evaluate(account_with)
      expect(result[:decision]).to eq('ok')
      expect(result[:reasons]).to be_empty
    end
  end

  context 'hard block — overdue days threshold' do
    it 'blocks when overdue_days >= hard_block_overdue_days' do
      account = account_with(overdue_days: 30)
      result  = evaluate(account)
      expect(result[:decision]).to eq('blocked')
      expect(result[:reasons].first).to match(/Overdue by 30 days/)
    end

    it 'does not block when overdue_days is just below threshold' do
      account = account_with(overdue_days: 29)
      result  = evaluate(account)
      expect(result[:decision]).not_to eq('blocked')
    end
  end

  context 'hard block — outstanding exceeds margin' do
    it 'blocks when outstanding > limit + margin %' do
      # limit 50k, margin 20% → threshold 60k
      account = account_with(credit_limit: 50_000, current_balance: 61_000)
      result  = evaluate(account)
      expect(result[:decision]).to eq('blocked')
    end

    it 'does not block when outstanding is within margin' do
      account = account_with(credit_limit: 50_000, current_balance: 59_000)
      result  = evaluate(account)
      expect(result[:decision]).not_to eq('blocked')
    end
  end

  context 'soft hold — overdue in band' do
    it 'holds when overdue is in soft-hold band (15–29)' do
      account = account_with(overdue_days: 20)
      result  = evaluate(account)
      expect(result[:decision]).to eq('hold')
    end
  end

  context 'soft hold — outstanding pct' do
    it 'holds when outstanding >= 100% of credit limit' do
      account = account_with(credit_limit: 50_000, current_balance: 50_000)
      result  = evaluate(account)
      expect(result[:decision]).to eq('hold')
    end
  end

  context 'collection_first flag' do
    it 'returns hold when account is flagged collection_first' do
      account = account_with(collection_first: true)
      result  = evaluate(account)
      expect(result[:decision]).to eq('hold')
      expect(result[:actions_required][:collection_required]).to be true
    end
  end

  context 'hold_required flag' do
    it 'returns hold when account is flagged hold_required' do
      account = account_with(hold_required: true)
      result  = evaluate(account)
      expect(result[:decision]).to eq('hold')
    end
  end

  context 'prepayment SKUs' do
    let!(:product)         { create(:product, organization: org) }
    let!(:prepayment_sku)  { create(:prepayment_sku, organization: org, product: product, effective_from: Date.current) }

    it 'blocks when order includes a prepayment product' do
      account = account_with
      result  = evaluate(account, product_ids: [product.id])
      expect(result[:decision]).to eq('blocked')
      expect(result[:actions_required][:prepayment_required]).to include(product.id)
    end

    it 'does not block for products not in prepayment list' do
      other_product = create(:product, organization: org)
      account       = account_with
      result        = evaluate(account, product_ids: [other_product.id])
      expect(result[:decision]).to eq('ok')
    end
  end

  describe 'metrics' do
    it 'includes expected keys' do
      account = account_with(credit_limit: 50_000, current_balance: 10_000)
      result  = evaluate(account)
      expect(result[:metrics]).to include(
        :credit_limit, :outstanding, :available, :overdue_days, :overdue_bucket, :outstanding_pct, :order_total
      )
    end

    it 'computes available correctly' do
      account = account_with(credit_limit: 50_000, current_balance: 20_000)
      result  = evaluate(account)
      expect(result[:metrics][:available]).to eq(30_000)
    end
  end
end
