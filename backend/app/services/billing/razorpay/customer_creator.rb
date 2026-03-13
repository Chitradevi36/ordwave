# app/services/billing/razorpay/customer_creator.rb
#
# Finds or creates a Razorpay customer for an Organization.
# Stores the razorpay_customer_id on the organization record.
#
module Billing
  module Razorpay
    class CustomerCreator
      Result = Struct.new(:success?, :customer_id, :error, keyword_init: true)

      def initialize(organization)
        @organization = organization
      end

      def call
        # Return cached customer id if we already created one
        if @organization.razorpay_customer_id.present?
          return Result.new(success?: true, customer_id: @organization.razorpay_customer_id, error: nil)
        end

        owner = @organization.users.find_by(memberships: { role: "owner" }) ||
                @organization.users.first

        customer = ::Razorpay::Customer.create(
          name:    @organization.name.truncate(100),
          email:   owner&.email.to_s,
          contact: owner&.phone.to_s,
          notes:   {
            organization_id:   @organization.id.to_s,
            organization_name: @organization.name
          }
        )

        @organization.update_column(:razorpay_customer_id, customer.id)

        Result.new(success?: true, customer_id: customer.id, error: nil)
      rescue ::Razorpay::Error => e
        Rails.logger.error("[Billing::CustomerCreator] Razorpay error: #{e.message}")
        Result.new(success?: false, customer_id: nil, error: e.message)
      end
    end
  end
end
