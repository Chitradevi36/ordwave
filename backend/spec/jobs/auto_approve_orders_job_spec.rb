# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AutoApproveOrdersJob, type: :job do
  describe '#perform' do
    it 'is enqueued on the default queue' do
      expect(described_class.new.queue_name).to eq('default')
    end

    context 'when organization has automatic approval mode' do
      let!(:org) do
        create(:organization, settings: {
          'order_approval_mode' => 'automatic',
          'order_edit_window_minutes' => 30
        })
      end
      let(:branch)   { create(:branch, organization: org) }
      let(:customer) { create(:customer, organization: org, branch: branch) }
      let(:user)     { create(:user) }

      it 'approves submitted orders past the edit window' do
        order = create(:sales_order,
                       organization: org, branch: branch,
                       customer: customer, created_by: user,
                       status: 'submitted', updated_at: 31.minutes.ago)

        described_class.perform_now
        order.reload
        expect(order.status).to eq('approved')
      end

      it 'skips recently submitted orders' do
        order = create(:sales_order,
                       organization: org, branch: branch,
                       customer: customer, created_by: user,
                       status: 'submitted', updated_at: 5.minutes.ago)

        described_class.perform_now
        order.reload
        expect(order.status).to eq('submitted')
      end
    end

    context 'when organization has manual approval mode' do
      let!(:org) do
        create(:organization, settings: { 'order_approval_mode' => 'manual' })
      end

      it 'skips the organization entirely' do
        expect { described_class.perform_now }.not_to raise_error
      end
    end
  end
end
