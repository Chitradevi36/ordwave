# frozen_string_literal: true

module Web
  # Base controller for all web-rendered (HTML) admin views.
  #
  # Unlike Api::V1::BaseController (ActionController::API + JWT), this
  # controller uses ActionController::Base (cookie sessions) so it can:
  #   - render ERB views and layouts
  #   - use Devise's cookie-based authenticate_user!
  #   - use flash messages
  #
  # Organization is resolved from:
  #   1. session[:current_organization_id] (set after org selection)
  #   2. the first active org the user belongs to (auto-select for single-org users)
  class BaseController < ActionController::Base
    include Pundit::Authorization

    protect_from_forgery with: :exception

    before_action :authenticate_user!
    before_action :set_current_organization
    before_action :require_organization!
    before_action :set_current_context

    rescue_from Pundit::NotAuthorizedError,             with: :handle_unauthorized
    rescue_from ActiveRecord::RecordNotFound,           with: :handle_not_found

    after_action :verify_authorized,        except: %i[index]
    after_action :verify_policy_scoped,     only:   %i[index]

    helper_method :current_organization, :current_user

    private

    # ── Pundit ───────────────────────────────────────────────────────────────

    def pundit_user
      UserContext.new(user: current_user, organization: current_organization)
    end

    # ── Organization resolution ──────────────────────────────────────────────

    def set_current_organization
      @current_organization = resolve_organization
    end

    def resolve_organization
      # 1. Explicit session selection
      if session[:current_organization_id].present?
        org = Organization.active.find_by(id: session[:current_organization_id])
        return org if org && current_user&.membership_for(org).present?
      end

      # 2. Auto-resolve: first active org the user is a member of
      org = current_user
              &.memberships
              &.active
              &.includes(:organization)
              &.first
              &.organization
      session[:current_organization_id] = org&.id
      org
    end

    def current_organization
      @current_organization
    end

    def require_organization!
      return if current_organization.present?

      redirect_to root_path, alert: "No active organization found for your account."
    end

    # ── Context ───────────────────────────────────────────────────────────────

    def set_current_context
      Current.user         = current_user
      Current.organization = current_organization
      Current.request_id   = request.uuid
    end

    # ── Error handlers ────────────────────────────────────────────────────────

    def handle_unauthorized
      redirect_back fallback_location: root_path,
                    alert: "You are not authorized to perform that action."
    end

    def handle_not_found
      redirect_back fallback_location: root_path,
                    alert: "The requested record could not be found."
    end
  end
end
