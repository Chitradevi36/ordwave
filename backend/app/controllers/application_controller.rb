class ApplicationController < ActionController::API
  # Append structured context for lograge
  def append_info_to_payload(payload)
    super
    payload[:request_id]      = Current.request_id
    payload[:user_id]         = Current.user&.id
    payload[:organization_id] = Current.organization&.id
  end
end