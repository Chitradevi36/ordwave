module Delivery
  # Completes a trip stop (marks as delivered/partial_delivery/failed).
  # Handles proof of delivery, per-line delivered quantities, return records,
  # and automatically marks the order status accordingly.
  #
  # Usage:
  #   result = Delivery::CompleteStopService.call(
  #     actor:            current_user,
  #     stop:             trip_stop,
  #     idempotency_key:  "uuid",
  #     outcome:          "delivered" | "partial_delivery" | "failed",
  #     delivered_lines:  [{ sales_order_line_id: 1, delivered_qty: 5 }, ...],
  #     returns:          [{ product_id: 1, qty_returned: 2, condition: "good", reason_code: "refused" }],
  #     proof_type:       "photo" | "signature" | "otp" | "override",
  #     photo:            uploaded_file,        # for photo proof
  #     signature_image:  uploaded_file,        # for signature proof
  #     otp_code:         "1234",               # for otp proof
  #     override_reason:  "unreachable area",   # for override proof
  #     latitude:         12.9716,
  #     longitude:        77.5946,
  #     device_id:        "device-uuid",
  #     exception_code:   nil,                  # if outcome is failed
  #     delivery_notes:   "Left with neighbour"
  #   )
  #
  class CompleteStopService
    VALID_OUTCOMES = %w[delivered partial_delivery failed].freeze

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(actor:, stop:, idempotency_key:, outcome:,
                   delivered_lines: [], returns: [], proof_type: 'photo',
                   photo: nil, signature_image: nil, otp_code: nil,
                   override_reason: nil, latitude: nil, longitude: nil,
                   device_id: nil, exception_code: nil, delivery_notes: nil)
      @actor           = actor
      @stop            = stop
      @idempotency_key = idempotency_key
      @outcome         = outcome
      @delivered_lines = Array(delivered_lines)
      @returns         = Array(returns)
      @proof_type      = proof_type
      @photo           = photo
      @signature_image = signature_image
      @otp_code        = otp_code
      @override_reason = override_reason
      @latitude        = latitude
      @longitude       = longitude
      @device_id       = device_id
      @exception_code  = exception_code
      @delivery_notes  = delivery_notes
    end

    def call
      # Idempotency guard — already completed with same key
      if @idempotency_key.present? && @stop.idempotency_key == @idempotency_key && @stop.completed?
        return { ok: true, stop: @stop, errors: [] }
      end

      errors = validate
      return { ok: false, stop: @stop, errors: errors } if errors.any?

      ActiveRecord::Base.transaction do
        # 1. Update stop
        @stop.update!(
          status:         @outcome,
          delivered_at:   Time.current,
          latitude:       @latitude,
          longitude:      @longitude,
          device_id:      @device_id,
          exception_code: @exception_code,
          delivery_notes: @delivery_notes,
          idempotency_key: @idempotency_key
        )

        # 2. Create proof record
        proof = DeliveryProof.new(trip_stop: @stop, proof_type: @proof_type)
        proof.override_reason = @override_reason if @proof_type == 'override'
        proof.overridden_by   = @actor           if @proof_type == 'override'
        if @proof_type == 'otp' && @otp_code.present?
          proof.otp_code_digest = DeliveryProof.digest_otp(@otp_code)
          proof.otp_verified_at = Time.current
        end
        proof.photo           = @photo           if @photo.present?
        proof.signature_image = @signature_image if @signature_image.present?
        proof.save!

        # 3. Update per-line delivered qty
        @delivered_lines.each do |line_data|
          line = @stop.sales_order.lines.find(line_data[:sales_order_line_id])
          line.update!(delivered_qty: line_data[:delivered_qty].to_i)
        end

        # 4. Create return records
        @returns.each do |ret|
          ReturnRecord.create!(
            trip_stop:   @stop,
            product_id:  ret[:product_id],
            qty_returned: ret[:qty_returned].to_i,
            condition:   ret.fetch(:condition, 'good'),
            reason_code: ret[:reason_code],
            notes:       ret[:notes]
          )
          # Increment returned_qty on the matching line
          line = @stop.sales_order.lines.find_by(product_id: ret[:product_id])
          line&.update!(returned_qty: (line.returned_qty || 0) + ret[:qty_returned].to_i)
        end

        # 5. Transition order status
        order = @stop.sales_order.reload
        if @outcome.in?(%w[delivered partial_delivery])
          order.transition_to!(@outcome)
          action = @outcome == 'delivered' ? 'order_delivered' : 'order_partial_delivery'
          Credit::AuditLogger.log(
            actor:        @actor,
            organization: @stop.delivery_trip.organization,
            auditable:    order,
            action:       action,
            changes:      { status: @outcome }
          )
        end

        # 6. Check if whole trip is complete
        check_and_complete_trip!

        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @stop.delivery_trip.organization,
          auditable:    @stop,
          action:       @exception_code.present? ? 'stop_exception_flagged' : 'stop_completed',
          changes:      { outcome: @outcome, stop_sequence: @stop.sequence }
        )

        { ok: true, stop: @stop.reload, errors: [] }
      end.tap do |result|
        # Auto-invoice trigger: enqueue asynchronously after transaction commits
        if result[:ok] && auto_invoice_enabled?
          Invoice::GenerateFromDeliveryJob.perform_later(@stop.id)
        end
      end
    rescue ActiveRecord::RecordInvalid => e
      { ok: false, stop: @stop, errors: [e.message] }
    end

    private

    def validate
      errs = []
      errs << 'Outcome is required' if @outcome.blank?
      errs << "Invalid outcome '#{@outcome}'" unless @outcome.in?(VALID_OUTCOMES)
      errs << 'Stop is already completed' if @stop.completed?
      errs << 'Trip must be dispatched' unless @stop.delivery_trip.dispatched?

      if @outcome == 'failed' && @exception_code.blank?
        errs << 'Exception code is required when outcome is failed'
      end
      if @proof_type == 'override' && @override_reason.blank?
        errs << 'Override reason is required'
      end
      errs
    end

    def auto_invoice_enabled?
      return false unless @outcome.in?(%w[delivered partial_delivery])
      org     = @stop.delivery_trip.organization
      trigger = org.settings&.dig('auto_invoice_trigger').to_s
      # Default to on_delivery when setting is absent
      trigger.blank? || trigger == 'on_delivery'
    end

    def check_and_complete_trip!
      trip = @stop.delivery_trip.reload
      all_complete = trip.stops.not_deleted.all?(&:completed?)
      return unless all_complete

      trip.transition_to!('completed')
      Credit::AuditLogger.log(
        actor:        @actor,
        organization: trip.organization,
        auditable:    trip,
        action:       'trip_completed',
        changes:      { status: 'completed', completed_at: trip.completed_at }
      )
    end
  end
end
