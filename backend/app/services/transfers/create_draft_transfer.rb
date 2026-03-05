module Transfers
  class CreateDraftTransfer
    Result = Struct.new(:success?, :transfer, :errors)

    def initialize(params:, organization:, actor:)
      @params       = params.is_a?(ActionController::Parameters) ? params.to_h.deep_symbolize_keys : params
      @organization = organization
      @actor        = actor
    end

    def call
      transfer = StockTransfer.new(
        organization:       @organization,
        created_by:         @actor,
        source_branch_id:   @params[:source_branch_id],
        destination_branch_id: @params[:destination_branch_id],
        transfer_date:      @params[:transfer_date] || Date.current,
        notes:              @params[:notes],
        status:             'draft'
      )

      build_lines(transfer)

      ActiveRecord::Base.transaction do
        if transfer.save
          log_event(transfer, 'transfer_created')
          Result.new(true, transfer, [])
        else
          raise ActiveRecord::Rollback
          Result.new(false, nil, transfer.errors.full_messages)
        end
      end || Result.new(false, nil, transfer.errors.full_messages)
    end

    private

    def build_lines(transfer)
      (@params[:lines] || []).each do |attrs|
        transfer.lines.build(
          product_id:    attrs[:product_id],
          qty_requested: attrs[:qty_requested]
        )
      end
    end

    def log_event(transfer, action)
      Credit::AuditLogger.log(
        actor:        @actor,
        organization: @organization,
        auditable:    transfer,
        action:       action,
        changes:      {
          transfer_number: transfer.transfer_number,
          source_branch:   transfer.source_branch_id,
          destination_branch: transfer.destination_branch_id,
          transfer_date:   transfer.transfer_date
        }
      )
    end
  end
end
