# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PaymentMailer, type: :mailer do
  let(:org)      { create(:organization) }
  let(:branch)   { create(:branch, organization: org) }
  let(:customer) { create(:customer, organization: org, branch: branch, email: 'cust@example.com') }
  let(:payment) do
    create(:payment, organization: org, branch: branch,
           customer: customer, created_by: create(:user), status: 'confirmed')
  end

  describe '#payment_received' do
    subject(:mail) { described_class.payment_received(payment) }

    it 'sends to the customer email' do
      expect(mail.to).to eq(['cust@example.com'])
    end

    it 'includes the payment number in the subject' do
      expect(mail.subject).to include(payment.payment_number)
    end
  end
end
