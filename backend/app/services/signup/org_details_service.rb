module Signup
  class OrgDetailsService
    Result = Struct.new(:success?, :pending_registration, :errors, keyword_init: true)

    def initialize(email:, org_name:, city: nil, state: nil, gst_number: nil, contact_phone: nil)
      @email         = email.to_s.downcase.strip
      @org_name      = org_name
      @city          = city
      @state         = state
      @gst_number    = gst_number
      @contact_phone = contact_phone
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

      unless pending.current_step.in?(%w[set_password org_details])
        return Result.new(
          success?: false,
          pending_registration: pending,
          errors: ['Please complete previous steps first']
        )
      end

      if @org_name.blank?
        return Result.new(
          success?: false,
          pending_registration: pending,
          errors: ['Organization name is required']
        )
      end

      pending.store_data!(
        org_name:      @org_name,
        city:          @city,
        state:         @state,
        gst_number:    @gst_number,
        contact_phone: @contact_phone
      )
      pending.advance_to!('org_details')

      Result.new(success?: true, pending_registration: pending, errors: [])
    end
  end
end
