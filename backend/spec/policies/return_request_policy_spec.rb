require 'rails_helper'

RSpec.describe ReturnRequestPolicy, type: :policy do
  let(:org)    { create(:organization) }
  let(:branch) { create(:branch, organization: org) }

  # Role records
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

  def make_return(status: 'draft')
    create(:return_request, organization: org, branch: branch,
           customer: create(:customer, organization: org),
           created_by: create(:user), status: status)
  end

  def policy(ctx, record)
    described_class.new(ctx, record)
  end

  #  index? / show? 

  describe '#index? and #show?' do
    let(:return_request) { make_return }

    it 'permits owner' do
      ctx = make_context(owner_role)
      expect(policy(ctx, return_request)).to be_index
      expect(policy(ctx, return_request)).to be_show
    end

    it 'permits sales_rep' do
      ctx = make_context(sales_rep_role)
      expect(policy(ctx, return_request)).to be_index
    end

    it 'denies a user with no membership' do
      user = create(:user)
      ctx  = UserContext.new(user: user, organization: org)
      expect(policy(ctx, return_request)).not_to be_index
    end
  end

  #  create? / update? 

  describe '#create?' do
    it 'permits sales_rep' do
      expect(policy(make_context(sales_rep_role), make_return)).to be_create
    end

    it 'permits manager' do
      expect(policy(make_context(manager_role), make_return)).to be_create
    end

    it 'denies unauthenticated user' do
      ctx = UserContext.new(user: create(:user), organization: org)
      expect(policy(ctx, make_return)).not_to be_create
    end
  end

  describe '#update? (draft only)' do
    it 'permits sales_rep on a draft' do
      expect(policy(make_context(sales_rep_role), make_return(status: 'draft'))).to be_update
    end

    it 'denies update on a submitted return' do
      expect(policy(make_context(sales_rep_role), make_return(status: 'submitted'))).not_to be_update
    end
  end

  #  start_qc? — warehouse and above 

  describe '#start_qc?' do
    let(:submitted_return) { make_return(status: 'submitted') }

    it 'permits warehouse_staff' do
      expect(policy(make_context(warehouse_role), submitted_return)).to be_start_qc
    end

    it 'permits manager' do
      expect(policy(make_context(manager_role), submitted_return)).to be_start_qc
    end

    it 'permits owner' do
      expect(policy(make_context(owner_role), submitted_return)).to be_start_qc
    end

    it 'denies sales_rep (cannot perform QC)' do
      expect(policy(make_context(sales_rep_role), submitted_return)).not_to be_start_qc
    end
  end

  #  complete_qc? 

  describe '#complete_qc?' do
    let(:qc_in_progress_return) { make_return(status: 'qc_in_progress') }

    it 'permits warehouse_staff' do
      expect(policy(make_context(warehouse_role), qc_in_progress_return)).to be_complete_qc
    end

    it 'denies sales_rep' do
      expect(policy(make_context(sales_rep_role), qc_in_progress_return)).not_to be_complete_qc
    end

    it 'denies when return is already qc_completed' do
      expect(policy(make_context(warehouse_role), make_return(status: 'qc_completed'))).not_to be_complete_qc
    end
  end

  #  cancel? — manager and above 

  describe '#cancel?' do
    let(:draft_return) { make_return(status: 'draft') }

    it 'permits manager' do
      expect(policy(make_context(manager_role), draft_return)).to be_cancel
    end

    it 'permits owner' do
      expect(policy(make_context(owner_role), draft_return)).to be_cancel
    end

    it 'denies sales_rep' do
      expect(policy(make_context(sales_rep_role), draft_return)).not_to be_cancel
    end

    it 'denies warehouse_staff' do
      expect(policy(make_context(warehouse_role), draft_return)).not_to be_cancel
    end

    it 'denies cancel on a qc_completed return (not cancellable)' do
      expect(policy(make_context(manager_role), make_return(status: 'qc_completed'))).not_to be_cancel
    end
  end

  #  Scope 

  describe 'Scope' do
    let(:other_org)    { create(:organization) }
    let(:other_branch) { create(:branch, organization: other_org) }

    it 'includes only returns from the user organisation' do
      ctx = make_context(sales_rep_role)

      own_return = create(:return_request, organization: org, branch: branch,
                          customer: create(:customer, organization: org),
                          created_by: create(:user))
      _other_return = create(:return_request, organization: other_org, branch: other_branch,
                              customer: create(:customer, organization: other_org),
                              created_by: create(:user))

      scope_result = described_class::Scope.new(ctx, ReturnRequest).resolve
      expect(scope_result).to include(own_return)
      expect(scope_result.map(&:organization_id).uniq).to eq([org.id])
    end
  end
end