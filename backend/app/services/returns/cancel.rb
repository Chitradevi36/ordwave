module Returns
  # Cancels a draft or submitted ReturnRequest.
  # If QC has already been completed (inventory movements posted),
  # cancellation is blocked in v1 to prevent orphaned movements.
  #
  class Cancel
    Result = Struct.new(:success?, :return_request, :errors)

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(actor:, return_request:, reason:)
      @actor          = actor
      @return_request = return_request
      @reason         = reason
    end

    def call
      unless @return_request.cancellable?
        return Result.new(false, @return_request,
          ["Cannot cancel a return in '#{@return_request.status}' status. " \
           'Inventory movements have already been posted; contact support to reverse.'])
      end

      if @reason.blank?
        return Result.new(false, @return_request, ['Cancellation reason is required'])
      end

      ActiveRecord::Base.transaction do
        @return_request.transition_to!('cancelled', reason: @reason)

        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @return_request.organization,
          auditable:    @return_request,
          action:       'return_cancelled',
          changes:      {
            status:               'cancelled',
            cancellation_reason:  @reason,
            cancelled_at:         @return_request.cancelled_at
          }
        )

        Result.new(true, @return_request, [])
      end
    rescue ActiveRecord::RecordInvalid => e
      Result.new(false, @return_request, [e.message])
    end
  end
end
