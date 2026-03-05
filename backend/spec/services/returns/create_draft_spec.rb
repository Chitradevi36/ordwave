require 'rails_helper'

RSpec.describe Returns::CreateDraft, type: :service do
  let(:org)      { create(:organization) }
  let(:branch)   { create(:branch, organization: org) }
  let(:customer) { create(:customer, organization: org) }
  let(:actor)    { create(:user) }
  let(:product)  { create(:product, organization: org) }

  def call(**overrides)
    described_class.call(
      organization: org,
      branch:       branch,
      actor:        actor,
      params: {
        customer_id: customer.id,
        source_type: 'manual',
        return_date: Date.current.iso8601,
        lines: [
          { product_id: product.id, qty_reported: 3, condition_reported: 'unknown', reason_code: 'other' }
        ]
      }.merge(overrides)
    )
  end

  describe '.call' do
    context 'with valid inputs' do
      it 'returns success' do
        expect(call.success?).to be true
      end

      it 'creates a ReturnRequest record' do
        expect { call }.to change(ReturnRequest, :count).by(1)
      end

      it 'creates ReturnLine records for each line' do
        expect { call }.to change(ReturnLine, :count).by(1)
      end

      it 'sets status to draft' do
        result = call
        expect(result.return_request.status).to eq('draft')
      end

      it 'assigns a return_number in RET-XXXX-XXXXXX format' do
        result = call
        expect(result.return_request.return_number).to match(/\ARET-\d{4}-\d{6}\z/)
      end

      it 'assigns the correct organization' do
        result = call
        expect(result.return_request.organization).to eq(org)
      end

      it 'assigns the correct customer' do
        result = call
        expect(result.return_request.customer).to eq(customer)
      end

      it 'sets qty_reported on the return line' do
        result = call
        expect(result.return_request.lines.first.qty_reported).to eq(3)
      end

      it 'creates an audit log entry' do
        expect { call }.to change(AuditLog, :count).by(1)
      end

      it 'sets the audit log action to return_created' do
        call
        expect(AuditLog.last.action).to eq('return_created')
      end
    end

    context 'when multiple lines are submitted' do
      let(:product2) { create(:product, organization: org) }

      it 'creates one ReturnLine per entry' do
        result = described_class.call(
          organization: org,
          branch:       branch,
          actor:        actor,
          params: {
            customer_id: customer.id,
            source_type: 'manual',
            return_date: Date.current.iso8601,
            lines: [
              { product_id: product.id,  qty_reported: 2, condition_reported: 'unknown', reason_code: 'other' },
              { product_id: product2.id, qty_reported: 5, condition_reported: 'damaged', reason_code: 'transit_damage' }
            ]
          }
        )
        expect(result.return_request.lines.count).to eq(2)
      end
    end

    context 'when customer does not belong to organization' do
      let(:other_customer) { create(:customer) }

      it 'returns failure' do
        result = described_class.call(
          organization: org,
          branch:       branch,
          actor:        actor,
          params: { customer_id: other_customer.id, source_type: 'manual', return_date: Date.current.iso8601, lines: [] }
        )
        expect(result.success?).to be false
      end
    end

    context 'when lines list is empty' do
      it 'returns failure' do
        result = described_class.call(
          organization: org,
          branch:       branch,
          actor:        actor,
          params: { customer_id: customer.id, source_type: 'manual', return_date: Date.current.iso8601, lines: [] }
        )
        expect(result.success?).to be false
        expect(result.errors).not_to be_empty
      end
    end

    context 'return_number uniqueness within organization' do
      it 'generates incrementing numbers for consecutive drafts' do
        r1 = call.return_request
        r2 = call.return_request
        seq1 = r1.return_number.split('-').last.to_i
        seq2 = r2.return_number.split('-').last.to_i
        expect(seq2).to eq(seq1 + 1)
      end
    end

    context 'atomicity' do
      it 'does not persist anything when a line is invalid' do
        expect {
          described_class.call(
            organization: org,
            branch:       branch,
            actor:        actor,
            params: {
              customer_id: customer.id,
              source_type: 'manual',
              return_date: Date.current.iso8601,
              lines: [{ product_id: nil, qty_reported: 2 }]
            }
          )
        }.not_to change(ReturnRequest, :count)
      end
    end
  end
end
