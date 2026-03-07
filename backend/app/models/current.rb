# Thread-local storage for the currently authenticated user and organization.
# Set in Api::V1::BaseController before_action :set_current_context.
class Current < ActiveSupport::CurrentAttributes
  attribute :user, :organization, :request_id
end
