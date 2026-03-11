# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Gst::Gstr1::Validator, type: :service do
  # ── Helpers ──────────────────────────────────────────────────────────────────

  # Build a minimal fake invoice/credit-note struct without touching the DB.
  let(:valid_gstin)   { '27ABCDE1234F1Z5' }
  let(:seller_gstin)  { '27XYZAB1234C1Z9' }

  def fake_customer(gstin: nil, addresses: [])
    dbl = double('Customer', gstin: gstin, name: 'Test Customer')
    allow(dbl).to receive(:respond_to?).with(:addresses).and_return(addresses.any?)
    allow(dbl).to receive(:addresses).and_return(addresses)
    dbl
  end

  def fake_product(name: 'Rice', hsn_code: '1006')
    double('Product', name: name, hsn_code: hsn_code)
  end

  def fake_line(hsn_code: '1006', product: nil)
    double('SalesInvoiceLine',
      hsn_code:  hsn_code,
      product:   product || fake_product
    )
  end

  def fake_invoice(number: 'INV-001', date: Date.today, total: 1_180.0,
                   status: 'issued', customer: nil, lines: [])
    double('SalesInvoice',
      id:            1,
      invoice_number: number,
      invoice_date:  date,
      grand_total:   total,
      status:        status,
      customer:      customer || fake_customer(gstin: valid_gstin),
      lines:         lines.any? ? lines : [fake_line]
    )
  end

  def fake_credit_note(number: 'CN-001', issued_at: Time.current, total: 590.0,
                        customer: nil, lines: [])
    double('CreditNote',
      id:                 1,
      credit_note_number: number,
      issued_at:          issued_at,
      total:              total,
      customer:           customer || fake_customer(gstin: valid_gstin),
      lines:              lines.any? ? lines : [fake_line]
    )
  end

  def call_validator(gstin: seller_gstin, invoices: [], credit_notes: [])
    described_class.call(
      gstin:        gstin,
      invoices:     invoices,
      credit_notes: credit_notes
    )
  end

  # ── Seller GSTIN validation ───────────────────────────────────────────────────

  describe 'seller GSTIN' do
    it 'is valid? when seller GSTIN is correctly formatted' do
      result = call_validator(invoices: [fake_invoice])
      expect(result.valid?).to be true
      expect(result.errors.map { |e| e[:code] }).not_to include('MISSING_SELLER_GSTIN')
    end

    it 'errors on blank seller GSTIN' do
      result = call_validator(gstin: '')
      expect(result.valid?).to be false
      expect(result.errors.map { |e| e[:code] }).to include('MISSING_SELLER_GSTIN')
    end

    it 'errors on malformed seller GSTIN' do
      result = call_validator(gstin: 'INVALID-GSTIN')
      expect(result.valid?).to be false
      expect(result.errors.map { |e| e[:code] }).to include('INVALID_SELLER_GSTIN')
    end
  end

  # ── Invoice validation ────────────────────────────────────────────────────────

  describe 'invoice validation' do
    it 'passes for a well-formed invoice' do
      result = call_validator(invoices: [fake_invoice])
      expect(result.valid?).to be true
      expect(result.warnings).to be_empty
    end

    it 'warns when invoice has no HSN code on the line' do
      line   = fake_line(hsn_code: nil, product: double('Product', name: 'Item', hsn_code: nil))
      result = call_validator(invoices: [fake_invoice(lines: [line])])
      codes  = result.warnings.map { |w| w[:code] }
      expect(codes).to include('MISSING_HSN_CODE')
    end

    it 'errors when customer is nil' do
      inv = double('SalesInvoice', id: 1, invoice_number: 'INV-X',
                   invoice_date: Date.today, grand_total: 100, status: 'issued',
                   customer: nil, lines: [])
      result = call_validator(invoices: [inv])
      expect(result.errors.map { |e| e[:code] }).to include('MISSING_CUSTOMER')
    end

    it 'errors when buyer GSTIN is present but malformed' do
      customer = fake_customer(gstin: 'BAD-GSTIN')
      result   = call_validator(invoices: [fake_invoice(customer: customer)])
      expect(result.errors.map { |e| e[:code] }).to include('INVALID_BUYER_GSTIN')
    end

    it 'errors when invoice_date is nil' do
      inv = fake_invoice(date: nil)
      allow(inv).to receive(:invoice_date).and_return(nil)
      result = call_validator(invoices: [inv])
      expect(result.errors.map { |e| e[:code] }).to include('MISSING_INVOICE_DATE')
    end

    it 'errors on zero-value invoice' do
      result = call_validator(invoices: [fake_invoice(total: 0)])
      expect(result.errors.map { |e| e[:code] }).to include('ZERO_VALUE_INVOICE')
    end
  end

  # ── Credit note validation ────────────────────────────────────────────────────

  describe 'credit note validation' do
    it 'passes for a well-formed credit note' do
      result = call_validator(credit_notes: [fake_credit_note])
      expect(result.valid?).to be true
    end

    it 'errors when credit note has no customer' do
      cn = double('CreditNote', id: 1, credit_note_number: 'CN-X',
                  issued_at: Time.current, total: 100, customer: nil, lines: [fake_line])
      result = call_validator(credit_notes: [cn])
      expect(result.errors.map { |e| e[:code] }).to include('MISSING_CUSTOMER')
    end

    it 'errors when issue date is missing' do
      cn     = fake_credit_note(issued_at: nil)
      allow(cn).to receive(:issued_at).and_return(nil)
      result = call_validator(credit_notes: [cn])
      expect(result.errors.map { |e| e[:code] }).to include('MISSING_ISSUE_DATE')
    end
  end

  # ── Result accessors ──────────────────────────────────────────────────────────

  describe 'result struct' do
    it 'reports correct counts' do
      inv    = fake_invoice(total: 0) # zero value → 1 error, 0 warnings
      result = call_validator(invoices: [inv])

      expect(result.error_count).to   eq(1)
      expect(result.warning_count).to eq(0)
    end
  end
end
