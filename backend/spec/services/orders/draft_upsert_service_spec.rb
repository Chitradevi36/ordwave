require 'rails_helper'

RSpec.describe Orders::DraftUpsertService, type: :service do
  let(:org)      { create(:organization) }
  let(:branch)   { create(:branch, organization: org) }
  let(:customer) { create(:customer, organization: org, branch: branch) }
  let(:manager)  { create(:user) }
  let(:customer_user) { create(:user) }
  let(:product)  { create(:product, organization: org) }

  let!(:credit_policy) { create(:credit_policy, organization: org) }
  let!(:credit_account) do
    create(:credit_account, customer: customer, organization: org, branch: branch,
           credit_limit: 1000, current_balance: 0, available_credit: 1000,
           overdue_amount: 0, overdue_days: 0)
  end

  before do
    # Create memberships
    Membership.create!(user: manager, organization: org, branch: branch, role: Role.fetch!('manager'), active: true)
    Membership.create!(user: customer_user, organization: org, branch: branch, role: Role.fetch!('customer'), active: true)
  end

  def draft_params_with_line(qty: 2, price: 100)
    {
      customer_id: customer.id,
      branch_id: branch.id,
      lines_attributes: [
        { product_id: product.id, qty: qty, unit_price: price, discount_pct: 0 }
      ]
    }
  end

  it 'creates a draft order for manager' do
    result = described_class.call(actor: manager, params: draft_params_with_line, organization: org, branch: branch)
    expect(result[:ok]).to be true
    expect(result[:order]).to be_persisted
    expect(result[:order].status).to eq('draft')
    expect(result[:order].total_amount).to be > 0
  end

  it 'persists credit snapshot for customer actor and blocks when hard_block' do
    # set hard block rule on customer
    customer.update!(credit_block_rule: 'hard_block')

    # stub Credit::CreditEngine to return blocked decision
    allow(Credit::CreditEngine).to receive(:evaluate_order).and_return(
      { decision: 'blocked', reasons: ['Overdue test'], metrics: { overdue_days: 99 }, actions_required: {} }
    )

    result = described_class.call(actor: customer_user, params: draft_params_with_line(qty: 100, price: 1000), organization: org, branch: branch)
    expect(result[:ok]).to be false
    expect(result[:errors].join).to match(/blocked by credit policy/i)
  end
end
require 'rails_helper'

RSpec.describe Orders::DraftUpsertService, type: :service do
  let(:org)      { create(:organization) }
  let(:branch)   { create(:branch, organization: org) }
  let(:customer) { create(:customer, organization: org, branch: branch) }
  let(:actor)    { create(:user) }

  let(:product) do
    create(:product, organization: org)
  end

  let(:price_result) do
    Pricing::EffectivePriceResolver::Result.new(
      unit_price:      150.0,
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

  describe '.call' do
    let(:params) do
      {
        delivery_date: 7.days.from_now.to_date,
        notes:         'Test order',
        lines: [
          { product_id: product.id, qty: 5, unit_price: nil, discount_pct: 0 }
        ]
      }
    end

    context 'creating a new draft' do
      it 'creates a SalesOrder in draft status' do
        result = described_class.call(
          actor:        actor,
          organization: org,
          branch:       branch,
          customer:     customer,
          params:       params,
          order:        nil
        )

        expect(result[:ok]).to be true
        expect(result[:order]).to be_persisted
        expect(result[:order].status).to eq('draft')
        expect(result[:order].organization).to eq(org)
        expect(result[:order].customer).to eq(customer)
      end

      it 'creates order lines with resolved prices' do
        result = described_class.call(
          actor:        actor,
          organization: org,
          branch:       branch,
          customer:     customer,
          params:       params,
          order:        nil
        )

        line = result[:order].lines.first
        expect(line).to be_present
        expect(line.product).to eq(product)
        expect(line.unit_price).to eq(150.0)
        expect(line.price_source).to eq('standard')
      end

      it 'uses manual unit_price when provided' do
        params_with_price = params.merge(
          lines: [{ product_id: product.id, qty: 5, unit_price: 200.0, discount_pct: 0 }]
        )

        result = described_class.call(
          actor:        actor,
          organization: org,
          branch:       branch,
          customer:     customer,
          params:       params_with_price,
          order:        nil
        )

        line = result[:order].lines.first
        expect(line.unit_price).to eq(200.0)
        expect(line.price_source).to eq('manual')
      end

      it 'creates an audit log entry' do
        expect {
          described_class.call(
            actor:        actor,
            organization: org,
            branch:       branch,
            customer:     customer,
            params:       params,
            order:        nil
          )
        }.to change(AuditLog, :count).by(1)
      end
    end

    context 'updating an existing draft' do
      let!(:existing_order) do
        create(:sales_order, organization: org, branch: branch, customer: customer, created_by: actor)
      end

      it 'updates delivery_date and notes' do
        new_date = 14.days.from_now.to_date
        result = described_class.call(
          actor:        actor,
          organization: org,
          branch:       branch,
          customer:     customer,
          params:       { delivery_date: new_date, notes: 'Updated', lines: params[:lines] },
          order:        existing_order
        )

        expect(result[:ok]).to be true
        expect(result[:order].delivery_date).to eq(new_date)
        expect(result[:order].notes).to eq('Updated')
      end

      it 'returns error when order is not a draft' do
        existing_order.update!(status: 'submitted', submitted_at: Time.current)
        result = described_class.call(
          actor:        actor,
          organization: org,
          branch:       branch,
          customer:     customer,
          params:       params,
          order:        existing_order
        )

        expect(result[:ok]).to be false
        expect(result[:errors]).to be_present
      end
    end
  end
end
