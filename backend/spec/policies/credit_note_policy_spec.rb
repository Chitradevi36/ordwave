require 'rails_helper'

RSpec.describe CreditNotePolicy, type: :policy do
  let(:org)      { create(:organization) }
  let(:branch)   { create(:branch, organization: org) }
  let(:customer) { create(:customer, organization: org) }

  let(:owner_role)     { create(:role, name: 'owner') }
  let(:admin_role)     { create(:role, name: 'admin') }
  let(:manager_role)   { create(:role, name: 'manager') }
  let(:warehouse_role) { create(:role, name: 'warehouse_staff') }
  let(:sales_rep_role) { create(:role, name: 'sales_rep') }

  def make_context(role)
    user = create(:user)
    create(:membership, user: user, organization: org, branch: branch, role: role)
    UserContext.new(user: user, organization: org)
  end

  def make_credit_note(status: 'issued')
    rr = create(:return_request, organization: org, branch: branch,
                customer: customer, created_by: create(:user), status: 'credit_note_issued')
    create(:credit_note, organization: org, branch: branch, customer: customer,
           return_request: rr, created_by: create(:user), status: status)
  end

  def policy(ctx, cn)
    described_class.new(ctx, cn)
  end

  #  index? / show? — all members 

  describe '#index? and #show?' do
    let(:cn) { make_credit_note }

    it 'permits owner' do
      expect(policy(make_context(owner_role), cn)).to be_index
      expect(policy(make_context(owner_role), cn)).to be_show
    end

    it 'permits sales_rep' do
      expect(policy(make_context(sales_rep_role), cn)).to be_index
    end

    it 'permits warehouse_staff' do
      expect(policy(make_context(warehouse_role), cn)).to be_show
    end

    it 'denies user with no membership' do
      user = create(:user)
      ctx  = UserContext.new(user: user, organization: org)
      expect(policy(ctx, cn)).not_to be_index
    end
  end

  #  issue? — managers and above 

  describe '#issue?' do
    let(:cn) { make_credit_note }

    it 'permits owner' do
      expect(policy(make_context(owner_role), cn)).to be_issue
    end

    it 'permits admin' do
      expect(policy(make_context(admin_role), cn)).to be_issue
    end

    it 'permits manager' do
      expect(policy(make_context(manager_role), cn)).to be_issue
    end

    it 'denies warehouse_staff' do
      expect(policy(make_context(warehouse_role), cn)).not_to be_issue
    end

    it 'denies sales_rep' do
      expect(policy(make_context(sales_rep_role), cn)).not_to be_issue
    end
  end

  #  void? — owner ONLY 

  describe '#void?' do
    let(:cn) { make_credit_note }

    it 'permits owner' do
      expect(policy(make_context(owner_role), cn)).to be_void
    end

    it 'denies admin' do
      expect(policy(make_context(admin_role), cn)).not_to be_void
    end

    it 'denies manager' do
      expect(policy(make_context(manager_role), cn)).not_to be_void
    end

    it 'denies warehouse_staff' do
      expect(policy(make_context(warehouse_role), cn)).not_to be_void
    end

    it 'denies sales_rep' do
      expect(policy(make_context(sales_rep_role), cn)).not_to be_void
    end
  end

  #  Scope 

  describe 'Scope' do
    let(:other_org)    { create(:organization) }
    let(:other_branch) { create(:branch, organization: other_org) }

    it 'includes only credit notes from the user organisation' do
      ctx    = make_context(sales_rep_role)
      own_cn = make_credit_note

      other_customer = create(:customer, organization: other_org)
      other_rr = create(:return_request, organization: other_org, branch: other_branch,
                        customer: other_customer, created_by: create(:user), status: 'credit_note_issued')
      _other_cn = create(:credit_note, organization: other_org, branch: other_branch,
                          customer: other_customer, return_request: other_rr, created_by: create(:user))

      scope_result = described_class::Scope.new(ctx, CreditNote).resolve
      expect(scope_result).to include(own_cn)
      expect(scope_result.map(&:organization_id).uniq).to eq([org.id])
    end
  end
end