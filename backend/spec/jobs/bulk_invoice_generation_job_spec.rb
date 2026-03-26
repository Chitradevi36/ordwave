# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BulkInvoiceGenerationJob, type: :job do
  let(:org)  { create(:organization) }
  let(:user) { create(:user) }
  let(:branch) { create(:branch, organization: org) }
  let(:customer) { create(:customer, organization: org, branch: branch) }

  describe '#perform' do
    it 'is enqueued on the invoicing queue' do
      expect(described_class.new.queue_name).to eq('invoicing')
    end

    it 'creates a BulkGeneration tracking record' do
      order = create(:sales_order, organization: org, branch: branch, customer: customer, created_by: user)
      session_id = SecureRandom.uuid

      expect {
        described_class.perform_now(
          organization_id: org.id,
          order_ids: [order.id],
          user_id: user.id,
          session_id: session_id
        )
      }.to change(BulkGeneration, :count).by(1)
    end

    it 'handles empty order list gracefully' do
      expect {
        described_class.perform_now(
          organization_id: org.id,
          order_ids: [],
          user_id: user.id,
          session_id: SecureRandom.uuid
        )
      }.not_to raise_error
    end
  end
end
