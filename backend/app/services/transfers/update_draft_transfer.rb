module Transfers
  class UpdateDraftTransfer
    Result = Struct.new(:success?, :transfer, :errors)

    def initialize(transfer:, params:, actor:)
      @transfer = transfer
      @params   = params.is_a?(ActionController::Parameters) ? params.to_h.deep_symbolize_keys : params
      @actor    = actor
    end

    def call
      unless @transfer.editable?
        return Result.new(false, @transfer, ["Transfer cannot be edited in '#{@transfer.status}' status"])
      end

      ActiveRecord::Base.transaction do
        update_scalars
        sync_lines
        if @transfer.save
          Credit::AuditLogger.log(
            actor:        @actor,
            organization: @transfer.organization,
            auditable:    @transfer,
            action:       'transfer_updated',
            changes:      { status: @transfer.status }
          )
          Result.new(true, @transfer, [])
        else
          raise ActiveRecord::Rollback
          Result.new(false, @transfer, @transfer.errors.full_messages)
        end
      end || Result.new(false, @transfer, @transfer.errors.full_messages)
    end

    private

    def update_scalars
      @transfer.assign_attributes(
        @params.slice(:destination_branch_id, :transfer_date, :notes)
               .reject { |_, v| v.nil? }
      )
    end

    def sync_lines
      return unless @params[:lines].is_a?(Array)

      # Replace lines: destroy existing, rebuild
      @transfer.lines.destroy_all
      @params[:lines].each do |attrs|
        @transfer.lines.build(
          product_id:    attrs[:product_id],
          qty_requested: attrs[:qty_requested]
        )
      end
    end
  end
end
