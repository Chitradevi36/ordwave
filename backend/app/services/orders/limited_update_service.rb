module Orders
  # Allows limited updates to submitted/on_hold orders where only a small set
  # of attributes are permitted (delivery_date, notes).
  #
  # Usage:
  #   Orders::LimitedUpdateService.call(actor: current_user, order: order, params: params_hash)
  #
  class LimitedUpdateService
    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(actor:, order:, params:)
      @actor  = actor
      @order  = order
      @params = params.is_a?(ActionController::Parameters) ? params.to_h.symbolize_keys : params
    end

    def call
      return { ok: false, order: @order, errors: ['Order is not limited-editable'] } unless @order.limited_editable?

      permitted = @params.slice(:delivery_date, :notes)

      if permitted.empty?
        return { ok: false, order: @order, errors: ['No editable attributes provided'] }
      end

      @order.assign_attributes(permitted)

      # If actor is a customer, run a credit precheck and enforce hard_block policy
      if @actor.respond_to?(:membership_for) && @actor.membership_for(@order.organization)&.role&.name == 'customer'
        credit_account = @order.customer&.credit_account
        credit_result = Credit::PrecheckService.call(
          credit_account: credit_account,
          product_ids:    @order.lines.map(&:product_id),
          order_total:    @order.total_amount.to_f,
          branch:         @order.branch
        )

        @order.credit_snapshot = (credit_result[:metrics] || {})
        @order.credit_reasons  = (credit_result[:reasons] || [])

        if credit_result[:decision] == Credit::CreditEngine::DECISION_BLOCKED && @order.customer&.credit_block_rule == 'hard_block'
          return { ok: false, order: @order, errors: ['Order blocked by credit policy'] }
        end
      end

      if @order.save
        { ok: true, order: @order.reload, errors: [] }
      else
        { ok: false, order: @order, errors: @order.errors.full_messages }
      end
    rescue ActiveRecord::RecordInvalid => e
      { ok: false, order: @order, errors: [e.message] }
    end
  end
end
module Orders
  # Updates only delivery_date and notes on a submitted or on_hold order.
  # Intended for managers/owners who need to adjust logistics after submission
  # without re-opening the full draft.
  #
  # Usage:
  #   result = Orders::LimitedUpdateService.call(
  #     actor:  current_user,
  #     order:  sales_order,            # must be submitted or on_hold
  #     params: { delivery_date:, notes: }
  #   )
  #
  class LimitedUpdateService
    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(actor:, order:, params:)
      @actor  = actor
      @order  = order
      @params = params
    end

    def call
      return { ok: false, order: @order, errors: ['Order is not in a limited-editable state'] } unless @order.limited_editable?

      ActiveRecord::Base.transaction do
        changes = {}

        if @params.key?(:delivery_date)
          changes[:delivery_date] = [@order.delivery_date, @params[:delivery_date]]
          @order.delivery_date = @params[:delivery_date]
        end

        if @params.key?(:notes)
          changes[:notes] = [@order.notes, @params[:notes]]
          @order.notes = @params[:notes]
        end

        @order.save!

        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @order.organization,
          auditable:    @order,
          action:       'order_updated',
          changes:      changes,
          reason:       nil
        )

        { ok: true, order: @order.reload, errors: [] }
      end
    rescue ActiveRecord::RecordInvalid => e
      { ok: false, order: @order, errors: [e.message] }
    end
  end
end
