# frozen_string_literal: true

# Custom RSpec matchers for API response assertions.
#
# Usage:
#   expect(response).to have_http_status(:ok)
#   expect(json_body["data"]).to include("id", "name")
#   expect(response).to be_json_content_type
module ApiHelpers
  # Parse the JSON response body (memoised per example)
  def json_body
    @json_body ||= JSON.parse(response.body)
  end

  # Reset between examples
  def self.included(base)
    base.after { @json_body = nil }
  end
end

RSpec::Matchers.define :be_json_content_type do
  match do |response|
    response.content_type&.include?("application/json")
  end

  failure_message do |response|
    "expected Content-Type to include application/json, got #{response.content_type}"
  end
end

RSpec::Matchers.define :have_json_key do |key|
  match do |response|
    body = JSON.parse(response.body)
    body.key?(key.to_s)
  end
end
