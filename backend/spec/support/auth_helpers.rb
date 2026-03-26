# frozen_string_literal: true

# Shared authentication helpers for request / controller specs.
# Include via `config.include AuthHelpers, type: :request` in rails_helper.rb
# or use the shared context `with_authenticated_user`.
module AuthHelpers
  def generate_jwt_for(user)
    payload = {
      sub:   user.id,
      email: user.email,
      jti:   SecureRandom.uuid,
      exp:   24.hours.from_now.to_i
    }
    JWT.encode(payload, Rails.application.secret_key_base, "HS256")
  end

  def auth_headers(user = nil)
    user ||= defined?(owner) ? owner : create(:user)
    org    = user.organization

    {
      "Authorization"     => "Bearer #{generate_jwt_for(user)}",
      "X-Organization-Id" => org.id.to_s,
      "Content-Type"      => "application/json"
    }
  end
end
