module Returns
  # Submits a draft ReturnRequest.
  # Locks pricing snapshots from linked SalesOrderLine (or manual entry) and
  # transitions status → submitted.
  #
  class Submit
    Result = Struct.new(:success?, :return_request, :errors)

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(actor:, return_request:)
      @actor          = actor
      @return_request = return_request
    end

    def call
      unless @return_request.draft?
        return Result.new(false, @return_request, ['Only draft returns can be submitted'])
      end

      unless @return_request.lines.any?
        return Result.new(false, @return_request, ['At least one line is required'])
      end

      invalid = @return_request.lines.select { |l| l.qty_reported.to_d <= 0 }
      if invalid.any?
        return Result.new(false, @return_request, ['All lines must have qty_reported > 0'])
      end

      ActiveRecord::Base.transaction do
        lock_price_snapshots!
        @return_request.transition_to!('submitted')

        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @return_request.organization,
          auditable:    @return_request,
          action:       'return_submitted',
          changes:      { status: 'submitted', submitted_at: @return_request.submitted_at }
        )

        Result.new(true, @return_request, [])
      end
    rescue ActiveRecord::RecordInvalid => e
      Result.new(false, @return_request, [e.message])
    end

    private

    def lock_price_snapshots!
      @return_request.lines.each do |line|
        next if line.unit_price_snapshot.present?

        # Prefer price from linked order line
        if line.sales_order_line.present?
          sol = line.sales_order_line
          line.update_columns(
            unit_price_snapshot: sol.unit_price,
            gst_rate_snapshot:   sol.gst_rate,
            hsn_code_snapshot:   sol.hsn_code
          )
        else
          # Fall back to product base data — caller may have pre-populated snapshots on creation
          line.update_columns(
            unit_price_snapshot: line.unit_price_snapshot || line.product.try(:base_price) || 0,
            gst_rate_snapshot:   line.gst_rate_snapshot   || line.product.try(:gst_rate)   || 0,
            hsn_code_snapshot:   line.hsn_code_snapshot   || line.product.try(:hsn_code)
          )
        end
      end
    end
  end
end
