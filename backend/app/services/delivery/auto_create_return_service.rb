module Delivery
  # Automatically creates a ReturnRequest (source_type: 'delivery') from
  # the rejection records on a TripStop after a partial delivery outcome.
  #
  # Called asynchronously (after DB transaction commits) from
  # Delivery::CompleteStopService so the return is already persisted when
  # warehouse staff are notified.
  #
  # Usage:
  #   result = Delivery::AutoCreateReturnService.call(stop: trip_stop, actor: user)
  #   result[:ok]            # => true | false
  #   result[:return_request] # => ReturnRequest or nil
  #   result[:errors]        # => []
  #
  class AutoCreateReturnService
    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(stop:, actor:)
      @stop  = stop
      @actor = actor
    end

    def call
      return { ok: true, return_request: nil, errors: ["No returns to process"] } if @stop.returns.empty?

      trip     = @stop.delivery_trip
      order    = @stop.sales_order
      branch   = trip.branch
      org      = trip.organization
      customer = order.customer

      lines_params = @stop.returns.map do |ret|
        product = Product.find(ret.product_id)
        {
          product_id:              ret.product_id,
          qty_reported:            ret.qty_returned,
          condition_reported:      ret.condition.presence || 'unknown',
          reason_code:             ret.reason_code.presence || 'other',
          unit_price_snapshot:     product.default_price,
          gst_rate_snapshot:       product.gst_rate,
          hsn_code_snapshot:       product.hsn_code
        }
      end

      result = Returns::CreateDraft.call(
        actor:        @actor,
        organization: org,
        branch:       branch,
        params:       {
          customer_id:  customer.id,
          source_type:  'delivery',
          source_id:    @stop.delivery_trip_id,
          return_date:  Date.current,
          notes:        "Auto-created from delivery trip #{trip.trip_number} stop ##{@stop.sequence} (#{@stop.delivery_notes})",
          lines:        lines_params
        }
      )

      return { ok: false, return_request: nil, errors: result.errors } unless result.success?

      # Immediately submit (skip draft) — delivery returns don't need manual submission
      rr = result.return_request
      rr.transition_to!('submitted', actor: @actor)

      # Notify warehouse staff + managers
      notify_warehouse_staff(org: org, branch: branch, return_request: rr)

      { ok: true, return_request: rr, errors: [] }
    rescue StandardError => e
      Rails.logger.error "[AutoCreateReturnService] stop=#{@stop.id}: #{e.message}"
      { ok: false, return_request: nil, errors: [e.message] }
    end

    private

    def notify_warehouse_staff(org:, branch:, return_request:)
      recipients = org.memberships.active
                      .joins(:role)
                      .where(roles: { name: %w[warehouse_staff manager owner admin] })
                      .map(&:user)
                      .uniq
                      .compact

      return if recipients.empty?

      Notifications::CreateService.new(
        organization: org,
        recipients:   recipients,
        actor:        @actor,
        notifiable:   return_request,
        type:         'return_submitted',
        title:        "Return ##{return_request.return_number} submitted for QC",
        body:         "#{return_request.lines.size} item(s) returned from delivery. Branch: #{branch.name}.",
        deep_link:    "/returns/#{return_request.id}",
        severity:     'medium'
      ).call
    rescue StandardError => e
      Rails.logger.warn "[AutoCreateReturnService] Notification failed: #{e.message}"
    end
  end
end
