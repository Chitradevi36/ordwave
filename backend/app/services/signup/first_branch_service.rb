module Signup
  class FirstBranchService
    Result = Struct.new(:success?, :pending_registration, :errors, keyword_init: true)

    def initialize(email:, branch_name:, branch_code:, branch_city: nil, branch_state: nil)
      @email        = email.to_s.downcase.strip
      @branch_name  = branch_name
      @branch_code  = branch_code.to_s.upcase
      @branch_city  = branch_city
      @branch_state = branch_state
    end

    def call
      pending = PendingRegistration.active.find_by(email: @email)

      unless pending
        return Result.new(
          success?: false,
          pending_registration: nil,
          errors: ['No pending registration found or session expired']
        )
      end

      unless pending.current_step.in?(%w[org_details first_branch])
        return Result.new(
          success?: false,
          pending_registration: pending,
          errors: ['Please complete previous steps first']
        )
      end

      if @branch_name.blank? || @branch_code.blank?
        return Result.new(
          success?: false,
          pending_registration: pending,
          errors: ['Branch name and code are required']
        )
      end

      pending.store_data!(
        branch_name:  @branch_name,
        branch_code:  @branch_code,
        branch_city:  @branch_city,
        branch_state: @branch_state
      )
      pending.advance_to!('first_branch')

      Result.new(success?: true, pending_registration: pending, errors: [])
    end
  end
end
