module Signup
  class InitiateService
    Result = Struct.new(:success?, :pending_registration, :errors, keyword_init: true)

    def initialize(identifier:)
      @raw_identifier = identifier.to_s.strip
      @email = normalize_email(@raw_identifier)
      @phone = normalize_phone(@raw_identifier)
    end

    def call
      # Check if user already exists
      if @email.present?
        if User.exists?(email: @email)
          return Result.new(success?: false, pending_registration: nil, errors: ['Email is already registered. Please login instead.'])
        end
        pending = PendingRegistration.find_or_initialize_by(email: @email)
      elsif @phone.present?
        if User.exists?(phone: @phone)
          return Result.new(success?: false, pending_registration: nil, errors: ['Phone is already registered. Please login instead.'])
        end
        pending = PendingRegistration.find_or_initialize_by(phone: @phone)
      else
        return Result.new(success?: false, pending_registration: nil, errors: ['Invalid email or phone'])
      end
      pending.current_step = 'initiate'
      pending.completed = false
      pending.expires_at = 24.hours.from_now

      # Generate and "send" OTP (in real app, send via email/SMS)
      pending.generate_otp!

      # Send OTP via email or SMS depending on identifier
      if pending.email.present?
        SignupMailer.send_otp(pending).deliver_now
      elsif pending.phone.present?
        begin
          send_phone_otp(pending.phone, pending.otp_code)
        rescue => e
          Rails.logger.warn("Failed to send signup OTP: #{e.class} #{e.message}")
        end
      end

      Result.new(success?: true, pending_registration: pending, errors: [])
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, pending_registration: nil, errors: e.record.errors.full_messages)
    end

    private

    def normalize_email(value)
      val = value.to_s.strip
      return nil unless val.match?(/\A[^\s@]+@[^\s@]+\.[^\s@]+\z/)
      val.downcase
    end

    def normalize_phone(value)
      digits = value.to_s.gsub(/\D/, '')
      return nil unless digits.match?(/\A[6-9]\d{9}\z/)
      digits
    end

    def send_phone_otp(phone_number, otp_code)
      if whatsapp_otp_enabled?
        begin
          WhatsappService.new.send_registration_otp(phone_number, otp_code)
          return
        rescue => e
          Rails.logger.warn("Failed to send signup OTP via WhatsApp, falling back to SMS: #{e.class} #{e.message}")
        end
      end

      SmsService.new.send_registration_otp(phone_number, otp_code)
    end

    def whatsapp_otp_enabled?
      ENV.fetch('WHATSAPP_OTP_ENABLED', 'true') == 'true'
    end
  end
end


