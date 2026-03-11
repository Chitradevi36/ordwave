# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Gst::Gstr2b::MatchingEngine, type: :service do
  let(:org)    { create(:organization) }
  let(:import) { create(:gst2b_import, organization: org, import_status: 'parsed') }
  let(:supplier_gstin) { '27AAPFU0939F1ZV' }

  subject(:engine) { described_class.new(gst2b_import: import, organization: org) }

  def create_line(invoice_number:, taxable_value: 100_000.0, igst: 18_000.0, invoice_date: nil)
    create(:gst2b_import_line,
           gst2b_import:   import,
           organization:   org,
           supplier_gstin: supplier_gstin,
           invoice_number: invoice_number,
           taxable_value:  taxable_value,
           igst:           igst,
           invoice_date:   invoice_date || Date.new(2025, 9, 15),
           match_status:   'pending')
  end

  def create_purchase(invoice_number:, taxable_value: 100_000.0, total_tax_amount: 18_000.0,
                      invoice_date: nil, status: 'approved')
    create(:purchase_invoice,
           organization:     org,
           supplier_gstin:   supplier_gstin,
           invoice_number:   invoice_number,
           taxable_value:    taxable_value,
           total_tax_amount: total_tax_amount,
           invoice_date:     invoice_date || Date.new(2025, 9, 15),
           status:           status)
  end

  describe '#run!' do
    context 'Tier-1: exact invoice number match' do
      let!(:line) { create_line(invoice_number: 'INV-2025-001') }
      let!(:pi)   { create_purchase(invoice_number: 'INV-2025-001') }

      it 'matches the line to the purchase invoice' do
        engine.run!
        line.reload
        expect(line.match_status).to eq('matched')
        expect(line.matched_purchase_invoice_id).to eq(pi.id)
        expect(line.match_confidence).to eq(1.0)
      end

      it 'marks import as completed' do
        engine.run!
        expect(import.reload.import_status).to eq('completed')
      end
    end

    context 'Tier-2: fuzzy invoice number (lowercase vs uppercase)' do
      let!(:line) { create_line(invoice_number: 'INV/2025/001') }
      let!(:pi)   { create_purchase(invoice_number: 'INV2025001') }

      it 'matches via fuzzy normalization' do
        engine.run!
        line.reload
        expect(line.match_status).to eq('matched')
        expect(line.match_confidence).to eq(0.90)
      end
    end

    context 'when no purchase invoice matches' do
      let!(:line) { create_line(invoice_number: 'COMPLETELY-DIFFERENT-INV') }

      it 'marks the line as missing_in_books' do
        engine.run!
        line.reload
        expect(line.match_status).to eq('missing_in_books')
      end

      it 'creates a reconciliation issue' do
        expect { engine.run! }.to change(GstReconciliationIssue, :count).by(1)
        issue = GstReconciliationIssue.last
        expect(issue.issue_type).to eq('missing_in_books')
        expect(issue.supplier_gstin).to eq(supplier_gstin)
      end
    end

    context 'when there are multiple purchase invoices with the same number' do
      let!(:line) { create_line(invoice_number: 'INV-DUPE') }
      let!(:pi1)  { create_purchase(invoice_number: 'INV-DUPE') }
      let!(:pi2)  { create_purchase(invoice_number: 'INV-DUPE') }

      it 'marks the line as multiple_candidates' do
        engine.run!
        line.reload
        expect(line.match_status).to eq('multiple_candidates')
      end
    end

    context 'when tax amounts do not match (within threshold)' do
      let!(:line) { create_line(invoice_number: 'INV-TAX', igst: 18_000.0) }
      # within ₹1 tolerance — should still match as 'ok'
      let!(:pi)   { create_purchase(invoice_number: 'INV-TAX', total_tax_amount: 18_000.50) }

      it 'still matches (within tolerance)' do
        engine.run!
        expect(line.reload.match_status).to eq('matched')
      end
    end

    context 'when tax amounts differ significantly' do
      let!(:line) { create_line(invoice_number: 'INV-MISMATCH', igst: 18_000.0) }
      let!(:pi)   { create_purchase(invoice_number: 'INV-MISMATCH', total_tax_amount: 15_000.0) }

      it 'marks as matched but creates a tax_mismatch issue' do
        expect { engine.run! }.to change(GstReconciliationIssue, :count).by(1)
        line.reload
        expect(line.match_status).to eq('matched')
        issue = GstReconciliationIssue.last
        expect(issue.issue_type).to eq('tax_mismatch')
        expect(issue.difference_amount).to eq(3_000.0.to_d)
      end
    end

    context 'when import fails partway' do
      before do
        allow_any_instance_of(PurchaseInvoice).to receive(:supplier_gstin).and_raise(StandardError, "DB error")
      end

      it 'marks import as failed' do
        expect { engine.run! }.to raise_error(StandardError)
        expect(import.reload.import_status).to eq('failed')
      end
    end
  end
end
