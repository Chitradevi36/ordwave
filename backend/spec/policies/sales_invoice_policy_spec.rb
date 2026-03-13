require 'rails_helper'

RSpec.describe SalesInvoicePolicy, type: :policy do
  subject(:policy) { described_class }

  let(:org)     { create(:organization) }
  let(:branch)  { create(:branch, organization: org) }

  let(:owner)     { create(:user, organization: org, branch: branch, role: 'owner') }
  let(:admin)     { create(:user, organization: org, branch: branch, role: 'admin') }
  let(:manager)   { create(:user, organization: org, branch: branch, role: 'manager') }
  let(:sales_rep) { create(:user, organization: org, branch: branch, role: 'sales_rep') }

  let(:customer)  { create(:customer, organization: org, branch: branch) }

  let(:invoice) do
    create(:sales_invoice, organization: org, branch: branch,
           customer: customer, created_by: owner,
           status: 'issued', issued_at: Time.current)
  end

  def permissions_for(user)
    described_class.new(user, invoice)
  end

  # ── index? ────────────────────────────────────────────────────────────────────

  describe 'index?' do
    it 'permits owner'     do expect(permissions_for(owner).index?).to be true end
    it 'permits admin'     do expect(permissions_for(admin).index?).to be true end
    it 'permits manager'   do expect(permissions_for(manager).index?).to be true end
    it 'permits sales_rep' do expect(permissions_for(sales_rep).index?).to be true end
  end

  # ── show? ─────────────────────────────────────────────────────────────────────

  describe 'show?' do
    it 'permits owner'     do expect(permissions_for(owner).show?).to be true end
    it 'permits admin'     do expect(permissions_for(admin).show?).to be true end
    it 'permits manager'   do expect(permissions_for(manager).show?).to be true end
    it 'permits sales_rep' do expect(permissions_for(sales_rep).show?).to be true end
  end

  # ── create? ───────────────────────────────────────────────────────────────────

  describe 'create?' do
    it 'permits owner'   do expect(permissions_for(owner).create?).to be true end
    it 'permits admin'   do expect(permissions_for(admin).create?).to be true end
    it 'permits manager' do expect(permissions_for(manager).create?).to be true end

    it 'denies sales_rep' do expect(permissions_for(sales_rep).create?).to be false end
  end

  # ── issue? ────────────────────────────────────────────────────────────────────

  describe 'issue?' do
    it 'permits owner'   do expect(permissions_for(owner).issue?).to be true end
    it 'permits admin'   do expect(permissions_for(admin).issue?).to be true end
    it 'permits manager' do expect(permissions_for(manager).issue?).to be true end

    it 'denies sales_rep' do expect(permissions_for(sales_rep).issue?).to be false end
  end

  # ── generate_from_order? ──────────────────────────────────────────────────────

  describe 'generate_from_order?' do
    it 'permits manager' do expect(permissions_for(manager).generate_from_order?).to be true end
    it 'denies sales_rep' do expect(permissions_for(sales_rep).generate_from_order?).to be false end
  end

  # ── generate_from_stop? ───────────────────────────────────────────────────────

  describe 'generate_from_stop?' do
    it 'permits manager' do expect(permissions_for(manager).generate_from_stop?).to be true end
    it 'denies sales_rep' do expect(permissions_for(sales_rep).generate_from_stop?).to be false end
  end

  # ── void? ─────────────────────────────────────────────────────────────────────

  describe 'void?' do
    it 'permits owner'  do expect(permissions_for(owner).void?).to be true end
    it 'permits admin'  do expect(permissions_for(admin).void?).to be true end

    it 'denies manager'   do expect(permissions_for(manager).void?).to be false end
    it 'denies sales_rep' do expect(permissions_for(sales_rep).void?).to be false end
  end

  # ── pdf? ──────────────────────────────────────────────────────────────────────

  describe 'pdf?' do
    it 'permits owner'     do expect(permissions_for(owner).pdf?).to be true end
    it 'permits admin'     do expect(permissions_for(admin).pdf?).to be true end
    it 'permits manager'   do expect(permissions_for(manager).pdf?).to be true end
    it 'permits sales_rep' do expect(permissions_for(sales_rep).pdf?).to be true end
  end

  # ── Scope ─────────────────────────────────────────────────────────────────────

  describe 'Scope' do
    let(:other_branch)   { create(:branch, organization: org, code: 'OTH') }
    let(:other_invoice)  do
      create(:sales_invoice, organization: org, branch: other_branch,
             customer: customer, created_by: owner,
             status: 'issued', issued_at: Time.current)
    end

    before { invoice; other_invoice }

    context 'when manager_above' do
      it 'returns ALL invoices in the org' do
        scope = described_class::Scope.new(owner, SalesInvoice.all).resolve
        expect(scope).to include(invoice, other_invoice)
      end
    end

    context 'when sales_rep' do
      let(:rep_invoice) do
        create(:sales_invoice, organization: org, branch: branch,
               customer: customer, created_by: sales_rep,
               status: 'issued', issued_at: Time.current)
      end

      before { rep_invoice }

      it 'restricts to own branch invoices' do
        scope = described_class::Scope.new(sales_rep, SalesInvoice.all).resolve
        expect(scope).to include(rep_invoice)
        expect(scope).not_to include(other_invoice)
      end
    end
  end
end
