# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Gst::Gstr1::JsonBuilder, type: :service do
  let(:seller_gstin)  { '27XYZAB1234C1Z9' }
  let(:return_period) { '032026' }

  # ── Sample data builders using FactoryBot ────────────────────────────────────

  let(:org)    { create(:organization, gst_number: seller_gstin) }
  let(:branch) { create(:branch, organization: org, state_code: '27', state: 'Maharashtra') }

  # B2B customer in Karnataka (29 → inter-state)
  let(:b2b_customer) do
    create(:customer, organization: org, branch: branch,
           gstin: '29ABCDE1234F1Z5', name: 'Karnataka Buyer')
  end

  # B2C unregistered customer in Maharashtra (27 → intra-state)
  let(:b2c_customer) do
    create(:customer, organization: org, branch: branch, gstin: nil, name: 'Unregistered Buyer')
  end

  let(:product) { create(:product, organization: org, hsn_code: '10060010') }

  # Intra-state role for UOM
  let(:uom) do
    create(:unit_of_measure, organization: org, symbol: 'KGS') rescue nil
  end

  def make_invoice(customer:, total: 1_180.0, status: 'issued')
    inv = create(:sales_invoice,
      organization: org,
      branch:       branch,
      customer:     customer,
      status:       status,
      subtotal:     1_000.0,
      tax_total:      180.0,
      grand_total:  total,
      invoice_date: Date.new(2026, 3, 15)
    )
    create(:sales_invoice_line,
      sales_invoice: inv,
      product:       product,
      qty:           10,
      unit_price:    100.0,
      taxable_value: 1_000.0,
      hsn_code:      '10060010',
      gst_rate:      18.0,
      cgst_rate:     9.0, cgst_amount: 90.0,
      sgst_rate:     9.0, sgst_amount: 90.0,
      igst_rate:     0.0, igst_amount:  0.0,
      tax_amount:    180.0,
      line_total:  1_180.0
    )
    inv.reload
  end

  def make_credit_note(customer:, total: 590.0, status: 'issued')
    cn = create(:credit_note,
      organization: org,
      branch:       branch,
      customer:     customer,
      status:       status,
      subtotal:     500.0,
      tax_total:     90.0,
      total:        total,
      issued_at:    Time.new(2026, 3, 20)
    )
    create(:credit_note_line,
      credit_note: cn,
      product:     product,
      qty:         5,
      unit_price:  100.0,
      gst_rate:    18.0,
      tax_amount:  90.0,
      line_total:  590.0
    )
    cn.reload
  end

  def build_json(b2b_invoices: [], b2cl_invoices: [], b2cs_invoices: [],
                 cdnr_notes: [], cdnur_notes: [], state_code: '27')
    described_class.call(
      gstin:             seller_gstin,
      return_period:     return_period,
      b2b_invoices:      b2b_invoices,
      b2cl_invoices:     b2cl_invoices,
      b2cs_invoices:     b2cs_invoices,
      cdnr_notes:        cdnr_notes,
      cdnur_notes:       cdnur_notes,
      seller_state_code: state_code
    )
  end

  # ── Top-level envelope ───────────────────────────────────────────────────────

  describe 'portal envelope' do
    subject(:json) { build_json }

    it 'includes mandatory portal fields' do
      expect(json).to include(:gstin, :fp, :b2b, :b2cl, :b2cs, :cdnr, :cdnur, :hsn, :doc_issue)
    end

    it 'sets gstin to seller GSTIN' do
      expect(json[:gstin]).to eq(seller_gstin)
    end

    it 'sets fp to MMYYYY format' do
      expect(json[:fp]).to eq('032026')
    end

    it 'sets gt and cur_gt to nil (portal fills these)' do
      expect(json[:gt]).to be_nil
      expect(json[:cur_gt]).to be_nil
    end
  end

  # ── B2B section ───────────────────────────────────────────────────────────────

  describe 'B2B section' do
    let(:inv) { make_invoice(customer: b2b_customer) }
    subject(:b2b) { build_json(b2b_invoices: [inv])[:b2b] }

    it 'groups by buyer GSTIN' do
      expect(b2b.size).to eq(1)
      expect(b2b.first[:ctin]).to eq('29ABCDE1234F1Z5')
    end

    it 'includes invoice details' do
      invoice_data = b2b.first[:inv].first
      expect(invoice_data).to include(:inum, :idt, :val, :pos, :rchrg, :inv_typ, :itms)
    end

    it 'sets pos to buyer state code from GSTIN' do
      expect(b2b.first[:inv].first[:pos]).to eq('29')
    end

    it 'sets rchrg to N (not reverse charge)' do
      expect(b2b.first[:inv].first[:rchrg]).to eq('N')
    end

    it 'computes inter-state IGST (no CGST/SGST) for Karnataka buyer' do
      # Seller is Maharashtra (27), buyer is Karnataka (29) → inter-state → IGST only
      itm_det = b2b.first[:inv].first[:itms].first[:itm_det]
      expect(itm_det[:iamt]).to be > 0
      expect(itm_det[:camt]).to eq(0.0)
      expect(itm_det[:samt]).to eq(0.0)
    end
  end

  # ── B2CS section ─────────────────────────────────────────────────────────────

  describe 'B2CS section' do
    let(:inv) { make_invoice(customer: b2c_customer, total: 1_180.0) }

    subject(:b2cs) { build_json(b2cs_invoices: [inv])[:b2cs] }

    it 'aggregates by POS + rate' do
      expect(b2cs).to be_an(Array)
      expect(b2cs).not_to be_empty
    end

    it 'sets sply_ty to INTRA for same-state transactions' do
      # Both seller and POS (fallback to branch) are Maharashtra (27)
      expect(b2cs.first[:sply_ty]).to eq('INTRA')
    end

    it 'does NOT use OE as sply_ty (regression for bug fix)' do
      expect(b2cs.map { |r| r[:sply_ty] }).not_to include('OE')
    end

    it 'sets CGST/SGST (not IGST) for intra-state B2CS' do
      expect(b2cs.first[:camt]).to be > 0
      expect(b2cs.first[:samt]).to be > 0
      expect(b2cs.first[:iamt]).to eq(0.0)
    end
  end

  # ── CDNR section ─────────────────────────────────────────────────────────────

  describe 'CDNR section' do
    let(:cn) { make_credit_note(customer: b2b_customer) }
    subject(:cdnr) { build_json(cdnr_notes: [cn])[:cdnr] }

    it 'groups by buyer GSTIN' do
      expect(cdnr.first[:ctin]).to eq('29ABCDE1234F1Z5')
    end

    it 'sets ntty to C for credit notes' do
      expect(cdnr.first[:nt].first[:ntty]).to eq('C')
    end

    it 'uses correct taxable value (line_total − tax_amount, not unit_price × qty)' do
      # Regression: old code used unit_price * qty which could diverge from actual taxable
      note_data = cdnr.first[:nt].first
      expect(note_data[:itms]).not_to be_empty
      txval = note_data[:itms].first[:itm_det][:txval]
      # 590 - 90 = 500 taxable
      expect(txval).to be_within(0.01).of(500.0)
    end
  end

  # ── HSN section ───────────────────────────────────────────────────────────────

  describe 'HSN section' do
    let(:inv) { make_invoice(customer: b2b_customer) }
    subject(:hsn) { build_json(b2b_invoices: [inv])[:hsn][:data] }

    it 'produces at least one HSN row' do
      expect(hsn).not_to be_empty
    end

    it 'includes required portal fields' do
      expect(hsn.first).to include(:hsn_sc, :desc, :uqc, :cnt, :qty, :rt, :txval)
    end

    it 'accumulates quantity and taxable value' do
      expect(hsn.first[:qty]).to be > 0
      expect(hsn.first[:txval]).to be > 0
    end
  end

  # ── Doc issue section ─────────────────────────────────────────────────────────

  describe 'doc_issue section' do
    let(:inv) { make_invoice(customer: b2b_customer) }
    subject(:doc) { build_json(b2b_invoices: [inv])[:doc_issue] }

    it 'returns an array with at least one doc_det entry' do
      expect(doc).to be_an(Array)
      expect(doc.first[:doc_det]).not_to be_empty
    end

    it 'sets totnum to the invoice count' do
      expect(doc.first[:doc_det].first[:totnum]).to eq(1)
    end
  end

  # ── Empty dataset ─────────────────────────────────────────────────────────────

  describe 'when called with no invoices or credit notes' do
    subject(:json) { build_json }

    it 'returns empty arrays for all sections' do
      expect(json[:b2b]).to   be_empty
      expect(json[:b2cl]).to  be_empty
      expect(json[:b2cs]).to  be_empty
      expect(json[:cdnr]).to  be_empty
      expect(json[:cdnur]).to be_empty
      expect(json[:hsn][:data]).to be_empty
      expect(json[:doc_issue]).to be_empty
    end
  end
end
