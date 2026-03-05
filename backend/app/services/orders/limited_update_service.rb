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
