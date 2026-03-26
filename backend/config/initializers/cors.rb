# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    default_origins = [
      'http://localhost:3000',
      'http://localhost:4400',
      'http://localhost:4000',
      'http://127.0.0.1:3000',
      'http://127.0.0.1:3001',
      'https://ordwave.com',
      'https://app.ordwave.com',
      'https://www.app.ordwave.com',
      'https://www.ordwave.com'
    ]

    env_origins = ENV.fetch('CORS_ALLOWED_ORIGINS', '')
                     .split(',')
                     .map(&:strip)
                     .reject(&:empty?)

    allowed = (default_origins + env_origins).uniq
    # Only allow arbitrary localhost ports in development/test.
    # In production, only explicitly listed origins are permitted.
    allowed << /\Ahttp:\/\/localhost:\d+\z/ if Rails.env.development? || Rails.env.test?

    origins(*allowed)

    resource '*',
      headers: :any,
      expose: ['Authorization', 'X-Organization-Id'],
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true
  end
end
