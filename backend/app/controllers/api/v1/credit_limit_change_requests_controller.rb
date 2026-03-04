module Api
  module V1
    class CreditLimitChangeRequestsController < BaseController
      before_action :require_organization!
      before_action :set_request, only: %i[show decision]

      # GET /api/v1/credit_limit_change_requests
      def index
        requests = policy_scope(CreditLimitChangeRequest)
                     .includes(:credit_account, :requested_by, :decided_by)
                     .order(created_at: :desc)

        requests = requests.where(status: params[:status]) if params[:status].present?
        requests = requests.joins(:credit_account)
                           .where(credit_accounts: { id: params[:credit_account_id] }) if params[:credit_account_id].present?

        paginated = paginate(requests)
        render_success(paginated.map { |r| serialize(r) }, meta: pagination_meta(paginated))
      end

      # GET /api/v1/credit_limit_change_requests/:id
      def show
        authorize @credit_request
        render_success(serialize(@credit_request))
      end

      # POST /api/v1/credit_accounts/:credit_account_id/limit_change_requests
      def create
        credit_account = CreditAccount.where(organization: current_organization)
                                      .find(params[:credit_account_id])
        req = CreditLimitChangeRequest.new(
          credit_account: credit_account,
          requested_by:   current_user,
          new_limit:      params.dig(:credit_limit_change_request, :new_limit),
          reason:         params.dig(:credit_limit_change_request, :reason)
        )
        authorize req

        if req.save
          Credit::AuditLogger.log(
            actor:        current_user,
            organization: current_organization,
            auditable:    credit_account,
            action:       'limit_request_created',
            changes:      { current_limit: credit_account.credit_limit, requested_limit: req.new_limit }
          )
          render_created(serialize(req))
        else
          render_errors(req.errors.full_messages)
        end
      end

      # POST /api/v1/credit_limit_change_requests/:id/decision
      # params: { decision: approved|rejected|countered, counter_offer_limit:, decision_note: }
      def decision
        authorize @credit_request

        decision_value     = params[:decision]
        counter_limit      = params[:counter_offer_limit]
        decision_note      = params[:decision_note]

        unless %w[approved rejected countered].include?(decision_value)
          return render_errors(["decision must be one of: approved, rejected, countered"])
        end

        if decision_value == 'countered' && counter_limit.blank?
          return render_errors(["counter_offer_limit is required when decision is 'countered'"])
        end

        ActiveRecord::Base.transaction do
          @credit_request.update!(
            status:              decision_value,
            decided_by:          current_user,
            decided_at:          Time.current,
            decision_note:       decision_note,
            counter_offer_limit: (decision_value == 'countered' ? counter_limit : nil)
          )

          # If approved — update credit limit on account
          if decision_value == 'approved'
            previous_limit = @credit_request.credit_account.credit_limit
            @credit_request.credit_account.update!(credit_limit: @credit_request.new_limit)

            Credit::AuditLogger.log(
              actor:        current_user,
              organization: current_organization,
              auditable:    @credit_request.credit_account,
              action:       'credit_limit_changed',
              changes:      { from: previous_limit, to: @credit_request.new_limit },
              reason:       @credit_request.reason
            )
          end

          Credit::AuditLogger.log(
            actor:        current_user,
            organization: current_organization,
            auditable:    @credit_request,
            action:       'limit_request_decided',
            changes:      { decision: decision_value, note: decision_note }
          )
        end

        render_success(serialize(@credit_request.reload))
      rescue ActiveRecord::RecordInvalid => e
        render_errors(e.record.errors.full_messages)
      end

      private

      def set_request
        @credit_request = CreditLimitChangeRequest
          .joins(:credit_account)
          .where(credit_accounts: { organization_id: current_organization.id })
          .find(params[:id])
      end

      def serialize(r)
        {
          id:                   r.id,
          credit_account_id:    r.credit_account_id,
          customer_name:        r.credit_account&.customer&.name,
          current_limit:        r.credit_account&.credit_limit,
          new_limit:            r.new_limit,
          counter_offer_limit:  r.counter_offer_limit,
          status:               r.status,
          reason:               r.reason,
          supporting_notes:     r.supporting_notes,
          decision_note:        r.decision_note,
          requested_by:         r.requested_by&.full_name,
          decided_by:           r.decided_by&.full_name,
          decided_at:           r.decided_at,
          sla_breached_at:      r.sla_breached_at,
          created_at:           r.created_at
        }
      end
    end
  end
end
