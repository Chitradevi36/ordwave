# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PaymentPolicy, type: :policy do
  let(:org)     { create(:organization) }
  let(:branch)  { create(:branch, organization: org) }

  let(:owner)     { create(:user, organization: org, branch: branch, role: 'owner') }
  let(:admin)     { create(:user, organization: org, branch: branch, role: 'admin') }
  let(:manager)   { create(:user, organization: org, branch: branch, role: 'manager') }
  let(:sales_rep) { create(:user, organization: org, branch: branch, role: 'sales_rep') }

  let(:customer) { create(:customer, organization: org, branch: branch) }
  let(:payment) do
    create(:payment, organization: org, branch: branch, customer: customer,
           created_by: owner, status: 'draft')
  end

  def permissions_for(user, record = payment)
    described_class.new(user, record)
  end

  # ── index? ────────────────────────────────────────────────────────────────────

  describe 'index?' do
    it 'permits all members' do
      [owner, admin, manager, sales_rep].each do |u|
        expect(permissions_for(u).index?).to be true
      end
    end
  end

  # ── show? ─────────────────────────────────────────────────────────────────────

  describe 'show?' do
    it 'permits all members within org' do
      [owner, admin, manager, sales_rep].each do |u|
        expect(permissions_for(u).show?).to be true
      end
    end
  end

  # ── create? ───────────────────────────────────────────────────────────────────

  describe 'create?' do
    it 'permits manager and above' do
      [owner, admin, manager].each do |u|
        expect(permissions_for(u).create?).to be true
      end
    end

    it 'denies sales_rep' do
      expect(permissions_for(sales_rep).create?).to be false
    end
  end

  # ── confirm? ──────────────────────────────────────────────────────────────────

  describe 'confirm?' do
    it 'permits manager+ for draft payments' do
      expect(permissions_for(manager).confirm?).to be true
    end

    it 'denies sales_rep' do
      expect(permissions_for(sales_rep).confirm?).to be false
    end

    it 'denies when payment is not draft' do
      confirmed = create(:payment, organization: org, branch: branch,
                         customer: customer, created_by: owner, status: 'confirmed')
      expect(permissions_for(manager, confirmed).confirm?).to be false
    end
  end

  # ── reverse? ──────────────────────────────────────────────────────────────────

  describe 'reverse?' do
    let(:confirmed_payment) do
      create(:payment, organization: org, branch: branch,
             customer: customer, created_by: owner, status: 'confirmed')
    end

    it 'permits owner/admin for confirmed payments' do
      [owner, admin].each do |u|
        expect(permissions_for(u, confirmed_payment).reverse?).to be true
      end
    end

    it 'denies manager' do
      expect(permissions_for(manager, confirmed_payment).reverse?).to be false
    end

    it 'denies for draft payments' do
      expect(permissions_for(owner).reverse?).to be false
    end
  end

  # ── Scope ─────────────────────────────────────────────────────────────────────

  describe 'Scope' do
    let!(:payment_in_org) do
      create(:payment, organization: org, branch: branch, customer: customer, created_by: owner)
    end
    let!(:other_payment) do
      other_org = create(:organization)
      other_br  = create(:branch, organization: other_org)
      other_cust = create(:customer, organization: other_org, branch: other_br)
      create(:payment, organization: other_org, branch: other_br, customer: other_cust,
             created_by: create(:user))
    end

    it 'scopes to org payments for managers' do
      scope = described_class::Scope.new(manager, Payment).resolve
      expect(scope).to include(payment_in_org)
      expect(scope).not_to include(other_payment)
    end
  end
end
