module Customers
  class CreateCustomerService
    Result = Struct.new(:success?, :customer, :errors)

    def initialize(params:, organization:, branch_id:)
      @params       = params.is_a?(ActionController::Parameters) ? params.to_h.symbolize_keys : params
      @organization = organization
      @branch_id    = branch_id || @params[:branch_id]
    end

    def call
      customer = Customer.new(
        @params.merge(
          organization: @organization,
          branch_id:    @branch_id
        )
      )

      if customer.save
        build_credit_account(customer)
        Result.new(true, customer, [])
      else
        Result.new(false, nil, customer.errors.full_messages)
      end
    end

    private

    def build_credit_account(customer)
      CreditAccount.create!(
        customer:        customer,
        organization:    @organization,
        branch_id:       customer.branch_id,
        credit_limit:    customer.credit_limit || 0,
        current_balance: 0,
        available_credit: customer.credit_limit || 0,
        overdue_amount:  0,
        overdue_days:    0
      )
    end
  end
end
