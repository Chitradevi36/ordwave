# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvoiceMailer, type: :mailer do
  let(:org)      { create(:organization) }
  let(:branch)   { create(:branch, organization: org) }
  let(:customer) { create(:customer, organization: org, branch: branch, email: 'buyer@example.com') }
  let(:invoice) do
    create(:sales_invoice, organization: org, branch: branch,
           customer: customer, created_by: create(:user),
           status: 'issued', issued_at: Time.current)
  end

  describe '#notify_issued' do
    subject(:mail) { described_class.notify_issued(invoice) }

    it 'sends to the customer email' do
      expect(mail.to).to eq(['buyer@example.com'])
    end

    it 'includes the invoice number in the subject' do
      expect(mail.subject).to include(invoice.invoice_number)
    end

    it 'includes the organization name in the subject' do
      expect(mail.subject).to include(org.name)
    end

    it 'sets custom X-headers' do
      expect(mail['X-Invoice-ID'].value).to eq(invoice.id.to_s)
      expect(mail['X-Organization-ID'].value).to eq(org.id.to_s)
    end
  end
end
