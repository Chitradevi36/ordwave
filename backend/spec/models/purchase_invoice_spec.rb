require 'rails_helper'

RSpec.describe PurchaseInvoice, type: :model do
  subject(:invoice) { build(:purchase_invoice) }

  # ── Validations ─────────────────────────────────────────────────────────────
  describe 'validations' do
    it { is_expected.to validate_presence_of(:invoice_number) }
    it { is_expected.to validate_presence_of(:invoice_date) }
    it { is_expected.to validate_presence_of(:currency) }
    it { is_expected.to validate_inclusion_of(:status).in_array(PurchaseInvoice::STATUSES) }

    it 'validates invoice_number uniqueness per supplier (ignoring deleted)' do
      existing = create(:purchase_invoice)
      duplicate = build(:purchase_invoice,
                        supplier:       existing.supplier,
                        organization:   existing.organization,
                        branch:         existing.branch,
                        invoice_number: existing.invoice_number)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:invoice_number]).to be_present
    end

    it 'allows the same invoice_number for a different supplier' do
      inv1 = create(:purchase_invoice, invoice_number: 'INV-001')
      inv2 = build(:purchase_invoice,
                   invoice_number: 'INV-001',
                   organization:   inv1.organization,
                   branch:         inv1.branch)
      expect(inv2).to be_valid
    end

    it 'disallows due_date before invoice_date' do
      inv = build(:purchase_invoice, invoice_date: Date.current, due_date: Date.current - 1)
      expect(inv).not_to be_valid
      expect(inv.errors[:due_date]).to be_present
    end
  end

  # ── State helpers ────────────────────────────────────────────────────────────
  describe 'state helpers' do
    it '#draft? returns true for draft status' do
      expect(build(:purchase_invoice, status: 'draft')).to be_draft
    end

    it '#posted? returns true for posted status' do
      expect(build(:purchase_invoice, :posted)).to be_posted
    end

    it '#cancelled? returns true for cancelled status' do
      expect(build(:purchase_invoice, :cancelled)).to be_cancelled
    end

    it '#editable? is true only when draft' do
      expect(build(:purchase_invoice, status: 'draft')).to be_editable
      expect(build(:purchase_invoice, status: 'posted')).not_to be_editable
    end
  end

  # ── Immutability ─────────────────────────────────────────────────────────────
  describe 'immutable_when_posted_or_cancelled' do
    it 'does not allow updating notes on a posted invoice' do
      inv = create(:purchase_invoice, :posted)
      inv.notes = 'changed'
      expect(inv).not_to be_valid
      expect(inv.errors.full_messages).to include(match(/cannot be modified/i))
    end

    it 'allows status transitions (cancellation)' do
      inv = create(:purchase_invoice, :posted)
      inv.status       = 'cancelled'
      inv.cancelled_at = Time.current
      expect(inv).to be_valid
    end
  end

  # ── recalculate_totals! ───────────────────────────────────────────────────────
  describe '#recalculate_totals!' do
    it 'sums line subtotals and taxes into the invoice totals' do
      inv  = create(:purchase_invoice)
      # qty:5, unit_price:100, tax_rate:18 → subtotal=500, tax=90, total=590
      create(:purchase_invoice_line, purchase_invoice: inv,
             qty: 5, unit_price: 100, discount_pct: 0, tax_rate: 18,
             tax_amount: 90, line_total: 590)
      # qty:2, unit_price:50, tax_rate:5 → subtotal=100, tax=5, total=105
      create(:purchase_invoice_line, purchase_invoice: inv,
             qty: 2, unit_price: 50, discount_pct: 0, tax_rate: 5,
             tax_amount: 5, line_total: 105)

      inv.reload.recalculate_totals!
      inv.reload

      expect(inv.total_amount).to eq(600.00)
      expect(inv.tax_amount).to   eq(95.00)
      expect(inv.grand_total).to  eq(695.00)
    end
  end

  # ── Associations ─────────────────────────────────────────────────────────────
  describe 'associations' do
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to belong_to(:supplier) }
    it { is_expected.to belong_to(:branch) }
    it { is_expected.to have_many(:lines).class_name('PurchaseInvoiceLine').dependent(:destroy) }
    it { is_expected.to have_many(:stock_movements).dependent(:nullify) }
  end
end
