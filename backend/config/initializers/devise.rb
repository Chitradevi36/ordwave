# frozen_string_literal: true

Devise.setup do |config|
  config.mailer_sender = ENV.fetch('MAILER_FROM', 'noreply@omnidist.com')
  config.mailer = 'DeviseMailer'

  require 'devise/orm/active_record'

  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]
  config.skip_session_storage = [:http_auth, :token_auth]

  config.stretches = Rails.env.test? ? 1 : 12

  config.reconfirmable = true
  config.expire_all_remember_me_on_sign_out = true

  config.password_length = 8..128
  config.email_regexp = URI::MailTo::EMAIL_REGEXP

  config.reset_password_within = 6.hours
  config.sign_out_via = :delete

  # JWT configuration
  config.jwt do |jwt|
    jwt.secret = ENV.fetch('DEVISE_JWT_SECRET_KEY', Rails.application.secret_key_base)
    jwt.dispatch_requests = [
      ['POST', %r{^/api/v1/auth/login$}]
    ]
    jwt.revocation_requests = [
      ['DELETE', %r{^/api/v1/auth/logout$}]
    ]
    jwt.expiration_time = 24.hours.to_i
  end

  config.navigational_formats = []
end
