module Api
  module V1
    class BaseController < ApplicationController
      include Pundit::Authorization

      wrap_parameters false

      before_action :authenticate_user!
      before_action :set_current_organization
      before_action :set_current_context

      rescue_from Pundit::NotAuthorizedError,              with: :forbidden
      rescue_from Pundit::AuthorizationNotPerformedError, with: :forbidden
      rescue_from ActiveRecord::RecordNotFound,            with: :not_found
      rescue_from ActiveRecord::RecordInvalid,             with: :unprocessable
      rescue_from PlanLimits::PlanLimitError,              with: :plan_limit_exceeded

      after_action :verify_authorized,             except: :index
      after_action :verify_policy_scoped,          only:   :index

      private

      # ── Auth ──────────────────────────────────────────────────────────────

      def pundit_user
        UserContext.new(user: current_user, organization: current_organization)
      end

      def current_user
        @current_user ||= begin
          payload = jwt_payload
          return nil if payload.blank? || payload['sub'].blank?

          # Check if token is denylisted
          if payload['jti'] && JwtDenylist.exists?(jti: payload['jti'])
            return nil
          end

          User.active.find_by(id: payload['sub'])
        end
      end

      def authenticate_user!
        render json: { errors: ['Unauthorized'] }, status: :unauthorized unless current_user
      end

      def jwt_payload
        token = request.headers['Authorization']&.split(' ')&.last
        return {} unless token

        JWT.decode(token, jwt_secret, true, algorithm: 'HS256').first
      rescue JWT::DecodeError, JWT::ExpiredSignature
        {}
      end

      def jwt_secret
        ENV.fetch('DEVISE_JWT_SECRET_KEY', Rails.application.secret_key_base)
      end

      # ── Multi-tenancy ─────────────────────────────────────────────────────

      def set_current_organization
        # Optional — resolves from X-Organization-Id header if present.
        # Controllers that strictly require it call require_organization! explicitly.
        @current_organization = resolve_organization
      end
      def set_current_context
        Current.user         = current_user
        Current.organization = current_organization
        Current.request_id   = request.uuid
      end
      def require_organization!
        render json: { errors: ['X-Organization-Id header is required'] }, status: :bad_request unless current_organization
      end

      def current_organization
        @current_organization
      end

      def resolve_organization
        org_id = request.headers['X-Organization-Id']
        return nil if org_id.blank?
        return nil unless current_user

        org = Organization.active.find_by(id: org_id)
        return nil unless org

        # CRITICAL: Verify the current user actually has a membership in this org.
        # Without this check, any authenticated user could access any org's data
        # by spoofing the X-Organization-Id header.
        unless current_user.memberships.exists?(organization: org)
          Rails.logger.warn(
            "[SECURITY] User##{current_user.id} attempted to access Organization##{org.id} without membership"
          )
          return nil
        end

        org
      end

      def current_membership
        @current_membership ||= current_user&.membership_for(current_organization)
      end

      def current_branch
        @current_branch ||= current_membership&.branch
      end

      def current_role
        current_membership&.role
      end

      def require_role!(*role_names)
        unless current_role&.name.in?(role_names.map(&:to_s))
          render json: { errors: ['Forbidden'] }, status: :forbidden
        end
      end

      # ── Pagination ────────────────────────────────────────────────────────

      MAX_PER_PAGE = 100

      def paginate(scope)
        per = [[( params[:per_page] || 25).to_i, 1].max, MAX_PER_PAGE].min
        scope.page(params[:page] || 1).per(per)
      end

      def pagination_meta(scope)
        {
          current_page:  scope.current_page,
          total_pages:   scope.total_pages,
          total_count:   scope.total_count,
          per_page:      scope.limit_value
        }
      end

      # ── Response helpers ──────────────────────────────────────────────────

      def render_success(data, status: :ok, meta: nil)
        payload = { data: data }
        payload[:meta] = meta if meta
        render json: payload, status: status
      end

      def render_created(data)
        render_success(data, status: :created)
      end

      def render_errors(errors, status: :unprocessable_entity)
        render json: { errors: Array(errors) }, status: status
      end

      # ── Error handlers ────────────────────────────────────────────────────

      def forbidden
        render json: { errors: ['Forbidden'] }, status: :forbidden
      end

      def not_found
        render json: { errors: ['Not found'] }, status: :not_found
      end

      def unprocessable(exception)
        render_errors(exception.record.errors.full_messages)
      end

      def plan_limit_exceeded(exception)
        render json: {
          errors:     [exception.message],
          limit_type: exception.limit_type,
          current:    exception.current,
          max:        exception.max,
          upgrade_to: exception.upgrade_to
        }, status: :payment_required  # HTTP 402
      end

      # ── Plan limits helper ────────────────────────────────────────────────

      def plan_limits
        @plan_limits ||= PlanLimits.for(current_organization)
      end
    end
  end
end
