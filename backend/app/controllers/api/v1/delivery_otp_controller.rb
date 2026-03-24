# == API Endpoints for SMS/OTP Management =======================================
#
# Routes:
#   POST   /api/v1/delivery_stops/:id/send_otp
#   POST   /api/v1/delivery_stops/:id/verify_otp

module Api
  module V1
    class DeliveryOTPController < ApplicationController
      before_action :authenticate_user!
      before_action :find_delivery_stop, only: [:send_otp, :verify_otp]
      before_action :authorize_access!

      # ── Send OTP to Driver ─────────────────────────────────────────────────────
      # Generates and sends OTP via SMS to the driver for delivery verification
      #
      # POST /api/v1/delivery_stops/:id/send_otp
      #
      # @return [200] { otp_sent: true, message: "OTP sent", expires_in_seconds: 600 }
      # @return [422] If SMS service fails
      # @return [403] If user doesn't have permission
      def send_otp
        # Find or create delivery proof record
        delivery_proof = @delivery_stop.delivery_proof || @delivery_stop.build_delivery_proof

        # Generate OTP (bcrypted for security)
        raw_otp = format('%06d', SecureRandom.random_number(1_000_000))
        delivery_proof.otp_code_digest = BCrypt::Password.create(raw_otp)
        delivery_proof.otp_sent_at = Time.current
        delivery_proof.otp_attempts = 0

        unless delivery_proof.save
          return render_error('Failed to create OTP record', status: :unprocessable_entity)
        end

        # Send OTP via SMS
        driver = @delivery_stop.trip.driver
        unless driver&.phone_number.present?
          return render_error('Driver phone number not available', status: :bad_request)
        end

        begin
          sms_service = SMSService.new
          sms_service.send_delivery_otp(
            driver.phone_number,
            raw_otp,
            @delivery_stop.id
          )

          # Log action for audit trail
          @delivery_stop.audit_trail.create!(
            action: 'otp_sent',
            actor_id: current_user.id,
            actor_name: current_user.name,
            changes: { otp_requested_at: Time.current },
            reason: params[:reason]
          )

          render json: {
            otp_sent: true,
            message: "OTP sent to #{driver.phone_number}",
            expires_in_seconds: 600,
            attempts_remaining: 5
          }
        rescue SMSService::SMSSendError => e
          Rails.logger.error("OTP send failed: #{e.message}")
          render_error("Failed to send OTP: #{e.message}", status: :service_unavailable)
        end
      end

      # ── Verify OTP ───────────────────────────────────────────────────────────────
      # Validates driver's OTP submission
      #
      # POST /api/v1/delivery_stops/:id/verify_otp
      # Body: { otp: "123456" }
      #
      # @return [200] { verified: true, message: "OTP verified successfully" }
      # @return [422] If OTP is invalid, expired, or too many attempts
      # @return [403] If user doesn't have permission
      def verify_otp
        otp_code = params.require(:otp)
        delivery_proof = @delivery_stop.delivery_proof

        unless delivery_proof.present?
          return render_error('No OTP request found for this delivery', status: :not_found)
        end

        # Check if OTP is still valid (10 minutes)
        if delivery_proof.otp_sent_at.blank? || delivery_proof.otp_sent_at < 10.minutes.ago
          return render_error('OTP has expired. Please request a new one.', status: :unprocessable_entity)
        end

        # Check attempt limit
        if (delivery_proof.otp_attempts || 0) >= 5
          return render_error('Too many OTP attempts. Please request a new OTP.', status: :unprocessable_entity)
        end

        # Verify OTP (bcrypt comparison)
        if delivery_proof.otp_matches?(otp_code)
          delivery_proof.update(
            otp_verified_at: Time.current,
            otp_proof_type: 'otp'
          )

          # Log successful verification
          @delivery_stop.audit_trail.create!(
            action: 'otp_verified',
            actor_id: current_user.id,
            actor_name: current_user.name,
            changes: { otp_verified_at: Time.current }
          )

          render json: {
            verified: true,
            message: 'OTP verified successfully',
            proof_id: delivery_proof.id
          }
        else
          # Increment attempt counter
          delivery_proof.increment!(:otp_attempts)

          render_error(
            "Invalid OTP. #{5 - delivery_proof.otp_attempts} attempts remaining.",
            status: :unprocessable_entity
          )
        end
      end

      private

      def find_delivery_stop
        @delivery_stop = DeliveryStop.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_error('Delivery stop not found', status: :not_found)
      end

      def authorize_access!
        # User can verify OTP for their own delivery stops
        # Typically the driver/attendant verifying the delivery
        authorize @delivery_stop, :view?
      end

      def render_error(message, status:)
        render json: { error: message }, status: status
      end
    end
  end
end
