module Api
  module V1
    # Singleton resource — one credit policy per organization.
    # GET  /api/v1/credit_policy
    # PATCH/PUT /api/v1/credit_policy
    class CreditPoliciesController < BaseController
      before_action :require_organization!

      skip_after_action :verify_authorized
      skip_after_action :verify_policy_scoped

      # GET /api/v1/credit_policy
      def show
        policy = CreditPolicy.for_org!(current_organization)
        authorize policy
        render_success(serialize(policy))
      end

      # PATCH /api/v1/credit_policy
      def update
        policy = CreditPolicy.for_org!(current_organization)
        authorize policy

        if policy.update(credit_policy_params)
          Credit::AuditLogger.log(
            actor:        current_user,
            organization: current_organization,
            auditable:    policy,
            action:       'credit_policy_updated',
            changes:      policy.previous_changes.except('updated_at'),
            reason:       params[:reason]
          )
          render_success(serialize(policy))
        else
          render_errors(policy.errors.full_messages)
        end
      end

      private

      def credit_policy_params
        params.require(:credit_policy).permit(
          :hard_block_overdue_days,
          :hard_block_margin_pct,
          :soft_hold_overdue_days_min,
          :soft_hold_overdue_days_max,
          :soft_hold_outstanding_pct,
          :collection_first_bucket,
          :approval_sla_hours_manager,
          :approval_sla_hours_owner,
          :auto_invoice_trigger,
          :allow_partial_allocation
        )
      end

      def serialize(p)
        {
          id:                          p.id,
          hard_block_overdue_days:     p.hard_block_overdue_days,
          hard_block_margin_pct:       p.hard_block_margin_pct,
          soft_hold_overdue_days_min:  p.soft_hold_overdue_days_min,
          soft_hold_overdue_days_max:  p.soft_hold_overdue_days_max,
          soft_hold_outstanding_pct:   p.soft_hold_outstanding_pct,
          collection_first_bucket:     p.collection_first_bucket,
          approval_sla_hours_manager:  p.approval_sla_hours_manager,
          approval_sla_hours_owner:    p.approval_sla_hours_owner,
          auto_invoice_trigger:        p.auto_invoice_trigger,
          allow_partial_allocation:    p.allow_partial_allocation,
          updated_at:                  p.updated_at
        }
      end
    end
  end
end
