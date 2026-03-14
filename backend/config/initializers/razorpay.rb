# config/initializers/razorpay.rb
#
# Configures the Razorpay Ruby SDK.
# Credentials are read from environment variables — never hard-code them.
#
# Required environment variables:
#   RAZORPAY_KEY_ID      — found in Razorpay Dashboard → API Keys
#   RAZORPAY_KEY_SECRET  — the secret part of the API key pair
#
# Optional (only needed in production):
#   RAZORPAY_WEBHOOK_SECRET — set when creating a webhook in Razorpay Dashboard

Razorpay.setup(
  ENV.fetch("RAZORPAY_KEY_ID",     ""),
  ENV.fetch("RAZORPAY_KEY_SECRET", "")
)

# Expose webhook secret as a constant so the webhook controller can access it
# without referencing ENV directly (easier to mock in tests).
module Billing
  RAZORPAY_WEBHOOK_SECRET = ENV.fetch("RAZORPAY_WEBHOOK_SECRET", "").freeze
end
