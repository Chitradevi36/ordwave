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

      ActiveRecord::Base.transaction do
        unless customer.save
          raise ActiveRecord::Rollback
        end

        build_credit_account(customer)

        # If a phone is present, ensure a corresponding User exists (or create one)
        if customer.phone.present?
          existing_user = User.find_by(phone: customer.phone)
          unless existing_user
            parts = customer.name.to_s.strip.split(/\s+/)
            first_name = parts[0] || "Customer"
            last_name = parts.length > 1 ? parts[1..].join(' ') : ""

            generated_email = "phone+#{customer.phone}@orderlane.local"
            pwd = SecureRandom.hex(10)

            user_result = Users::CreateUserService.new(
              email: first_name.present? ? generated_email : generated_email,
              password: pwd,
              first_name: first_name,
              last_name: last_name,
              phone: customer.phone
            ).call

            unless user_result.success?
              customer.errors.add(:base, "user_creation_failed: #{user_result.errors.join('; ')}")
              raise ActiveRecord::Rollback
            end
            created_user = user_result.user
            # Ensure the user has a membership for this organization/branch with role 'customer'
            begin
              customer_role = Role.fetch!('customer')
              existing_membership = Membership.where(user: created_user, organization: @organization, branch_id: customer.branch_id).first
              unless existing_membership
                Membership.create!(user: created_user, organization: @organization, branch_id: customer.branch_id, role: customer_role, active: true)
              end
            rescue => e
              customer.errors.add(:base, "membership_creation_failed: #{e.message}")
              raise ActiveRecord::Rollback
            end
          end
        end
      end

      if customer.persisted?
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
