module PriceLists
  class AssignService
    Result = Struct.new(:success?, :assignment, :errors)

    # assign_to: 'retailer' | 'tier' | 'branch_standard' | 'promo'
    def initialize(price_list:, params:)
      @price_list = price_list
      @params     = params.is_a?(ActionController::Parameters) ? params.to_h.symbolize_keys : params
    end

    def call
      case @params[:assign_to].to_s
      when 'retailer'
        assign_retailer
      when 'tier'
        assign_tier
      when 'branch_standard'
        activate_as_standard
      else
        Result.new(false, nil, ['assign_to must be retailer, tier, or branch_standard'])
      end
    rescue ActiveRecord::RecordInvalid => e
      Result.new(false, nil, e.record.errors.full_messages)
    rescue ActiveRecord::RecordNotFound => e
      Result.new(false, nil, [e.message])
    end

    private

    def assign_retailer
      customer = Customer.find(@params[:retailer_id])
      assignment = RetailerPriceListAssignment.find_or_initialize_by(
        customer:   customer,
        price_list: @price_list
      )
      assignment.assign_attributes(
        active:     true,
        starts_on:  @params[:starts_on],
        ends_on:    @params[:ends_on]
      )
      assignment.save!
      Result.new(true, assignment, [])
    end

    def assign_tier
      branch = Branch.find(@params[:branch_id])
      assignment = TierPriceListAssignment.find_or_initialize_by(
        branch:        branch,
        retailer_tier: @params[:tier],
        price_list:    @price_list
      )
      assignment.assign_attributes(
        active:    true,
        starts_on: @params[:starts_on],
        ends_on:   @params[:ends_on]
      )
      assignment.save!
      Result.new(true, assignment, [])
    end

    def activate_as_standard
      # Set any other active standard list for the branch to inactive first
      PriceList.not_deleted
               .where(branch_id: @price_list.branch_id, list_type: 'standard', status: 'active')
               .where.not(id: @price_list.id)
               .update_all(status: 'inactive')

      @price_list.update!(status: 'active', list_type: 'standard')
      Result.new(true, @price_list, [])
    end
  end
end
