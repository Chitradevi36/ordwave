module Api
  module V1
    class SignupController < ActionController::API
      # No auth required for signup flow

      def initiate
        identifier = params[:identifier] || params[:email] || params[:phone]
        result = Signup::InitiateService.new(identifier: identifier).call

        if result.success?
          render json: {
            data: {
              identifier:   result.pending_registration.identifier,
              message:      result.pending_registration.email.present? ? 'OTP sent to your email' : 'OTP sent to your phone',
              otp_code:     Rails.env.development? ? result.pending_registration.otp_code : nil,
              current_step: result.pending_registration.current_step
            }
          }, status: :ok
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      def verify_otp
      identifier = params[:identifier] || params[:email] || params[:phone]
      result = Signup::VerifyOtpService.new(identifier: identifier, otp_code: params[:otp_code]).call

      if result.success?
        render json: {
          data: {
            identifier:   result.pending_registration.identifier,
            current_step: result.pending_registration.current_step,
            message:      'OTP verified successfully'
          }
        }, status: :ok
      else
        render json: { errors: result.errors }, status: :unprocessable_entity
      end
      end

      def set_password
        result = Signup::SetPasswordService.new(
          email:                 params[:email],
          password:              params[:password],
          password_confirmation: params[:password_confirmation]
        ).call

        if result.success?
          render json: {
            data: {
              email:        result.pending_registration.email,
              current_step: result.pending_registration.current_step,
              message:      'Password set successfully'
            }
          }, status: :ok
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      def org_details
        result = Signup::OrgDetailsService.new(
          email:         params[:email],
          org_name:      params[:org_name],
          city:          params[:city],
          state:         params[:state],
          gst_number:    params[:gst_number],
          contact_phone: params[:contact_phone]
        ).call

        if result.success?
          render json: {
            data: {
              email:        result.pending_registration.email,
              current_step: result.pending_registration.current_step,
              message:      'Organization details saved'
            }
          }, status: :ok
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      def first_branch
        result = Signup::FirstBranchService.new(
          email:         params[:email],
          branch_name:   params[:branch_name],
          branch_code:   params[:branch_code],
          branch_city:   params[:branch_city],
          branch_state:  params[:branch_state]
        ).call

        if result.success?
          render json: {
            data: {
              email:        result.pending_registration.email,
              current_step: result.pending_registration.current_step,
              message:      'Branch details saved'
            }
          }, status: :ok
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      def choose_plan
        result = Signup::ChoosePlanService.new(
          email:      params[:email],
          plan:       params[:plan],
          first_name: params[:first_name],
          last_name:  params[:last_name],
          phone:      params[:phone]
        ).call

        if result.success?
          render json: {
            data: {
              token:                  result.token,
              user:                   serialize_user(result.user),
              requires_payment:       result.requires_payment,
              subscription_short_url: result.subscription_short_url,
              message: result.requires_payment \
                         ? 'Please complete payment to activate your plan.' \
                         : 'Registration completed successfully. Please proceed to onboarding.'
            }
          }, status: :created
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      private

      def serialize_user(user)
        {
          id:         user.id,
          email:      user.email,
          first_name: user.first_name,
          last_name:  user.last_name,
          full_name:  user.full_name,
          phone:      user.phone,
          plan:       user.plan
        }
      end

      def serialize_organization(org)
        {
          id:    org.id,
          name:  org.name,
          slug:  org.slug,
          city:  org.city,
          state: org.state
        }
      end
    end
  end
end
