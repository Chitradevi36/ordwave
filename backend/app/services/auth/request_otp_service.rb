module Auth
  class RequestOtpService
    Result = Struct.new(:success?, :otp_request, :errors, keyword_init: true)

    def initialize(identifier:)
      @identifier = identifier.to_s.strip
    end

    def call
      # Determine identifier type
      if email?
        @identifier_type = :email  # Use symbol for enum
        @normalized = @identifier.downcase.strip
      elsif phone?
        @identifier_type = :phone  # Use symbol for enum
        @normalized = @identifier.gsub(/\D/, '')
      else
        return Result.new(
          success?: false,
          otp_request: nil,
          errors: ['Invalid email or phone number format']
        )
      end

      # Check if user exists
      user = find_user
      unless user&.active? && !user.deleted?
        return Result.new(
          success?: false,
          otp_request: nil,
          errors: ['This account does not exist. Please sign up first.']
        )
      end

      # Create OTP request (scoped to user for security)
      otp_request = OtpRequest.where(
        identifier: @normalized,
        identifier_type: @identifier_type,
        user_id: user.id
      ).order(created_at: :desc).first
      
      # Create new OTP request if none exists or last one is expired
      if otp_request.blank? || otp_request.expired?
        otp_code = format('%06d', SecureRandom.random_number(1_000_000))
        otp_request = OtpRequest.create!(
          user_id: user.id,
          identifier: @normalized,
          identifier_type: @identifier_type,
          otp_code: otp_code,
          request_id: SecureRandom.hex(16),
          otp_sent_at: Time.current
        )
      else
        otp_request.generate_otp!
      end

      # Send OTP via email or phone channel
      sendOtp(otp_request, user)

      Result.new(success?: true, otp_request: otp_request, errors: [])
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("OTP RecordInvalid: #{e.message}")
      Rails.logger.error("Errors: #{e.record.errors.full_messages.inspect}")
      Result.new(success?: false, otp_request: nil, errors: e.record.errors.full_messages)
    rescue => e
      Rails.logger.error("OTP request error: #{e.class} #{e.message}")
      Rails.logger.error(e.backtrace.first(10).join("\n"))
      Result.new(success?: false, otp_request: nil, errors: ['Failed to send OTP. Please try again.'])
    end

    private

    def email?
      @identifier.match?(/\A[^\s@]+@[^\s@]+\.[^\s@]+\z/)
    end

    def phone?
      @identifier.gsub(/\D/, '').match?(/\A[6-9]\d{9}\z/)
    end

    def find_user
      case @identifier_type
      when :email
        User.find_by(email: @normalized)
      when :phone
        User.find_by(phone: @normalized)
      end
    end

    def sendOtp(otp_request, user)
      begin
        case @identifier_type
        when :email
          # Send OTP via email
          AuthMailer.send_otp(user, otp_request.otp_code).deliver_now
        when :phone
          send_phone_otp(otp_request.identifier, otp_request.otp_code)
        end
      rescue => e
        Rails.logger.warn("Failed to send OTP: #{e.class} #{e.message}")
        # Log but don't fail - OTP is already in database
      end
    end

    def send_phone_otp(phone_number, otp_code)
      if whatsapp_otp_enabled?
        begin
          WhatsappService.new.send_template(:login_otp, phone_number: phone_number, otp_code: otp_code)
          return
        rescue => e
          Rails.logger.warn("Failed to send OTP via WhatsApp, falling back to SMS: #{e.class} #{e.message}")
        end
      else
        SmsService.new.send_login_otp(phone_number, otp_code)
      end
    end

    def whatsapp_otp_enabled?
      ENV.fetch('WHATSAPP_OTP_ENABLED', 'true') == 'true'
    end
  end
end
