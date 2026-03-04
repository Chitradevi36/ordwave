module Customers
  class UpdateCustomerService
    Result = Struct.new(:success?, :customer, :errors)

    def initialize(customer:, params:)
      @customer = customer
      @params   = params.is_a?(ActionController::Parameters) ? params.to_h.symbolize_keys : params
    end

    def call
      if @customer.update(@params)
        sync_credit_account_limit
        Result.new(true, @customer, [])
      else
        Result.new(false, @customer, @customer.errors.full_messages)
      end
    end

    private

    def sync_credit_account_limit
      return unless @params.key?(:credit_limit)

      ca = @customer.credit_account
      return unless ca

      ca.update(credit_limit: @customer.credit_limit)
    end
  end
end
