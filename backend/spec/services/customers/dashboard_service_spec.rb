require 'rails_helper'

RSpec.describe Customers::DashboardService, type: :service do
  let(:org)    { create(:organization) }
  let(:branch) { create(:branch, organization: org) }
  let(:customer) { create(:customer, organization: org, branch: branch) }

  it 'returns a payload with expected keys' do
    # create a credit account and an invoice
    create(:credit_account, customer: customer, organization: org, branch: branch, credit_limit: 5000, current_balance: 1000, available_credit: 4000)
    create(:sales_invoice, customer: customer, organization: org, grand_total: 1500, status: 'pending')

    payload = described_class.call(customer: customer, branch: branch)

    expect(payload).to include(:customer, :credit, :recent_orders, :outstanding_invoices, :notifications)
    expect(payload[:customer][:id]).to eq(customer.id)
    expect(payload[:credit][:limit]).to be >= 0
    expect(payload[:outstanding_invoices]).to include(:count, :total_outstanding)
  end
end
