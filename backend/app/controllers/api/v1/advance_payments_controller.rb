module Api
  module V1
    class AdvancePaymentsController < BaseController
      before_action :require_organization!
      before_action :set_advance, only: %i[show apply refund]

      # ── GET /api/v1/advance_payments ──────────────────────────────────────
      def index
        base  = policy_scope(AdvancePayment).includes(:customer, :source_payment)
        base  = base.where(customer_id: params[:customer_id]) if params[:customer_id].present?
        base  = base.by_status(params[:status])               if params[:status].present?
        items = paginate(base.recent)

        render_success(
          items.map { |a| serialize_advance(a) },
          meta: pagination_meta(items)
        )
      end

      # ── GET /api/v1/advance_payments/:id ──────────────────────────────────
      def show
        authorize @advance
        render_success(serialize_advance(@advance))
      end

      # ── POST /api/v1/advance_payments/:id/apply ───────────────────────────
      def apply
        authorize @advance, :apply?

        invoice = current_organization.sales_invoices.find(params[:invoice_id])
        amount  = params[:amount].to_d

        result = Payments::ApplyAdvanceService.call(
          actor:           current_user,
          advance_payment: @advance,
          invoice:         invoice,
          amount:          amount
        )

        if result.success?
          render_success(serialize_advance(@advance.reload))
        else
          render_errors(result.errors)
        end
      end

      # ── POST /api/v1/advance_payments/:id/refund ──────────────────────────
      def refund
        authorize @advance, :refund?

        result = Payments::RefundAdvanceService.call(
          actor:           current_user,
          advance_payment: @advance,
          reason:          params[:reason].to_s.strip
        )

        if result.success?
          render_success(serialize_advance(result.advance_payment))
        else
          render_errors(result.errors)
        end
      end

      private

      def set_advance
        @advance = policy_scope(AdvancePayment).find(params[:id])
      end

      def serialize_advance(adv)
        {
          id:              adv.id,
          organization_id: adv.organization_id,
          customer:        { id: adv.customer_id, name: adv.customer&.name },
          source_payment:  { id: adv.source_payment_id, number: adv.source_payment&.payment_number },
          original_amount: adv.original_amount,
          balance:         adv.balance,
          status:          adv.status,
          refunded_at:     adv.refunded_at,
          notes:           adv.notes,
          created_at:      adv.created_at
        }
      end
    end
  end
end
