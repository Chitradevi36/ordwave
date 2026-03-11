# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Gst::Gstr1::SectionClassifier, type: :service do
  let(:maharashtra_code) { '27' }
  let(:delhi_code)       { '07' }

  # ── Helpers ───────────────────────────────────────────────────────────────────

  def invoice_double(gstin: nil, grand_total: 100_000, state_code: maharashtra_code)
    branch   = double('Branch', state_code: state_code, state: 'Maharashtra')
    customer = double('Customer', gstin: gstin, name: 'Test')
    allow(customer).to receive(:respond_to?).with(:addresses).and_return(false)

    invoice = double('SalesInvoice',
      customer:    customer,
      branch:      branch,
      grand_total: grand_total
    )
    allow(invoice).to receive(:try).with(:branch).and_return(branch)
    invoice
  end

  def credit_note_double(gstin: nil)
    customer = double('Customer', gstin: gstin)
    double('CreditNote', customer: customer)
  end

  # ── Invoice classification ─────────────────────────────────────────────────────

  describe '.invoice_section' do
    context 'when customer has a GSTIN' do
      it 'classifies as :b2b' do
        inv = invoice_double(gstin: '29ABCDE1234F1Z5')   # Karnataka buyer
        expect(described_class.invoice_section(inv, seller_state_code: maharashtra_code))
          .to eq(:b2b)
      end
    end

    context 'when customer has no GSTIN and is inter-state' do
      let(:delhi_customer_invoice) { invoice_double(grand_total: 300_000) }

      it 'classifies large inter-state invoices as :b2cl' do
        # Buyer's POS will be derived from branch fallback; force via a Delhi customer
        inv = invoice_double(grand_total: 300_000)
        # Override POS by stubbing – place_of_supply returns branch code (27),
        # so this is intra → b2cs unless we force a different POS.
        # To test b2cl we need a genuinely inter-state customer:
        # Use a customer address in Delhi.
        branch   = double('Branch', state_code: maharashtra_code, state: 'Maharashtra')
        customer = double('Customer', gstin: nil, name: 'Anon')
        allow(customer).to receive(:respond_to?).with(:addresses).and_return(true)
        billing  = double('Address', label: 'billing', state: 'delhi')
        allow(customer).to receive(:addresses).and_return([billing])

        inv2 = double('SalesInvoice',
          customer:    customer,
          branch:      branch,
          grand_total: 300_000
        )
        allow(inv2).to receive(:try).with(:branch).and_return(branch)

        expect(described_class.invoice_section(inv2, seller_state_code: maharashtra_code))
          .to eq(:b2cl)
      end

      it 'classifies small inter-state invoices as :b2cs' do
        branch   = double('Branch', state_code: maharashtra_code, state: 'Maharashtra')
        customer = double('Customer', gstin: nil, name: 'Anon')
        allow(customer).to receive(:respond_to?).with(:addresses).and_return(true)
        billing  = double('Address', label: 'billing', state: 'delhi')
        allow(customer).to receive(:addresses).and_return([billing])

        inv = double('SalesInvoice',
          customer:    customer,
          branch:      branch,
          grand_total: 100_000   # below ₹2.5L threshold
        )
        allow(inv).to receive(:try).with(:branch).and_return(branch)

        expect(described_class.invoice_section(inv, seller_state_code: maharashtra_code))
          .to eq(:b2cs)
      end
    end

    context 'when customer is intra-state unregistered' do
      it 'classifies as :b2cs regardless of invoice value' do
        inv = invoice_double(grand_total: 5_000_000)   # very large but same state
        # Branch state_code = 27, POS = 27 (falls back to branch) → intra-state
        expect(described_class.invoice_section(inv, seller_state_code: maharashtra_code))
          .to eq(:b2cs)
      end
    end
  end

  # ── Credit note classification ─────────────────────────────────────────────────

  describe '.credit_note_section' do
    it 'classifies as :cdnr when customer has GSTIN' do
      cn = credit_note_double(gstin: '27ABCDE1234F1Z5')
      expect(described_class.credit_note_section(cn)).to eq(:cdnr)
    end

    it 'classifies as :cdnur when customer has no GSTIN' do
      cn = credit_note_double(gstin: nil)
      expect(described_class.credit_note_section(cn)).to eq(:cdnur)
    end
  end

  # ── Place of supply code ───────────────────────────────────────────────────────

  describe '.place_of_supply_code' do
    it 'returns first two chars of customer GSTIN for registered buyers' do
      inv = invoice_double(gstin: '29ABCDE1234F1Z5')  # Karnataka
      expect(described_class.place_of_supply_code(inv)).to eq('29')
    end

    it 'maps billing address state name to code for unregistered buyers' do
      branch   = double('Branch', state_code: maharashtra_code)
      customer = double('Customer', gstin: nil)
      allow(customer).to receive(:respond_to?).with(:addresses).and_return(true)
      billing  = double('Address', label: 'billing', state: 'gujarat')
      allow(customer).to receive(:addresses).and_return([billing])

      inv = double('SalesInvoice', customer: customer, branch: branch)
      allow(inv).to receive(:try).with(:branch).and_return(branch)

      expect(described_class.place_of_supply_code(inv)).to eq('24')
    end

    it 'falls back to branch state_code when address is unavailable' do
      inv = invoice_double(gstin: nil)
      expect(described_class.place_of_supply_code(inv)).to eq(maharashtra_code)
    end
  end

  # ── STATE_CODE_MAP ────────────────────────────────────────────────────────────

  describe 'STATE_CODE_MAP' do
    it 'maps well-known states correctly' do
      expect(described_class::STATE_CODE_MAP['maharashtra']).to eq('27')
      expect(described_class::STATE_CODE_MAP['karnataka']).to   eq('29')
      expect(described_class::STATE_CODE_MAP['gujarat']).to     eq('24')
      expect(described_class::STATE_CODE_MAP['delhi']).to       eq('07')
    end
  end
end
