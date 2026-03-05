module Returns
  # Creates a draft ReturnRequest with lines.
  #
  # Usage:
  #   result = Returns::CreateDraft.call(
  #     actor:        current_user,
  #     organization: current_organization,
  #     branch:       branch,
  #     params:       {
  #       customer_id:  "...",
  #       source_type:  "manual|delivery|order",
  #       source_id:    nil,
  #       return_date:  Date.current,
  #       notes:        "...",
  #       lines: [
  #         { product_id:, qty_reported:, condition_reported:, reason_code:,
  #           unit_price_snapshot:, gst_rate_snapshot:, hsn_code_snapshot:,
  #           sales_order_line_id: }
  #       ]
  #     }
  #   )
  #   result.success?     # => true | false
  #   result.return_request # => ReturnRequest
  #   result.errors       # => []
  #
  class CreateDraft
    Result = Struct.new(:success?, :return_request, :errors)

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(actor:, organization:, branch:, params:)
      @actor        = actor
      @organization = organization
      @branch       = branch
      @params       = params.is_a?(ActionController::Parameters) ? params.to_h.deep_symbolize_keys : params
    end

    def call
      customer = Customer.not_deleted
                         .where(organization: @organization)
                         .find(@params[:customer_id])

      rr = ReturnRequest.new(
        organization: @organization,
        branch:       @branch,
        customer:     customer,
        created_by:   @actor,
        source_type:  @params[:source_type].presence || 'manual',
        source_id:    @params[:source_id],
        return_date:  @params[:return_date].presence || Date.current,
        notes:        @params[:notes],
        status:       'draft'
      )

      build_lines(rr)

      ActiveRecord::Base.transaction do
        if rr.save
          log_audit(rr, 'return_created')
          Result.new(true, rr, [])
        else
          raise ActiveRecord::Rollback
          Result.new(false, nil, rr.errors.full_messages)
        end
      end || Result.new(false, nil, rr.errors.full_messages)
    rescue ActiveRecord::RecordNotFound => e
      Result.new(false, nil, ["#{e.model} not found"])
    rescue ActiveRecord::RecordInvalid => e
      Result.new(false, nil, [e.message])
    end

    private

    def build_lines(rr)
      Array(@params[:lines]).each do |attrs|
        rr.lines.build(
          product_id:          attrs[:product_id],
          sales_order_line_id: attrs[:sales_order_line_id],
          qty_reported:        attrs[:qty_reported],
          condition_reported:  attrs[:condition_reported].presence || 'unknown',
          reason_code:         attrs[:reason_code].presence || 'other',
          unit_price_snapshot: attrs[:unit_price_snapshot],
          gst_rate_snapshot:   attrs[:gst_rate_snapshot],
          hsn_code_snapshot:   attrs[:hsn_code_snapshot]
        )
      end
    end

    def log_audit(rr, action)
      Credit::AuditLogger.log(
        actor:        @actor,
        organization: @organization,
        auditable:    rr,
        action:       action,
        changes:      {
          return_number: rr.return_number,
          customer_id:   rr.customer_id,
          source_type:   rr.source_type,
          return_date:   rr.return_date,
          line_count:    rr.lines.size
        }
      )
    end
  end
end
