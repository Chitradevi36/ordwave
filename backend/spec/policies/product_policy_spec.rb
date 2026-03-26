# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProductPolicy, type: :policy do
  let(:org)     { create(:organization) }
  let(:branch)  { create(:branch, organization: org) }

  let(:owner)     { create(:user, organization: org, branch: branch, role: 'owner') }
  let(:admin)     { create(:user, organization: org, branch: branch, role: 'admin') }
  let(:manager)   { create(:user, organization: org, branch: branch, role: 'manager') }
  let(:sales_rep) { create(:user, organization: org, branch: branch, role: 'sales_rep') }

  let(:product) { create(:product, organization: org) }

  def permissions_for(user)
    described_class.new(user, product)
  end

  describe 'index?' do
    it 'permits all members' do
      [owner, admin, manager, sales_rep].each do |u|
        expect(permissions_for(u).index?).to be true
      end
    end
  end

  describe 'show?' do
    it 'permits all members' do
      [owner, admin, manager, sales_rep].each do |u|
        expect(permissions_for(u).show?).to be true
      end
    end
  end

  describe 'create?' do
    it 'permits manager and above' do
      [owner, admin, manager].each do |u|
        expect(permissions_for(u).create?).to be(true), "Expected #{u.inspect} to be permitted"
      end
    end

    it 'denies sales_rep' do
      expect(permissions_for(sales_rep).create?).to be false
    end
  end

  describe 'update?' do
    it 'permits manager and above' do
      [owner, admin, manager].each do |u|
        expect(permissions_for(u).update?).to be true
      end
    end

    it 'denies sales_rep' do
      expect(permissions_for(sales_rep).update?).to be false
    end
  end

  describe 'destroy?' do
    it 'permits manager and above' do
      [owner, admin, manager].each do |u|
        expect(permissions_for(u).destroy?).to be true
      end
    end

    it 'denies sales_rep' do
      expect(permissions_for(sales_rep).destroy?).to be false
    end
  end

  describe 'discontinue?' do
    it 'permits manager and above' do
      [owner, admin, manager].each do |u|
        expect(permissions_for(u).discontinue?).to be true
      end
    end

    it 'denies sales_rep' do
      expect(permissions_for(sales_rep).discontinue?).to be false
    end
  end

  describe 'Scope' do
    let!(:product_in_org) { create(:product, organization: org) }
    let!(:product_other)  { create(:product, organization: create(:organization)) }
    let!(:deleted_product) { create(:product, organization: org, deleted_at: Time.current) }

    it 'returns non-deleted products for the user organization' do
      scope = described_class::Scope.new(owner, Product).resolve
      expect(scope).to include(product_in_org)
      expect(scope).not_to include(product_other)
      expect(scope).not_to include(deleted_product)
    end
  end
end
