# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SalesInvoice, type: :model do
  subject { build(:sales_invoice) }

  # ── Associations ────────────────────────────────────────────────────────────

  describe 'associations' do
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to belong_to(:branch) }
    it { is_expected.to belong_to(:customer) }
    it { is_expected.to belong_to(:created_by).class_name('User') }
    it { is_expected.to have_many(:sales_invoice_lines).dependent(:destroy) }
    it { is_expected.to have_many(:payment_allocations) }
  end

  # ── Validations ─────────────────────────────────────────────────────────────

  describe 'validations' do
    it { is_expected.to validate_presence_of(:invoice_number) }
    it { is_expected.to validate_presence_of(:invoice_date) }
    it { is_expected.to validate_presence_of(:currency) }

    context 'status inclusion' do
      %w[draft issued partially_paid paid void].each do |status|
        it "allows #{status}" do
          subject.status = status
          subject.valid?
          expect(subject.errors[:status]).to be_empty
        end
      end
    end

    context 'void_reason required when void' do
      it 'requires void_reason if status is void' do
        subject.status = 'void'
        subject.void_reason = nil
        subject.valid?
        expect(subject.errors[:void_reason]).to be_present
      end
    end

    context 'invoice_number uniqueness scoped to org' do
      let!(:existing) { create(:sales_invoice) }

      it 'rejects duplicate invoice numbers within the same org' do
        dup = build(:sales_invoice,
                    organization: existing.organization,
                    branch: existing.branch,
                    customer: existing.customer,
                    created_by: existing.created_by,
                    invoice_number: existing.invoice_number)
        expect(dup).not_to be_valid
        expect(dup.errors[:invoice_number]).to be_present
      end
    end
  end

  # ── Scopes ──────────────────────────────────────────────────────────────────

  describe 'scopes' do
    let!(:invoice) { create(:sales_invoice, status: 'issued') }

    describe '.not_deleted' do
      it 'excludes soft-deleted invoices' do
        deleted = create(:sales_invoice, deleted_at: Time.current)
        expect(SalesInvoice.not_deleted).to include(invoice)
        expect(SalesInvoice.not_deleted).not_to include(deleted)
      end
    end

    describe '.by_status' do
      it 'filters by status' do
        expect(SalesInvoice.by_status('issued')).to include(invoice)
      end
    end

    describe '.outstanding' do
      it 'returns issued or partially_paid invoices' do
        paid = create(:sales_invoice, status: 'paid')
        expect(SalesInvoice.outstanding).to include(invoice)
        expect(SalesInvoice.outstanding).not_to include(paid)
      end
    end
  end

  # ── Instance methods ────────────────────────────────────────────────────────

  describe '#editable?' do
    it 'returns true for draft invoices' do
      subject.status = 'draft'
      expect(subject.editable?).to be true
    end

    it 'returns false for issued invoices' do
      subject.status = 'issued'
      expect(subject.editable?).to be false
    end
  end

  describe '#voidable?' do
    it 'returns true for issued invoices' do
      subject.status = 'issued'
      expect(subject.voidable?).to be true
    end

    it 'returns false for draft invoices' do
      subject.status = 'draft'
      expect(subject.voidable?).to be false
    end
  end

  describe '#soft_delete!' do
    let(:invoice) { create(:sales_invoice) }

    it 'sets deleted_at timestamp' do
      invoice.soft_delete!
      expect(invoice.deleted_at).to be_present
    end
  end
end
