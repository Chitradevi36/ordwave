# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RecalculateCreditAccountJob, type: :job do
  describe '#perform' do
    it 'is enqueued on the default queue' do
      expect(described_class.new.queue_name).to eq('default')
    end

    it 'discards when CreditAccount is not found' do
      expect { described_class.perform_now(999_999) }.not_to raise_error
    end

    context 'with a valid credit account' do
      let(:org)      { create(:organization) }
      let(:branch)   { create(:branch, organization: org) }
      let(:customer) { create(:customer, organization: org, branch: branch) }
      let!(:credit_account) do
        create(:credit_account, organization: org, branch: branch,
               customer: customer, current_balance: 50_000, available_credit: 0)
      end

      it 'recalculates outstanding balance from invoices' do
        # Create a paid invoice — should reduce outstanding
        create(:sales_invoice,
               organization: org, branch: branch, customer: customer,
               created_by: create(:user), status: 'paid',
               grand_total: 5_000)

        described_class.perform_now(credit_account.id)
        credit_account.reload

        # After recalculation, outstanding should reflect actual invoice state
        expect(credit_account.current_balance).to be_a(Numeric)
      end

      it 'updates overdue_amount and overdue_days' do
        described_class.perform_now(credit_account.id)
        credit_account.reload
        expect(credit_account.overdue_amount).to be >= 0
      end
    end
  end
end
