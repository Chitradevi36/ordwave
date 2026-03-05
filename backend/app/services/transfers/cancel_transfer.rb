module Transfers
  class CancelTransfer
    Result = Struct.new(:success?, :transfer, :errors)

    def initialize(transfer:, actor:, reason:)
      @transfer = transfer
      @actor    = actor
      @reason   = reason
    end

    def call
      unless @transfer.cancellable?
        return Result.new(false, @transfer,
          ["Transfer cannot be cancelled from '#{@transfer.status}' status"])
      end

      if @reason.blank?
        return Result.new(false, @transfer, ['Cancellation reason is required'])
      end

      ActiveRecord::Base.transaction do
        @transfer.update!(
          status:               'cancelled',
          cancellation_reason:  @reason
        )

        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @transfer.organization,
          auditable:    @transfer,
          action:       'transfer_cancelled',
          changes: {
            transfer_number:     @transfer.transfer_number,
            cancellation_reason: @reason
          }
        )
      end

      Result.new(true, @transfer.reload, [])
    rescue ActiveRecord::RecordInvalid => e
      Result.new(false, @transfer, [e.message])
    end
  end
end
